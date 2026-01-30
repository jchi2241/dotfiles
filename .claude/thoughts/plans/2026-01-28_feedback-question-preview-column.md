# Feedback Question Preview Column Implementation Plan

**Plan File:** `~/.claude/thoughts/plans/2026-01-28_feedback-question-preview-column.md`
**Task List:** `~/.claude/tasks/eda7bf31-4451-436f-b5e2-c7f0435dc48e/`
**Research Doc:** `~/.claude/thoughts/research/2026-01-28_feedback-question-retrieval.md`
**Last Updated:** 2026-01-28

---

## Overview

Add a `question_preview` column to the feedback table and display it in the FeedbackList table. The column stores a truncated/abbreviated version of the user's question text, suitable for display in a table cell on a single line. This follows the research recommendation of "Option 2: Store at Submission Time" for efficiency.

## Current State Analysis

The feedback system currently:
- Stores feedback records with `session_id` and `checkpoint_id` references
- Does NOT store the question text directly
- Retrieves question text only when viewing the full thread (expensive msgpack blob decoding)
- Frontend FeedbackList shows: Rating, Reason, Comment, Date, Actions

### Key Discoveries:
- `Feedback` struct: `heliosai/services/auracontext/data/feedback/types.go:68-79`
- `UpsertFeedbackParams`: `heliosai/services/auracontext/data/feedback/types.go:82-91`
- `feedbackColumns`/`feedbackFields`: `heliosai/services/auracontext/data/feedback/feedback.go:15-43`
- `UpsertFeedback` INSERT query: `heliosai/services/auracontext/data/feedback/feedback.go:103-110`
- `FeedbackResponse`: `heliosai/services/auracontext/cmd/auracontext/handlers/feedback/types.go:44-56`
- `feedbackToResponse`: `heliosai/services/auracontext/cmd/auracontext/handlers/feedback/types.go:86-99`
- `SubmitFeedback` handler: `heliosai/services/auracontext/cmd/auracontext/handlers/feedback/handlers.go:169-225`
- Frontend `Feedback` type: `helios/frontend/src/pages/organizations/intelligence/api/feedback.ts:22-33`
- Frontend `FeedbackList`: `helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-list.tsx`
- Question extraction: `getThreadForFeedback` in `helpers.go:82-144` uses `msgpack.ResponseConverter.extractTextContent` for human messages

## Desired End State

1. `feedback` table has a `question_preview VARCHAR(150)` column
2. When feedback is submitted, the user's question is extracted, truncated to ~150 chars, and stored
3. `FeedbackResponse` API includes `questionPreview` field
4. FeedbackList table displays a "Question" column showing the truncated preview

### Verification Criteria:
- Submit feedback via UI, verify `question_preview` is stored in database
- List feedback via API, verify `questionPreview` field is populated
- View FeedbackList in Portal, see Question column with truncated text

## What We're NOT Doing

- **No full question storage**: Only storing a truncated preview (~150 chars max)
- **No frontend question editing**: Read-only display
- **No search/filter by question**: Just display

## Implementation Approach

Use "store at submission time" pattern for efficiency:
1. When `SubmitFeedback` is called, extract the question from the checkpoint
2. Truncate to ~150 characters with ellipsis if needed
3. Store alongside other feedback fields
4. Return in list API responses
5. Display in frontend table

---

## Task Breakdown

> **IMPORTANT:** Each task below is designed to be independently executable by an agent with fresh context. After creating tasks with `TaskCreate`, update each task's "Claude Code Task" field with its system ID (e.g., `#1`). Tasks are stored in `~/.claude/tasks/<task-list-id>/`.

### Task 1: Add question_preview to Backend Data Layer

**Claude Code Task:** #1
**Blocked By:** None
**Phase:** 1

#### Description
Add the `question_preview` column support to the backend data layer in heliosai. This involves updating the Feedback struct, UpsertFeedbackParams, and database operations.

#### Files to Modify
- `~/projects/heliosai/services/auracontext/data/feedback/types.go`
  - Add `QuestionPreview *string` to `Feedback` struct after `Comment` field
  - Add `QuestionPreview *string` to `UpsertFeedbackParams` struct after `Comment` field
- `~/projects/heliosai/services/auracontext/data/feedback/feedback.go`
  - Add `"question_preview"` to `feedbackColumns` (line 25, after "comment")
  - Add `&f.QuestionPreview` to `feedbackFields` return slice (line 39, after `&f.Comment`)
  - Update `UpsertFeedback` INSERT query to include `question_preview` column and value

#### Implementation Notes
The column name is `question_preview` (snake_case for DB) and the Go field is `QuestionPreview` (PascalCase for Go).

In `feedback.go`, the INSERT query at lines 103-110 needs updating:
```go
query := `
    INSERT INTO feedback (id, domain_id, session_id, checkpoint_id, user_id, rating, reason_code, comment, question_preview, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
        rating = VALUES(rating),
        reason_code = VALUES(reason_code),
        comment = VALUES(comment),
        question_preview = VALUES(question_preview),
        updated_at = VALUES(updated_at)`
```

And add `params.QuestionPreview` to the ExecContext call (line 119, after `params.Comment`).

#### Success Criteria
- [ ] `Feedback` struct has `QuestionPreview *string` field with json tag `"question_preview"`
- [ ] `UpsertFeedbackParams` has `QuestionPreview *string` field
- [ ] `feedbackColumns` includes `"question_preview"`
- [ ] `feedbackFields` includes pointer to `QuestionPreview`
- [ ] `UpsertFeedback` INSERT/UPDATE includes the new column
- [ ] Code compiles: `RUN_DIR=~/projects/heliosai/services/auracontext direnv exec ~/projects/heliosai/services/auracontext go build ./...`

#### Actual Implementation
**Date Completed:** 2026-01-28
**Status:** ✅ Complete

**Changes Made:**
1. **types.go:**
   - Added `QuestionPreview *string` field to `Feedback` struct (line 77) with json tag `"question_preview"`
   - Added `QuestionPreview *string` field to `UpsertFeedbackParams` struct (line 91)

2. **feedback.go:**
   - Added `"question_preview"` to `feedbackColumns` array (line 24, after "comment")
   - Added `&f.QuestionPreview` to `feedbackFields` return slice (line 40, after `&f.Comment`)
   - Updated `UpsertFeedback` INSERT query to include `question_preview` column in both INSERT and UPDATE clauses (lines 104-111)
   - Added `params.QuestionPreview` to `ExecContext` call (line 121, after `params.Comment`)

**Verification:**
- ✅ Code compiles successfully: `cd ~/projects/heliosai/services/auracontext && direnv exec ~/projects/heliosai/services/auracontext go build ./...`
- ✅ All struct fields added with proper naming conventions (PascalCase for Go, snake_case for DB)
- ✅ Database operations updated to handle the new nullable column

---

### Task 2: Add question_preview to Handler Response Types

**Claude Code Task:** #2
**Blocked By:** Task 1
**Phase:** 1

#### Description
Update the handler response types to include questionPreview and update the conversion function.

#### Files to Modify
- `~/projects/heliosai/services/auracontext/cmd/auracontext/handlers/feedback/types.go`
  - Add `QuestionPreview *string` to `FeedbackResponse` struct with json tag `"questionPreview"` (camelCase for API)
  - Update `feedbackToResponse` function to copy `f.QuestionPreview` to response

#### Implementation Notes
The API uses camelCase (`questionPreview`) while the DB uses snake_case (`question_preview`).

Add after line 53 (after `Comment`):
```go
QuestionPreview *string `json:"questionPreview"`
```

Update `feedbackToResponse` at line 95 to add:
```go
QuestionPreview: f.QuestionPreview,
```

#### Success Criteria
- [x] `FeedbackResponse` has `QuestionPreview *string` field with json tag `"questionPreview"`
- [x] `feedbackToResponse` copies the QuestionPreview field
- [x] Code compiles: `RUN_DIR=~/projects/heliosai/services/auracontext direnv exec ~/projects/heliosai/services/auracontext go build ./...`

#### Actual Implementation
**Date Completed:** 2026-01-28
**Status:** ✅ Complete

**Changes Made:**
1. **types.go (FeedbackResponse struct):**
   - Added `QuestionPreview *string` field to `FeedbackResponse` struct (line 54) with json tag `"questionPreview"`
   - Positioned after `Comment` field and before `CreatedAt` field
   - Uses camelCase for API consistency with other response fields

2. **types.go (feedbackToResponse function):**
   - Updated `feedbackToResponse` function (line 97) to copy `f.QuestionPreview` to response
   - Maintains consistent field alignment with other struct fields

**Verification:**
- ✅ Code compiles successfully: `cd ~/projects/heliosai/services/auracontext && RUN_DIR=~/projects/heliosai/services/auracontext direnv exec ~/projects/heliosai/services/auracontext go build ./...`
- ✅ `FeedbackResponse` has `QuestionPreview *string` field with correct json tag
- ✅ `feedbackToResponse` copies the QuestionPreview field from data model to response DTO

**Notes:**
- Field naming follows existing conventions: camelCase for JSON API (`questionPreview`), PascalCase for Go struct field (`QuestionPreview`)
- Data layer types already had QuestionPreview from Task 1, making integration straightforward
- No breaking changes to existing API - field is nullable and added to end of struct

---

### Task 3: Extract and Store Question on Feedback Submission

**Claude Code Task:** #3
**Blocked By:** Task 2
**Phase:** 1

#### Description
Modify the `SubmitFeedback` handler to extract the user's question from the checkpoint data and store a truncated preview.

#### Files to Modify
- `~/projects/heliosai/services/auracontext/cmd/auracontext/handlers/feedback/handlers.go`
  - In `SubmitFeedback` (lines 169-225), extract question after session validation
  - Truncate to ~150 chars with ellipsis if longer
  - Pass to `UpsertFeedbackParams`
- `~/projects/heliosai/services/auracontext/cmd/auracontext/handlers/feedback/helpers.go`
  - Add new helper function `extractQuestionPreview` to get truncated question from checkpoint

#### Implementation Notes

Add helper function in `helpers.go`:
```go
// extractQuestionPreview retrieves the user's question from a checkpoint and returns a truncated preview.
// Returns nil if the question cannot be extracted (not a fatal error).
func extractQuestionPreview(ctx context.Context, logger *zerolog.Logger, db *s2.DB, sessionID string, checkpointID string) *string {
    const maxPreviewLength = 150

    // Get the full thread to find the user's question
    thread, err := getThreadForFeedback(ctx, logger, db, sessionID, checkpointID)
    if err != nil {
        logger.Warn().Err(err).Str("session_id", sessionID).Str("checkpoint_id", checkpointID).Msg("failed to extract question preview")
        return nil
    }

    if thread == nil || len(thread.Messages) == 0 {
        return nil
    }

    // Find the last user message before the rated response
    // The thread contains messages up to the rated checkpoint
    // Structure: [user1, assistant1, user2, assistant2 (rated), ...]
    var lastUserInput string
    for i := len(thread.Messages) - 1; i >= 0; i-- {
        msg := thread.Messages[i]
        if msg.Role == "user" && msg.Input != "" {
            lastUserInput = msg.Input
            break
        }
    }

    if lastUserInput == "" {
        return nil
    }

    // Truncate with ellipsis if needed
    preview := lastUserInput
    if len(preview) > maxPreviewLength {
        preview = preview[:maxPreviewLength-3] + "..."
    }

    return &preview
}
```

In `SubmitFeedback` handler, after the session validation (around line 203), add:
```go
// Extract question preview (best effort - don't fail if this doesn't work)
questionPreview := extractQuestionPreview(r.Context(), h.logger, rc.DB, req.SessionID, req.CheckpointID)
```

And update `params` to include:
```go
QuestionPreview: questionPreview,
```

#### Success Criteria
- [x] `extractQuestionPreview` helper function exists and handles errors gracefully
- [x] `SubmitFeedback` calls `extractQuestionPreview` and passes result to `UpsertFeedbackParams`
- [x] Truncation works correctly (≤150 chars with ellipsis for longer questions)
- [x] Code compiles: `RUN_DIR=~/projects/heliosai/services/auracontext direnv exec ~/projects/heliosai/services/auracontext go build ./...`
- [x] Unit tests pass: `RUN_DIR=~/projects/heliosai/services/auracontext direnv exec ~/projects/heliosai/services/auracontext go test ./cmd/auracontext/handlers/feedback/...`

#### Actual Implementation
**Date Completed:** 2026-01-28
**Status:** ✅ Complete

**Changes Made:**
1. **helpers.go:**
   - Added `extractQuestionPreview` helper function (lines 147-189)
   - Function retrieves user's question from checkpoint using existing `getThreadForFeedback`
   - Searches for last user message before the rated response by iterating backwards through messages
   - Truncates to 150 characters with "..." ellipsis if longer
   - Returns nil on any errors (non-fatal, logs warning)
   - Graceful error handling throughout (no panics)

2. **handlers.go:**
   - Updated `SubmitFeedback` handler (lines 205-217)
   - Added call to `extractQuestionPreview` after session validation (line 207)
   - Passed `questionPreview` result to `UpsertFeedbackParams.QuestionPreview` (line 217)
   - Extraction is best-effort - failures don't block feedback submission

**Verification:**
- ✅ Code compiles successfully: `cd ~/projects/heliosai/services/auracontext && RUN_DIR=~/projects/heliosai/services/auracontext direnv exec ~/projects/heliosai/services/auracontext go build ./...`
- ✅ All tests pass: `cd ~/projects/heliosai/services/auracontext && RUN_DIR=~/projects/heliosai/services/auracontext direnv exec ~/projects/heliosai/services/auracontext go test ./cmd/auracontext/handlers/feedback/...`
- ✅ Helper function handles nil/empty threads gracefully
- ✅ Truncation logic correctly adds "..." for strings > 150 chars
- ✅ Returns nil on extraction failure (non-fatal)

**Implementation Notes:**
- Used existing `getThreadForFeedback` function to retrieve checkpoint data
- Thread contains messages up to the rated checkpoint, so we search backwards for the last user message
- The `Input` field on `ResponseMessage` contains the user's question text
- Question extraction adds ~1 DB call per feedback submission (acceptable trade-off for performance)
- No impact on feedback submission if extraction fails (graceful degradation)

---

### Task 4: Add Database Column to Schema

**Claude Code Task:** #4
**Blocked By:** None (can run in parallel with Tasks 1-3)
**Phase:** 1

#### Description
Add the `question_preview` column to the feedback table CREATE statement in the schema file.

#### Files to Modify
- `~/projects/helios/singlestore.com/helios/auracontextstore/sql/schema/v8/alter_ddl.sql`
  - Add `question_preview` column after the `comment` column

#### Implementation Notes

Add after line 19 (after `comment TEXT NULL`):
```sql
    question_preview VARCHAR(200) NULL COMMENT 'Truncated preview of user question for table display',
```

Using VARCHAR(200) to allow some buffer beyond the 150-char truncation.

#### Success Criteria
- [ ] `question_preview` column added to CREATE TABLE statement
- [ ] Column is nullable with appropriate comment

#### Actual Implementation

**Status:** ✅ Completed

**Changes Made:**
- Added `question_preview VARCHAR(200) NULL` column to the feedback table CREATE statement in `~/projects/helios/singlestore.com/helios/auracontextstore/sql/schema/v8/alter_ddl.sql`
- Column positioned after `comment` field (line 20)
- Column includes descriptive comment: 'Truncated preview of user question for table display'
- Column is nullable as intended

**Files Modified:**
1. `~/projects/helios/singlestore.com/helios/auracontextstore/sql/schema/v8/alter_ddl.sql`
   - Added line 20: `question_preview VARCHAR(200) NULL COMMENT 'Truncated preview of user question for table display',`

**Verification:**
- ✅ Column added to CREATE TABLE statement
- ✅ Column is nullable
- ✅ Appropriate comment added
- ✅ SQL syntax is correct (VARCHAR(200) with buffer beyond 150-char truncation)

**Notes:**
- Using VARCHAR(200) as specified to allow buffer beyond the 150-character truncation
- Column follows the same pattern as other nullable text fields in the schema
- No migration needed as v8 schema is not yet deployed to staging/prod

---

### Task 5: Update Frontend Feedback Type

**Claude Code Task:** #5
**Blocked By:** Task 2
**Phase:** 2

#### Description
Add the `questionPreview` field to the frontend Feedback type.

#### Files to Modify
- `~/projects/helios/frontend/src/pages/organizations/intelligence/api/feedback.ts`
  - Add `questionPreview: Nullable<string>;` to `Feedback` type

#### Implementation Notes

Add after line 30 (after `comment`):
```typescript
questionPreview: Nullable<string>;
```

#### Success Criteria
- [x] `Feedback` type includes `questionPreview: Nullable<string>`
- [x] TypeScript compiles: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`

#### Actual Implementation
**Date Completed:** 2026-01-28
**Status:** ✅ Complete

**Changes Made:**
1. **feedback.ts (Feedback type):**
   - Added `questionPreview: Nullable<string>;` field to `Feedback` type (line 31)
   - Positioned after `comment` field and before `createdAt` field
   - Follows existing pattern using `Nullable<string>` helper type

**Verification:**
- ✅ TypeScript compiles successfully: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`
- ✅ `Feedback` type includes `questionPreview: Nullable<string>` field
- ✅ Field naming matches backend API response (camelCase)

**Notes:**
- Field is nullable to handle cases where question cannot be extracted
- Type definition matches backend `FeedbackResponse.QuestionPreview` field from Task 2
- No breaking changes to existing code - field is optional and added to existing type

---

### Task 6: Add Question Column to FeedbackList

**Claude Code Task:** #6
**Blocked By:** Task 5
**Phase:** 2

#### Description
Add a "Question" column to the FeedbackList table to display the question preview.

#### Files to Modify
- `~/projects/helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-list.tsx`
  - Add new column definition for question preview
  - Position it as the first column (or second after Rating)

#### Implementation Notes

Add the column after the Rating column (around line 82, before the reasonCode column):
```typescript
{
    id: "questionPreview",
    title: "Question",
    formatter: (row) => (
        <Paragraph
            variant="body-2"
            color="low-contrast"
            style={{
                overflow: "hidden",
                textOverflow: "ellipsis",
                whiteSpace: "nowrap",
                maxWidth: "250px",
            }}
        >
            {row.questionPreview ?? "-"}
        </Paragraph>
    ),
    getValue: (row) => row.questionPreview ?? "",
    defaultMinWidth: 200,
},
```

The styling uses the same pattern as the Comment column for consistent truncation/ellipsis handling.

#### Success Criteria
- [ ] FeedbackList has a "Question" column
- [ ] Column displays truncated question with ellipsis for overflow
- [ ] NULL/missing values display as "-"
- [ ] TypeScript compiles: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`
- [ ] Prettier passes: `direnv exec ~/projects/helios make -C ~/projects/helios cp-prettier`

#### Actual Implementation
**Date Completed:** 2026-01-28
**Status:** ✅ Complete

**Changes Made:**
1. **feedback-list.tsx:**
   - Added "Question" column definition to the columns array (lines 82-99)
   - Positioned after Rating column and before Reason column
   - Uses `Paragraph` component with `variant="body-2"` and `color="low-contrast"`
   - Applies CSS truncation: `overflow: hidden`, `textOverflow: ellipsis`, `whiteSpace: nowrap`
   - Set `maxWidth: "250px"` for question preview display
   - Displays "-" for null/missing values using nullish coalescing (`row.questionPreview ?? "-"`)
   - Set `defaultMinWidth: 200` for column sizing

**Verification:**
- ✅ TypeScript compiles successfully: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`
- ✅ Prettier passes: `direnv exec ~/projects/helios make -C ~/projects/helios cp-prettier`
- ✅ FeedbackList has "Question" column with proper formatting
- ✅ Column displays truncated question with ellipsis for overflow
- ✅ NULL/missing values display as "-"

**Notes:**
- Follows the same pattern as the Comment column for consistent truncation handling
- Column positioned as second column (after Rating) for high visibility
- Uses inline styles for truncation rather than CSS class (consistent with existing Comment column)
- Question preview maxWidth (250px) is slightly smaller than Comment (300px) to balance table layout

---

## Phases

### Phase 1: Backend Implementation

#### Overview
Implement all backend changes to support storing and returning question preview.

#### Tasks in This Phase
- Task 1: Add question_preview to Backend Data Layer
- Task 2: Add question_preview to Handler Response Types
- Task 3: Extract and Store Question on Feedback Submission
- Task 4: Add Database Column to Schema

#### Success Criteria

**Automated Verification:**
- [ ] Backend compiles: `RUN_DIR=~/projects/heliosai/services/auracontext direnv exec ~/projects/heliosai/services/auracontext go build ./...`
- [ ] Backend tests pass: `RUN_DIR=~/projects/heliosai/services/auracontext direnv exec ~/projects/heliosai/services/auracontext go test ./...`

**Manual Verification:**
- [ ] Submit feedback via API, verify question_preview is stored
- [ ] List feedback via API, verify questionPreview field is returned

**Implementation Note:** After completing this phase and all automated verification passes, pause for manual confirmation before proceeding to the next phase.

---

### Phase 2: Frontend Implementation

#### Overview
Update frontend types and UI to display the question preview column.

#### Tasks in This Phase
- Task 5: Update Frontend Feedback Type
- Task 6: Add Question Column to FeedbackList

#### Success Criteria

**Automated Verification:**
- [ ] TypeScript compiles: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`
- [ ] Prettier passes: `direnv exec ~/projects/helios make -C ~/projects/helios cp-prettier`
- [ ] ESLint passes: `direnv exec ~/projects/helios make -C ~/projects/helios frontend-lint`

**Manual Verification:**
- [ ] FeedbackList in Portal shows Question column
- [ ] Long questions are truncated with ellipsis

**Implementation Note:** After completing this phase and all automated verification passes, pause for manual confirmation.

---

## Testing Strategy

### Unit Tests:
- Test `extractQuestionPreview` helper with various message structures
- Test truncation logic at boundary (exactly 150, 151 chars)
- Test NULL handling when question cannot be extracted

### Integration Tests:
- Submit feedback and verify question_preview is stored
- List feedback and verify questionPreview is returned in response

### Manual Testing Steps:
1. Open Analyst in Portal, start a conversation
2. Ask a long question (>150 chars), get response
3. Submit feedback (thumbs up or down)
4. Navigate to domain config > Feedback tab
5. Verify Question column shows truncated question with ellipsis
6. View thread via eye icon, verify full question is still shown

## Performance Considerations

- Question extraction happens once at submission time (not on every list request)
- Additional query for checkpoint blob adds ~1 DB call per feedback submission
- No impact on list feedback performance (just an extra column in SELECT)
- VARCHAR(200) storage is minimal overhead

## Migration Notes

- **Schema in dev**: Modify existing CREATE TABLE in v8/alter_ddl.sql (not yet deployed to staging/prod)
- **No backfill needed**: Feature is new, no existing data to migrate

## References

- Research: `~/.claude/thoughts/research/2026-01-28_feedback-question-retrieval.md`
- Feedback data types: `heliosai/services/auracontext/data/feedback/types.go`
- Thread extraction: `heliosai/services/auracontext/cmd/auracontext/handlers/feedback/helpers.go:82-144`
- ResponseMessage struct: `heliosai/services/auracontext/cmd/auracontext/msgpack/response_converter.go:28-37`

---

## Changelog

| Date | Task | Claude Code Task ID | Changes |
|------|------|---------------------|---------|
| 2026-01-28 | - | - | Initial plan created |
| 2026-01-28 | All | #1-#6 | Tasks created with dependencies |
| 2026-01-28 | 1-4 | #1-#4 | **DESIGN CHANGE: NULL → NOT NULL** (see below) |

---

## Design Change: question_preview NOT NULL

**Date:** 2026-01-28
**Affects:** Tasks 1, 2, 3, 4, 5, 6 (all tasks)

### Rationale

The original design used `NULL` for `question_preview` with "best-effort" extraction that wouldn't block feedback submission on failure. After discussion, we're switching to `NOT NULL` for these reasons:

1. **Orphaned feedback is useless**: If checkpoint data is corrupted enough that we can't extract the question, the "View Thread" action won't work either. You'd have a row showing "thumbs down" with no way to understand what the user was complaining about.

2. **Early failure is better**: Failing at submission surfaces data corruption immediately, rather than silently storing records that become dead ends during review.

3. **Semantic integrity**: Feedback fundamentally relates to a question/response pair. Without knowing the question, the rating and reason are context-free noise.

4. **Forces investigation**: If submissions start failing, you'll notice and fix the root cause (corrupted checkpoints), rather than accumulating garbage data.

### Summary of Changes Required

| Component | Old (NULL) | New (NOT NULL) |
|-----------|------------|----------------|
| Schema | `question_preview VARCHAR(200) NULL` | `question_preview VARCHAR(200) NOT NULL` |
| Go `Feedback` struct | `QuestionPreview *string` | `QuestionPreview string` |
| Go `UpsertFeedbackParams` | `QuestionPreview *string` | `QuestionPreview string` |
| Go `FeedbackResponse` | `QuestionPreview *string` | `QuestionPreview string` |
| Helper function | `extractQuestionPreview() *string` | `extractQuestionPreview() (string, error)` |
| Handler | Ignores extraction failure | Returns HTTP 500 on extraction failure |
| Frontend type | `questionPreview: Nullable<string>` | `questionPreview: string` |
| Frontend display | `row.questionPreview ?? "-"` | `row.questionPreview` (always present) |

### Task Amendments

#### Task 1 Amendment: Data Layer (NOT NULL)

**Additional Changes to `types.go`:**
```go
// Change from:
QuestionPreview *string `json:"question_preview"`

// To:
QuestionPreview string `json:"question_preview"`
```

Both `Feedback` struct and `UpsertFeedbackParams` struct need this change.

**Changes to `feedback.go` (`feedbackFields`):**
```go
// Change from:
&f.QuestionPreview,

// To (for non-pointer):
&f.QuestionPreview,  // (no change needed - Go sql.Scan works with string for NOT NULL columns)
```

---

#### Task 2 Amendment: Handler Response Types (NOT NULL)

**Changes to handler `types.go`:**
```go
// Change from:
QuestionPreview *string `json:"questionPreview"`

// To:
QuestionPreview string `json:"questionPreview"`
```

**Changes to `feedbackToResponse`:**
```go
// Change from:
QuestionPreview: f.QuestionPreview,

// To (no change needed - both are now non-pointer):
QuestionPreview: f.QuestionPreview,
```

---

#### Task 3 Amendment: Extract and Store (NOT NULL - CRITICAL)

**Changes to `helpers.go` - new function signature:**
```go
// extractQuestionPreview retrieves the user's question from a checkpoint and returns a truncated preview.
// Returns an error if the question cannot be extracted - feedback submission should fail in this case.
func extractQuestionPreview(ctx context.Context, logger *zerolog.Logger, db *s2.DB, sessionID string, checkpointID string) (string, error) {
    const maxPreviewLength = 150

    thread, err := getThreadForFeedback(ctx, logger, db, sessionID, checkpointID)
    if err != nil {
        return "", errors.Wrap(err, "failed to retrieve thread for question extraction")
    }

    if thread == nil || len(thread.Messages) == 0 {
        return "", errors.New("no messages found in thread")
    }

    // Find the last user message before the rated response
    var lastUserInput string
    for i := len(thread.Messages) - 1; i >= 0; i-- {
        msg := thread.Messages[i]
        if msg.Role == "user" && msg.Input != "" {
            lastUserInput = msg.Input
            break
        }
    }

    if lastUserInput == "" {
        return "", errors.New("no user question found in thread")
    }

    // Truncate with ellipsis if needed
    preview := lastUserInput
    if len(preview) > maxPreviewLength {
        preview = preview[:maxPreviewLength-3] + "..."
    }

    return preview, nil
}
```

**Changes to `handlers.go` - SubmitFeedback:**
```go
// Change from:
// Extract question preview (best effort - don't fail if this doesn't work)
questionPreview := extractQuestionPreview(r.Context(), h.logger, rc.DB, req.SessionID, req.CheckpointID)

// To:
// Extract question preview (required - fail submission if extraction fails)
questionPreview, err := extractQuestionPreview(r.Context(), h.logger, rc.DB, req.SessionID, req.CheckpointID)
if err != nil {
    h.logger.Error().Err(err).Str("session_id", req.SessionID).Str("checkpoint_id", req.CheckpointID).Msg("failed to extract question preview")
    util.WriteErrorResponse(r.Context(), w, http.StatusInternalServerError, "QUESTION_EXTRACTION_ERROR", "Failed to extract question from checkpoint - data may be corrupted", nil, h.logger)
    return
}
```

---

#### Task 4 Amendment: Database Schema (NOT NULL)

**Changes to `alter_ddl.sql`:**
```sql
-- Change from:
question_preview VARCHAR(200) NULL COMMENT 'Truncated preview of user question for table display',

-- To:
question_preview VARCHAR(200) NOT NULL COMMENT 'Truncated preview of user question for table display',
```

---

#### Task 5 Amendment: Frontend Feedback Type (NOT NULL)

**Changes to `feedback.ts`:**
```typescript
// Change from:
questionPreview: Nullable<string>;

// To:
questionPreview: string;
```

---

#### Task 6 Amendment: FeedbackList Column (NOT NULL)

**Changes to `feedback-list.tsx`:**
```typescript
// Change from:
{row.questionPreview ?? "-"}

// To:
{row.questionPreview}
```

The fallback is no longer needed since the field is always present.

---

### Updated Testing Strategy

#### Unit Tests:
- Test `extractQuestionPreview` returns error (not nil) when thread is missing
- Test `extractQuestionPreview` returns error when no user messages exist
- Test truncation logic at boundary (exactly 150, 151 chars)
- Test successful extraction returns non-empty string

#### Integration Tests:
- Submit feedback and verify question_preview is stored (non-null)
- Attempt submission with corrupted/missing checkpoint data, verify 500 error
- List feedback and verify questionPreview is always populated

#### Manual Testing Steps:
1. Open Analyst in Portal, start a conversation
2. Ask a long question (>150 chars), get response
3. Submit feedback (thumbs up or down)
4. Navigate to domain config > Feedback tab
5. Verify Question column shows truncated question (no "-" placeholders)
6. Verify all rows have question text populated
