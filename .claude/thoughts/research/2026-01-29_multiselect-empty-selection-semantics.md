---
type: research
title: MultiSelect Empty Selection Semantics - Paulo's Alternative Approach
project: helios
area: fusion-design-system/src/components/multi-select
tags: [multiselect, filters, design-system, UX, component-api]
date: 2026-01-29
status: complete
related_plans: []
---

# MultiSelect Empty Selection Semantics Research

## Context

PR #22303 renames `emptySelectionDisplay` to `treatNoSelectionAs` with values `"all-selected"` | `"none-selected"`. Paulo's review comment suggests an alternative approach:

> "Keeping both approaches could be a bit confusing, wouldn't it be better to make all items selected or not by default where we need the different behavior?"

This research analyzes whether Paulo's suggestion is feasible and what changes would be necessary.

## Overview

The MultiSelect component in the Fusion design system serves two distinct use cases:

1. **Selection variant** (`variant="select"`): Traditional multi-select for form inputs
2. **Filter variant** (`variant="filter"`): Filter controls where empty selection can mean either "show all" or "show none"

The `treatNoSelectionAs` prop controls the semantic meaning of an empty selection for filter variants.

## Current Design

### Component Location

- **Main component**: `fusion-design-system/src/components/multi-select/multi-select.tsx`
- **Stories**: `fusion-design-system/src/components/multi-select/multi-select.stories.tsx`

### The `treatNoSelectionAs` Prop

```typescript
// multi-select.tsx:49-56
treatNoSelectionAs?: "all-selected" | "none-selected";
```

**What it controls:**

| Aspect | `"all-selected"` (default) | `"none-selected"` |
|--------|---------------------------|-------------------|
| Display text | Just the label (e.g., "Status") | Label + "None" (e.g., "Status: None") |
| Button styling | No "selected" indicator | Shows "selected" state (blue outline) |
| Semantic meaning | Empty = no filter applied | Empty = explicit empty filter |

**Implementation in MultiSelectValue** (`multi-select.tsx:293-298`):
```typescript
let emptyText;
if (variant === "filter" && allItems.length > 0) {
    emptyText =
        context.treatNoSelectionAs === "all-selected" ? undefined : "None";
}
```

**Implementation in MultiSelectTriggerButton** (`multi-select.tsx:179-187`):
```typescript
const hasSomeSelected = value.length > 0 && value.length < allItems.length;
const isFilterNoneSelected =
    variant === "filter" &&
    treatNoSelectionAs === "none-selected" &&
    value.length === 0 &&
    allItems.length > 0;

const selected = hasSomeSelected || isFilterNoneSelected;
```

### Current Usage Across Codebase

**21 total usages found:**

| Behavior | Count | Example Locations |
|----------|-------|-------------------|
| `"all-selected"` (empty = show all) | 11 | `clusters-tab-all.tsx`, `query-history-filter-checkboxes.tsx`, `traces-multi-select-filter.tsx` |
| `"none-selected"` (empty = show none) | 10 | `maintenance.tsx`, `generic-pipeline-filter.tsx`, `cluster.tsx` |

### Filtering Logic Pattern

The component does NOT control filtering logic - consumers implement it themselves. Two patterns exist:

**Pattern A: Empty means "show all"** (used with `treatNoSelectionAs="all-selected"`):
```typescript
// clusters-tab-all.tsx:239-252
const filteredClusters = clusters.filter(({ cell, plan }) => {
    let filterCell = false;
    if (selectedCellFilters.length === 0) {
        filterCell = true;  // Empty = show all
    } else if (cell?.cellID) {
        filterCell = selectedCellFilters.includes(cell.cellID);
    }
    return filterCell;
});
```

**Pattern B: Empty means "show none"** (used with `treatNoSelectionAs="none-selected"`):
```typescript
// multi-select.stories.tsx:110-114 (storybook example)
const filteredNoneItems =
    noneValue.length === 0
        ? []  // Empty = show none
        : items.filter((item) => noneValue.includes(item.status));
```

## Paulo's Suggestion Analysis

### The Proposal

Instead of having a prop that changes the semantic meaning of empty selection:
- Remove the `treatNoSelectionAs` prop
- Always treat empty as "none selected" semantically
- If you want "all selected" behavior, initialize state with all items selected

### What Changes Would Be Required

#### 1. Component Changes

Remove from `MultiSelectContextValue`:
```typescript
// DELETE
treatNoSelectionAs?: "all-selected" | "none-selected";
```

Simplify `MultiSelectValue` empty display:
```typescript
// Always show "None" when empty for filter variant
if (variant === "filter" && value.length === 0 && allItems.length > 0) {
    emptyText = "None";
}
```

Simplify `MultiSelectTriggerButton` styling:
```typescript
// "selected" state when anything is selected OR when empty (for filter)
const selected = value.length > 0 && value.length < allItems.length;
// Remove the isFilterNoneSelected special case
```

#### 2. Consumer Changes (11 files)

All usages currently relying on `treatNoSelectionAs="all-selected"` would need to:

**a) Initialize state with all items:**
```typescript
// Before
const [selectedFilters, setSelectedFilters] = useState<string[]>([]);

// After
const [selectedFilters, setSelectedFilters] = useState<string[]>(allItems.map(i => i.value));
```

**b) Update filtering logic:**
```typescript
// Before (empty = show all)
const filtered = selected.length === 0
    ? items
    : items.filter(i => selected.includes(i.value));

// After (check for all selected)
const filtered = selected.length === allItems.length
    ? items  // All selected = show all
    : items.filter(i => selected.includes(i.value));
```

**c) Handle dynamic options:**
```typescript
// Need to sync selection when options change
useEffect(() => {
    // If new options were added, should they be auto-selected?
    // If options were removed, need to remove from selection
    setSelectedFilters(prev => {
        const validPrev = prev.filter(v => allItems.some(i => i.value === v));
        // Decision: add new items? Or leave them unselected?
        return validPrev;
    });
}, [allItems]);
```

### Files Requiring Migration

| File | Current Usage | Migration Complexity |
|------|--------------|---------------------|
| `clusters-tab-all.tsx` | 5x `all-selected` | Medium - static options |
| `clusters-tab-content.tsx` | 3x `all-selected` | Medium - static options |
| `query-history-filter-checkboxes.tsx` | 1x `all-selected` | High - dynamic server-driven options |
| `traces-multi-select-filter.tsx` | 1x `all-selected` | High - dynamic server-driven options |
| `ml-models-tab.tsx` | 1x `all-selected` | Low - static options |
| `model-service-table.tsx` | 1x `all-selected` | Low - static options |

## Tradeoffs Assessment

### Pros of Paulo's Approach

1. **Consistent mental model**: Display always matches actual state
2. **No semantic overloading**: Empty always means empty
3. **Simpler component API**: One less prop to understand
4. **Type-safer filtering**: No need for special `length === 0` cases

### Cons of Paulo's Approach

1. **Initialization complexity**: Must know all items upfront to select them
   - Problem: Server-driven option lists aren't available at state initialization
   - Workaround: Initialize empty, then select all in useEffect when data arrives

2. **Dynamic options handling**: When options change, selection state must be synced
   - Example: `query-history-filter-checkboxes.tsx` gets options from GraphQL query
   - Must decide: auto-select new options? Leave them unselected?

3. **URL state bloat**: If selection is persisted to URL query params:
   - Current: `?status=` (empty = all)
   - Paulo's: `?status=active,inactive,pending,archived` (all items listed)

4. **Visual clutter**: All items appear checked in dropdown initially
   - Current: Clean unchecked state with "Status" label
   - Paulo's: All checkboxes checked, "Status: All" or similar

5. **Reset behavior changes**: "Clear filters" action:
   - Current: Set to `[]` and display shows clean state
   - Paulo's: Must set to all items, which may look like filters are applied

6. **"Select All" checkbox UX**: Currently:
   - Unchecked initial state, clicking selects all
   - With Paulo's approach: Checked initial state, which is unusual

### Ergonomics Comparison

**Current approach (with `treatNoSelectionAs`):**
```tsx
// Simple initialization
const [selected, setSelected] = useState<string[]>([]);

// Simple reset
const handleClear = () => setSelected([]);

// Component usage
<MultiSelect
    value={selected}
    allItems={options}
    treatNoSelectionAs="all-selected"
/>
```

**Paulo's approach:**
```tsx
// Complex initialization
const [selected, setSelected] = useState<string[]>([]);

// Must sync when options load
useEffect(() => {
    if (options.length > 0 && selected.length === 0) {
        setSelected(options.map(o => o.value));
    }
}, [options]);

// Reset requires knowing all options
const handleClear = () => setSelected(options.map(o => o.value));

// Component usage (simpler, no prop)
<MultiSelect
    value={selected}
    allItems={options}
/>
```

## Recommendation

Paulo's approach has merit for **simplicity of mental model** but introduces significant **practical complexity** for the common use case of filters with server-driven options.

The current approach is more pragmatic because:

1. **Most filter UIs want "empty = all"** - this is the natural expectation
2. **Options often load asynchronously** - can't pre-select all until they arrive
3. **URL serialization is cleaner** - empty means no filter
4. **Visual state is cleaner** - unchecked items feel like "no filter applied"

### If We Were to Adopt Paulo's Approach

The most significant changes would be:

1. **Create a helper hook** to manage "select all on load" pattern:
   ```typescript
   function useAllSelectedByDefault<T extends string>(
       allItems: Array<{ value: T }>,
       initialSelected?: Array<T>
   ) {
       const [selected, setSelected] = useState<T[]>(initialSelected ?? []);

       // Auto-select all when items first load
       useEffect(() => {
           if (allItems.length > 0 && selected.length === 0) {
               setSelected(allItems.map(i => i.value));
           }
       }, [allItems.length]);

       return [selected, setSelected] as const;
   }
   ```

2. **Migrate all 11 usages** of `treatNoSelectionAs="all-selected"` to use this pattern

3. **Update storybook** to demonstrate the new pattern

4. **Consider URL state implications** for pages using query params

## Code References

| File | Line | Description |
|------|------|-------------|
| `fusion-design-system/src/components/multi-select/multi-select.tsx` | 49-56 | Prop definition |
| `fusion-design-system/src/components/multi-select/multi-select.tsx` | 179-187 | Button "selected" state logic |
| `fusion-design-system/src/components/multi-select/multi-select.tsx` | 293-298 | Empty display text logic |
| `frontend/src/pages/admin/clusters/clusters-tab-all.tsx` | 239-252 | Example filtering logic |
| `frontend/src/pages/organizations/monitoring/query-history/state/query-history-context.tsx` | 8-15 | Example empty filters constant |

---

## Research Complete

Report saved to: `~/.claude/thoughts/research/2026-01-29_multiselect-empty-selection-semantics.md`

**Next step:** To create an implementation plan based on this research:
```
/create_plan [describe the feature/task], referencing ~/.claude/thoughts/research/2026-01-29_multiselect-empty-selection-semantics.md
```
