# Research: Table Rendering Patterns in Helios Frontend

## Overview

This document details how tables, filters, status badges, dates, and users are rendered across the Helios frontend, with specific focus on patterns from `/query-history`, `/jobs`, `/functions`, and `/pythonudfs` pages. These patterns should be reused when implementing the FeedbackTab table.

---

## 1. Table Component

### GeneralTable

All tables in Helios use `GeneralTable` from `@single-js/common/components/super-table/general-table`.

**Import:**
```tsx
import type { GeneralTableColumn } from "@single-js/common/components/super-table/general-table";
import { GeneralTable } from "@single-js/common/components/super-table/general-table";
```

**Key File References:**
- `/home/jchi/projects/helios/frontend/src/pages/organizations/monitoring/query-history/query-history-table.tsx`
- `/home/jchi/projects/helios/frontend/src/pages/organizations/clusters/database/components/functions-table.tsx`
- `/home/jchi/projects/helios/frontend/src/view/common/admin/jobs-table.tsx`

**Basic Usage Pattern:**
```tsx
<GeneralTable<DataType>
    columns={columns}
    rows={rows}
    getRowId={(row) => row.id}
    sort={sort}
    onSort={handleSort}
    rowHeight={48}
    verticallyAlignCells
/>
```

**Column Definition Structure:**
```tsx
const columns: Array<GeneralTableColumn<DataType>> = [
    {
        id: "columnId",           // Unique column identifier
        title: "Column Name",      // Header text
        formatter: (row) => <Component />,  // Cell renderer
        getValue: (row) => row.value,       // Sort value extractor
        defaultMinWidth: 200,      // Min width in pixels
        defaultMaxWidth: 400,      // Max width (optional)
        sort: "DISABLED",          // Disable sorting (optional)
        comparator: (a, b) => a.localeCompare(b), // Custom sort (optional)
    },
];
```

---

## 2. Existing FeedbackList Component

**Location:** `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-list.tsx`

**Current Implementation Issues:**
- Uses inline styles (`style={{ overflow: "hidden", ... }}`) - should use design system props
- Uses `ButtonGroup` with toggle buttons for filtering instead of `MultiSelect` dropdowns
- Rating column uses thumbs up/down icons instead of text badges
- Missing USER column with avatar

---

## 3. Filter Components

### MultiSelect Filter Pattern

**Location:** `/home/jchi/projects/helios/frontend/src/pages/organizations/monitoring/query-history/query-history-filter-checkboxes.tsx`

**Imports:**
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
import { LONG_EM_DASH } from "@single-js/common/util/symbols";
```

**Component Pattern:**
```tsx
<MultiSelect
    value={selected}
    onValueChange={handleValueChange}
    allItems={allItems}
    loading={loading}
    variant="filter"
    emptySelectionDisplay="any"
    onOpenChange={handleOpenChange}
>
    <MultiSelectTriggerButton>
        <Span maxWidth="20x" display="block" ellipsis>
            <MultiSelectValue
                placeholder={buttonText}
                prefixLabel={buttonText}
            />
        </Span>
    </MultiSelectTriggerButton>
    <MultiSelectContent data-testid="filter-options">
        <MultiSelectSelectAll />
        {allItems.map((item) => (
            <MultiSelectItem key={item.value} value={item.value}>
                {item.value}
            </MultiSelectItem>
        ))}
    </MultiSelectContent>
</MultiSelect>
```

### MultiSelectGroup for Filter Grouping

**Import:**
```tsx
import { MultiSelectGroup } from "@singlestore/fusion/components/multi-select";
```

**Usage (from query-history-page.tsx:420-466):**
```tsx
<Flex m="2x" justifyContent="space-between">
    <MultiSelectGroup>
        <QueryHistoryFilterCheckboxes buttonText="Database" ... />
        <QueryHistoryFilterCheckboxes buttonText="User" ... />
        <QueryHistoryFilterCheckboxes buttonText="Status" ... />
    </MultiSelectGroup>
</Flex>
```

---

## 4. Cell Rendering Patterns

### Status Badge (Rating)

**Location:** `/home/jchi/projects/helios/frontend/src/pages/organizations/monitoring/query-history/query-history-table.tsx:422-450`

**Imports:**
```tsx
import { Badge } from "@singlestore/fusion/components";
```

**Badge Variants Available:**
- `"positive"` - Green (for success, good states)
- `"critical"` - Red (for errors, failures)
- `"info"` - Blue (for informational)
- `"neutral"` - Gray (for neutral states)
- `"secondary"` - Purple/secondary color
- `"warning"` - Yellow/orange (for warnings)

**Pattern for Rating Badge (text only, no icons):**
```tsx
// For positive rating
<Badge variant="positive" width="fit-content">
    Good
</Badge>

// For negative rating
<Badge variant="critical" width="fit-content">
    Bad
</Badge>
```

### Date Formatting

**Location:** `/home/jchi/projects/helios/frontend/src/util/date.tsx`

**Import:**
```tsx
import { formatDateTime, formatDate } from "util/date";
```

**Common Patterns:**

```tsx
// Format: "Jan 12, 2025 - 2:30 PM" (matches screenshot)
formatDateTime(row.createdAt)

// Without time
formatDate(row.createdAt)
// Returns: "Jan 12, 2025"

// With specific options
formatDateTime(row.createdAt, {
    seconds: true,
    timezone: true,
    utc: true,
})
// Returns: "Jan 12, 2025 - 2:30:45 PM UTC"
```

**Cell Renderer for Dates:**
```tsx
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
}
```

### Text with Ellipsis

**Import:**
```tsx
import { Span } from "@singlestore/fusion/components";
```

**Pattern (replacing inline styles):**
```tsx
// Instead of style={{ overflow: "hidden", textOverflow: "ellipsis", ... }}
<Span ellipsis maxWidth="30x" display="block">
    {row.questionPreview}
</Span>

// With title tooltip on hover
<Span ellipsis maxWidth="30x" display="block" title={row.questionPreview}>
    {row.questionPreview}
</Span>
```

### Link-Styled Text (Clickable Questions)

From the screenshot, the QUESTION column shows link-styled text. Use `color="link"` on a Span:

**Pattern:**
```tsx
<Span
    ellipsis
    maxWidth="30x"
    display="block"
    color="link"
    title={row.questionPreview}
    onClick={() => handleQuestionClick(row)}
    style={{ cursor: "pointer" }}
>
    {row.questionPreview}
</Span>
```

### User Display with Avatar Popover

**Location:** `/home/jchi/projects/helios/frontend/src/view/common/user-popover.tsx`

The `UserPopover` component displays an avatar with user initials, and on hover shows a popover with user details. It only requires a `userID` - the component internally queries org members via `GET_ORG_MEMBERS_BASE_INFO` GQL query to resolve the user info.

**Import:**
```tsx
import { UserPopover } from "view/common/user-popover";
```

**Usage in container service pages:**
- `/home/jchi/projects/helios/frontend/src/pages/organizations/pythonudf/python-udfs.tsx:76`
- `/home/jchi/projects/helios/frontend/src/pages/organizations/dashboards/dashboards.tsx:87`
- `/home/jchi/projects/helios/frontend/src/pages/organizations/code-services/code-services.tsx:105`
- `/home/jchi/projects/helios/frontend/src/pages/organizations/scheduled-notebooks/jobs.tsx:163`

**Pattern:**
```tsx
{
    id: "user",
    title: "USER",
    formatter: (row) => <UserPopover userID={row.userID} />,
    getValue: (row) => row.userID,
    defaultMinWidth: 140,
}
```

**How UserPopover works internally (lines 23-107):**
```tsx
export function UserPopover({ userID }: { userID: string }) {
    const { data, loading } = useOrganization<...>({
        query: GET_ORG_MEMBERS_BASE_INFO
    });

    const user = data?.organization.members.find(
        ({ userID: id }) => userID === id
    );

    const initials = user?.firstName[0] + user?.lastName[0] ?? "U";

    return (
        <HoverPopover
            trigger={
                <Flex flexDirection="row" alignItems="center" gap="1x">
                    <Avatar size="1" fallback={initials} />
                    <Paragraph lineHeight="fit">
                        {user?.firstName} {user?.lastName}
                    </Paragraph>
                </Flex>
            }
            content={/* Popover content with email and link to user profile */}
        />
    );
}
```

**For empty values:**
```tsx
import { LONG_EM_DASH } from "@single-js/common/util/symbols";

// Renders as "—" for null/undefined values
{row.value ?? LONG_EM_DASH}
```

---

## 5. Complete Filter Row Layout

Based on query-history-page.tsx:420-471 and screenshot (without Reviews, User filters, and Export CSV):

```tsx
<Flex m="2x" justifyContent="space-between">
    <MultiSelectGroup>
        <RatingsFilter
            buttonText="Ratings"
            selected={filters.ratings}
            onChange={(v) => handleFilter("ratings", v)}
        />
        <ReasonsFilter
            buttonText="Reasons"
            selected={filters.reasons}
            onChange={(v) => handleFilter("reasons", v)}
        />
    </MultiSelectGroup>
</Flex>
```

---

## 6. Key Imports Summary

```tsx
// Table
import type { GeneralTableColumn } from "@single-js/common/components/super-table/general-table";
import { GeneralTable } from "@single-js/common/components/super-table/general-table";

// Layout & Typography
import {
    Badge,
    Flex,
    Span,
    Paragraph,
    IconButton,
    Tooltip,
} from "@singlestore/fusion/components";

// Filters
import { MultiSelectGroup } from "@singlestore/fusion/components/multi-select";
import {
    MultiSelect,
    MultiSelectContent,
    MultiSelectItem,
    MultiSelectSelectAll,
    MultiSelectTriggerButton,
    MultiSelectValue,
} from "@singlestore/fusion/components/multi-select";

// User Display
import { UserPopover } from "view/common/user-popover";

// Icons
import { faEye } from "@fortawesome/sharp-regular-svg-icons";

// Utilities
import { LONG_EM_DASH } from "@single-js/common/util/symbols";
import { formatDateTime } from "util/date";

// Loading
import { Loading } from "@single-js/common/components/loading/loading";
```

---

## 7. Column Definitions for Feedback Table (Based on Screenshot)

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
                onClick={() => handleQuestionClick(row)}
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
            return LONG_EM_DASH;
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

---

## 8. Data Requirements

The current `Feedback` type from `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/api/feedback.ts:22-34`:

```tsx
export type Feedback = {
    id: string;
    domainID: string;
    sessionID: string;
    checkpointID: string;
    userID: string;           // Used by UserPopover to lookup user info
    rating: number;
    reasonCode: Nullable<string>;
    comment: Nullable<string>;
    questionPreview: string;
    createdAt: string;
    updatedAt: string;
};
```

**User Resolution:** The `UserPopover` component handles user lookup internally. It takes `userID` and queries `GET_ORG_MEMBERS_BASE_INFO` (from `/home/jchi/projects/helios/frontend/src/data/models/members-and-teams.gql.tsx:155`) to get the list of org members, then finds the matching user to display their name and avatar.

---

## 9. File References

| Component | Path |
|-----------|------|
| Existing FeedbackTab | `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-tab.tsx` |
| Existing FeedbackList | `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-list.tsx` |
| Feedback API | `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/api/feedback.ts` |
| Query History Page (filter pattern) | `/home/jchi/projects/helios/frontend/src/pages/organizations/monitoring/query-history/query-history-page.tsx:420-471` |
| Query History Filter Checkboxes | `/home/jchi/projects/helios/frontend/src/pages/organizations/monitoring/query-history/query-history-filter-checkboxes.tsx` |
| Query History Table (badge pattern) | `/home/jchi/projects/helios/frontend/src/pages/organizations/monitoring/query-history/query-history-table.tsx:422-450` |
| Date Utilities | `/home/jchi/projects/helios/frontend/src/util/date.tsx` |
| UserPopover Component | `/home/jchi/projects/helios/frontend/src/view/common/user-popover.tsx` |
| Members GQL Query | `/home/jchi/projects/helios/frontend/src/data/models/members-and-teams.gql.tsx:155` |
| Functions Table (column pattern) | `/home/jchi/projects/helios/frontend/src/pages/organizations/clusters/database/components/functions-table.tsx` |
| Python UDFs (UserPopover usage) | `/home/jchi/projects/helios/frontend/src/pages/organizations/pythonudf/python-udfs.tsx:76` |
| Dashboards (UserPopover usage) | `/home/jchi/projects/helios/frontend/src/pages/organizations/dashboards/dashboards.tsx:87` |
| Code Services (UserPopover usage) | `/home/jchi/projects/helios/frontend/src/pages/organizations/code-services/code-services.tsx:105` |

---

## Research Complete

Report saved to: `~/.claude/thoughts/research/2026-01-28_feedback-table-rendering-patterns.md`

**Next step:** To create an implementation plan based on this research:
```
/create_plan implement FeedbackTab table with filters, referencing ~/.claude/thoughts/research/2026-01-28_feedback-table-rendering-patterns.md
```
