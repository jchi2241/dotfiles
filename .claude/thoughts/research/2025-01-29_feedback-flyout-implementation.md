---
type: research
title: Feedback Flyout Implementation and ChatHistory Component Integration
project: helios
area: frontend/intelligence
tags: [feedback, flyout, chat-history, ui-components, domain-ownership]
date: 2025-01-29
status: complete
related_plans: []
---

# Feedback Flyout Implementation Research

## Overview

The feedback flyout is a modal component in the Helios frontend that displays the full conversation context when reviewing user feedback for the Analyst feature. Currently, it fetches and renders the conversation thread independently from the main chat UI components, resulting in duplicated rendering logic.

## Key Components

### 1. FeedbackThreadFlyout Component
- **Path:** `~/projects/helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-thread-flyout.tsx`
- **Lines:** 1-287
- **Purpose:** Displays full conversation context for a specific feedback item
- **Current Implementation:**
  - Uses the `Flyout` component from `@single-js/common`
  - Fetches thread via `getFeedbackThreadAPI()` independently
  - Manually maps through messages to render `UserPrompt` and `IntelligenceResponse`
  - Passes `hideActions={true}` to `IntelligenceResponse` to disable interaction buttons
  - Highlights the rated message with colored border (green for positive, red for negative)
  - Shows feedback metadata (rating, date, reason, comment) at the top

### 2. ChatHistory Component
- **Path:** `~/projects/helios/frontend/src/pages/organizations/intelligence/components/chat-history/chat-history.tsx`
- **Lines:** 1-389
- **Purpose:** Main conversation display component used in the chat UI
- **Key Features:**
  - Fetches feedback for entire session via `useListFeedback()` hook
  - Passes `feedbackList` down to `IntelligenceResponse` components
  - Handles auto-scrolling, scroll-to-bottom button
  - Renders follow-up queries for last message
  - Supports streaming responses

### 3. ResponseFeedback Component
- **Path:** `~/projects/helios/frontend/src/pages/organizations/intelligence/components/response-feedback/response-feedback.tsx`
- **Lines:** 1-176
- **Purpose:** Thumbs up/down feedback UI with reason selector
- **Key Features:**
  - Shows "Is this correct?" prompt with thumbs buttons
  - Opens `FeedbackReasonSelector` for negative feedback
  - Calls `submitFeedback()` hook to submit feedback
  - Accepts `feedbackList` prop to show existing feedback
  - Currently rendered conditionally inside `ResponseActions`

### 4. IntelligenceResponse Component
- **Path:** `~/projects/helios/frontend/src/pages/organizations/intelligence/components/intelligence-response/intelligence-response.tsx`
- **Purpose:** Response rendering container
- **Key Props:**
  - `hideActions`: Boolean to hide all action buttons (including feedback)
  - `feedbackList`: Array of existing feedback for the session
  - `checkpointID`, `domainID`: Required for feedback submission

### 5. ResponseActions Component
- **Path:** `~/projects/helios/frontend/src/pages/organizations/intelligence/components/response-actions/response-actions.tsx`
- **Purpose:** Container for response interaction buttons
- **Contains:**
  - Copy response button
  - Regenerate response button
  - Debug button (internal only)
  - `ResponseFeedback` component (when prompt exists)

## Data Flow

### Feedback Data Structure
```typescript
type Feedback = {
    id: string;
    domainID: string;
    sessionID: string;
    checkpointID: string;
    userID: string;  // Owner of the feedback
    rating: number;   // 1 for positive, -1 for negative
    reasonCode: Nullable<string>;
    comment: Nullable<string>;
    questionPreview: string;
    createdAt: string;
    updatedAt: string;
};
```

### Current Feedback Flyout Flow
1. User clicks feedback row in `FeedbackList` table
2. `FeedbackThreadFlyout` opens with feedback details
3. Component fetches full thread via `getFeedbackThreadAPI()`
4. Thread is transformed and rendered manually with `UserPrompt` and `IntelligenceResponse`
5. `hideActions={true}` prevents any interaction with the conversation

### ChatHistory Feedback Flow
1. `ChatHistory` fetches all feedback for session via `useListFeedback()`
2. `feedbackList` passed down: ChatHistory → IntelligenceResponse → ResponseActions → ResponseFeedback
3. `ResponseFeedback` finds existing feedback by `checkpointID`
4. Shows existing feedback state or allows new submission

## API Contracts

### Feedback API Endpoints
- **List Feedback:** `GET /v1/organizations/{orgID}/projects/{projectID}/domains/{domainID}/feedback`
- **Submit Feedback:** `POST /v1/organizations/{orgID}/projects/{projectID}/domains/{domainID}/feedback`
- **Get Thread:** `GET /v1/organizations/{orgID}/projects/{projectID}/domains/{domainID}/feedback/{feedbackID}/thread`

### Session/Conversation APIs
- **List Sessions:** `GET /users/{userID}/conversations/sessions`
- **Get Messages:** `GET /users/{userID}/conversations/sessions/{sessionID}/messages`
- **Delete Session:** `DELETE /users/{userID}/conversations/sessions/{sessionID}`

## Dependencies

### Permission System
- **Hook:** `useAgentDomainActionsGranted()` from `~/projects/helios/frontend/src/data/models/permissions.tsx`
- **Usage:** Checks if user has specific domain actions (e.g., `AgentDomainUpdate`, `AgentDomainViewFeedback`)
- **Domain Owner:** Identified by having `AgentDomainUpdate` permission on the domain

### Authentication Context
- **Path:** `~/projects/helios/frontend/src/view/common/auth/auth-context.tsx`
- **Provides:**
  - `token`: Auth token for API calls
  - `userId`: Current user's ID from JWT
  - `email`: User's email
  - `sessionID`: Auth session ID (not chat session)

### Intelligence Context
- **Path:** `~/projects/helios/frontend/src/pages/organizations/intelligence/context/intelligence-context.tsx`
- **Key Functions:**
  - `loadSessionMessages(sessionId)`: Loads a specific session's messages
  - `setSessionId()`: Changes current session
  - `chatHistory`: Current session's message history
  - `sessionId`: Current chat session ID
  - `currentDomainID`: Currently selected domain

## Configuration

### Component Hierarchy
```
FeedbackList (Table View)
└── FeedbackThreadFlyout (Current Implementation)
    ├── Feedback Metadata Display
    └── Manual Message Rendering
        ├── UserPrompt
        └── IntelligenceResponse (hideActions=true)

ChatHistory (Main Chat UI)
├── useListFeedback() → fetch session feedback
└── IntelligenceResponse
    └── ResponseActions
        └── ResponseFeedback
            ├── Thumbs buttons
            └── FeedbackReasonSelector
```

### Session Ownership
- Sessions are created per user (identified by `userID` from JWT)
- Each feedback entry includes the `userID` of who submitted it
- Session messages don't directly store owner information
- Domain owners identified by `AgentDomainUpdate` permission

## Code References

### Key Integration Points for Revamp

1. **Reusing ChatHistory Component:**
   - ChatHistory already handles feedback fetching via `useListFeedback()`
   - Would need modification to accept pre-fetched `chatHistory` data
   - Currently tightly coupled to `useIntelligence()` context

2. **Disabling Feedback for Non-Owners:**
   - ResponseFeedback component would need new prop: `disabled` or `readOnly`
   - Check: `feedback.userID !== currentUser.userId`
   - Currently no mechanism to disable feedback buttons

3. **Go to Session Navigation:**
   - Intelligence context provides `loadSessionMessages(sessionId)` - line 155-157
   - Would need to close flyout and load session in main chat
   - Session belongs to owner if: session was created by feedback.userID

4. **Component Reuse Opportunities:**
   - `IntelligenceResponse` already supports `hideActions` prop
   - `UserPrompt` is already reused between components
   - `ChatHistory` could be extracted to accept props instead of using context directly

### Current Limitations

1. **Context Dependency:** ChatHistory is tightly coupled to `useIntelligence()` context
2. **No Partial Disabling:** ResponseFeedback doesn't support selective disabling
3. **No Session Owner Info:** Sessions don't store owner information directly
4. **No Navigation Support:** No existing "Go to Session" functionality
5. **Duplicate Fetching:** Thread is fetched separately from main chat history

## UX Requirements for Revamp

### Auto-Scroll to Rated Response
The flyout should automatically scroll to the bottom of the conversation thread when opened. The rated response (the one that received feedback) should be front and center for the domain owner reviewing the feedback.

**Implementation Considerations:**
- ChatHistory has existing scroll logic using `scrollerRef` and `scrollIntoView()` (lines 65-72, 117-134)
- The rated message is identified by matching `checkpointID` to `feedback.checkpointID`
- Current ChatHistory scrolls to the latest user prompt; flyout should scroll to the rated response instead

### Extra Padding for Visibility
Add extra padding below the conversation thread to ensure the rated response is prominently visible and not obscured by the viewport edge. This padding ensures the feedback response appears centered/front-and-center rather than stuck at the bottom of the scrollable area.

**Implementation Considerations:**
- Current flyout uses `maxHeight="120x"` on the thread container (line 278)
- Extra bottom padding could be added conditionally after the rated message
- Could use CSS `scroll-margin-bottom` or explicit padding element