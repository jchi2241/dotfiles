---
type: prd + tech-spec
title: Chat Review - Domain Owner Conversation Visibility
project: helios, heliosai
area: frontend/intelligence, cmd/nova-gateway, auracontext service, auracontextstore
tags: [chat-review, recording, feedback, domain-configuration, pagination]
date: 2026-02-09
status: draft
---

# Part 1: PRD

## Problem

Domain owners lack visibility into how the analyst is performing for their domain. Today, the only signal is explicit user feedback (thumbs up/down), which is sparse — most users never leave feedback. Domain owners need a way to observe actual analyst conversations to evaluate quality, identify gaps in domain configuration, and proactively improve the analyst experience.

## Solution

Introduce a **Chat Review** feature that gives domain owners a unified view of both recorded analyst turns and user feedback within the domain configuration flyout.

Domain owners can enable **recording** on a per-domain basis. When recording is on, every turn (user question + assistant response) is captured and made available for review. These recorded turns appear alongside existing feedback entries in a single, filterable, paginated table.

---

## Scope

### In Scope

1. **Recording toggle** — A per-domain setting to enable/disable turn recording, managed in the renamed "Settings" tab (formerly "Details").
2. **Chat Review tab** — A new tab (replacing "Feedback") displaying both recorded turns and feedback in a unified table with filtering and pagination.
3. **Turn capture** — Backend logic to persist turns when recording is enabled for the domain.
4. **Consolidated API** — New `/chat-review` endpoints for listing entries and drilling into threads.
5. **Pagination** — Cursor-based pagination (Stripe-style, forward-only API).
6. **Thread drill-down** — Clicking a row opens the full conversation thread via a new generic thread endpoint.

---

## User Stories

**As a domain owner**, I want to enable recording for my domain so that I can review how the analyst responds to users.

**As a domain owner**, I want to see all recorded turns and user feedback in a single table so that I have one place to assess analyst quality.

**As a domain owner**, I want to filter the Chat Review table by rating (good, bad, unrated, or all), reason code, date range, and user so that I can focus on what matters.

**As a domain owner**, I want to paginate through results so that performance remains good as data grows.

**As a domain owner**, I want to click a row to see the full conversation thread so that I can understand the context around a response.

**As a domain owner**, I want to disable recording at any time, with the understanding that new turns will stop being captured but previously recorded turns remain visible.

---

## Feature Details

### 1. Recording Toggle

**Location:** Domain configuration flyout > **Settings** tab (renamed from "Details").

**Behavior:**
- Toggle is OFF by default for all domains (existing and new).
- When turned ON, the backend records a `recording_enabled_at` timestamp. This timestamp serves as the lower bound — only turns occurring after this point are captured.
- When turned OFF, `recording_enabled_at` is cleared (or a `recording_disabled_at` is set). New turns are no longer captured. Previously recorded turns remain viewable.
- Toggling ON again sets a new `recording_enabled_at`, creating a new recording window. Turns from the gap (recording off period) are never captured.

### 2. Tab Renames

| Current Name | New Name |
|---|---|
| Details | Settings |
| *(new)* | Chat Review |

**Tab order:** Data, Context, Access Controls, API Keys, **Chat Review**, **Settings**

Chat Review replaces where a Feedback tab would have been. Settings remains last.

### 3. Chat Review Tab — Unified Table

The Chat Review table displays two **entry types** in a single list:

| Entry Type | Description |
|---|---|
| `feedback` | User-submitted thumbs up/down with optional reason/comment |
| `recorded_turn` | System-captured turn (user question + assistant response) with no explicit rating |

A recorded turn that later receives user feedback is promoted to `type = 'feedback'` — the table always shows one row per conversation turn.

**Table columns:**

| Column | Description |
|---|---|
| Type | Icon or badge: feedback (thumbs icon) or recorded turn (chat icon) |
| Question Preview | Truncated user question (first ~150 chars) |
| User | Display name or ID of the user who asked |
| Rating | Thumbs up/down for feedback; empty for recorded turns |
| Timestamp | When the feedback was submitted or the turn was recorded |

**Interactions:**
- Click a row to open the full conversation thread in the chat review thread flyout.
- Fixed sort order: newest first (`created_at DESC`).
- Paginated with page size selector (10/20/30/40/50) and prev/next navigation.

**Filters:**

| Filter | Control | Options | Default | Notes |
|---|---|---|---|---|
| Rating | Segmented control (single-select) | **All**, **Good** (1), **Bad** (-1), **Unrated** (—) | All | Unrated shows entries with `rating IS NULL` (recorded turns and entries without a rating). All shows everything. |
| Reason code | Multi-select dropdown (Fusion `MultiSelect` `variant="filter"`) | **—** (no reason), plus all codes from `GET /v1/feedback-reasons` | None selected (show all) | **—** matches `reason_code IS NULL`. Selecting specific reasons implicitly excludes recorded turns (they have no reason). Multi-select: OR within values. Uses existing Fusion `MultiSelectSelectAll` for toggle-all. |
| User | Multi-select searchable dropdown | Populated from the domain's **access control list endpoint** (existing member list) | None selected (show all) | Multi-select: OR within values. Searchable typeahead over domain members. |
| Date range | `DateRangePicker` (reuse `view/common/date-range-picker.tsx`) | Presets: **Last 7 days**, **Last 30 days**, **Last 90 days**, **Custom range** | No date range (all time) | Presets are frontend-only logic — convert to UTC RFC3339 `start_date`/`end_date` before API call. Trimmed preset list (query history has 15; Chat Review only needs 3 + custom). |

**Filter interaction rules:**
- Filters are AND across dimensions (rating AND reason AND user AND date range).
- Multi-select values within a dimension are OR (user A OR user B).
- **No cascading/dynamic narrowing.** All filter options remain visible regardless of other active filters. If a combination yields zero results, the empty state handles it.
- **Reason code + rating interaction:** When a reason code is selected and rating is "All", results naturally exclude recorded turns (they have `reason_code = NULL` unless the **—** option is also selected). When rating is "Good", most reason codes will yield zero results (reasons are typically associated with negative feedback). The frontend does not prevent these combinations — the API returns an empty set, and the empty state communicates clearly.
- Each filter control shows an active indicator when a non-default value is selected (existing `MultiSelect` `variant="filter"` active state pattern). Individual filters support clearing to default via the per-filter clear pattern used in query history.

**Empty states:**
- **Recording OFF, no feedback exists:** "No feedback yet. Enable recording in the Settings tab to capture analyst conversations for review."
- **Recording OFF, historical feedback/recorded turns exist:** Show the table normally.
- **Recording ON, no entries yet:** "Recording is enabled. Entries will appear here as users interact with the analyst."
- **Filters applied, no matching entries:** "No entries match the current filters." Each active filter shows its clear/reset control. Distinct from the "no data exists" states above.

### 4. Turn Recording Mechanism

When recording is enabled for a domain and a user receives an analyst response:
- The system captures a lightweight record of the turn (domain, session, checkpoint, user, question preview, timestamp).
- The conversation content itself is already stored in checkpoint blobs — the recorded turn entry is a pointer, same pattern as feedback.
- If the user later submits feedback on the same response, the recorded turn is promoted to feedback (one row, enriched over time).

---

## Key Decisions

### Persist rows vs. virtual query from recording time ranges

**Decision:** Persist a row per recorded turn.

**Alternative considered:** Don't write any new rows. Instead, store recording on/off time windows in the domain config JSON (e.g., `[{enabled_at: T1, disabled_at: T2}, {enabled_at: T3}]`) and query existing checkpoint/session data at read time — the "virtual" approach. This avoids per-turn writes entirely.

**Why persist won:**

The virtual approach is appealing because it avoids write-path changes entirely. But it fails on the existing schema:

| Dimension | Persist rows | Virtual query |
|---|---|---|
| **Schema fit** | Extends the existing `feedback` table (same shape). No changes to checkpoint or session tables. | `checkpoints` has no `created_at` column and no `domain_id`. Can't query "checkpoints created within a recording window for domain X" without: (1) adding `created_at` to the highest-write table in the system, (2) JOINing `sessions` on every query for domain scoping — no covering index exists for this join. |
| **question_preview** | Extracted once from the msgpack checkpoint blob at write time (~1-5ms). Stored as a VARCHAR column, served directly from the index. | Extracted from the blob on every page load. Each blob is 50-500KB of msgpack. A single page of 50 entries decodes 50 blobs — 2.5-25MB of I/O per page view. This is the read-time cost of avoiding a 200-byte write. |
| **Pagination** | Standard cursor query: `WHERE (created_at, id) < (?, ?) ORDER BY created_at DESC, id DESC LIMIT 51`. Hits the SORT KEY directly. O(limit). | No usable cursor anchor — checkpoints lack `created_at`. The query requires a full JOIN + sort: `SELECT ... FROM checkpoints JOIN sessions ON thread_id = id WHERE sessions.domain_id = ? AND <window clauses> ORDER BY ???`. No SORT KEY to leverage. Even with a `created_at` column added, the JOIN prevents index-only pagination. |
| **Recording windows** | Structural guarantee: no row exists before `recording.enabled_at`, so no data outside the window is returned — regardless of query bugs. | Time-window filtering: `WHERE created_at BETWEEN T1 AND T2 OR created_at BETWEEN T3 AND T4 ...`. Multiple on/off toggles produce multiple OR'd ranges. A bug in window boundary logic could expose conversations from before recording was enabled. The security boundary is a query predicate, not a data invariant. |
| **Feedback dedup** | Same table, same deterministic ID. Recorded turn + later feedback = one row via UPSERT. No dedup logic needed in any query. | Two data sources: virtual result set (checkpoints) + feedback table. Displaying both in a unified list requires `LEFT JOIN feedback ON SHA256(checkpoint_id:session_id) = feedback.id` to avoid showing the same turn twice. This dedup JOIN runs on every page load and is fragile if the ID generation logic drifts between the read path and the write path. |
| **Write cost** | ~200 bytes per row. Best-effort goroutine, ~2-4ms, swallowed on failure. At 1,000 domains all recording with 100 turns/domain/day: ~20MB/day, ~7GB/year. Zero latency impact on checkpoint response (goroutine). | Zero writes. But the read cost (blob decoding, JOIN, no index) dwarfs the write savings on any domain with regular usage. |
| **Filtering** | Standard SQL: `WHERE rating = ? AND reason_code IN (...) AND user_id IN (...)`. All filter columns are on the persisted row. Composable with the cursor. | Filters like `rating` and `reason_code` only exist on the feedback table, not on checkpoints. Filtering virtual entries by these fields requires the dedup JOIN even for basic queries. Unrated recorded turns have no row to filter — they're synthesized from checkpoint data and can't be filtered by feedback-specific attributes. |

**Summary:** The virtual approach trades a trivial write (~200 bytes, best-effort) for an expensive read (multi-table JOIN, blob decoding, no pagination index, fragile dedup). The existing schema was not designed to support read-time reconstruction of domain-scoped conversation turns. The persist approach works with the schema as-is, reuses the feedback table's existing indexes and cursor pagination, and provides a structural security guarantee that pre-recording conversations cannot be exposed.

### Single table vs. separate tables

**Decision:** Extend the existing `feedback` table with a `type` column rather than creating a separate `recorded_turns` table. See Tech Spec § Database Changes for rationale.

### Pagination strategy

**Decision:** Stripe-style cursor-based pagination with a forward-only API and client-side cursor caching for backward navigation.

**API shape:**
- `limit` (page size) + `starting_after` (entry ID cursor). No `offset`, no `ending_before`.
- Response includes `has_more` (bool). No `total_count` — avoids a `COUNT(*)` query on every page load, which degrades linearly with table growth.
- Sort order is fixed: `created_at DESC, id DESC`. Not configurable.

**Cursor mechanics:**
- Compound cursor `(created_at, id)` — the pair is always unique, eliminating duplicate-timestamp edge cases where items can be skipped or duplicated at page boundaries.
- The `id` is a SHA256 hex string, not a sequential integer. Lexicographic ordering of hex within a tied timestamp is arbitrary but **stable** — the hash is deterministic and immutable after insert, so page boundaries never shift. The tiebreaker doesn't need to be chronological; it only needs to be unique and consistent.
- Client sends an entry ID; server resolves it to `(created_at, id)` via single-row lookup, then uses `WHERE (created_at, id) < (?, ?)` for the range scan.
- `LIMIT + 1` trick: fetch one extra row to derive `has_more` without a separate query.

**Frontend navigation:**
- Next page: pass last entry's ID as `starting_after`, cache it in a `cursors[]` array indexed by page number.
- Previous page: re-fetch using the already-cached cursor for that page (query hook cache hit — no network call).
- Filter or page size change: reset `cursors` array and page number to 1.

**Why not offset-based:**
1. `OFFSET N` scans and discards N rows — O(offset + limit) per page. Cursor is O(limit) regardless of depth.
2. Concurrent writes shift offset positions — new entries cause duplicates/skips across pages. Cursors anchor to a specific `(created_at, id)` position that is stable under inserts.
3. The existing auracontext `ListFeedback` uses offset but returns no `total_count` — the pattern was incomplete and needed rework regardless.

**Why forward-only API (no `ending_before`):**
- The UX is prev/next with a page size selector — the client always knows which page it came from.
- Backward navigation is handled client-side by re-fetching with a cached cursor. The query hook (React Query) caches results, so prev-page clicks are instant.
- Eliminating the reverse query path (`ending_before` → ASC query → reverse results) halves the backend code paths.

**Improvement over existing codebase cursor pattern (Code Services, Scheduled Jobs):**
- Existing pattern uses `createdat <= :cursor_time AND id != :cursor_id` — vulnerable to duplicate-timestamp skips when multiple items share a timestamp. The tuple comparison `(created_at, id) < (?, ?)` is mathematically correct for any timestamp distribution.
- Existing pattern makes 3 queries per page (data + `HasNextPage` + `HasPreviousPage`). This makes 1 (data with `LIMIT + 1` for `has_more`).

---

## Open Questions

1. **Backward compatibility on existing `GET .../feedback` endpoint** — Adding `WHERE type = 'feedback'` ensures the existing endpoint only returns explicit feedback. Confirm no consumers rely on the absence of a `type` field in the response (the field will now be present on all rows).

2. **User consent and notification for recording** — When a domain owner enables recording, end users are not currently notified that their conversations are being captured and reviewable. Should the analyst UI show a "this conversation may be recorded" indicator when recording is active for the domain? Legal/compliance review may be needed for GDPR (Article 13/14 disclosure requirements) and CCPA before shipping to EU/CA users. This also intersects with the deferred retention policy question — recorded data currently accumulates indefinitely with no deletion path.

---
---

# Part 2: Tech Spec

## Architecture Overview

The feature spans four layers:

| Layer | Repository | Changes |
|---|---|---|
| **Frontend** (Helios) | `helios/frontend` | New Chat Review tab, Settings tab rename, recording toggle UI, paginated table |
| **Nova Gateway** | `helios/cmd/nova-gateway` | Two new proxy routes (`/chat-review`, `/chat-review/{entryID}/thread`) |
| **Aura Context Service** | `heliosai/services/auracontext` | New chat-review handlers, recording capture in checkpoint path, schema migration |
| **Aura Context Store** | `helios/auracontextstore` | v11 migration (ALTER feedback table) |

---

## API Design

### New Endpoints

```
GET  .../domains/{domainID}/chat-review                   # List entries (feedback + recorded turns)
GET  .../domains/{domainID}/chat-review/{entryID}/thread   # Thread drill-down for any entry
```

### Existing Endpoints — Unchanged

```
POST .../domains/{domainID}/feedback                       # Submit feedback (end-user facing, inline thumbs up/down)
GET  .../domains/{domainID}/feedback?session_id=X          # User's own feedback lookup (end-user facing)
GET  .../domains/{domainID}/feedback/{feedbackID}/thread    # Legacy thread endpoint (deprecated, keep working)
GET  /v1/feedback-reasons                                  # Reason code list
PUT  .../domains/{domainID}                                # Update domain settings (extended with recording config)
```

The `/feedback` endpoints serve the **end-user inline experience** (thumbs up/down on responses). The `/chat-review` endpoints serve the **domain-owner review experience**. Clean separation of concerns.

### List Chat Review Entries

```
GET .../domains/{domainID}/chat-review
```

**Query parameters:**

| Param | Type | Default | Description |
|---|---|---|---|
| `starting_after` | string | | Entry ID cursor — fetch entries after this position (next page). Omit for first page. |
| `limit` | int | 50 | Page size (max: 200) |
| `type` | string | *(both)* | Filter: `feedback`, `recorded_turn`, or omit for both. Available for API consumers; frontend uses `rating` as the primary filter instead. |
| `user_id` | string (CSV) | | Filter by user(s). Comma-delimited for multiple: `?user_id=uuid1,uuid2`. OR logic within values. |
| `rating` | int | | Filter by rating: `1` (good), `-1` (bad), or `0` (unrated — `rating IS NULL`, includes recorded turns and entries without a rating). Omit to show all entries. |
| `reason_code` | string (CSV) | | Filter by reason code(s). Comma-delimited: `?reason_code=missing_data,other,none`. OR logic within values. `none` is a sentinel for entries with no reason code (`reason_code IS NULL`). |
| `start_date` | RFC3339 | | Lower bound on timestamp |
| `end_date` | RFC3339 | | Upper bound on timestamp |

**Response:**
```json
{
  "results": {
    "entries": [
      {
        "id": "sha256-hex",
        "type": "feedback",
        "domain_id": "uuid",
        "session_id": "uuid",
        "checkpoint_id": "string",
        "user_id": "uuid",
        "question_preview": "What is the total revenue...",
        "rating": -1,
        "reason_code": "missing_data",
        "comment": "Numbers seem wrong",
        "created_at": "2026-02-09T..."
      },
      {
        "id": "sha256-hex",
        "type": "recorded_turn",
        "domain_id": "uuid",
        "session_id": "uuid",
        "checkpoint_id": "string",
        "user_id": "uuid",
        "question_preview": "Show me all orders from...",
        "rating": null,
        "reason_code": null,
        "comment": null,
        "created_at": "2026-02-09T..."
      }
    ],
    "has_more": true
  }
}
```

Sort order is fixed: `created_at DESC, id DESC` (newest first).

**Implementation:**

1. **Data query:** If `starting_after` is provided, resolve the entry ID to `(created_at, id)` via single-row lookup. Then:
   ```sql
   SELECT * FROM feedback
   WHERE domain_id = ? AND (created_at, id) < (?, ?)
     [AND type IN (...)]                                     -- if type filter
     [AND user_id IN (?, ?, ...)]                            -- if user_id (multi-value, OR)
     [AND rating = ?]                                        -- if rating = 1 or -1
     [AND rating IS NULL]                                    -- if rating = 0 (unrated sentinel)
     [AND (reason_code IN (?, ...) OR reason_code IS NULL)]  -- if reason_code includes 'none' + others
     [AND reason_code IN (?, ...)]                           -- if reason_code without 'none'
     [AND reason_code IS NULL]                               -- if reason_code = 'none' only
     [AND created_at >= ?]                                   -- if start_date
     [AND created_at <= ?]                                   -- if end_date
   ORDER BY created_at DESC, id DESC
   LIMIT :limit + 1
   ```
   If `len(rows) > limit`, set `has_more = true` and trim to `limit`. Uses the compound cursor `(created_at, id)` for stable page boundaries — no duplicate-timestamp skips. Without `starting_after`, omit the tuple WHERE clause (first page).

   **Multi-value filter logic:** `user_id` and `reason_code` accept comma-delimited values (e.g., `?reason_code=missing_data,other,none`). Parsed via `strings.Split(r.URL.Query().Get("reason_code"), ",")` → `[]string`. This follows the Google API convention for multi-value query params. The `none` sentinel for `reason_code` is translated to `IS NULL` in the query. When `none` is combined with other reason codes, the clause becomes `(reason_code IS NULL OR reason_code IN (...))`. Use squirrel's `sq.Or{sq.Eq{"reason_code": nil}, sq.Eq{"reason_code": values}}` for composition.

   **Rating `0` sentinel:** The API accepts `rating=0` to mean "unrated" (`rating IS NULL`). The handler translates `0` to a `sq.Eq{"rating": nil}` clause. Values `1` and `-1` remain standard equality filters.

Uses the composite index `(domain_id, type, created_at DESC)`.

### Chat Review Thread Drill-Down

```
GET .../domains/{domainID}/chat-review/{entryID}/thread
```

**Response:**
```json
{
  "results": {
    "entry": {
      "id": "sha256-hex",
      "type": "recorded_turn",
      "domain_id": "uuid",
      "session_id": "uuid",
      "checkpoint_id": "string",
      "user_id": "uuid",
      "question_preview": "Show me all orders from...",
      "rating": null,
      "reason_code": null,
      "comment": null,
      "created_at": "2026-02-09T..."
    },
    "thread": {
      "title": "Order Analysis",
      "messages": [...],
      "follow_up_suggestions": [...],
      "latest_settings": {...}
    }
  }
}
```

**Implementation:** The handler follows the exact same pattern as the existing `GetFeedbackThread`:

| Step | Current `GetFeedbackThread` | New `GetChatReviewThread` |
|---|---|---|
| 1 | Extract `feedbackID` from path | Extract `entryID` from path |
| 2 | `getFeedbackByID(feedbackID)` | `getEntryByID(entryID)` — same table, same query |
| 3 | Verify `feedback.domain_id` matches requested domain | Verify `entry.domain_id` matches — identical |
| 4 | Verify `session.domain_id` matches (defense-in-depth) | Identical |
| 5 | `getThreadForFeedback(session_id, checkpoint_id)` | `getThreadForEntry(session_id, checkpoint_id)` — identical logic |
| 6 | Return `{ feedback: {...}, thread: {...} }` | Return `{ entry: {...}, thread: {...} }` — shape change |

The only material difference is the response shape: `feedback` key becomes `entry` and includes the `type` field. The underlying thread retrieval (`GetSessionByID` → `GetCheckpointBlobsForCheckpoint` → `GetCheckpointIDsUpTo` → msgpack decode) is unchanged.

The existing `GET .../feedback/{feedbackID}/thread` endpoint continues to work as-is for backward compatibility. It returns the old response shape with `feedback` key. It can be deprecated once the frontend migrates to the new endpoint.

---

## RBAC

### Permission rename

`AgentDomainViewFeedback` is renamed to **`AgentDomainReviewConversations`**. The old name was feedback-specific; the new name reflects the broader scope of reviewing both feedback and recorded turns. This is a code-only change — permission strings are resolved from `agentdomain.yaml` at startup, not persisted in grant rows. Role assignments (Owner gets all permissions) are unchanged.

**Files to update:**
- `agentdomain.yaml` — rename the permission definition
- `graph/authz.go:385-415` — update the GraphQL permission mapping
- `feedbackhandler.go` — update the action constant in `ProxyListFeedback`
- New `ProxyListChatReview` handler — uses the new name from the start

| Endpoint | RBAC Permission | Rationale |
|---|---|---|
| `GET .../chat-review` | `AgentDomainReviewConversations` | Gates access to the domain-owner review table (feedback + recorded turns). |
| `GET .../chat-review/{entryID}/thread` | `AgentDomainViewUserConversations` | Viewing a recorded turn's thread IS viewing a user's conversation. The permission name is generic enough to cover both entry types. |
| `PUT .../domains/{domainID}` (recording toggle) | `AgentDomainUpdate` | Reuses the existing domain update permission. The recording toggle is a domain setting — same authorization as changing domain name or description. |
| `GET .../feedback` (existing) | `AgentDomainReviewConversations` | Same permission, renamed. Existing `ProxyListFeedback` handler updated to use new constant. |

**No new permissions needed:**
- `AgentDomainReviewConversations` — replaces `AgentDomainViewFeedback`. Covers the "review analyst quality" use case for both entry types.
- `AgentDomainViewUserConversations` — already describes the action generically. A recorded turn's thread is a user conversation.
- `AgentDomainUpdate` — the recording toggle is a domain configuration setting. No different from updating domain name or description.

### Gateway handler pattern

Both new handlers follow the same proxy pattern as the existing feedback handlers:

```go
// ProxyListChatReview — same pattern as ProxyListFeedback (feedbackhandler.go:43-98)
// 1. Extract orgID, domainID from path
// 2. checkDomainPermission(..., AgentDomainReviewConversations, ...)
// 3. If !hasPermission → 403
// 4. Reverse proxy to upstream

// ProxyGetChatReviewThread — same pattern as ProxyGetFeedbackThread (feedbackhandler.go:104-147)
// 1. Extract orgID, domainID, entryID from path
// 2. checkDomainPermission(..., AgentDomainViewUserConversations, ...)
// 3. If !hasPermission → 403
// 4. Reverse proxy to upstream
```

The existing `checkDomainPermission()` helper (feedbackhandler.go:163-190) is reused directly — it's already parameterized on the required action.

---

## Database Changes

### Decision: Single Table

We evaluated separate tables (`feedback` + `recorded_turns`) vs. extending the existing `feedback` table. Single table was chosen for three reasons:

1. **No dedup problem.** Both entry types share the same deterministic ID (`SHA256(checkpoint_id:session_id)`). A recorded turn that later gets feedback is a single UPSERT — the row is promoted from `recorded_turn` to `feedback` with rating/reason populated. Separate tables would produce two rows for the same checkpoint, requiring JOIN-based dedup in every query.
2. **Native pagination.** Single table query with cursor-based `WHERE (created_at, id) < (?, ?) ORDER BY created_at DESC, id DESC` uses the existing SORT KEY directly. UNION ALL over two tables requires materializing both result sets before sorting and slicing — degrades linearly with scale.
3. **Low migration risk.** Both ALTERs (`ADD COLUMN` with DEFAULT, `MODIFY COLUMN` to nullable) are metadata-only operations on SingleStore. No data rewrite, no backfill.

### Migration v11: Alter `feedback` table

```sql
-- v11/alter_ddl.sql

-- Guarded ADD COLUMN (SingleStore lacks IF NOT EXISTS for columns)
DELIMITER //
DO BEGIN
    ALTER TABLE feedback ADD COLUMN type VARCHAR(20) NOT NULL DEFAULT 'feedback';
EXCEPTION
    WHEN ER_DUP_FIELDNAME THEN
    BEGIN ROLLBACK; END;
    WHEN OTHERS THEN
    BEGIN ROLLBACK; RAISE; END;
END //
DELIMITER ;

-- Guarded MODIFY COLUMN (rating nullable)
DELIMITER //
DO BEGIN
    ALTER TABLE feedback MODIFY COLUMN rating TINYINT NULL;
EXCEPTION
    WHEN ER_DUP_FIELDNAME THEN
    BEGIN ROLLBACK; END;
    WHEN OTHERS THEN
    BEGIN ROLLBACK; RAISE; END;
END //
DELIMITER ;

CREATE INDEX IF NOT EXISTS idx_feedback_domain_type_created ON feedback (domain_id, type, created_at DESC);
```

- `type` defaults to `'feedback'` — existing rows are automatically classified without a data migration.
- `rating` becomes nullable — recorded turns have `rating = NULL`.
- New composite index supports the chat-review list query: `WHERE domain_id = ? AND type IN (...) ORDER BY created_at DESC`.

### No schema migration for recording toggle

The recording setting lives in the existing `domains.config` JSON column:

```json
{
  "data": { "tables": [...] },
  "recording": {
    "enabled": true,
    "enabled_at": "2026-02-09T12:00:00Z"
  }
}
```

No DDL change needed. The `DomainConfig` Go struct is extended:

```go
type DomainConfig struct {
    Data      *DomainConfigData      `json:"data,omitempty"`
    Recording *DomainRecordingConfig `json:"recording,omitempty"`
}

type DomainRecordingConfig struct {
    Enabled   bool       `json:"enabled"`
    EnabledAt *time.Time `json:"enabled_at,omitempty"`
}
```

---

## Turn Recording — Implementation

### Hook point: Best-effort goroutine in checkpoint write path

Recording is performed in a fire-and-forget goroutine spawned from the checkpoint handler after the checkpoint transaction commits. The HTTP response returns immediately — recording never adds latency to the user-facing checkpoint response.

**Evaluated alternatives:**

| Approach | Pros | Cons |
|---|---|---|
| **Best-effort goroutine (chosen)** | Zero latency impact on checkpoint response; same-process simplicity; no external dependencies | Detached context requires timeout; silent data loss if process crashes mid-goroutine |
| Blocking synchronous | Consistency guaranteed; simplest code path | Adds ~3-8ms to every checkpoint response when recording is on; recording failures could affect UX |
| External async (queue/worker) | Full isolation; retry semantics | New infrastructure dependency; operational complexity; overkill for a best-effort write |

**Flow when recording is enabled:**
```
Checkpoint transaction commits
  → Return HTTP 200 immediately
  → goroutine (detached context, 10s timeout):
      → Check domain config cache for recording.enabled          (~0ms, cache hit)
      → SELECT domain_id FROM sessions WHERE id = thread_id      (~1ms, on cache miss)
      → Decode msgpack blob, extract question_preview             (~1-5ms)
      → INSERT INTO feedback (type='recorded_turn', rating=NULL)  (~1-2ms)
```

**Flow when recording is disabled:** The goroutine short-circuits after the domain config cache check. Near-zero overhead.

**Error handling:** Recording failures are swallowed. Log the error, emit a metric (`recording_turn_failures_total`). The goroutine uses a detached context with a 10-second timeout to avoid leaking connections if the parent request is cancelled.

### Domain config cache

To avoid a database read on every checkpoint write, domain recording configs are cached in-memory with a 5-minute TTL.

```go
type DomainConfigCache struct {
    cache *sync.Map // domain_id → *cachedConfig
}

type cachedConfig struct {
    config    *DomainRecordingConfig
    expiresAt time.Time
}
```

- **Cache hit:** `maybeRecordTurn` reads `recording.enabled` from the in-memory cache. No DB call. This is the hot path when recording is OFF for a domain — the goroutine short-circuits immediately.
- **Cache miss / expired:** Read domain config from DB, populate cache with 5-minute TTL.
- **Invalidation on toggle:** When `UpdateDomain` sets `recording.enabled`, it evicts the cache entry for that domain. The next checkpoint write will re-read from DB. The 5-minute TTL is a safety net — worst case, recording starts/stops with up to 5 minutes of delay after a toggle.
- **Memory footprint:** One entry per active domain. At 1,000 domains, ~50KB total.

**UPSERT behavior and interaction with SubmitFeedback:**

The existing `SubmitFeedback` handler must be updated to always set `type = 'feedback'` in its UPSERT. This is the mechanism that promotes a recorded turn to feedback:

- **Recording ON, user submits feedback:** The recorded turn row already exists (`type = 'recorded_turn'`, `rating = NULL`). `SubmitFeedback` UPSERTs with the same deterministic ID and sets `type = 'feedback'`, `rating`, `reason_code`, `comment`. The row is promoted — no new row is inserted.
- **Recording OFF, user submits feedback:** No recorded turn row exists. `SubmitFeedback` INSERTs a new row with `type = 'feedback'` and the provided rating/reason/comment. This is the existing behavior, unchanged except for the explicit `type` field.

In both cases, `SubmitFeedback` always writes `type = 'feedback'`. The handler doesn't need to know whether recording is on — the UPSERT handles both paths.

**ID generation:** Same deterministic pattern as existing feedback: `SHA256(checkpoint_id + ":" + session_id)`. Provides natural deduplication — if a turn is somehow processed twice, the second write is a no-op.

---

## Nova Gateway Changes

### New routes (`routes.go`)

```go
mux.Handle(http.MethodGet,
    fmt.Sprintf("/domains/{%s}/chat-review", constants.DomainID),
    handlers.ProxyListChatReview(auraServiceURL, stateSvc))

mux.Handle(http.MethodGet,
    fmt.Sprintf("/domains/{%s}/chat-review/{%s}/thread", constants.DomainID, constants.EntryID),
    handlers.ProxyGetChatReviewThread(auraServiceURL, stateSvc))
```

### New constant (`constants/constants.go`)

```go
EntryID PathVariable = "entryID"
```

### New handlers

`ProxyListChatReview` and `ProxyGetChatReviewThread` follow the same patterns as `ProxyListFeedback` (feedbackhandler.go:43-98) and `ProxyGetFeedbackThread` (feedbackhandler.go:104-147) respectively. Thin RBAC check + reverse proxy passthrough.

---

## Aura Context Service Changes

### New handler file: `handlers/chatreview/handlers.go`

| Handler | Description |
|---|---|
| `ListChatReview` | Parse query params (starting_after, limit, type, user_id, rating, reason_code, date range). Multi-value params (user_id, reason_code) are comma-delimited, parsed via `strings.Split()`. Translate `rating=0` → `IS NULL`, `reason_code` containing `none` → `IS NULL`. Resolve cursor if present. Query feedback table with tuple comparison + filters. LIMIT+1 for has_more. |
| `GetChatReviewThread` | Extract entryID. Look up from feedback table. Verify domain ownership. Verify session-domain binding. Retrieve thread from checkpoint blobs. Return entry + thread. |

### Route registration (`cmd/auracontext/main.go`)

```go
chatReviewHandler := chatreview.NewChatReviewHandler(logger, connections, jwtHandler, opts.UseDomainIDInToken)
router.PathPrefix(commonPrefix + "/domains/{domain_id}/chat-review").Handler(chatReviewHandler.Handler())
```

### Recording capture in checkpoint handler

In `checkpoints/handlers.go`, after checkpoint transaction commits and before the HTTP response:

```go
// After checkpoint commit, fire-and-forget turn recording (best-effort)
go func() {
    recordCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer cancel()
    if err := h.maybeRecordTurn(recordCtx, db, sessionID, checkpointID); err != nil {
        h.logger.Error().Err(err).Str("session_id", sessionID).Msg("failed to record turn")
        h.metrics.RecordingFailures.Inc()
    }
}()
// Return HTTP 200 immediately — goroutine runs in background
```

`maybeRecordTurn` implementation:
1. Check domain config cache for `recording.enabled` — short-circuit if disabled or absent (cache hit, ~0ms)
2. On cache miss: `SELECT domain_id FROM sessions WHERE id = ?` → read domain config → populate cache
3. Short-circuit if no domain (legacy session) or `recording.enabled_at` is after the checkpoint timestamp
4. Extract question preview from checkpoint blob (reuse existing `extractQuestionPreview` from feedback helpers)
5. `INSERT INTO feedback (id, domain_id, session_id, checkpoint_id, user_id, question_preview, type, rating, created_at) VALUES (?, ?, ?, ?, ?, ?, 'recorded_turn', NULL, NOW())` with deterministic ID

### Backward compatibility for existing `ListFeedback` handler

Add `WHERE type = 'feedback'` to the existing `ListFeedback` query in `handlers/feedback/handlers.go:248-331` so the existing `GET .../feedback` endpoint excludes recorded turns. This preserves the current contract for any consumers of that endpoint.

**New `type` field in response:** Every feedback row now includes a `type` field (`"feedback"`) that was not present before. The frontend must not use Zod runtime schema validation (or similar strict parsing) on the existing feedback response types — the new field would cause validation failures on any frontend version that hasn't been updated. Ensure the existing `Feedback` TypeScript type in `api/feedback.ts` is extended with `type?: string` as an optional field so older response shapes (without `type`) and newer shapes (with `type`) both parse correctly.

### Extended domain types

In `handlers/domains/types.go`, extend `UpdateDomainRequest`:

```go
type UpdateDomainRequest struct {
    Name        *string                `json:"name"`
    Description *string                `json:"description"`
    State       *string                `json:"state"`
    Recording   *UpdateRecordingConfig `json:"recording"`
}

type UpdateRecordingConfig struct {
    Enabled *bool `json:"enabled"`
}
```

The `UpdateDomain` handler reads `recording.enabled`, sets `recording.enabled_at` to `now()` when enabling, and clears it when disabling.

---

## Frontend Changes

### Routes (`api/routes.ts`)

Add to `INTELLIGENCE_ROUTES`:

```typescript
listChatReview: {
    method: "GET",
    path: "/domains/:domainID/chat-review",
},
getChatReviewThread: {
    method: "GET",
    path: "/domains/:domainID/chat-review/:entryID/thread",
},
```

### New API file: `api/chat-review.ts`

Following the existing pattern in `api/feedback.ts`, create a new file with types, fetch functions, and React hooks:

```typescript
// --- Types ---

type ChatReviewEntryType = "feedback" | "recorded_turn";

type ChatReviewEntry = {
    id: string;
    type: ChatReviewEntryType;
    domain_id: string;
    session_id: string;
    checkpoint_id: string;
    user_id: string;
    question_preview: string;
    rating: number | null;
    reason_code: string | null;
    comment: string | null;
    created_at: string;
};

type ChatReviewFilters = {
    starting_after?: string;
    limit?: number;
    user_id?: string[];       // multi-select — joined as CSV in query param
    rating?: 1 | -1 | 0;     // good / bad / unrated (0 = NULL sentinel) — omit for all
    reason_code?: string[];   // multi-select — joined as CSV in query param; "none" = NULL sentinel
    start_date?: string;
    end_date?: string;
};

type ChatReviewListResponse = {
    entries: ChatReviewEntry[];
    has_more: boolean;
};

type ChatReviewThreadResponse = {
    entry: ChatReviewEntry;
    thread: SessionMessagesResponse;
};

// --- Hooks ---
// useListChatReview — uses useAuraContextFetch with INTELLIGENCE_ROUTES.listChatReview
// useGetChatReviewThread — uses useAuraContextFetch with INTELLIGENCE_ROUTES.getChatReviewThread
```

Hooks follow the same pattern as `useListFeedback` and `useGetFeedbackThread` in `api/feedback.ts:89-236`, using `useAuraContextFetch` for domain-scoped OBO calls.

### Domain type extension (`api/domains.ts`)

Extend the existing `Domain` type (`api/domains.ts:43-53`):

```typescript
type Domain = {
    id: string;
    name: string;
    description?: string;
    projectID: string;
    createdBy: string;
    createdAt: string;
    updatedAt: string;
    updatedBy?: string;
    status?: DomainStatus;
    recording?: {
        enabled: boolean;
        enabled_at?: string;
    };
};
```

### Tab system (`configure-domains-flyout.tsx`)

```typescript
type TabID = "data" | "insights" | "access-controls" | "api-keys" | "chat-review" | "settings";
```

- Rename `"details"` → `"settings"` in the TabID union and all references.
- Add `"chat-review"` tab before `"settings"`.
- `"settings"` remains always-last.

### New components

| Component | Description |
|---|---|
| `chat-review-tab.tsx` | Chat Review tab container with filter controls and paginated table |
| `chat-review-table.tsx` | Table rendering entries with type badge, question preview, user, rating, timestamp |
| `chat-review-thread-flyout.tsx` | Flyout showing full conversation thread when a row is clicked (same pattern as existing `feedback-thread-flyout.tsx`, renamed) |

**Reused components (no new code):**

| Component | Source | Usage |
|---|---|---|
| `DateRangePicker` | `view/common/date-range-picker.tsx` | Date range filter. Configure with trimmed presets: Last 7 days, Last 30 days, Last 90 days, Custom range. Emits `{ startDateTime, endDateTime }` as UTC RFC3339. |
| `MultiSelect` | Fusion DS `multi-select/multi-select.tsx` | Reason code filter (`variant="filter"`) and user filter. Supports `MultiSelectSelectAll` for toggle-all. Already used in existing feedback tab's rating filter (`feedback-filter-select.tsx`). |
| `NotebookAppPagination` | `view/common/notebook-apps/pagination.tsx` | Pagination controls. Adapted to hide "X–Y of Z items" and "N of M pages" indicators (no `totalCount` available). |

**Data sources for filter dropdowns:**

| Filter | Data Source | Caching |
|---|---|---|
| Reason codes | `GET /v1/feedback-reasons` (existing endpoint, static enum: 5 codes) + hardcoded `—` option for NULL | Cache indefinitely (static data). Load once on tab mount. |
| Users | Domain access control list endpoint (existing member list from Access Controls tab) | Cache per domain. Reload on tab mount. |
| Rating | Hardcoded: All, Good, Bad, Unrated (—) | N/A (static) |

### Pagination

**Component:** Reuse `NotebookAppPagination` from `@/view/common/notebook-apps/pagination.tsx`. Provides page size selector (10/20/30/40/50) and prev/next chevron buttons with `disabled` state. The "X–Y of Z items" and "N of M pages" indicators are omitted — no `total_count` is available from the API. The component is presentation-only with no cursor logic.

**State management in `chat-review-tab.tsx`:**

```typescript
const [pageSize, setPageSize] = useState(DEFAULT_PAGE_SIZE);
const [currentPage, setCurrentPage] = useState(1);
const [cursors, setCursors] = useState<(string | undefined)[]>([undefined]);

const startingAfter = cursors[currentPage - 1];

// Rating filter: All (undefined), Good (1), Bad (-1), Unrated (0 = NULL sentinel, displayed as —)
const [ratingFilter, setRatingFilter] = useState<1 | -1 | 0 | undefined>(undefined);

// Reason code filter: multi-select. "none" = NULL sentinel (displayed as —). Loaded from GET /v1/feedback-reasons + "none".
const [reasonCodes, setReasonCodes] = useState<string[]>([]);

// User filter: multi-select. Populated from domain access control list endpoint.
const [userIds, setUserIds] = useState<string[]>([]);

// Date range filter: reuse DateRangePicker. Presets: Last 7 days, Last 30 days, Last 90 days, Custom.
const [startDate, setStartDate] = useState<string | undefined>(undefined);
const [endDate, setEndDate] = useState<string | undefined>(undefined);

const { data } = useListChatReview(domainID, {
    limit: pageSize,
    starting_after: startingAfter,
    rating: ratingFilter,
    reason_code: reasonCodes.length > 0 ? reasonCodes : undefined,
    user_id: userIds.length > 0 ? userIds : undefined,
    start_date: startDate,
    end_date: endDate,
});

const entries = data?.results.entries ?? [];
const hasMore = data?.results.has_more ?? false;
const hasNextPage = hasMore;
const hasPreviousPage = currentPage > 1;

const handleClickNext = () => {
    const lastEntry = entries[entries.length - 1];
    if (lastEntry) {
        setCursors((prev) => {
            const next = [...prev];
            next[currentPage] = lastEntry.id;
            return next;
        });
        setCurrentPage(currentPage + 1);
    }
};

const handleClickPrevious = () => setCurrentPage(currentPage - 1);

// Reset pagination on any filter or page size change
const resetPagination = () => {
    setCurrentPage(1);
    setCursors([undefined]);
};

// Reset all filters to defaults
const resetFilters = () => {
    setRatingFilter(undefined);
    setReasonCodes([]);
    setUserIds([]);
    setStartDate(undefined);
    setEndDate(undefined);
    resetPagination();
};
```

**Navigation flow:**
- First page: `starting_after` = undefined → fetches newest entries.
- Next: caches last entry ID in `cursors[currentPage]`, increments page.
- Previous: decrements page, uses `cursors[currentPage - 1]` (already cached). Query hook returns cached result — no network call.
- Any filter change (rating, reason code, user, date range) or page size change: resets cursors array and page to 1 via `resetPagination()`.
- Domain change (opening a different domain's flyout): resets all filters and pagination via `resetFilters()`.

### Settings tab update (`details-tab.tsx` → `settings-tab.tsx`)

- Rename file.
- Add recording toggle (switch component) below the existing domain name/description fields.
- Toggle calls `PUT .../domains/{domainID}` with `{ recording: { enabled: true/false } }`.

---

## Full API Surface

| Method | Path | Auth | Purpose | Status |
|---|---|---|---|---|
| `GET` | `.../domains/{domainID}/chat-review` | RBAC: `AgentDomainReviewConversations` | List entries (feedback + recorded turns) | **New** |
| `GET` | `.../domains/{domainID}/chat-review/{entryID}/thread` | RBAC: `AgentDomainViewUserConversations` | Thread drill-down for any entry | **New** |
| `POST` | `.../domains/{domainID}/feedback` | OBO passthrough | Submit feedback | Unchanged |
| `GET` | `.../domains/{domainID}/feedback` | OBO / RBAC: `AgentDomainReviewConversations` | List feedback (adds `WHERE type='feedback'`) | Backward-compat filter added |
| `GET` | `.../domains/{domainID}/feedback/{feedbackID}/thread` | RBAC: `AgentDomainViewUserConversations` | Legacy thread endpoint | Deprecated, keep working |
| `GET` | `/v1/feedback-reasons` | Bearer | Reason code list | Unchanged |
| `PUT` | `.../domains/{domainID}` | RBAC: `AgentDomainUpdate` | Update domain (extended with recording config) | Extended |
