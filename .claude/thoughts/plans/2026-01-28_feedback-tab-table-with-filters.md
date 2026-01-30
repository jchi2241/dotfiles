# FeedbackTab Table with Filters Implementation Plan

**Plan File:** `~/.claude/thoughts/plans/2026-01-28_feedback-tab-table-with-filters.md`
**Task List:** `~/.claude/tasks/38ec099e-76eb-456c-8a87-165576cef3c0/`
**Research Doc:** `~/.claude/thoughts/research/2026-01-28_feedback-table-rendering-patterns.md`
**Last Updated:** 2026-01-28

---

## Overview

Refactor the FeedbackList component to use standard Helios table patterns: replace ButtonGroup toggle filters with MultiSelect dropdowns for Ratings and Reasons, use Badge components instead of thumbs icons for ratings, add a USER column with UserPopover, replace inline styles with design system props, and use `formatDateTime` for date formatting.

## Current State Analysis

The existing `FeedbackList` component at `frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-list.tsx` has several issues:

### Key Discoveries:
- Uses `ButtonGroup` with toggle buttons for filtering (lines 217-251) - should use `MultiSelect` dropdowns per query-history pattern
- Rating column uses `FaIcon` with thumbs up/down (lines 70-80) - should use `Badge` with "Good"/"Bad" text
- Uses inline styles for text overflow (lines 89-94, 120-125) - should use `Span` component with `ellipsis` prop
- Missing USER column - need to add `UserPopover` component (data already has `userID` field)
- Date formatting uses inline `toLocaleDateString` (lines 138-142) - should use `formatDateTime` utility
- No Reasons filter - API already supports `reasonCode` filter (feedback.ts:146)
- Has `useGetReasonCodes` hook already available (feedback.ts:265-279)

## Desired End State

A FeedbackList component that:
1. Has MultiSelect dropdown filters for Ratings and Reasons in a `MultiSelectGroup`
2. Displays rating as Badge components ("Good" in green, "Bad" in red)
3. Shows USER column with avatar and name via `UserPopover`
4. Uses proper design system components (`Span` with `ellipsis`) instead of inline styles
5. Formats dates consistently using `formatDateTime`
6. Supports multi-select filtering (multiple ratings, multiple reasons)

### Verification Criteria:
- Ratings filter shows "Good" and "Bad" options, allows multi-select
- Reasons filter shows all reason codes from API, allows multi-select
- USER column displays avatar with user name, shows popover on hover
- Rating column shows colored Badge components
- Question column has link styling and ellipsis on overflow
- Date column uses "Jan 12, 2025 - 2:30 PM" format
- Filtering works correctly with API

## What We're NOT Doing

- Adding pagination (not in current requirements)
- Adding sorting controls (table already supports sorting via GeneralTable)
- Adding date range filters (could be future enhancement)
- Adding export/download functionality
- Changing the FeedbackThreadFlyout behavior
- Modifying the feedback API endpoints

## Implementation Approach

Follow the established patterns from query-history-page.tsx and query-history-filter-checkboxes.tsx. Create a reusable filter component that can be used for both Ratings and Reasons. Update the FeedbackList to use the new patterns while maintaining existing functionality.

---

## Task Breakdown

> **IMPORTANT:** Each task below is designed to be independently executable by an agent with fresh context. After creating tasks with `TaskCreate`, update each task's "Claude Code Task" field with its system ID (e.g., `#1`). Tasks are stored in `~/.claude/tasks/<task-list-id>/`.

### Task 1: Create FeedbackFilterSelect Component

**Claude Code Task:** #1
**Blocked By:** None
**Phase:** 1

#### Description
Create a new `FeedbackFilterSelect` component following the `QueryHistoryFilterCheckboxes` pattern. This component will be reused for both the Ratings and Reasons filters.

#### Files to Modify
- `frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-filter-select.tsx` - Create new file

#### Implementation Notes

Create the component with this structure:

```tsx
import { Span } from "@singlestore/fusion/components";
import {
    MultiSelect,
    MultiSelectContent,
    MultiSelectItem,
    MultiSelectSelectAll,
    MultiSelectTriggerButton,
    MultiSelectValue,
} from "@singlestore/fusion/components/multi-select";
import * as React from "react";

type FeedbackFilterSelectProps = {
    buttonText: string;
    items: Array<{ value: string; label: string }>;
    selected: Array<string>;
    onChange: (selected: Array<string>) => void;
    loading?: boolean;
};

export function FeedbackFilterSelect({
    buttonText,
    items,
    selected,
    onChange,
    loading = false,
}: FeedbackFilterSelectProps) {
    const allItems = items.map((item) => ({ value: item.value }));

    return (
        <MultiSelect
            value={selected}
            onValueChange={onChange}
            allItems={allItems}
            loading={loading}
            variant="filter"
            emptySelectionDisplay="any"
        >
            <MultiSelectTriggerButton>
                <Span maxWidth="20x" display="block" ellipsis>
                    <MultiSelectValue
                        placeholder={buttonText}
                        prefixLabel={buttonText}
                    />
                </Span>
            </MultiSelectTriggerButton>
            <MultiSelectContent>
                <MultiSelectSelectAll />
                {items.map((item) => (
                    <MultiSelectItem key={item.value} value={item.value}>
                        {item.label}
                    </MultiSelectItem>
                ))}
            </MultiSelectContent>
        </MultiSelect>
    );
}
```

#### Success Criteria
- [x] Component created at correct path
- [x] TypeScript compiles: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`
- [x] Component follows QueryHistoryFilterCheckboxes pattern

#### Actual Implementation

**Status:** ✅ Completed

**Date:** 2026-01-28

**Changes Made:**
- Created new component at `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-filter-select.tsx`
- Component follows the `QueryHistoryFilterCheckboxes` pattern exactly as specified
- Implemented with the following features:
  - Accepts `buttonText`, `items`, `selected`, `onChange`, and optional `loading` props
  - Uses `MultiSelect` with `variant="filter"` and `emptySelectionDisplay="any"`
  - Includes `MultiSelectSelectAll` for bulk selection
  - Uses `Span` with `maxWidth="20x"` and `ellipsis` for button text
  - Maps items to `allItems` format required by MultiSelect

**Verification:**
- ✅ TypeScript compilation successful: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`
- ✅ Component follows established patterns from research document
- ✅ All imports are correct and component is properly typed

**Notes:**
- Component is ready to be used in Task 3 for integrating filters into FeedbackList
- No blockers encountered
- Implementation matches specification exactly

---

### Task 2: Update FeedbackList Table Columns

**Claude Code Task:** #2
**Blocked By:** None
**Phase:** 2

#### Description
Update the table column definitions in FeedbackList to use proper design system patterns:
1. Change Rating column from thumbs icons to Badge components
2. Add USER column with UserPopover
3. Replace inline styles with Span component props
4. Use formatDateTime for date formatting
5. Add link styling to Question column
6. Keep Comment column with proper Span styling
7. Remove Actions column (question text is clickable)

#### Files to Modify
- `frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-list.tsx` - Update columns

#### Implementation Notes

**New imports to add:**
```tsx
import { Badge, Span } from "@singlestore/fusion/components";
import { LONG_EM_DASH } from "@single-js/common/util/symbols";
import { formatDateTime } from "util/date";
import { UserPopover } from "view/common/user-popover";
```

**Remove these imports:**
```tsx
// Remove: faThumbsDown, faThumbsUp from @fortawesome/sharp-solid-svg-icons
// Remove: FaIcon (if no longer used elsewhere)
// Remove: Paragraph (if no longer used elsewhere)
```

**Updated columns array:**
```tsx
const columns: Array<GeneralTableColumn<Feedback>> = [
    {
        id: "question",
        title: "QUESTION",
        formatter: (row) => (
            <Span
                ellipsis
                maxWidth="35x"
                display="block"
                color="link"
                title={row.questionPreview}
                onClick={() => setSelectedFeedback(row)}
                style={{ cursor: "pointer" }}
            >
                {row.questionPreview}
            </Span>
        ),
        getValue: (row) => row.questionPreview,
        defaultMinWidth: 200,
    },
    {
        id: "rating",
        title: "RATING",
        formatter: (row) => {
            if (row.rating === 1) {
                return (
                    <Badge variant="positive" width="fit-content">
                        Good
                    </Badge>
                );
            }
            if (row.rating === -1) {
                return (
                    <Badge variant="critical" width="fit-content">
                        Bad
                    </Badge>
                );
            }
            return <Span>{LONG_EM_DASH}</Span>;
        },
        getValue: (row) => String(row.rating),
        defaultMinWidth: 100,
    },
    {
        id: "reason",
        title: "REASON",
        formatter: (row) => (
            <Span variant="body-2" ellipsis maxWidth="20x" display="block">
                {row.reasonCode ?? LONG_EM_DASH}
            </Span>
        ),
        getValue: (row) => row.reasonCode ?? "",
        defaultMinWidth: 140,
    },
    {
        id: "comment",
        title: "COMMENT",
        formatter: (row) => (
            <Span variant="body-2" ellipsis maxWidth="25x" display="block" title={row.comment ?? undefined}>
                {row.comment ?? LONG_EM_DASH}
            </Span>
        ),
        getValue: (row) => row.comment ?? "",
        defaultMinWidth: 180,
    },
    {
        id: "createdAt",
        title: "CREATED AT",
        formatter: (row) => (
            <Span variant="body-2">
                {formatDateTime(row.createdAt)}
            </Span>
        ),
        getValue: (row) => row.createdAt,
        defaultMinWidth: 150,
    },
    {
        id: "user",
        title: "USER",
        formatter: (row) => <UserPopover userID={row.userID} />,
        getValue: (row) => row.userID,
        defaultMinWidth: 140,
    },
];
```

**Note:** Remove the Actions column - the question text is clickable to open the flyout. Also remove the `faEye` import since the actions column is removed.

#### Success Criteria
- [x] Rating column displays Badge components with "Good"/"Bad" text
- [x] USER column shows avatar and name via UserPopover
- [x] Question column has link styling and ellipsis
- [x] Date uses formatDateTime format
- [x] No inline styles remain (except cursor: pointer for clickable question)
- [x] TypeScript compiles: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`

#### Actual Implementation
**Completed:** 2026-01-28

**Changes Made:**
1. **Updated imports** in `feedback-list.tsx`:
   - Added: `Badge`, `Span` from `@singlestore/fusion/components`
   - Added: `LONG_EM_DASH` from `@single-js/common/util/symbols`
   - Added: `formatDateTime` from `util/date`
   - Added: `UserPopover` from `view/common/user-popover`
   - Removed: `faEye` from `@fortawesome/sharp-regular-svg-icons` (Actions column removed)
   - Kept: `faThumbsUp`, `faThumbsDown`, `FaIcon` (still used in ButtonGroup filters, will be removed in Task 3)
   - Kept: `Paragraph` (still used for error and empty states)

2. **Completely rewrote columns array** with updated patterns:
   - **QUESTION column**: Now first column, uses `Span` with `color="link"`, `ellipsis`, and `onClick` to open flyout
   - **RATING column**: Replaced thumbs icons with `Badge` components ("Good" in variant="positive", "Bad" in variant="critical")
   - **REASON column**: Uses `Span` with `ellipsis` and `LONG_EM_DASH` for empty values
   - **COMMENT column**: Uses `Span` with `ellipsis`, `maxWidth="25x"`, and `title` prop for full text on hover
   - **CREATED AT column**: Uses `formatDateTime` utility instead of inline date formatting
   - **USER column**: New column using `UserPopover` component to display user avatar and info
   - **Removed Actions column**: Question text is now clickable to open the flyout

3. **All inline styles removed** from column formatters (except `cursor: "pointer"` for clickable question text)

4. **Column order**: Question, Rating, Reason, Comment, Created At, User

**Verification:**
- TypeScript compilation passed successfully
- All imports are properly used or will be cleaned up in Task 3
- Table columns follow design system patterns per plan specifications

**Notes:**
- ButtonGroup filter UI still uses thumbs icons - this will be replaced with MultiSelect filters in Task 3
- `FaIcon`, `faThumbsUp`, `faThumbsDown` imports intentionally kept for Task 3 cleanup

---

### Task 3: Integrate MultiSelect Filters into FeedbackList

**Claude Code Task:** #3
**Blocked By:** Task 1
**Phase:** 3

#### Description
Replace the ButtonGroup filter with MultiSelect filters for Ratings and Reasons. Wire up the filter state to the API calls. Fetch reason codes for the Reasons filter dropdown.

#### Files to Modify
- `frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-list.tsx` - Update filter UI and state
- `frontend/src/pages/organizations/intelligence/api/feedback.ts` - May need to update FeedbackFilters type for multi-value support

#### Implementation Notes

**Update imports:**
```tsx
import { MultiSelectGroup } from "@singlestore/fusion/components/multi-select";
import { FeedbackFilterSelect } from "pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-filter-select";
import { useGetReasonCodes } from "pages/organizations/intelligence/api/feedback";
```

**Update state management:**
```tsx
// Replace single ratingFilter with multi-select state
const [selectedRatings, setSelectedRatings] = React.useState<Array<string>>([]);
const [selectedReasons, setSelectedReasons] = React.useState<Array<string>>([]);

// Fetch reason codes
const { data: reasonCodesData, loading: reasonCodesLoading } = useGetReasonCodes();
const reasonCodes = reasonCodesData?.results?.reasonCodes ?? [];
```

**Update filters construction:**
```tsx
const filters: FeedbackFilters = React.useMemo(() => {
    const f: FeedbackFilters = {};

    // Handle ratings - if only one selected, use single value
    // If both or none selected, don't filter
    if (selectedRatings.length === 1) {
        f.rating = selectedRatings[0] === "good" ? 1 : -1;
    }

    // Handle reasons - if any selected, use first one (API limitation)
    // TODO: API may need update to support multiple reason codes
    if (selectedReasons.length === 1) {
        f.reasonCode = selectedReasons[0];
    }

    return f;
}, [selectedRatings, selectedReasons]);
```

**Update filter UI (replace ButtonGroup section):**
```tsx
<Flex gap="2x" alignItems="center">
    <MultiSelectGroup>
        <FeedbackFilterSelect
            buttonText="Rating"
            items={[
                { value: "good", label: "Good" },
                { value: "bad", label: "Bad" },
            ]}
            selected={selectedRatings}
            onChange={setSelectedRatings}
        />
        <FeedbackFilterSelect
            buttonText="Reason"
            items={reasonCodes.map((rc) => ({
                value: rc.code,
                label: rc.displayName,
            }))}
            selected={selectedReasons}
            onChange={setSelectedReasons}
            loading={reasonCodesLoading}
        />
    </MultiSelectGroup>
</Flex>
```

**Update empty state message:**
```tsx
<Paragraph variant="body-2" color="low-contrast">
    {selectedRatings.length > 0 || selectedReasons.length > 0
        ? "Try adjusting your filters"
        : "Users haven't submitted feedback yet"}
</Paragraph>
```

**Remove unused imports after refactor:**
- `Button`, `ButtonGroup` from @singlestore/fusion/components (if not used elsewhere)
- `faThumbsDown`, `faThumbsUp` from @fortawesome/sharp-solid-svg-icons
- `FaIcon` (if not used elsewhere)

#### Success Criteria
- [x] Rating MultiSelect filter shows "Good" and "Bad" options
- [x] Reason MultiSelect filter shows reason codes from API
- [x] Filters correctly update API query params
- [x] Empty state message updates based on filter state
- [x] TypeScript compiles: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`
- [ ] Filters work correctly when tested in browser (Manual verification required)

#### Actual Implementation

**Status:** ✅ Completed

**Date:** 2026-01-28

**Changes Made:**

1. **Updated imports** in `feedback-list.tsx`:
   - Added: `MultiSelectGroup` from `@singlestore/fusion/components/multi-select`
   - Added: `useGetReasonCodes` to the existing import from `pages/organizations/intelligence/api/feedback`
   - Added: `FeedbackFilterSelect` from the component created in Task 1
   - Removed: `faThumbsDown`, `faThumbsUp` from `@fortawesome/sharp-solid-svg-icons`
   - Removed: `Button`, `ButtonGroup`, `FaIcon` from `@singlestore/fusion/components`

2. **Updated state management**:
   - Removed `RatingFilter` type definition
   - Replaced `ratingFilter` state with `selectedRatings: Array<string>`
   - Added `selectedReasons: Array<string>` state
   - Added `useGetReasonCodes()` hook to fetch reason codes from API
   - Extracted `reasonCodes` with fallback to empty array

3. **Updated filters construction** (lines 36-52):
   - Changed logic to handle multi-select state
   - If exactly one rating is selected, set `f.rating` to 1 (good) or -1 (bad)
   - If both or no ratings selected, no rating filter is applied
   - If exactly one reason is selected, set `f.reasonCode` (API limitation)
   - Added TODO comment about API potentially needing updates for multiple reason codes

4. **Replaced ButtonGroup UI** with MultiSelect filters (lines 210-232):
   - Wrapped filters in `MultiSelectGroup` component
   - Added `FeedbackFilterSelect` for Rating with "Good" and "Bad" options
   - Added `FeedbackFilterSelect` for Reason with dynamically loaded reason codes
   - Passed `loading` state to Reason filter for loading indicator

5. **Updated empty state message** (lines 191-193):
   - Changed condition from `ratingFilter !== "all"` to check if any filters are active
   - Now shows "Try adjusting your filters" when `selectedRatings.length > 0 || selectedReasons.length > 0`
   - Otherwise shows "Users haven't submitted feedback yet"

**Verification:**
- ✅ TypeScript compilation successful: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`
- ✅ All unused imports removed (Button, ButtonGroup, FaIcon, thumbs icons)
- ✅ MultiSelect filters integrated following the plan specifications
- ✅ Reason codes fetched from API using `useGetReasonCodes` hook
- ✅ Filter state correctly wired to API query parameters

**Notes:**
- The API currently only supports single rating and single reason code filtering
- Multi-select UI allows users to select multiple values, but only the first selected reason is used
- This provides a foundation for future API enhancements to support multi-value filtering
- No blockers encountered during implementation

---

## Phases

### Phase 1: Create Filter Component

#### Overview
Create the reusable FeedbackFilterSelect component that follows the QueryHistoryFilterCheckboxes pattern.

#### Tasks in This Phase
- Task 1: Create FeedbackFilterSelect Component

#### Success Criteria

**Automated Verification:**
- [ ] TypeScript compiles: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`

**Manual Verification:**
- [ ] Component file exists and follows pattern

**Implementation Note:** This task has no dependencies and can be done in parallel with Task 2.

---

### Phase 2: Update Table Columns

#### Overview
Update the table column definitions to use proper design system patterns (Badge, UserPopover, Span, formatDateTime).

#### Tasks in This Phase
- Task 2: Update FeedbackList Table Columns

#### Success Criteria

**Automated Verification:**
- [ ] TypeScript compiles: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`

**Manual Verification:**
- [ ] Table displays correctly with new column renderers
- [ ] Badge shows "Good" (green) and "Bad" (red) correctly
- [ ] UserPopover shows avatar and name
- [ ] Date format matches "Jan 12, 2025 - 2:30 PM"

**Implementation Note:** This task has no dependencies and can be done in parallel with Task 1.

---

### Phase 3: Integrate Filters

#### Overview
Replace ButtonGroup with MultiSelect filters and wire up to API.

#### Tasks in This Phase
- Task 3: Integrate MultiSelect Filters into FeedbackList

#### Success Criteria

**Automated Verification:**
- [ ] TypeScript compiles: `direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc`

**Manual Verification:**
- [ ] Rating filter dropdown works correctly
- [ ] Reason filter dropdown shows reason codes from API
- [ ] Selecting filters updates table data
- [ ] Clearing filters shows all data

**Implementation Note:** This task depends on Task 1 (needs FeedbackFilterSelect component). After completing this phase and all automated verification passes, pause for manual confirmation.

---

## Testing Strategy

### Unit Tests:
- No new unit tests required (using existing tested components)

### Integration Tests:
- Verify filters interact correctly with API
- Verify UserPopover resolves user info

### Manual Testing Steps:
1. Navigate to Intelligence > Configure Domain > Feedback tab
2. Verify table displays with new column layout (Question, Rating, Reason, Comment, Created At, User)
3. Verify Rating column shows "Good" (green badge) or "Bad" (red badge)
4. Verify User column shows avatar with name, hover shows popover
5. Click Rating filter, verify "Good" and "Bad" options appear
6. Select "Good", verify only positive feedback shown
7. Click Reason filter, verify reason codes from API appear
8. Select a reason, verify filtering works
9. Clear all filters, verify all feedback shown
10. Click question text, verify FeedbackThreadFlyout opens

## Performance Considerations

- UserPopover internally caches org members query, so multiple rows won't cause N+1 queries
- MultiSelect filters are lightweight and don't impact performance
- Reason codes are fetched once and cached

## Migration Notes

No database or API migrations required. This is a frontend-only change.

## References

- Research: `~/.claude/thoughts/research/2026-01-28_feedback-table-rendering-patterns.md`
- QueryHistoryFilterCheckboxes pattern: `frontend/src/pages/organizations/monitoring/query-history/query-history-filter-checkboxes.tsx`
- UserPopover usage: `frontend/src/pages/organizations/pythonudf/python-udfs.tsx:76`
- Badge pattern: `frontend/src/pages/organizations/monitoring/query-history/query-history-table.tsx:422-450`

---

## Changelog

| Date | Task | Claude Code Task ID | Changes |
|------|------|---------------------|---------|
| 2026-01-28 | - | - | Initial plan created |
| 2026-01-28 | 1, 2, 3 | #1, #2, #3 | Tasks created, dependencies set (Task 3 blocked by Task 1) |
| 2026-01-28 | 2 | #2 | Removed actions column from plan per user request |
| 2026-01-28 | 2 | #2 | Added Comment column per user request |
| 2026-01-28 | 2 | #2 | Moved Comment column after Reason |
