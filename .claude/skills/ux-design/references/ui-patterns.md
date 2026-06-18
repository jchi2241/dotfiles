# UI Patterns Reference

Layout patterns by page type, visual hierarchy, accessibility, responsive design, and component methodology. Read the relevant section when the core process in SKILL.md calls for it.

## Page Type Patterns

### Dashboard / Overview

**Purpose:** Surface the most important information and enable quick triage without navigating away.

**Layout framework:**
1. **Top bar:** Global context (time range, filters, account switcher)
2. **KPI row:** 3-5 summary metrics with sparklines or trend indicators
3. **Primary content:** 2-3 column grid of charts/tables, most critical top-left
4. **Secondary content:** Activity feed, notifications, or recent items

**Principles:**
- Position the single most critical metric **top-left** (F-pattern primary scan area)
- Use **size and position** to signal hierarchy — bigger = more important
- Group related metrics logically; add section titles
- Context is mandatory: include comparisons, targets, trend data alongside raw numbers
- Each widget should answer a question ("Am I on track?") AND link to an action
- Consistent card structure: title → primary metric/viz → supporting context → action link
- Tune information density to user expertise (power users prefer higher density)

### Detail Page

**Purpose:** Show everything about a single entity.

**Layout framework:**
1. Breadcrumb + page title + status badge + primary action buttons
2. Summary card (key attributes at a glance)
3. Tabbed or sectioned content for different attribute groups
4. Related entities / activity log in secondary column or bottom section

**Principles:**
- Page header must unambiguously identify the entity (name, ID, status, breadcrumb)
- Group related attributes with clear headings (Gestalt: common region)
- Progressive disclosure: most-used info immediately, less-common behind tabs/expanders
- Inline actions near the data they affect, not in a remote toolbar

### List / Table Page

**Purpose:** Scan, compare, filter, sort, and select from a collection.

**Layout framework:**
1. Page title + primary action ("Create new")
2. Filter bar / search / sort controls
3. Table or card grid with consistent columns/layout
4. Pagination or infinite scroll
5. Bulk action bar (appears on selection)

**Principles:**
- All entries must follow the same structural pattern (users compare by scanning corresponding positions)
- Highest-priority attribute in the **top-left** of each entry
- Show 4-6 triage attributes to avoid pogo-sticking (repeatedly clicking into detail pages and back)
- Functional controls (search, filter, sort, bulk actions) above the list, clearly separated from data

### Settings Page

**Principles:**
- Group by domain, not by input type ("Notification Preferences" together, not "all toggles together")
- Related settings visually grouped with minimal spacing between them
- Show current value without requiring click-in
- Destructive settings (delete account, revoke access) require confirmation and spatial separation
- Save behavior must be clear: auto-save with feedback, or explicit "Save" with unsaved-changes indication

### Onboarding

**Principles:**
- **"Pull" over "push":** Show guidance at the moment needed (contextual tooltips) — not upfront tutorials users dismiss and forget
- **Paradox of the active user:** Users want to DO things immediately. Design onboarding as a byproduct of action, not a prerequisite.
- Progressive feature introduction — as users encounter features, not all at once
- Easy dismissal and later recall via help menu

### Empty States

Three requirements:

1. **Communicate system status.** Never blank — display a clear message: "No alerts configured yet"
2. **Provide learning cues.** Explain what will appear and what to do: "Star favorites to list them here."
3. **Enable direct action.** Include a CTA to populate the area: "Create your first alert"

---

## Atomic Design (Brad Frost)

Five hierarchical levels for building interfaces from components:

| Level | Definition | Example |
|-------|-----------|---------|
| **Atoms** | Smallest functional elements | Button, input, label, icon |
| **Molecules** | Simple groups with single responsibility | Search bar = label + input + button |
| **Organisms** | Complex sections composed of molecules | Site header = logo + nav + search |
| **Templates** | Page-level layout placing organisms | Content structure without final content |
| **Pages** | Templates populated with real content | Stress-test with edge cases |

**Process:**
1. Build atom library (typography, colors, spacing, form elements, icons)
2. Compose molecules, test in isolation
3. Assemble organisms in representative context
4. Create templates on responsive grid
5. Populate pages with real content — test: longest string, shortest string, zero items, max items, errors, permission variations

---

## Visual Hierarchy

### Three Primary Tools

**1. Color and Contrast**
- High contrast = high importance
- Saturated/bright for primary actions; muted for secondary
- Limit to 2 primary + 2 secondary colors
- Max 3 contrast tiers
- Never rely on color alone (accessibility)
- **Squint test:** blur the page — hierarchy should still emerge

**2. Scale**
- Larger = more important
- Max 3 size tiers (body, subhead, heading)
- Max 2 large elements per viewport to prevent competition

**3. Grouping (Proximity + Common Region)**
- Increase spacing between unrelated groups; decrease within related groups
- Use containers when whitespace alone is insufficient
- Important content gets generous surrounding whitespace

### Scanning Patterns

**F-Pattern** (content-heavy pages: articles, data tables, search results):
1. Horizontal sweep across top
2. Shorter horizontal sweep slightly lower
3. Vertical scan down left side
- **Design for it:** front-load headings, key info in first two lines, bold key terms, use bulleted lists

**Z-Pattern** (sparse pages: login, landing, simple dashboards):
1. Top-left → top-right
2. Diagonal to bottom-left
3. Bottom-left → bottom-right
- **Design for it:** logo top-left, CTA top-right, conversion action bottom-right

---

## Accessibility (POUR)

### Perceivable
- Text alternatives for non-decorative images
- 4.5:1 contrast for normal text; 3:1 for large text and UI components
- Don't convey info through color alone — add icons, text, or patterns
- Support 200% text resize without content loss
- Captions for video, transcripts for audio

### Operable
- Full keyboard accessibility for every interactive element
- Visible focus indicators (never `outline: none` without replacement)
- Logical tab order matching visual layout
- Skip links for repetitive navigation
- No time limits without user control
- Adequate touch target spacing

### Understandable
- Logical heading hierarchy (one h1, sequential levels)
- Consistent navigation placement across pages
- All inputs have associated `<label>` with `for`/`id`
- Errors: summary list + inline next to fields
- Descriptive link/button text ("Download invoice" not "Click here")
- Autocomplete on common form fields

### Robust
- Valid semantic HTML (`<nav>`, `<main>`, `<button>`, `<table>` with `<th scope>`)
- `lang` attribute on `<html>`
- Unique, descriptive page titles
- ARIA only when semantic HTML is insufficient

---

## Responsive / Mobile-First

### Process

1. **Content priority.** Rank all content. Mobile shows highest-priority without scrolling.
2. **Single-column layout.** Stack everything vertically in priority order.
3. **Design smallest breakpoint first.** Fully functional — not a degraded experience.
4. **Add complexity at wider breakpoints:** multi-column, visible nav (not hamburger), expanded tables, persistent sidebars.
5. **Leverage device capabilities.** Desktop: hover states, keyboard shortcuts. Mobile: touch gestures, bottom-reachable actions.

### Critical Caveat (NNGroup)

Mobile-first does NOT mean mobile-only. Porting mobile patterns (hamburger menus, hidden search, bottom nav) directly to desktop **degrades** desktop usability. Navigation usage drops significantly when mobile patterns are applied unchanged to desktop.

### Responsive Fundamentals

- Fluid grids (proportions, not fixed pixels)
- Breakpoints tied to content needs, not arbitrary device widths
- Content reshuffling: 3 cols → 2 → 1
- Test on real devices, not just browser resizing

---

## Gestalt Principles

| Principle | Rule | Application |
|-----------|------|-------------|
| **Proximity** | Close items = related (strongest principle) | Whitespace as primary organizer. Reduce spacing within groups; increase between. |
| **Similarity** | Shared visual traits = functionally related | All primary CTAs look identical; secondary share different-but-consistent style. |
| **Common Region** | Same boundary = same group | Cards for related settings/metrics. Background color for page sections. |
| **Continuity** | Line/curve alignment = sequence | Vertical form fields, horizontal breadcrumbs, step indicators. |
| **Closure** | Mind completes incomplete shapes | Partial borders or implied containers suggest grouping without heavy borders. |
| **Figure-Ground** | Focal object vs. background | Contrast, shadows, whitespace make primary content pop. Modals leverage explicitly. |
| **Common Fate** | Move together = grouped | Animate related elements together during transitions. |
| **Symmetry** | Balanced = stable | Balanced grids for stability; center-align hero content for emphasis. |

---

## NNGroup Top 10 Application Mistakes

Sweep against these during Phase 4 validation:

1. **Poor feedback** — No system status. Fix: spinners (2-10s), progress bars (10s+).
2. **Inconsistency** — Same action, different labels/locations. Fix: audit terminology and spatial patterns.
3. **Bad error messages** — "Something went wrong." Fix: explain what, why, and how to recover.
4. **No default values** — Forcing decisions everywhere. Fix: pre-select most common option.
5. **Unlabeled icons** — Icons without text. Fix: always pair icons with text labels.
6. **Tiny click targets** — Hard to acquire. Fix: generous sizing, clear affordances.
7. **Modal overuse** — Covering reference content. Fix: inline editing or side panels.
8. **Meaningless info** — Database IDs as identifiers. Fix: human-readable labels first.
9. **Junk-drawer menus** — "More..." hiding features. Fix: descriptive categories with clear scent.
10. **Destructive near confirm** — "Save" next to "Delete." Fix: spatial separation + visual differentiation.

---

## Design System Layout Principles

### Shopify Polaris

- Space and proximity define relationships — whitespace over divider lines
- Emphasis creates hierarchy — size, weight, contrast as primary tools
- Software-first — elements sized by function, not visual impact
- Group by relationship — related data in same card; nested surfaces for sub-grouping

### IBM Carbon

- Universal patterns: 15 standardized solutions (dialogs, forms, notifications, search, empty states, loading, filtering, global header)
- 2x grid system for mathematical spatial consistency
- Content treated as foundational design material, not afterthought

### Cross-Cutting

- **Tokens over hardcoded values** — colors, spacing, typography as themeable tokens
- **Minimal component API** — cover 80% of use cases with escape hatches for 20%
- **Page-level patterns are as important as components** — systems that only define buttons but not "how to build a settings page" leave the hardest decisions to individual teams
