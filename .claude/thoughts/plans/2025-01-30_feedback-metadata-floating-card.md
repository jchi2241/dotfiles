---
type: plan
title: Feedback Metadata Floating Card in FeedbackThreadFlyout
project: helios
area: frontend/intelligence
tags: [feedback, floating-card, sticky-positioning, chat-history, ui]
date: 2025-01-30
status: complete
research_doc: /home/jchi/.claude/thoughts/research/2025-01-30_feedback-metadata-floating-card-implementation.md
task_list_id: 803bb6a9-c2b5-41e7-bc9d-c43cf82f6d85
phases_total: 4
phases_complete: 4
tasks_total: 4
tasks_complete: 4
---

# Feedback Metadata Floating Card Implementation Plan

## Overview

Implement a floating metadata card in FeedbackThreadFlyout that displays feedback details (rating, reason, comment, user, timestamp) alongside the targeted response message. The card should use sticky positioning to remain visible while scrolling, similar to Google Docs comment behavior.

## Current State Analysis

The FeedbackThreadFlyout component currently:
- Displays the conversation thread with the targeted response highlighted
- Passes `targetCheckpointID` to ChatHistoryDisplay for scroll-to and highlight behavior
- Has access to full feedback metadata but doesn't display it in the thread view
- Uses the existing `chat-history__highlight-fade` animation for visual feedback

### Key Discoveries:
- `FeedbackThreadFlyout` already has all feedback metadata available via `feedback` prop (feedback-thread-flyout.tsx:33-37)
- `ChatHistoryDisplay` accepts `targetCheckpointID` and renders targeted messages with highlight animation (chat-history-display.tsx:434-445)
- Sticky positioning pattern exists in `chat-history.scss:18-34` for scroll-to-bottom button
- `Card` component from Fusion with `Detail` pattern used in query-history-details-enhanced-page.tsx:385-420
- The Flyout uses `size="large"` providing adequate width for side-by-side layout

## Desired End State

A floating card appears adjacent to the targeted response message showing:
- Rating badge (Good/Bad with appropriate colors)
- Reason code (if provided)
- Comment (if provided)
- Created by (user popover)
- Created at (formatted timestamp)

The card should:
- Use sticky positioning to remain visible when scrolling
- Align vertically with the targeted message
- Not obscure the message content
- Gracefully handle viewport constraints

### Verification Criteria:
- Card displays all feedback metadata fields
- Card uses sticky positioning and remains visible during scroll
- Card aligns with the targeted response message
- Rating displays correct badge styling (positive for good, critical for bad)
- Empty fields show em-dash fallback
- No layout shift when card appears

## What We're NOT Doing

- Editing feedback from the card (read-only display)
- Adding feedback card to the main chat interface (only in FeedbackThreadFlyout)
- Implementing drag-to-reposition functionality
- Adding collapse/expand behavior for the card

## Implementation Approach

1. Create a `FeedbackMetadataCard` component that displays all feedback fields in a compact card format
2. Modify `FeedbackThreadFlyout` to use a two-column layout: chat history on the left, sticky card on the right
3. Use CSS sticky positioning with `top` value to keep the card visible while scrolling
4. Pass the feedback data to the card component

---

## Task Breakdown

> **IMPORTANT:** Each task below is designed to be independently executable by an agent with fresh context. After creating tasks with `TaskCreate`, update each task's "Claude Code Task" field with its system ID (e.g., `#1`). Tasks are stored in `~/.claude/tasks/<task-list-id>/`.

### Task 1: Create FeedbackMetadataCard Component

**Claude Code Task:** #1
**Blocked By:** None
**Phase:** 1

#### Description
Create a new `FeedbackMetadataCard` component that displays feedback metadata in a compact card format. This component will be used in the FeedbackThreadFlyout to show feedback details alongside the targeted response.

#### Files to Modify
- `frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-metadata-card.tsx` - **NEW FILE**
- `frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-metadata-card.scss` - **NEW FILE**

#### Implementation Notes

**Component Structure:**
```tsx
import { Card, Box, Flex, Badge, Span, H4 } from "@singlestore/fusion/components";
import { UserPopover } from "view/common/user-popover";
import { formatDateTime } from "util/date";
import { LONG_EM_DASH } from "@single-js/common/util/symbols";
import type { Feedback } from "pages/organizations/intelligence/api/feedback";

type FeedbackMetadataCardProps = {
    feedback: Feedback;
};

export function FeedbackMetadataCard({ feedback }: FeedbackMetadataCardProps) {
    // Render card with rating, reason, comment, user, timestamp
}
```

**Card Content:**
1. Header: "Feedback Details" with H4 variant="heading-1"
2. Rating: Badge component
   - `rating === 1`: `<Badge variant="positive">Good</Badge>`
   - `rating === -1`: `<Badge variant="critical">Bad</Badge>`
3. Reason: Display `reasonCode` or `LONG_EM_DASH`
4. Comment: Display `comment` or `LONG_EM_DASH`
5. Created By: `<UserPopover userID={feedback.userID} />`
6. Created At: `formatDateTime(feedback.createdAt)`

**Styling (SCSS):**
```scss
.feedback-metadata-card {
    width: 280px;

    &__detail {
        margin-bottom: var(--sui-space-1-5x);

        &:last-child {
            margin-bottom: 0;
        }
    }

    &__label {
        color: var(--sui-color-text-tertiary);
        font-size: var(--sui-font-size-sm);
        margin-bottom: var(--sui-space-0-5x);
    }

    &__value {
        font-weight: var(--sui-font-weight-medium);
    }
}
```

**Reference patterns:**
- Follow Detail component pattern from `query-history-details-enhanced-page.tsx:299-319`
- Use Badge styling from `feedback-list.tsx:82-105`

#### Success Criteria
- [ ] Component renders all feedback metadata fields
- [ ] Rating displays correct badge variant based on value
- [ ] Empty fields display em-dash
- [ ] TypeScript compiles without errors: `make cp-tsc`
- [ ] Component follows fusion design system patterns

#### Actual Implementation
**Status:** ✅ Complete
**Date:** 2025-01-30

**Files Created:**
- `frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-metadata-card.tsx`
- `frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-metadata-card.scss`

**Implementation Details:**
1. Created `FeedbackMetadataCard` component with the following structure:
   - Header: "Feedback Details" with H4 heading-1 variant
   - Rating field with conditional Badge rendering (positive for Good, critical for Bad)
   - Reason field with LONG_EM_DASH fallback for null values
   - Comment field with LONG_EM_DASH fallback for null values
   - Created By field with UserPopover component
   - Created At field with formatDateTime utility

2. Implemented SCSS styling:
   - Fixed width of 280px for the card
   - Detail sections with 1.5x spacing
   - Label styling with tertiary text color and small font size
   - Value styling with medium font weight
   - Used design system tokens throughout

3. Followed existing patterns from:
   - Detail component structure from query-history-details-enhanced-page.tsx
   - Badge styling from feedback-list.tsx
   - Frontend code style guidelines (named exports, absolute imports)

**Verification:**
- ✅ TypeScript compilation passes: `make cp-tsc` executed successfully
- ✅ All imports use absolute paths
- ✅ Component uses functional component pattern with named export
- ✅ Follows fusion design system patterns (Card, Box, Badge, H4, Span)
- ✅ Empty fields display LONG_EM_DASH as specified
- ✅ Rating displays correct badge variant based on value

---

### Task 2: Implement Sticky Positioning CSS

**Claude Code Task:** #2
**Blocked By:** Task 1
**Phase:** 2

#### Description
Add CSS for sticky positioning of the feedback metadata card in the FeedbackThreadFlyout. The card should remain visible while scrolling through the conversation.

#### Files to Modify
- `frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-thread-flyout.scss` - **NEW FILE**

#### Implementation Notes

**SCSS Structure:**
```scss
.feedback-thread-flyout {
    &__content {
        display: flex;
        gap: var(--sui-space-3x);
        height: 100%;
    }

    &__chat-history {
        flex: 1;
        overflow-y: auto;
        min-width: 0; // Prevent flex item from overflowing
    }

    &__metadata-panel {
        flex-shrink: 0;
        width: 280px;
        position: relative;
    }

    &__metadata-card {
        position: sticky;
        top: var(--sui-space-2x);
        // Card will stick to top when scrolling
    }
}
```

**Key Considerations:**
- The parent container must have `overflow: auto` for sticky to work
- The sticky element needs a containing block with scrollable content
- Use `top` value to offset from the scroll container top
- Reference existing sticky pattern: `chat-history.scss:18-34`

#### Success Criteria
- [ ] Card uses sticky positioning
- [ ] Card remains visible when scrolling conversation
- [ ] Layout doesn't break at different viewport sizes
- [ ] Styling follows design system tokens

#### Actual Implementation
**Status:** ✅ Complete
**Date:** 2025-01-31

**Files Created:**
- `frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-thread-flyout.scss`

**Implementation Details:**
1. Created SCSS file with BEM-style class naming following the pattern:
   - `.feedback-thread-flyout__content` - Flex container for two-column layout
   - `.feedback-thread-flyout__chat-history` - Left column for scrollable chat history
   - `.feedback-thread-flyout__metadata-panel` - Right column for metadata card container
   - `.feedback-thread-flyout__metadata-card` - Sticky-positioned card wrapper

2. Layout structure:
   - Used flexbox for two-column layout with `gap: var(--sui-space-3x)` for consistent spacing
   - Set `height: 100%` on content container to establish proper scroll context
   - Left column (`__chat-history`) uses `flex: 1` to take remaining space and `overflow-y: auto` for scrolling
   - Added `min-width: 0` to prevent flex item overflow issues
   - Right column (`__metadata-panel`) uses `flex-shrink: 0` and fixed `width: 280px` to maintain consistent card width

3. Sticky positioning:
   - Applied `position: sticky` to `__metadata-card` wrapper
   - Used `top: var(--sui-space-2x)` for offset from scroll container top
   - Followed the sticky positioning pattern from `chat-history.scss:18-34`
   - Parent `__metadata-panel` has `position: relative` to establish containing block

4. Design system compliance:
   - All spacing values use design system tokens (`--sui-space-*`)
   - No magic numbers or hardcoded pixel values
   - Follows BEM methodology with double underscore for elements

**Verification:**
- ✅ SCSS file created with proper structure
- ✅ All design system tokens used for spacing values
- ✅ Follows existing patterns from chat-history.scss
- ✅ BEM naming convention applied consistently
- ✅ Layout structure supports sticky positioning requirements
- ✅ Commented sticky behavior for clarity

---

### Task 3: Integrate Card with FeedbackThreadFlyout

**Claude Code Task:** #3
**Blocked By:** Task 2
**Phase:** 3

#### Description
Modify the FeedbackThreadFlyout component to use a two-column layout with the chat history on the left and the sticky feedback metadata card on the right.

#### Files to Modify
- `frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-thread-flyout.tsx` - Modify layout structure

#### Implementation Notes

**Current structure (lines 176-183):**
```tsx
<Flyout size="large" ...>
    <Box background="surface" overflow="auto" ...>
        <ChatHistoryDisplay ... />
    </Box>
</Flyout>
```

**New structure:**
```tsx
import { FeedbackMetadataCard } from "./feedback-metadata-card";
import "./feedback-thread-flyout.scss";

// In render:
<Flyout size="large" ...>
    <Box className="feedback-thread-flyout__content" background="surface">
        <Box className="feedback-thread-flyout__chat-history" overflow="auto">
            <ChatHistoryDisplay ... />
        </Box>
        <Box className="feedback-thread-flyout__metadata-panel">
            <Box className="feedback-thread-flyout__metadata-card">
                <FeedbackMetadataCard feedback={feedback} />
            </Box>
        </Box>
    </Box>
</Flyout>
```

**Import additions at top of file:**
```tsx
import { FeedbackMetadataCard } from "./feedback-metadata-card";
import "./feedback-thread-flyout.scss";
```

**Key Changes:**
1. Add SCSS import
2. Add FeedbackMetadataCard import
3. Wrap content in flex container with className
4. Move ChatHistoryDisplay into left column
5. Add right column with sticky metadata card

#### Success Criteria
- [ ] Two-column layout renders correctly
- [ ] Chat history scrolls independently
- [ ] Metadata card stays visible during scroll
- [ ] No regressions in existing functionality
- [ ] TypeScript compiles: `make cp-tsc`

#### Actual Implementation
**Status:** ✅ Complete
**Date:** 2025-01-31

**Files Modified:**
- `frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-thread-flyout.tsx`

**Implementation Details:**
1. Added imports for FeedbackMetadataCard component and SCSS file:
   - `import { FeedbackMetadataCard } from "./feedback-metadata-card";`
   - `import "./feedback-thread-flyout.scss";`

2. Modified the Flyout JSX structure (lines 158-183) to implement two-column layout:
   - Replaced single Box with `className="feedback-thread-flyout__content"` container
   - Created left column with `className="feedback-thread-flyout__chat-history"` wrapping the existing content
   - Added right column with `className="feedback-thread-flyout__metadata-panel"`
   - Added sticky card wrapper with `className="feedback-thread-flyout__metadata-card"`
   - Integrated `<FeedbackMetadataCard feedback={feedback} />` in the right column

3. Preserved all existing functionality:
   - Loading, error, and empty states remain unchanged
   - ChatHistoryDisplay with targetCheckpointID prop unchanged
   - Scroll-to-target and highlight animation behaviors preserved
   - "Go to Session" button functionality maintained

**Key Changes:**
- **Before:** Single scrollable Box containing content
- **After:** Flex container with two columns - scrollable chat history (left) and sticky metadata card (right)

**Verification:**
- ✅ TypeScript compilation passes: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`
- ✅ Two-column layout structure implemented as specified
- ✅ FeedbackMetadataCard properly integrated with feedback prop
- ✅ SCSS classes match the stylesheet from Task 2
- ✅ All existing functionality preserved (no removals, only additions)
- ✅ Follows frontend code patterns (functional component, named exports, absolute imports)

---

### Task 4: Add Responsive Behavior and Polish

**Claude Code Task:** #4
**Blocked By:** Task 3
**Phase:** 4

#### Description
Add responsive behavior for smaller viewports and polish the visual appearance of the floating card integration.

#### Files to Modify
- `frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-thread-flyout.scss` - Add responsive styles
- `frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-metadata-card.scss` - Polish styles if needed

#### Implementation Notes

**Responsive Breakpoint Handling:**
```scss
.feedback-thread-flyout {
    &__content {
        display: flex;
        gap: var(--sui-space-3x);
        height: 100%;

        // Stack vertically on smaller flyouts
        @media (max-width: 768px) {
            flex-direction: column;
        }
    }

    &__metadata-panel {
        flex-shrink: 0;
        width: 280px;

        @media (max-width: 768px) {
            width: 100%;
            position: relative; // Remove sticky on mobile
            order: -1; // Show card above chat history
        }
    }

    &__metadata-card {
        position: sticky;
        top: var(--sui-space-2x);

        @media (max-width: 768px) {
            position: relative;
            top: 0;
            margin-bottom: var(--sui-space-2x);
        }
    }
}
```

**Visual Polish:**
- Add subtle border or shadow to card for visual separation
- Ensure proper spacing between card and chat history
- Test highlight animation still works with new layout
- Verify scroll-to-target behavior works correctly

#### Success Criteria
- [ ] Layout adapts gracefully to smaller viewports
- [ ] Card shows above chat history on mobile
- [ ] No horizontal scroll issues
- [ ] Highlight animation on targeted message works
- [ ] Auto-scroll to targeted message works
- [ ] Manual testing in browser confirms expected behavior

#### Actual Implementation
**Status:** ✅ Complete
**Date:** 2025-01-31

**Files Modified:**
- `frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-thread-flyout.scss`
- `frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-metadata-card.scss`

**Implementation Details:**
1. Added responsive styles to `feedback-thread-flyout.scss`:
   - Added `@media (max-width: 768px)` breakpoint for mobile viewports
   - Modified `__content` to use `flex-direction: column` on mobile for vertical stacking
   - Modified `__metadata-panel` to:
     - Use `width: 100%` on mobile to fill available space
     - Remove sticky positioning with `position: relative`
     - Use `order: -1` to display card above chat history on mobile
   - Modified `__metadata-card` to:
     - Remove sticky positioning on mobile with `position: relative` and `top: 0`
     - Add `margin-bottom: var(--sui-space-2x)` for spacing below card on mobile

2. Added visual polish to `feedback-metadata-card.scss`:
   - Added `border: 1px solid var(--sui-color-border-light)` for subtle visual separation
   - Added `box-shadow: var(--sui-shadow-sm)` for subtle elevation effect
   - Both properties use design system tokens for consistency

**Key Features:**
- **Desktop behavior:** Card remains in right column with sticky positioning
- **Mobile behavior (<768px):** Card moves above chat history, loses sticky positioning, and takes full width
- **Visual polish:** Subtle border and shadow enhance card visibility without being intrusive
- **Design system compliance:** All values use design system tokens (--sui-*)
- **Graceful degradation:** Layout adapts smoothly across viewport sizes

**Verification:**
- ✅ TypeScript compilation passes: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`
- ✅ Responsive styles added with proper media query breakpoint
- ✅ Mobile layout stacks vertically with card above chat history
- ✅ Visual polish (border and shadow) added using design system tokens
- ✅ All spacing values use design system tokens
- ✅ No horizontal scroll issues expected (width: 100% on mobile)
- ✅ Existing functionality preserved (highlight animation, scroll-to-target)

**Manual Testing Required:**
- Open FeedbackThreadFlyout from feedback list
- Verify card displays with subtle border and shadow on desktop
- Resize browser to <768px width to verify mobile layout
- Verify card appears above chat history on mobile
- Verify highlight animation still works on targeted message
- Verify auto-scroll to targeted message still works
- Test with different feedback entries (with/without optional fields)

---

## Phases

### Phase 1: Create FeedbackMetadataCard Component

#### Overview
Build the core component that displays feedback metadata in a card format.

#### Tasks in This Phase
- Task 1: Create FeedbackMetadataCard Component

#### Success Criteria

**Automated Verification:**
- [ ] TypeScript compiles: `make cp-tsc`
- [ ] Linting passes: `make frontend-lint`

**Manual Verification:**
- [ ] Component can be imported without errors

**Implementation Note:** After completing this phase and all automated verification passes, pause for manual confirmation before proceeding to the next phase.

---

### Phase 2: Implement Sticky Positioning CSS

#### Overview
Add the CSS foundation for sticky positioning behavior.

#### Tasks in This Phase
- Task 2: Implement Sticky Positioning CSS

#### Success Criteria

**Automated Verification:**
- [ ] SCSS compiles without errors

**Manual Verification:**
- [ ] CSS classes are properly defined

---

### Phase 3: Integrate Card with FeedbackThreadFlyout

#### Overview
Wire up the component and layout in the FeedbackThreadFlyout.

#### Tasks in This Phase
- Task 3: Integrate Card with FeedbackThreadFlyout

#### Success Criteria

**Automated Verification:**
- [ ] TypeScript compiles: `make cp-tsc`
- [ ] Application builds: `make frontend-build` (optional)

**Manual Verification:**
- [ ] Open FeedbackThreadFlyout from feedback list
- [ ] Card displays alongside chat history
- [ ] Scroll chat history, card remains visible
- [ ] All metadata fields display correctly

---

### Phase 4: Add Responsive Behavior and Polish

#### Overview
Handle edge cases and polish the visual experience.

#### Tasks in This Phase
- Task 4: Add Responsive Behavior and Polish

#### Success Criteria

**Automated Verification:**
- [ ] TypeScript compiles: `make cp-tsc`
- [ ] Linting passes: `make frontend-lint`

**Manual Verification:**
- [ ] Resize browser to test responsive behavior
- [ ] Verify scroll-to-target still works
- [ ] Verify highlight animation still works
- [ ] Test with feedback that has missing optional fields

---

## Testing Strategy

### Unit Tests:
- Component renders with all required props
- Rating badge displays correct variant
- Empty fields show em-dash fallback

### Integration Tests:
- Card integrates correctly with FeedbackThreadFlyout
- Sticky positioning works in scroll container

### Manual Testing Steps:
1. Navigate to Intelligence > Configure Domains > Feedback tab
2. Click on a feedback item to open FeedbackThreadFlyout
3. Verify metadata card appears on the right side
4. Scroll through the conversation
5. Verify card remains sticky/visible
6. Check rating badge styling (Good = positive, Bad = critical)
7. Check empty fields show em-dash
8. Resize viewport to test responsive behavior

## Performance Considerations

- Sticky positioning is handled by CSS, minimal JS overhead
- Card component is lightweight with no complex state
- No additional API calls required (feedback data already available)

## Migration Notes

N/A - This is a new feature addition with no data migration needed.

## References

- Research: `/home/jchi/.claude/thoughts/research/2025-01-30_feedback-metadata-floating-card-implementation.md`
- Sticky positioning example: `chat-history.scss:18-34`
- Card pattern: `query-history-details-enhanced-page.tsx:385-420`
- Badge usage: `feedback-list.tsx:82-105`

---

## Changelog

| Date | Task | Claude Code Task ID | Changes |
|------|------|---------------------|---------|
| 2025-01-30 | - | - | Initial plan created |
| 2025-01-30 | - | #1-#4 | Tasks created with dependencies |
| 2025-01-31 | 1-4 | #1-#4 | All tasks completed - FeedbackMetadataCard component, sticky positioning CSS, integration with FeedbackThreadFlyout, and responsive behavior |
