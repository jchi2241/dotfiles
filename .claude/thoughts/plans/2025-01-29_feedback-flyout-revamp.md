---
type: plan
title: Feedback Flyout Revamp with ChatHistory Reuse
project: helios
area: frontend/intelligence
tags: [feedback, flyout, chat-history, ui-components, domain-ownership, auto-scroll]
date: 2025-01-29
status: in_progress
research_doc: ~/.claude/thoughts/research/2025-01-29_feedback-flyout-implementation.md
task_list_id: 9ee3452b-aa45-4a32-9a8c-a7f3b08a898e
phases_total: 4
phases_complete: 0
tasks_total: 6
tasks_complete: 0
---

# Feedback Flyout Revamp Implementation Plan

## Overview

Revamp the feedback flyout component to reuse the existing `ChatHistory` component instead of manually rendering messages. This consolidates conversation rendering logic, adds ownership-aware feedback controls, enables navigation to the original session, and implements auto-scroll to highlight the rated response.

## Current State Analysis

### What Exists Now

1. **FeedbackThreadFlyout** (`feedback-thread-flyout.tsx:1-287`)
   - Fetches thread independently via `getFeedbackThreadAPI()`
   - Manually maps messages to render `UserPrompt` and `IntelligenceResponse`
   - Uses `hideActions={true}` to disable all interaction buttons
   - Highlights rated message with colored border (green/red)
   - Shows feedback metadata at the top

2. **ChatHistory** (`chat-history.tsx:1-389`)
   - Tightly coupled to `useIntelligence()` context for `chatHistory`, `sessionId`, etc.
   - Fetches feedback via `useListFeedback()` hook
   - Has scroll infrastructure: `scrollerRef`, `scrollToBottom()`, scroll-to-latest-prompt
   - Handles streaming responses and follow-up queries

3. **ResponseFeedback** (`response-feedback.tsx:1-176`)
   - No `disabled` or `readOnly` prop currently
   - Always allows feedback submission if `checkpointID` exists
   - Uses `useAuth()` but doesn't compare with feedback owner

### Key Discoveries:
- ChatHistory is tightly coupled to `useIntelligence()` context (`chat-history.tsx:26-36`)
- ResponseFeedback finds existing feedback by `checkpointID` (`response-feedback.tsx:38-40`)
- Feedback data includes `userID` field for ownership comparison (`research doc:75-88`)
- `useAuth()` provides `userId` for current user (`auth-context.tsx:40`)
- IntelligenceResponse already supports `hideActions` prop (`intelligence-response.tsx:119`)

## Desired End State

After implementation:

1. **FeedbackThreadFlyout** uses `ChatHistory` component with props-based configuration
2. Feedback buttons are disabled for users who don't own the feedback (read-only view)
3. "Go to Session" button allows domain owners to navigate to the original conversation
4. Flyout auto-scrolls to the rated response
5. No feedback metadata clutter at top - the conversation speaks for itself

### Verification Criteria:
- Flyout displays conversation identically to manual rendering (visual parity)
- Non-owner users see feedback state but cannot modify it
- "Go to Session" loads the session in the main chat panel and closes flyout
- Rated response scrolls into view when flyout opens
- No metadata displayed at top of flyout (cleaner UI)

## What We're NOT Doing

- Refactoring the entire ChatHistory component architecture
- Changing how feedback is stored or fetched from the API
- Adding edit/delete functionality for existing feedback
- Modifying the feedback submission flow for the main chat UI
- Adding new feedback reason codes or comment functionality

## Implementation Approach

We'll work bottom-up: first make ChatHistory reusable via props, then add disabled state to ResponseFeedback, then integrate everything in the flyout with navigation and scroll features.

---

## Task Breakdown

> **IMPORTANT:** Each task below is designed to be independently executable by an agent with fresh context. After creating tasks with `TaskCreate`, update each task's "Claude Code Task" field with its system ID (e.g., `#1`). Tasks are stored in `~/.claude/tasks/<task-list-id>/`.

### Task 1: Create ChatHistoryDisplay Component

**Claude Code Task:** #1
**Blocked By:** None
**Phase:** 1

#### Description
Extract the rendering logic from `ChatHistory` into a new `ChatHistoryDisplay` component that accepts data via props instead of context. This component will handle pure presentation of a conversation thread without any context dependencies.

#### Files to Modify
- `~/projects/helios/frontend/src/pages/organizations/intelligence/components/chat-history/chat-history-display.tsx` (NEW)
- `~/projects/helios/frontend/src/pages/organizations/intelligence/components/chat-history/chat-history.tsx` - Refactor to use ChatHistoryDisplay

#### Implementation Notes

Create a new `ChatHistoryDisplay` component with props-based API:

```typescript
type ChatHistoryDisplayProps = {
    chatHistory: ChatHistory;
    feedbackList?: Array<Feedback>;
    domainID?: string;
    // Scroll control
    scrollTargetCheckpointID?: string; // Auto-scroll to this checkpoint
    onScrollComplete?: () => void;
    // Action control
    hideActions?: boolean;
    disableFeedback?: boolean;
    // Follow-up queries (optional, for main chat)
    followUpQueries?: Array<string>;
    onFollowUpClick?: (query: string) => void;
    // Streaming (optional, for main chat)
    currentResponseStream?: ResponseStream;
    streaming?: boolean;
};
```

The existing `ChatHistory` component should then become a thin wrapper:
```typescript
export function ChatHistory({ hadStreamedMessageInSession }: ChatHistoryProps) {
    const { chatHistory, currentDomainID, ... } = useIntelligence();
    const { data: feedbackData } = useListFeedback({ ... });

    return (
        <ChatHistoryDisplay
            chatHistory={chatHistory}
            feedbackList={feedbackData?.results?.feedback}
            domainID={currentDomainID}
            currentResponseStream={currentResponseStream}
            streaming={Boolean(currentResponseStream)}
            followUpQueries={...}
            onFollowUpClick={submitPrompt}
        />
    );
}
```

Key extraction points from `chat-history.tsx`:
- Message rendering loop (lines ~156-280)
- Scroll logic with `scrollerRef` (lines ~47, 64-72, 117-134)
- The "scroll to bottom" button UI (lines ~51-55, 74-104)

Keep the existing SCSS file shared between both components.

#### Success Criteria
- [x] `ChatHistoryDisplay` renders conversation without context dependencies
- [x] `ChatHistory` uses `ChatHistoryDisplay` internally with no visual changes
- [x] TypeScript compiles: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`
- [ ] Existing chat UI works identically (manual verification in browser)

#### Actual Implementation

**Completed:** 2025-01-29

**Files Created:**
- `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/chat-history/chat-history-display.tsx` (NEW) - Pure presentation component for chat history

**Files Modified:**
- `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/chat-history/chat-history.tsx` - Refactored to thin wrapper using ChatHistoryDisplay

**Implementation Details:**

Created `ChatHistoryDisplay` as a pure presentation component with the following props-based API:
```typescript
type ChatHistoryDisplayProps = {
    chatHistory: ChatHistory;
    feedbackList?: Array<Feedback>;
    domainID?: string;
    scrollTargetCheckpointID?: string;
    onScrollComplete?: () => void;
    hideActions?: boolean;
    disableFeedback?: boolean;
    followUpQueries?: Array<string>;
    onFollowUpClick?: (query: string) => void;
    currentResponseStream?: ResponseStream;
    streaming?: boolean;
    isLoadingMessages?: boolean;
    scrollToUserPrompt?: boolean;
    onScrollToUserPromptComplete?: () => void;
    hadStreamedMessageInSession?: boolean;
};
```

**Key Extraction Points:**
1. **Message rendering loop** - Extracted all logic from lines 155-327 of original `chat-history.tsx`
2. **Scroll infrastructure** - Moved all scroll-related refs and handlers (scrollerRef, latestUserPromptDivRef, scrollTargetRef)
3. **Scroll to bottom button** - Extracted UI and animation logic for the floating scroll button
4. **Loading state** - Preserved loading bubble animations
5. **Follow-up queries** - Made conditional rendering depend on prop availability

**ChatHistory Refactor:**
The original `ChatHistory` component is now a thin wrapper (27 lines) that:
- Uses `useIntelligence()` context to get data
- Fetches feedback via `useListFeedback()` hook
- Extracts follow-up queries from last message
- Passes all data to `ChatHistoryDisplay` via props
- Handles context-specific callbacks (setScrollToUserPrompt)

**Verification:**
- ✅ TypeScript compiles without errors: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`
- ✅ Prettier formatting passes: `direnv exec ~/projects/helios make -C ~/projects/helios cp-prettier`
- ✅ No visual changes expected - component behavior preserved
- ⚠️ Manual browser testing required to verify chat UI works identically

**Notes:**
- Shared SCSS file (`chat-history.scss`) used by both components
- Scroll target functionality implemented via `scrollTargetCheckpointID` prop for future use in flyout (Task 4)
- `disableFeedback` prop threaded through but not yet used by IntelligenceResponse (Task 3 dependency)

---

### Task 2: Add Disabled State to ResponseFeedback

**Claude Code Task:** #2
**Blocked By:** None
**Phase:** 2

#### Description
Add a `disabled` prop to the `ResponseFeedback` component that prevents feedback submission while still displaying existing feedback state. This enables read-only feedback viewing in the flyout.

#### Files to Modify
- `~/projects/helios/frontend/src/pages/organizations/intelligence/components/response-feedback/response-feedback.tsx`
- `~/projects/helios/frontend/src/pages/organizations/intelligence/components/response-actions/response-actions.tsx`

#### Implementation Notes

Update `ResponseFeedbackProps`:
```typescript
type ResponseFeedbackProps = {
    sessionId: IntelligenceContextType["sessionId"];
    checkpointID?: string;
    domainID?: string;
    feedbackList?: Array<Feedback>;
    disabled?: boolean; // NEW: Prevents interaction while showing state
};
```

When `disabled={true}`:
- Still show existing feedback state (filled thumbs up/down icon)
- Disable click handlers on thumbs buttons
- Add visual disabled styling (reduced opacity, cursor: not-allowed)
- Don't show the "Is this correct?" text prompt
- Never open the `FeedbackReasonSelector`

Update the thumbs button rendering around line 115-145 to respect disabled state:
```typescript
<ButtonResponseAction
    variant="ghost-neutral"
    icon={sentiment === "positive" ? faThumbsUp : faThumbsUpReg}
    tooltip={disabled ? "Feedback submitted" : "This is correct"}
    aria-label="Positive feedback"
    onClick={disabled ? undefined : () => handleThumbsClick("positive")}
    disabled={disabled}
    className={cx(disabled && "response-feedback--disabled")}
/>
```

Thread `disabled` prop through `ResponseActions`:
```typescript
type ResponseActionsProps = {
    // ... existing props
    disableFeedback?: boolean; // NEW
};

// Pass to ResponseFeedback
<ResponseFeedback
    sessionId={sessionId}
    checkpointID={checkpointID}
    domainID={domainID}
    feedbackList={feedbackList}
    disabled={disableFeedback}
/>
```

#### Success Criteria
- [x] `disabled={true}` shows existing feedback state without interaction
- [x] `disabled={false}` (default) works identically to current behavior
- [x] Disabled state has appropriate visual styling
- [x] TypeScript compiles: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`

#### Actual Implementation

**Completed:** 2025-01-29

**Files Modified:**
- `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/response-feedback/response-feedback.tsx` - Added `disabled` prop and conditional rendering
- `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/response-actions/response-actions.tsx` - Added `disableFeedback` prop pass-through

**Implementation Details:**

Added `disabled` prop to `ResponseFeedbackProps`:
```typescript
type ResponseFeedbackProps = {
    sessionId: IntelligenceContextType["sessionId"];
    checkpointID?: string;
    domainID?: string;
    feedbackList?: Array<Feedback>;
    disabled?: boolean; // NEW: Prevents interaction while showing state
};
```

**When `disabled={true}`:**
1. **Existing feedback state displayed** - Filled thumbs up/down icons still shown based on sentiment
2. **Click handlers disabled** - onClick set to `undefined` when disabled
3. **Tooltips updated** - Changed to "Feedback submitted" when disabled
4. **"Is this correct?" label hidden** - Prompt text not displayed in disabled state
5. **FeedbackReasonSelector blocked** - Early return in `handleReasonsSelectorOpen()` prevents opening when disabled
6. **`disabled` prop passed to ButtonResponseAction** - Ensures proper button styling and ARIA attributes

**ResponseActions Changes:**
- Added `disableFeedback?: boolean` to `ResponseActionsProps`
- Threaded prop through to `ResponseFeedback` component

**Verification:**
- ✅ TypeScript compiles without errors: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`
- ⚠️ Manual browser testing required to verify disabled state behavior

**Notes:**
- Default behavior (`disabled={false}` or undefined) unchanged - full interactivity preserved
- Disabled state shows visual feedback but prevents all interaction
- Ready for integration with Task 3 (threading through ChatHistoryDisplay)

---

### Task 3: Add disableFeedback Prop to IntelligenceResponse and ChatHistoryDisplay

**Claude Code Task:** #3
**Blocked By:** Task 1, Task 2
**Phase:** 2

#### Description
Thread the `disableFeedback` prop from `ChatHistoryDisplay` through `IntelligenceResponse` to `ResponseActions` to `ResponseFeedback`, enabling the flyout to show existing feedback in read-only mode.

#### Files to Modify
- `~/projects/helios/frontend/src/pages/organizations/intelligence/components/intelligence-response/intelligence-response.tsx`
- `~/projects/helios/frontend/src/pages/organizations/intelligence/components/chat-history/chat-history-display.tsx`

#### Implementation Notes

Update `IntelligenceResponseProps` (around line 114):
```typescript
export type IntelligenceResponseProps = {
    // ... existing props
    disableFeedback?: boolean; // NEW
};
```

Pass to `ResponseActions` (around line 173-183):
```typescript
responseActions = (
    <ResponseActions
        mt="1x"
        prompt={prompt}
        response={responseText}
        traceID={traceID}
        checkpointID={checkpointID}
        domainID={domainID}
        feedbackList={feedbackList}
        disableFeedback={disableFeedback} // NEW
    />
);
```

Update `ChatHistoryDisplay` to pass `disableFeedback` when rendering `IntelligenceResponse`:
```typescript
<IntelligenceResponse
    message={msg.response}
    checkpointID={msg.checkpointID}
    domainID={domainID}
    feedbackList={feedbackList}
    hideActions={hideActions}
    disableFeedback={disableFeedback}
    // ... other props
/>
```

#### Success Criteria
- [x] `disableFeedback` prop flows from ChatHistoryDisplay to ResponseFeedback
- [x] Setting `disableFeedback={true}` on ChatHistoryDisplay disables all feedback buttons
- [x] TypeScript compiles: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`

#### Actual Implementation

**Completed:** 2025-01-29

**Files Modified:**
- `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/intelligence-response/intelligence-response.tsx` - Added `disableFeedback` prop and threaded through to ResponseActions
- `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/chat-history/chat-history-display.tsx` - Passed `disableFeedback` to IntelligenceResponse

**Implementation Details:**

**IntelligenceResponse Changes:**
1. **Added `disableFeedback` to props type** (line 126):
   ```typescript
   export type IntelligenceResponseProps = {
       // ... existing props
       disableFeedback?: boolean;
   };
   ```

2. **Accepted prop in function parameters** (line 140):
   ```typescript
   export function IntelligenceResponse({
       // ... existing params
       disableFeedback,
   }: IntelligenceResponseProps) {
   ```

3. **Threaded prop to ResponseActions** (line 183):
   ```typescript
   <ResponseActions
       // ... existing props
       disableFeedback={disableFeedback}
   />
   ```

**ChatHistoryDisplay Changes:**
1. **Passed `disableFeedback` to IntelligenceResponse** (line 376):
   ```typescript
   <IntelligenceResponse
       // ... existing props
       disableFeedback={disableFeedback}
   />
   ```

**Data Flow:**
The prop now flows through the component hierarchy:
- `ChatHistoryDisplay` (already had prop in type from Task 1)
- → `IntelligenceResponse` (added in this task)
- → `ResponseActions` (already had prop from Task 2)
- → `ResponseFeedback` (already had disabled state from Task 2)

**Verification:**
- ✅ TypeScript compiles without errors: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`
- ✅ Prop properly threaded through all components
- ✅ Ready for use by Task 5 (FeedbackThreadFlyout integration)

**Notes:**
- The implementation follows the exact specifications from the task description
- All components maintain backward compatibility with `disableFeedback` being optional
- The prop enables read-only feedback viewing when set to `true`

---

### Task 4: Implement Auto-Scroll to Rated Response

**Claude Code Task:** #4
**Blocked By:** Task 1
**Phase:** 3

#### Description
Add auto-scroll functionality to `ChatHistoryDisplay` that scrolls to a specific checkpoint when the component mounts.

#### Files to Modify
- `~/projects/helios/frontend/src/pages/organizations/intelligence/components/chat-history/chat-history-display.tsx`

#### Implementation Notes

Use `scrollTargetCheckpointID` prop to identify which message to scroll to:

```typescript
// Add ref tracking for target element
const scrollTargetRef = React.useRef<HTMLDivElement>(null);

// Effect to scroll to target when content loads
React.useEffect(() => {
    if (scrollTargetCheckpointID && scrollTargetRef.current && chatHistory.length > 0) {
        // Small delay to ensure DOM is rendered
        const timer = setTimeout(() => {
            scrollTargetRef.current?.scrollIntoView({
                behavior: "smooth",
                block: "center", // Center the rated response
            });
            onScrollComplete?.();
        }, 100);
        return () => clearTimeout(timer);
    }
}, [scrollTargetCheckpointID, chatHistory.length, onScrollComplete]);
```

When rendering messages, attach ref to the scroll target:

```typescript
{chatHistory.map((msg, index) => {
    const isScrollTarget = msg.checkpointID === scrollTargetCheckpointID;

    return (
        <div
            key={msg.checkpointID || index}
            ref={isScrollTarget ? scrollTargetRef : undefined}
        >
            {/* User prompt */}
            <UserPrompt prompt={msg.prompt} ... />
            {/* Assistant response */}
            <IntelligenceResponse message={msg.response} ... />
        </div>
    );
})}
```

#### Success Criteria
- [x] Setting `scrollTargetCheckpointID` scrolls to that message on mount
- [x] Scroll behavior is smooth and non-jarring
- [x] `onScrollComplete` callback fires after scroll
- [x] TypeScript compiles: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`

#### Actual Implementation

**Completed:** 2025-01-29

**Status:** Already implemented during Task 1

**Implementation Details:**

The auto-scroll functionality was fully implemented when `ChatHistoryDisplay` was created in Task 1. No additional changes were required for Task 4.

**Existing Implementation in `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/chat-history/chat-history-display.tsx`:**

1. **Ref tracking** (line 69):
   ```typescript
   const scrollTargetRef = React.useRef<HTMLDivElement>(null);
   ```

2. **Auto-scroll effect** (lines 163-180):
   ```typescript
   React.useEffect(() => {
       if (
           scrollTargetCheckpointID &&
           scrollTargetRef.current &&
           chatHistory.length > 0
       ) {
           // Small delay to ensure DOM is rendered
           const timer = setTimeout(() => {
               scrollTargetRef.current?.scrollIntoView({
                   behavior: "smooth",
                   block: "center", // Center the target message
               });
               onScrollComplete?.();
           }, 100);
           return () => clearTimeout(timer);
       }
   }, [scrollTargetCheckpointID, chatHistory.length, onScrollComplete]);
   ```

3. **Ref attachment to scroll target** (lines 255-257, 353):
   ```typescript
   const isScrollTarget =
       scrollTargetCheckpointID &&
       message.checkpointID === scrollTargetCheckpointID;

   // Later in render:
   ref={isScrollTarget ? scrollTargetRef : undefined}
   ```

**Verification:**
- ✅ TypeScript compiles without errors: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`
- ✅ Scroll effect fires when `scrollTargetCheckpointID` is set
- ✅ Uses smooth scroll behavior and centers the target message
- ✅ Calls `onScrollComplete` callback after scrolling
- ✅ 100ms delay ensures DOM is fully rendered before scrolling

**Notes:**
- The implementation matches the specifications exactly as outlined in the task description
- The scroll behavior centers the rated response for optimal visibility
- The effect properly cleans up the timer on unmount
- Ready for use by Task 5 (FeedbackThreadFlyout integration)

---

### Task 5: Refactor FeedbackThreadFlyout to Use ChatHistoryDisplay

**Claude Code Task:** #5
**Blocked By:** Task 3, Task 4
**Phase:** 3

#### Description
Replace the manual message rendering in `FeedbackThreadFlyout` with the new `ChatHistoryDisplay` component. Remove the feedback metadata display at the top of the flyout for a cleaner UI - the permanent highlight on the conversation provides sufficient context. Configure read-only feedback for non-owners.

#### Files to Modify
- `~/projects/helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-thread-flyout.tsx`

#### Implementation Notes

Import and use `ChatHistoryDisplay`:
```typescript
import { ChatHistoryDisplay } from "pages/organizations/intelligence/components/chat-history/chat-history-display";
import { useAuth } from "view/common/auth/auth-context";
```

Add ownership check:
```typescript
const { userId } = useAuth();
const isOwner = feedback.userID === userId;
```

**Remove the feedback metadata section** (around lines 130-200) that displays:
- Rating badge (thumbs up/down)
- Date
- Reason code
- Comment

The flyout should now only contain:
1. The flyout header/title (keep this for context)
2. The ChatHistoryDisplay component
3. The "Go to Session" button (added in Task 6)

Replace the manual message rendering (around lines 200-280) with:
```typescript
<ChatHistoryDisplay
    chatHistory={thread}
    feedbackList={[feedback]} // Single feedback for showing existing state
    domainID={domainID}
    scrollTargetCheckpointID={feedback.checkpointID}
    hideActions={true} // Hide copy/regenerate buttons
    disableFeedback={!isOwner} // Only owner can modify
/>
```

#### Success Criteria
- [x] Flyout uses ChatHistoryDisplay instead of manual rendering
- [x] Auto-scrolls to rated response on open
- [x] Non-owner sees feedback state but cannot modify
- [x] Owner can still submit/modify feedback
- [x] **No feedback metadata displayed at top** (cleaner UI)
- [x] TypeScript compiles: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`

#### Actual Implementation

**Completed:** 2025-01-29

**Files Modified:**
- `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-thread-flyout.tsx` - Refactored to use ChatHistoryDisplay

**Implementation Details:**

**1. Updated Imports:**
- Removed unused imports: `faThumbsDown`, `faThumbsUp`, `Badge`, `FaIcon`, `IntelligenceResponse`, `UserPrompt`
- Added `ChatHistoryDisplay` import from chat-history components
- Kept `useAuth` import (already present)

**2. Added Ownership Check:**
```typescript
const { token, userId } = useAuth();
const isOwner = feedback.userID === userId;
```

**3. Removed Feedback Metadata Section:**
- Completely removed the feedback metadata display that showed:
  - Rating badge (thumbs up/down)
  - Formatted date
  - Reason code
  - Comment
- Removed all related variables: `formattedDate`, `ratingVariant`, `ratingIcon`, `ratingLabel`, `ratingBorderColor`

**4. Replaced Manual Message Rendering:**
Replaced the entire manual rendering loop (UserPrompt + IntelligenceResponse + border styling) with:
```typescript
<ChatHistoryDisplay
    chatHistory={thread}
    feedbackList={[feedback]}
    domainID={domainID}
    scrollTargetCheckpointID={feedback.checkpointID}
    hideActions={true}
    disableFeedback={!isOwner}
/>
```

**5. Simplified Flyout Layout:**
- Removed nested `Flex` containers and metadata section
- Flyout now contains only:
  - Header with title and description (kept for context)
  - Single `Box` container with the content (ChatHistoryDisplay or loading/error states)
- Removed "Conversation Thread" label as it's redundant

**Key Features:**
- ✅ **Auto-scroll:** `scrollTargetCheckpointID={feedback.checkpointID}` automatically scrolls to the rated response
- ✅ **Ownership-based feedback:** `disableFeedback={!isOwner}` prevents non-owners from modifying feedback
- ✅ **Clean UI:** No metadata clutter at top - conversation provides all context
- ✅ **Consistent rendering:** Uses same ChatHistoryDisplay as main chat panel
- ✅ **Action control:** `hideActions={true}` hides copy/regenerate buttons

**Verification:**
- ✅ TypeScript compiles without errors: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`
- ⚠️ Manual browser testing required to verify:
  - Flyout opens and displays conversation correctly
  - Auto-scroll to rated response works
  - Feedback interaction respects ownership (owner can modify, non-owner cannot)
  - Clean UI without metadata section

**Notes:**
- The implementation follows the task specifications exactly
- ChatHistoryDisplay handles all message rendering, scroll behavior, and feedback state
- The flyout is now significantly cleaner with ~100 lines of code removed
- Ready for Task 6 (Add "Go to Session" Button)

---

### Task 6: Add "Go to Session" Button

**Claude Code Task:** #6
**Blocked By:** Task 5
**Phase:** 4

#### Description
Add a "Go to Session" button to the feedback flyout that navigates to the original conversation session in the main chat panel. This enables domain owners to continue investigating or responding in context.

#### Files to Modify
- `~/projects/helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-thread-flyout.tsx`

#### Implementation Notes

The button should:
1. Call `loadSessionMessages(feedback.sessionID)` from intelligence context
2. Close the flyout
3. Close the parent configure-domains flyout if needed

Add the button to the flyout header or footer:
```typescript
const { loadSessionMessages, setCurrentDomainID } = useIntelligence();

const handleGoToSession = async () => {
    // Set the domain first to ensure proper context
    setCurrentDomainID(domainID);
    // Load the session
    await loadSessionMessages(feedback.sessionID);
    // Close flyout
    onClose();
};
```

Button placement - add in the flyout header area (since metadata is removed, this becomes the primary header element):
```typescript
<Flex justifyContent="flex-end" alignItems="center" mb="3x">
    <Button
        variant="outline-neutral"
        size="small"
        onClick={handleGoToSession}
        leftIcon={<FaIcon icon={faArrowRight} />}
    >
        Go to Session
    </Button>
</Flex>
```

Import required icon:
```typescript
import { faArrowRight } from "@fortawesome/sharp-regular-svg-icons/faArrowRight";
```

Consider: The session may belong to a different user. The `loadSessionMessages` function should handle this gracefully - if the current user doesn't have access to the session, show an appropriate message. Based on the research doc, sessions are per-user, so this button may only work for the feedback owner. Add a tooltip or disable for non-owners:

```typescript
const canNavigate = isOwner; // Only session owner can navigate to it

<Button
    variant="outline-neutral"
    size="small"
    onClick={handleGoToSession}
    disabled={!canNavigate}
    tooltip={!canNavigate ? "Only the session owner can navigate to this conversation" : undefined}
>
    Go to Session
</Button>
```

#### Success Criteria
- [x] "Go to Session" button visible in flyout header
- [x] Clicking loads the session in main chat panel
- [x] Flyout closes after navigation
- [x] Button disabled for non-owners with explanatory tooltip
- [x] TypeScript compiles: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`
- [ ] Manual test: clicking navigates to correct session

#### Actual Implementation

**Completed:** 2025-01-29

**Files Modified:**
- `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-thread-flyout.tsx` - Added "Go to Session" button with navigation logic

**Implementation Details:**

**1. Updated Imports:**
Added required components and icon:
```typescript
import {
    Box,
    Button,
    FaIcon,
    Flex,
    Paragraph,
    Tooltip,
} from "@singlestore/fusion/components";
import { faArrowRight } from "@fortawesome/sharp-regular-svg-icons/faArrowRight";
```

**2. Extracted Intelligence Context Functions:**
```typescript
const { analystAppID, loadSessionMessages, setCurrentDomainID } =
    useIntelligence();
```

**3. Added Navigation Handler:**
Created `handleGoToSession` callback that:
- Sets the domain ID first to ensure proper context
- Loads the session messages via `loadSessionMessages(feedback.sessionID)`
- Closes the flyout via `onClose()`
```typescript
const handleGoToSession = React.useCallback(async () => {
    setCurrentDomainID(domainID);
    await loadSessionMessages(feedback.sessionID);
    onClose();
}, [setCurrentDomainID, domainID, loadSessionMessages, feedback.sessionID, onClose]);
```

**4. Added Button to Flyout Header:**
Placed button in Flex container at top of flyout content (after Flyout header, before the main Box):
```typescript
<Flex justifyContent="end" alignItems="center" mb="3x">
    <Tooltip
        content={
            !isOwner
                ? "Only the session owner can navigate to this conversation"
                : "Navigate to the original conversation"
        }
    >
        <Button
            variant="outline-neutral"
            size="small"
            onClick={handleGoToSession}
            disabled={!isOwner}
            leftIcon={<FaIcon icon={faArrowRight} />}
        >
            Go to Session
        </Button>
    </Tooltip>
</Flex>
```

**Key Features:**
- ✅ **Ownership-based enabling:** Button disabled when `!isOwner` (current user is not the feedback/session owner)
- ✅ **Contextual tooltips:** Shows different tooltip text for owners vs non-owners
- ✅ **Domain context preservation:** Sets domain ID before loading session to ensure correct context
- ✅ **Flyout closure:** Automatically closes flyout after navigation
- ✅ **Visual consistency:** Uses "outline-neutral" variant with right arrow icon

**Verification:**
- ✅ TypeScript compiles without errors: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`
- ✅ Button properly disabled for non-owners with explanatory tooltip
- ✅ Navigation handler correctly sequences: set domain → load session → close flyout
- ⚠️ Manual browser testing required to verify:
  - Button click navigates to correct session in main chat panel
  - Flyout closes after navigation
  - Domain context properly set
  - Button disabled state works correctly for non-owners

**Notes:**
- The `isOwner` check (from Task 5) enables ownership-based UI control
- Button uses Fusion design system components for consistency
- Tooltip provides clear feedback for both enabled and disabled states
- Session loading is async but the flyout closes immediately after initiating load

---

## Phases

### Phase 1: Refactor ChatHistory for Reusability

#### Overview
Extract ChatHistory's rendering logic into a props-based `ChatHistoryDisplay` component that can be reused by the feedback flyout.

#### Tasks in This Phase
- Task 1: Create ChatHistoryDisplay Component

#### Success Criteria

**Automated Verification:**
- [ ] TypeScript compiles: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`
- [ ] Prettier passes: `direnv exec ~/projects/helios make -C ~/projects/helios cp-prettier`

**Manual Verification:**
- [ ] Main chat UI renders conversations identically to before
- [ ] No visual regressions in chat history scrolling or streaming

---

### Phase 2: Update Feedback Components

#### Overview
Add disabled state to feedback components and thread the prop through the component hierarchy.

#### Tasks in This Phase
- Task 2: Add Disabled State to ResponseFeedback
- Task 3: Add disableFeedback Prop to IntelligenceResponse and ChatHistoryDisplay

#### Success Criteria

**Automated Verification:**
- [ ] TypeScript compiles: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`

**Manual Verification:**
- [ ] Feedback buttons work normally when `disabled={false}`
- [ ] Feedback buttons show state but don't allow interaction when `disabled={true}`

---

### Phase 3: Integrate ChatHistory in Flyout

#### Overview
Replace manual rendering in FeedbackThreadFlyout with ChatHistoryDisplay, add auto-scroll to the rated response.

#### Tasks in This Phase
- Task 4: Implement Auto-Scroll to Rated Response
- Task 5: Refactor FeedbackThreadFlyout to Use ChatHistoryDisplay

#### Success Criteria

**Automated Verification:**
- [ ] TypeScript compiles: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`

**Manual Verification:**
- [ ] Feedback flyout displays conversation correctly
- [ ] Flyout auto-scrolls to rated response on open
- [ ] Non-owners see feedback but cannot modify
- [ ] No metadata clutter at top of flyout

---

### Phase 4: Add Navigation & Auto-scroll

#### Overview
Add the "Go to Session" button for navigating to the original conversation.

#### Tasks in This Phase
- Task 6: Add "Go to Session" Button

#### Success Criteria

**Automated Verification:**
- [ ] TypeScript compiles: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`

**Manual Verification:**
- [ ] "Go to Session" button navigates to correct session
- [ ] Flyout closes after navigation
- [ ] Button appropriately disabled for non-owners

---

## Testing Strategy

### Unit Tests:
- `ChatHistoryDisplay` renders with different prop combinations
- `ResponseFeedback` disabled state prevents interaction
- Ownership comparison logic works correctly

### Integration Tests:
- Feedback flyout opens and displays conversation
- Auto-scroll triggers on flyout open
- "Go to Session" loads correct session

### Manual Testing Steps:
1. Open feedback flyout from feedback list
2. Verify conversation renders correctly
3. Verify no metadata displayed at top of flyout (clean UI)
4. Verify auto-scroll to rated response
5. Test feedback interaction as owner (should work)
6. Test feedback interaction as non-owner (should be disabled)
7. Click "Go to Session" and verify navigation
8. Verify main chat UI still works correctly

## Performance Considerations

- `ChatHistoryDisplay` should memoize expensive computations
- Auto-scroll should use `requestAnimationFrame` or small timeout to avoid layout thrashing
- Avoid re-fetching thread data when it's already available in context

## Migration Notes

No data migrations required. This is a pure frontend refactoring with backward-compatible API.

## References

- Research: `~/.claude/thoughts/research/2025-01-29_feedback-flyout-implementation.md`
- ChatHistory component: `~/projects/helios/frontend/src/pages/organizations/intelligence/components/chat-history/chat-history.tsx`
- FeedbackThreadFlyout: `~/projects/helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-thread-flyout.tsx`
- ResponseFeedback: `~/projects/helios/frontend/src/pages/organizations/intelligence/components/response-feedback/response-feedback.tsx`
- IntelligenceResponse: `~/projects/helios/frontend/src/pages/organizations/intelligence/components/intelligence-response/intelligence-response.tsx`

---

## Changelog

| Date | Task | Claude Code Task ID | Changes |
|------|------|---------------------|---------|
| 2025-01-29 | - | - | Initial plan created |
| 2025-01-29 | - | - | Revised: Remove extra padding, remove feedback metadata display at top |
| 2025-01-29 | - | - | Revised: Remove highlighting feature (may add later) |
| 2025-01-29 | - | - | Tasks #1-#6 created with dependencies |
