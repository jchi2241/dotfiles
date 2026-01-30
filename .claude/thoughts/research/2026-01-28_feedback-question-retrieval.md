# Research: Efficiently Retrieving Question Text for Feedback Table

## Overview

The FeedbackTab component displays a table of user feedback for domain owners. The screenshot shows a desired UI with a "QUESTION" column displaying the user's original question that triggered the response being rated. Currently, the question text is NOT stored directly with feedback - it must be retrieved from the conversation checkpoint data.

## Current Data Flow

### How Feedback is Stored

**Database Table**: `feedback` (in AuraContext DB)
- Location: `/home/jchi/projects/heliosai/services/auracontext/data/feedback/types.go`

```go
type Feedback struct {
    ID           string     // SHA-256 hash of checkpoint_id:user_id:session_id
    DomainID     string
    SessionID    string     // Reference to conversation session
    CheckpointID string     // Reference to specific message turn
    UserID       string
    Rating       int        // 1 (thumbs up) or -1 (thumbs down)
    ReasonCode   *string
    Comment      *string
    CreatedAt    time.Time
    UpdatedAt    time.Time
}
```

Key point: The feedback record contains `SessionID` and `CheckpointID` but **NOT** the question text itself.

### Where Question Text is Stored

The question text is stored in `checkpoint_blobs` table as msgpack-encoded binary data:

**Tables involved** (from `/home/jchi/projects/heliosai/services/auracontext/data/conversations/checkpoints.go`):
- `checkpoints` - Contains checkpoint metadata and channel versions
- `checkpoint_blobs` - Contains actual message content as binary blobs
- `sessions` - Contains session metadata (title, user_id, domain_id)

**Message blob structure**:
- Channel: `messages`
- Format: MessagePack-encoded array of LangChain message objects
- Decoding: Requires `/home/jchi/projects/heliosai/services/auracontext/cmd/auracontext/msgpack/decoder.go`

### How Question is Currently Retrieved (for Thread View)

When a user clicks the eye icon to view a feedback thread:

1. **Frontend** calls `GET /domains/{domainID}/feedback/{feedbackID}/thread`
   - File: `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/api/feedback.ts:235-262`

2. **Nova Gateway** proxies to AuraContext Service
   - File: `/home/jchi/projects/helios/singlestore.com/helios/cmd/nova-gateway/auracontext/handlers/feedbackhandler.go:104-147`

3. **AuraContext Service** retrieves the full thread:
   - File: `/home/jchi/projects/heliosai/services/auracontext/cmd/auracontext/handlers/feedback/handlers.go:314-372`
   - Calls `getThreadForFeedback()` helper function (lines 357)

4. **Helper function** `getThreadForFeedback()`:
   - File: `/home/jchi/projects/heliosai/services/auracontext/cmd/auracontext/handlers/feedback/helpers.go:82-144`
   - Gets session metadata (line 98)
   - Gets checkpoint blob data (line 104)
   - Gets all checkpoint IDs up to the rated checkpoint (line 123)
   - Decodes msgpack to API response format (line 138)

5. **Decoder** converts binary blob to messages:
   - File: `/home/jchi/projects/heliosai/services/auracontext/cmd/auracontext/msgpack/decoder.go:389-441`
   - `DecodeAndConvertToAPIResponse()` handles the conversion

6. **Response converter** extracts user input:
   - File: `/home/jchi/projects/heliosai/services/auracontext/cmd/auracontext/msgpack/response_converter.go:134-141`
   - Creates `ResponseMessage` with `Input` field for user messages (line 140)

### Frontend Thread Display

**File**: `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-thread-flyout.tsx`

The question is extracted from the user message preceding the rated assistant response:
- Lines 161-167: Gets previous message and extracts text
- Lines 148-157: Renders `UserPrompt` component with `message.output?.[0]?.content?.[0]?.text`

## Key Components

### Backend Services

| Component | File Path | Purpose |
|-----------|-----------|---------|
| Feedback Handler | `heliosai/services/auracontext/cmd/auracontext/handlers/feedback/handlers.go` | HTTP handlers for feedback CRUD |
| Feedback Helpers | `heliosai/services/auracontext/cmd/auracontext/handlers/feedback/helpers.go` | `getThreadForFeedback()` function |
| Feedback Types | `heliosai/services/auracontext/cmd/auracontext/handlers/feedback/types.go` | Request/Response DTOs |
| Feedback Data | `heliosai/services/auracontext/data/feedback/feedback.go` | Database operations |
| Checkpoints Data | `heliosai/services/auracontext/data/conversations/checkpoints.go` | Checkpoint blob queries |
| Sessions Data | `heliosai/services/auracontext/data/conversations/sessions.go` | Session metadata |
| Msgpack Decoder | `heliosai/services/auracontext/cmd/auracontext/msgpack/decoder.go` | Binary blob decoding |
| Response Converter | `heliosai/services/auracontext/cmd/auracontext/msgpack/response_converter.go` | Message transformation |
| Nova Gateway Proxy | `helios/singlestore.com/helios/cmd/nova-gateway/auracontext/handlers/feedbackhandler.go` | Auth & proxy to AuraContext |

### Frontend Components

| Component | File Path | Purpose |
|-----------|-----------|---------|
| FeedbackTab | `helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-tab.tsx` | Container component |
| FeedbackList | `helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-list.tsx` | Table rendering |
| FeedbackThreadFlyout | `helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-thread-flyout.tsx` | Thread detail view |
| Feedback API | `helios/frontend/src/pages/organizations/intelligence/api/feedback.ts` | API hooks and functions |
| Conversations API | `helios/frontend/src/pages/organizations/intelligence/api/conversations.ts` | Message transformation |

## API Endpoints

### List Feedback
- **Route**: `GET /domains/{domainID}/feedback`
- **Response**: `{ results: { feedback: Feedback[] } }`
- **Current fields returned**: id, domainID, sessionID, checkpointID, userID, rating, reasonCode, comment, createdAt, updatedAt
- **Missing**: question text

### Get Feedback Thread
- **Route**: `GET /domains/{domainID}/feedback/{feedbackID}/thread`
- **Response**: `{ results: { feedback: Feedback, thread: SessionMessagesResponse } }`
- **Contains**: Full conversation thread with all messages including user questions

## Options for Efficient Question Retrieval

### Option 1: Add `question` Field to List Feedback Response

**Backend changes required**:

1. **Modify `ListFeedbackResponse`** (`heliosai/services/auracontext/cmd/auracontext/handlers/feedback/types.go:44-56`):
   - Add `Question *string` field to `FeedbackResponse`

2. **Modify `ListFeedback` handler** (`heliosai/services/auracontext/cmd/auracontext/handlers/feedback/handlers.go:228-311`):
   - After fetching feedback list, batch-fetch questions for all items
   - Create helper function to efficiently get questions

3. **Create batch question retrieval function**:
   - Query checkpoint_blobs table for all feedback checkpoint IDs in one query
   - Decode only the first human message from each blob
   - Map questions back to feedback items

**Efficiency consideration**: This requires decoding msgpack blobs for each feedback item. For large lists, this could be expensive.

### Option 2: Store Question Text When Creating Feedback

**Backend changes required**:

1. **Modify feedback table schema**:
   - Add `question` TEXT column to `feedback` table

2. **Modify `SubmitFeedback` handler** (`heliosai/services/auracontext/cmd/auracontext/handlers/feedback/handlers.go:169-225`):
   - Before creating feedback, extract question from checkpoint
   - Store question alongside other feedback fields

3. **Modify `SubmitFeedbackRequest`** (`heliosai/services/auracontext/cmd/auracontext/handlers/feedback/types.go:12-18`):
   - Could either accept question from client OR extract server-side

**Efficiency consideration**: One-time cost at feedback submission. List queries remain fast. Adds storage overhead.

### Option 3: Add Denormalized Question to Checkpoints Table

**Backend changes required**:

1. **Modify checkpoints table**:
   - Add `user_input` TEXT column that stores the human message text

2. **Modify checkpoint creation** (sqlbot side):
   - Extract and store user input when creating checkpoint

3. **Modify `ListFeedback` handler**:
   - JOIN with checkpoints table to get user_input

**Efficiency consideration**: Requires sqlbot changes. Fast queries via JOIN.

### Option 4: Client-Side Batch Fetch

**Frontend changes required**:

1. **Modify `FeedbackList`** (`helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-list.tsx`):
   - After fetching feedback list, batch-fetch threads for visible items
   - Extract questions from threads

**Efficiency consideration**: N+1 problem if not batched. High latency for users. Not recommended.

## Recommended Approach: Option 2 (Store at Submission Time)

**Rationale**:
- Most efficient for list queries (no additional queries or decoding)
- One-time cost at feedback submission
- Question text is immutable after submission anyway
- Aligns with denormalization patterns used elsewhere

**Implementation outline**:

1. **Database migration**: Add `question` column to `feedback` table

2. **Backend - Extract question on submit**:
   - In `SubmitFeedback` handler, after validating session/checkpoint:
   - Fetch checkpoint blob for the checkpointID
   - Decode and find the user message preceding the rated response
   - Store question text with feedback

3. **Backend - Update response types**:
   - Add `Question *string` to `FeedbackResponse`
   - Update `feedbackToResponse()` conversion

4. **Frontend - Display question column**:
   - Add QUESTION column to FeedbackList table
   - Update Feedback type to include `question?: string`

## Database Schema Context

**Current feedback table** (inferred from `/home/jchi/projects/heliosai/services/auracontext/data/feedback/feedback.go:15-26`):
```sql
CREATE TABLE feedback (
    id VARCHAR(64) PRIMARY KEY,  -- SHA-256 hash
    domain_id VARCHAR(36) NOT NULL,
    session_id VARCHAR(36) NOT NULL,
    checkpoint_id VARCHAR(36) NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    rating INT NOT NULL,
    reason_code VARCHAR(100),
    comment TEXT,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    INDEX idx_domain_created (domain_id, created_at DESC)
);
```

**Proposed addition**:
```sql
ALTER TABLE feedback ADD COLUMN question TEXT;
```

## Related Types to Update

### Backend Types

**FeedbackResponse** (`heliosai/services/auracontext/cmd/auracontext/handlers/feedback/types.go:44-56`):
```go
type FeedbackResponse struct {
    ID           string    `json:"id"`
    DomainID     string    `json:"domainID"`
    SessionID    string    `json:"sessionID"`
    CheckpointID string    `json:"checkpointID"`
    UserID       string    `json:"userID"`
    Rating       int       `json:"rating"`
    ReasonCode   *string   `json:"reasonCode"`
    Comment      *string   `json:"comment"`
    Question     *string   `json:"question"`  // NEW FIELD
    CreatedAt    time.Time `json:"createdAt"`
    UpdatedAt    time.Time `json:"updatedAt"`
}
```

### Frontend Types

**Feedback** (`helios/frontend/src/pages/organizations/intelligence/api/feedback.ts:22-33`):
```typescript
export type Feedback = {
    id: string;
    domainID: string;
    sessionID: string;
    checkpointID: string;
    userID: string;
    rating: number;
    reasonCode: Nullable<string>;
    comment: Nullable<string>;
    question: Nullable<string>;  // NEW FIELD
    createdAt: string;
    updatedAt: string;
};
```

## Additional Considerations

### User Display Name

The screenshot also shows a "USER" column with display names (e.g., "Spongebob", "Patrick"). The current feedback stores `userID` but not display name. Similar denormalization may be needed for user names, or:
- Join with user data from another source
- Fetch user info client-side via GraphQL

### Review Status

The screenshot shows a "REVIEW" column with statuses like "Reviewed", "Requested", "Resolved". This appears to be a separate feature (feedback review workflow) not currently implemented based on the codebase exploration.

## Files to Modify (Summary)

### Backend (AuraContext Service)
1. `heliosai/services/auracontext/data/feedback/types.go` - Add Question field to Feedback struct
2. `heliosai/services/auracontext/data/feedback/feedback.go` - Update feedbackColumns and feedbackFields
3. `heliosai/services/auracontext/cmd/auracontext/handlers/feedback/types.go` - Add Question to FeedbackResponse
4. `heliosai/services/auracontext/cmd/auracontext/handlers/feedback/handlers.go` - Extract question on submit
5. Database migration - Add `question` column

### Frontend
1. `helios/frontend/src/pages/organizations/intelligence/api/feedback.ts` - Add question to Feedback type
2. `helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-list.tsx` - Add QUESTION column
