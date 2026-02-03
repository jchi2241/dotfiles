---
type: research
title: Feedback Metadata Floating Card Implementation Research
project: helios
area: frontend/intelligence
tags: [feedback, ui, chat-history, floating-card, sticky-positioning]
date: 2025-01-30
status: complete
related_plans: []
---

# Feedback Metadata Floating Card Implementation Research

## Overview

The FeedbackThreadFlyout component currently displays a conversation thread with feedback that has been submitted. The requirement is to display feedback metadata in a floating card alongside the response that the feedback was submitted for (targetCheckpointID), similar to Google Docs comments.

## Key Components

### 1. FeedbackThreadFlyout Component
**Path:** `/home/jchi/projects/helios-chi-feedback-p1-fix-auto-scroll/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-thread-flyout.tsx`

- Main container component that renders the feedback conversation thread
- Receives `feedback` prop containing all feedback metadata (lines 33-37)
- Renders ChatHistoryDisplay with feedback targeting (lines 135-142):
  ```tsx
  <ChatHistoryDisplay
      chatHistory={thread}
      feedbackList={[feedback]}
      domainID={domainID}
      targetCheckpointID={feedback.checkpointID}
      disableFeedback
  />
  ```
- Uses Flyout component with size="large" (line 176)
- Content wrapped in Box with background="surface" and overflow="auto" (line 178)

### 2. FeedbackList Component
**Path:** `/home/jchi/projects/helios-chi-feedback-p1-fix-auto-scroll/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-list.tsx`

Defines the table columns for displaying feedback metadata (lines 64-137):

1. **Question** (lines 65-81): Displays `questionPreview` with ellipsis
2. **Rating** (lines 82-105):
   - Good: Positive badge for rating === 1
   - Bad: Critical badge for rating === -1
3. **Reason** (lines 106-112): Displays `reasonCode` or em-dash
4. **Comment** (lines 113-119): Displays `comment` or em-dash
5. **Created By** (lines 120-127): Uses `<UserPopover userID={row.userID} />`
6. **Created At** (lines 128-136): Uses `formatDateTime(row.createdAt)`

### 3. ChatHistoryDisplay Component
**Path:** `/home/jchi/projects/helios-chi-feedback-p1-fix-auto-scroll/frontend/src/pages/organizations/intelligence/components/chat-history/chat-history-display.tsx`

- Handles the rendering of chat messages with feedback
- Has targetCheckpointID prop for highlighting specific messages (line 29)
- Uses scroll targeting and auto-scroll behavior (lines 165-182)
- Applies highlight animation to targeted messages (line 434)
- Uses `.chat-history__highlight-fade` class for visual feedback

### 4. Feedback Data Structure
**Path:** `/home/jchi/projects/helios-chi-feedback-p1-fix-auto-scroll/frontend/src/pages/organizations/intelligence/api/feedback.ts`

Feedback type definition (lines 22-34):
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
    questionPreview: string;
    createdAt: string;
    updatedAt: string;
};
```

### 5. QueryDetailsCard Pattern Reference
**Path:** `/home/jchi/projects/helios-chi-feedback-p1-fix-auto-scroll/frontend/src/pages/organizations/monitoring/query-history/query-history-details-enhanced-page.tsx`

Example metadata card structure (lines 384-420):
- Uses `<Card p="2x">` as container
- Has heading `<H3 variant="heading-1" mb="2x">`
- Uses Detail components for each metadata field
- Detail component structure (lines 299-319):
  - Title with `<H4 variant="body-1" mb="0-25x">`
  - Value with `<Span variant="body-1" fontWeight="medium">`

CSS Grid layout for details (from `.scss` file):
```scss
.query-event-details {
    display: grid;
    grid-template-columns:
        minmax(var(--sui-size-10x), var(--sui-size-20x))
        minmax(var(--sui-size-10x), var(--sui-size-20x));
    gap: var(--sui-space-2x) var(--sui-space-2-5x);
}
```

## Data Flow

1. FeedbackThreadFlyout receives feedback object from parent
2. Fetches conversation thread using `getFeedbackThreadAPI`
3. Transforms messages using `transformSessionMessages`
4. Passes feedback to ChatHistoryDisplay
5. ChatHistoryDisplay renders IntelligenceResponse components with feedback
6. Targeted checkpoint is highlighted and scrolled into view

## Dependencies

### UI Components
- `@singlestore/fusion/components`: Card, Box, Flex, Badge, Span, H3, H4
- `@single-js/common/components/flyout/flyout`: Flyout container
- `view/common/user-popover`: UserPopover for displaying user info

### Utilities
- `util/date`: formatDateTime for timestamp formatting
- `@single-js/common/util/symbols`: LONG_EM_DASH for empty values

## Configuration

### Positioning Patterns in Codebase
The codebase already uses sticky positioning in several places:
- `.chat-history__scroll-to-bottom` (chat-history.scss:19): Sticky button at bottom
- Python UDF functions list has sticky headers
- Table selector uses sticky positioning
- Fusion markdown components use sticky headers

### Existing Sticky Button Pattern
From chat-history.scss (lines 18-34):
```scss
.chat-history__scroll-to-bottom {
    position: sticky;
    bottom: calc(var(--glass-height, 0px) + var(--sui-space-1x));
    left: 50%;
    transform: translateX(-50%);
    z-index: 5;
}
```

## Code References

- FeedbackThreadFlyout main component: `/home/jchi/projects/helios-chi-feedback-p1-fix-auto-scroll/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-thread-flyout.tsx:39-183`
- FeedbackList columns definition: `/home/jchi/projects/helios-chi-feedback-p1-fix-auto-scroll/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-list.tsx:64-137`
- ChatHistoryDisplay targeting logic: `/home/jchi/projects/helios-chi-feedback-p1-fix-auto-scroll/frontend/src/pages/organizations/intelligence/components/chat-history/chat-history-display.tsx:165-182`
- QueryDetailsCard structure: `/home/jchi/projects/helios-chi-feedback-p1-fix-auto-scroll/frontend/src/pages/organizations/monitoring/query-history/query-history-details-enhanced-page.tsx:323-420`
- Feedback type definition: `/home/jchi/projects/helios-chi-feedback-p1-fix-auto-scroll/frontend/src/pages/organizations/intelligence/api/feedback.ts:22-34`
- Sticky positioning examples: `/home/jchi/projects/helios-chi-feedback-p1-fix-auto-scroll/frontend/src/pages/organizations/intelligence/components/chat-history/chat-history.scss:19`

## Research Complete

Report saved to: `/home/jchi/.claude/thoughts/research/2025-01-30_feedback-metadata-floating-card-implementation.md`

**Next step:** To create an implementation plan based on this research:
/create-plan Display feedback metadata as a floating card alongside the targeted response in FeedbackThreadFlyout, referencing /home/jchi/.claude/thoughts/research/2025-01-30_feedback-metadata-floating-card-implementation.md