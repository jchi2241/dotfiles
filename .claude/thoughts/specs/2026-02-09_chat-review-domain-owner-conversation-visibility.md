---
type: spec
title: Chat Review - Domain Owner Conversation Visibility
project: helios, heliosai
area: frontend/intelligence, cmd/nova-gateway, auracontext service, auracontextstore
tags: [chat-review, recording, feedback, domain-configuration, pagination]
date: 2026-02-09
status: complete
research_doc: ~/.claude/thoughts/research/2026-02-09_analyst-feedback-and-chat-review-feature.md
approach_chosen: Persist rows in extended feedback table with cursor-based pagination
---

# Part 1: Requirements

## 1. Problem Statement

Domain owners lack visibility into how the analyst is performing for their domain. The only signal today is explicit user feedback (thumbs up/down), which is sparse — most users never leave feedback. Without observing actual conversations, domain owners cannot evaluate quality, identify gaps in domain configuration, or proactively improve the analyst experience.

**Why now:** Domains are growing in usage. The feedback-only signal is insufficient for quality assurance at scale.

**Cost of not solving:** Domain owners fly blind. Configuration issues go undetected until users complain (or silently stop using the analyst). No data-driven path to improvement.

## 2. Users & Stakeholders

| Role | Relationship to feature |
|------|------------------------|
| **Domain owner** | Primary user. Enables recording, reviews conversations, acts on insights. |
| **End user** (analyst user) | Indirectly affected. Their conversations may be recorded and reviewed. Not a direct user of the Chat Review UI. |
| **Legal/compliance** | Stakeholder. Recording user conversations triggers GDPR Article 13/14 disclosure requirements and CCPA considerations. |

## 3. User Stories

**As a domain owner**, I want to enable recording for my domain so that I can review how the analyst responds to users.

**As a domain owner**, I want to see all recorded turns and user feedback in a single table so that I have one place to assess analyst quality.

**As a domain owner**, I want to filter the Chat Review table by rating (good, bad, unrated, or all), reason code, date range, and user so that I can focus on what matters.

**As a domain owner**, I want to paginate through results so that performance remains good as data grows.

**As a domain owner**, I want to click a row to see the full conversation thread so that I can understand the context around a response.

**As a domain owner**, I want to disable recording at any time, with the understanding that new turns will stop being captured but previously recorded turns remain visible.

## 4. Requirements

### Functional

| ID | Requirement |
|----|-------------|
| F1 | Per-domain recording toggle (OFF by default) in the Settings tab (renamed from "Details"). |
| F2 | When recording is ON, every analyst turn (user question + assistant response) is captured as a lightweight row pointing to the existing checkpoint blob. |
| F3 | When recording is OFF, new turns are not captured. Previously recorded turns remain visible. |
| F4 | Toggling ON sets a `recording_enabled_at` timestamp. Only turns occurring after this point are captured. Toggling OFF clears the window. Re-enabling creates a new window — gap turns are never captured. |
| F5 | Chat Review tab displays both `feedback` and `recorded_turn` entries in a single, unified table sorted newest-first. |
| F6 | A recorded turn that later receives user feedback is promoted to `type = 'feedback'` — one row per conversation turn, enriched over time. |
| F7 | Table columns: Question (clickable, opens thread flyout), Rating (thumbs badge), Reason (resolved display name), Comment, Created By (UserPopover), Created At. Matches feedback tab columns. |
| F8 | Filters: Rating (segmented control: All/Good/Bad/Unrated), Reason code (multi-select), User (multi-select searchable), Date range (presets: 7d/30d/90d/custom). |
| F9 | Filters are AND across dimensions, OR within multi-select values. No cascading/dynamic narrowing. |
| F10 | Cursor-based pagination (Stripe-style, forward-only API) with page size selector (10/20/30/40/50) and prev/next navigation. |
| F11 | Thread drill-down: clicking a row opens the full conversation thread in a flyout. |
| F12 | Tab rename: "Details" becomes "Settings". Tab order: Data, Context, Access Controls, API Keys, **Chat Review**, **Settings**. |
| F13 | Existing `GET .../feedback` endpoint must continue to return only explicit feedback (backward compatibility via `WHERE type = 'feedback'`). |

### Non-Functional

| ID | Requirement |
|----|-------------|
| NF1 | Turn recording adds zero latency to the user-facing checkpoint response (fire-and-forget goroutine). |
| NF2 | Recording failures are best-effort: log + metric, no user impact. |
| NF3 | Pagination is O(limit) regardless of depth (no OFFSET scan). |
| NF4 | Domain recording config is cached in-memory with 5-minute TTL to avoid per-checkpoint DB reads. |
| NF5 | Write cost: ~200 bytes per recorded turn. At 1,000 domains recording with 100 turns/domain/day: ~20MB/day, ~7GB/year. |

## 5. Acceptance Criteria

| # | Criterion |
|---|-----------|
| AC1 | Domain owner can toggle recording ON/OFF in the Settings tab. Toggle state persists across sessions. |
| AC2 | With recording ON, analyst turns appear in the Chat Review table within seconds of the checkpoint commit. |
| AC3 | With recording OFF, no new turns appear. Previously recorded turns remain visible and pageable. |
| AC4 | Feedback submitted on a previously-recorded turn promotes the row to `type = 'feedback'` with rating/reason/comment populated. Only one row exists for that turn. |
| AC5 | All four filters (rating, reason code, user, date range) work independently and in combination. |
| AC6 | Pagination: next page loads correctly, previous page returns to the exact same result set (query cache hit), page size change resets to page 1. |
| AC7 | Thread flyout opens and displays the full conversation thread for both `feedback` and `recorded_turn` entries. |
| AC8 | Existing `GET .../feedback` endpoint returns only `type = 'feedback'` rows. No breaking change for existing consumers. |
| AC9 | Recording goroutine failure does not affect the checkpoint HTTP response. |
| AC10 | Empty states render correctly for all four scenarios: recording OFF + no data, recording OFF + historical data, recording ON + no entries yet, filters applied + no matches. |

## 6. Scope Boundaries

### In Scope

1. Recording toggle (per-domain setting in renamed Settings tab)
2. Chat Review tab (unified table replacing Feedback tab, with filtering and pagination)
3. Turn capture (backend persistence of recorded turns as lightweight rows)
4. Consolidated API (`/chat-review` list and thread endpoints)
5. Cursor-based pagination (Stripe-style, forward-only API with client-side cursor caching)
6. Thread drill-down (full conversation thread via new generic thread endpoint)
7. RBAC: rename `AgentDomainViewFeedback` → `AgentDomainReviewConversations`
8. Backward compatibility: existing `/feedback` endpoint filtered to `type = 'feedback'`

### Out of Scope

- **Retention policy / data deletion** — Recorded turns accumulate indefinitely. Retention/TTL is a separate feature.
- **End-user notification of recording** — No "this conversation may be recorded" indicator. Requires legal/compliance review (GDPR, CCPA). Flagged as open question.
- **Analytics / aggregations** — No summary dashboards, trend charts, or aggregate metrics over recorded turns. This is raw conversation review only.
- **Recording for non-domain-owner roles** — Only domain owners can enable/view recordings. No admin-level cross-domain recording.
- **Bulk actions on entries** — No multi-select delete, export, or annotation on the Chat Review table.

## 7. Open Questions

| # | Question | Impact |
|---|----------|--------|
| OQ1 | **Backward compatibility on existing `GET .../feedback` endpoint** — Adding `WHERE type = 'feedback'` ensures exclusion of recorded turns. Confirm no consumers rely on the absence of a `type` field in the response (the field will now be present on all rows). | Could break strict schema validators on existing consumers. |
| OQ2 | **User consent and notification for recording** — When recording is enabled, end users are not notified. Should the analyst UI show a "this conversation may be recorded" indicator? Legal/compliance review may be needed for GDPR (Article 13/14) and CCPA before shipping to EU/CA users. Intersects with the deferred retention policy question. | Potential legal blocker for EU/CA rollout. |

## 8. Dependencies & Risks

| Type | Description |
|------|-------------|
| **Dependency** | Aura Context Store v11 migration must be deployed before the auracontext service changes. |
| **Dependency** | Frontend must extend the `Domain` type with `recording` config before the Settings tab toggle can function. |
| **Risk** | GDPR/CCPA compliance for recording without user notification (OQ2). May require a consent mechanism before EU/CA launch. |
| **Risk** | Existing consumers of `GET .../feedback` that use strict runtime schema validation (e.g., Zod) may fail on the new `type` field (OQ1). The `type` field is added as optional in the TypeScript type to mitigate. |

---

# Part 2: Technical Design

## 9. Approach Decision

Two key architectural decisions were evaluated:

### Decision 1: Persist rows vs. virtual query from recording time ranges

**Chosen: Persist a row per recorded turn.**

**Rejected: Virtual query** — Store recording on/off time windows in domain config JSON and query existing checkpoint/session data at read time.

The virtual approach fails on the existing schema:
- `checkpoints` has no `created_at` column and no `domain_id`. Can't query "checkpoints created within a recording window for domain X" without adding columns to the highest-write table in the system.
- `question_preview` must be extracted from 50-500KB msgpack blobs at read time. A page of 50 entries decodes 2.5-25MB of I/O per page view.
- No usable cursor anchor for pagination — the query requires a full JOIN + sort with no SORT KEY to leverage.
- Security boundary is a query predicate (time-window filter), not a data invariant. A bug could expose pre-recording conversations.
- Dedup between virtual results and feedback requires a fragile LEFT JOIN on every page load.

The persist approach trades a trivial write (~200 bytes, best-effort goroutine) for efficient reads using existing indexes and cursor pagination, with a structural guarantee that pre-recording conversations cannot be exposed.

### Decision 2: Single table vs. separate tables

**Chosen: Extend the existing `feedback` table with a `type` column.**

**Rejected: Separate `recorded_turns` table.**

- **No dedup problem:** Both entry types share the same deterministic ID (`SHA256(checkpoint_id:session_id)`). A recorded turn that later gets feedback is a single UPSERT — the row is promoted. Separate tables produce two rows requiring JOIN-based dedup in every query.
- **Native pagination:** Single table cursor query uses the existing SORT KEY directly. UNION ALL over two tables requires materializing both result sets before sorting.
- **Low migration risk:** The ALTER (`ADD COLUMN` with DEFAULT) is metadata-only on SingleStore. No data rewrite. Rating stays NOT NULL — recorded turns use `rating = 0` as the unrated sentinel, avoiding the complexity of making a NOT NULL column nullable in SingleStore.

### Decision 3: Pagination strategy

**Chosen: Stripe-style cursor-based pagination (forward-only API, client-side cursor caching for backward navigation).**

**Rejected: Offset-based pagination.**

- `OFFSET N` is O(offset + limit) per page; cursor is O(limit) regardless of depth.
- Concurrent writes shift offset positions causing duplicates/skips. Cursors anchor to a stable `(created_at, id)` position.
- The existing auracontext `ListFeedback` uses offset but returns no `total_count` — the pattern was incomplete.

**Improvement over existing codebase cursor pattern:** Existing pattern uses `createdat <= :cursor_time AND id != :cursor_id` — vulnerable to duplicate-timestamp skips. The tuple comparison `(created_at, id) < (?, ?)` is correct for any timestamp distribution. Existing pattern makes 3 queries per page; this makes 1 (LIMIT + 1 for `has_more`).

## 10. Architecture

The feature spans four layers:

| Layer | Repository | Changes |
|-------|-----------|---------|
| **Frontend** (Helios) | `helios/frontend` | New Chat Review tab, Settings tab rename, recording toggle UI, paginated table |
| **Nova Gateway** | `helios/cmd/nova-gateway` | Two new proxy routes (`/chat-review`, `/chat-review/{entryID}/thread`) |
| **Aura Context Service** | `heliosai/services/auracontext` | New chat-review handlers, recording capture in checkpoint path, schema migration |
| **Aura Context Store** | `helios/auracontextstore` | v11 migration (ALTER feedback table) |

### Turn recording data flow

```
Checkpoint transaction commits
  -> Return HTTP 200 immediately
  -> goroutine (detached context, 10s timeout):
      -> Check domain config cache for recording.enabled        (~0ms, cache hit)
      -> SELECT domain_id FROM sessions WHERE id = thread_id    (~1ms, on cache miss)
      -> Decode msgpack blob, extract question_preview           (~1-5ms)
      -> INSERT INTO feedback (type='recorded_turn', rating=0)     (~1-2ms)
```

When recording is disabled, the goroutine short-circuits after the cache check. Near-zero overhead.

### Domain config cache

In-memory cache with 5-minute TTL to avoid per-checkpoint DB reads:

```go
type DomainConfigCache struct {
    cache *sync.Map // domain_id -> *cachedConfig
}

type cachedConfig struct {
    config    *DomainRecordingConfig
    expiresAt time.Time
}
```

- Cache hit: `maybeRecordTurn` reads `recording.enabled` from memory. No DB call.
- Cache miss/expired: Read domain config from DB, populate cache.
- Invalidation on toggle: `UpdateDomain` evicts the cache entry. Next checkpoint write re-reads from DB.
- Memory: ~50KB at 1,000 domains.

### UPSERT behavior (recording + feedback interaction)

The existing `SubmitFeedback` handler must always set `type = 'feedback'` in its UPSERT:

- **Recording ON, user submits feedback:** Recorded turn row exists (`type = 'recorded_turn'`, `rating = 0`). `SubmitFeedback` UPSERTs with the same deterministic ID, sets `type = 'feedback'`, `rating` (1 or -1), `reason_code`, `comment`. Row is promoted.
- **Recording OFF, user submits feedback:** No recorded turn row. `SubmitFeedback` INSERTs with `type = 'feedback'`. Existing behavior, unchanged except for explicit `type` field.

`SubmitFeedback` doesn't need to know whether recording is on — the UPSERT handles both paths.

## 11. Data Models

### Database migration v11: ALTER `feedback` table

```sql
-- v11/alter_ddl.sql
-- rating remains NOT NULL; recorded turns use rating = 0 as the unrated sentinel.

-- Add type column (metadata-only on SingleStore)
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

-- Composite index for chat-review list query
DELIMITER //
DO BEGIN
    CREATE INDEX idx_feedback_domain_type_created
        ON feedback (domain_id, type, created_at DESC);
EXCEPTION
    WHEN ER_DUP_KEYNAME THEN
    BEGIN ROLLBACK; END;
    WHEN OTHERS THEN
    BEGIN ROLLBACK; RAISE; END;
END //
DELIMITER ;
```

- `type` defaults to `'feedback'` — existing rows are automatically classified without a data migration.
- `rating` stays NOT NULL. Recorded turns use `rating = 0` as the unrated sentinel (making a NOT NULL column nullable in SingleStore is prohibitively expensive).

### Recording config in domain JSON (no DDL change)

Lives in the existing `domains.config` JSON column:

```json
{
  "data": { "tables": [...] },
  "recording": {
    "enabled": true,
    "enabled_at": "2026-02-09T12:00:00Z"
  }
}
```

Go struct extension:

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

### Extended domain update request

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

### Frontend types (`api/chat-review.ts`)

```typescript
type ChatReviewEntryType = "feedback" | "recorded_turn";

type ChatReviewEntry = {
    id: string;
    type: ChatReviewEntryType;
    domain_id: string;
    session_id: string;
    checkpoint_id: string;
    user_id: string;
    question_preview: string;
    rating: number;           // 1 = good, -1 = bad, 0 = unrated
    reason_code: string | null;
    comment: string | null;
    created_at: string;
};

type ChatReviewFilters = {
    starting_after?: string;
    limit?: number;
    user_id?: string[];
    rating?: 1 | -1 | 0;
    reason_code?: string[];
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
```

### Extended `Domain` type (`api/domains.ts`)

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

## 12. API Contracts

### New Endpoints

#### List Chat Review Entries

```
GET .../domains/{domainID}/chat-review
```

**Auth:** RBAC `AgentDomainReviewConversations`

**Query parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `starting_after` | string | — | Entry ID cursor. Omit for first page. |
| `limit` | int | 50 | Page size (max 200). |
| `type` | string | *(both)* | `feedback`, `recorded_turn`, or omit for both. |
| `user_id` | string (CSV) | — | Filter by user(s). OR logic. |
| `rating` | int | — | `1` (good), `-1` (bad), `0` (unrated). Omit for all. |
| `reason_code` | string (CSV) | — | Filter by reason code(s). `none` = `IS NULL` sentinel. OR logic. |
| `start_date` | RFC3339 | — | Lower bound on timestamp. |
| `end_date` | RFC3339 | — | Upper bound on timestamp. |

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
        "rating": 0,
        "reason_code": null,
        "comment": null,
        "created_at": "2026-02-09T..."
      }
    ],
    "has_more": true
  }
}
```

Fixed sort: `created_at DESC, id DESC`.

**SQL implementation:**

```sql
SELECT * FROM feedback
WHERE domain_id = ? AND (created_at, id) < (?, ?)
  [AND type IN (...)]
  [AND user_id IN (?, ?, ...)]
  [AND rating = ?]               -- rating = 1, -1, or 0 (unrated)
  [AND (reason_code IN (?, ...) OR reason_code IS NULL)]  -- includes 'none'
  [AND reason_code IN (?, ...)]  -- without 'none'
  [AND created_at >= ?]
  [AND created_at <= ?]
ORDER BY created_at DESC, id DESC
LIMIT :limit + 1
```

Multi-value filter parsing: `strings.Split(r.URL.Query().Get("reason_code"), ",")`. Use squirrel's `sq.Or{sq.Eq{"reason_code": nil}, sq.Eq{"reason_code": values}}` for `none` + other values. Rating filter is a simple equality: `sq.Eq{"rating": value}` for any of 0, 1, -1.

#### Chat Review Thread Drill-Down

```
GET .../domains/{domainID}/chat-review/{entryID}/thread
```

**Auth:** RBAC `AgentDomainViewUserConversations`

**Response:**

```json
{
  "results": {
    "entry": { ... },
    "thread": {
      "title": "Order Analysis",
      "messages": [...],
      "follow_up_suggestions": [...],
      "latest_settings": {...}
    }
  }
}
```

Implementation follows the same pattern as existing `GetFeedbackThread`: extract entry ID from path -> look up from feedback table -> verify domain ownership -> verify session-domain binding -> retrieve thread from checkpoint blobs -> return entry + thread.

### Modified Endpoints

| Endpoint | Change |
|----------|--------|
| `GET .../feedback` | Add `WHERE type = 'feedback'` to exclude recorded turns. Add `type` field to response. |
| `POST .../feedback` | Always set `type = 'feedback'` in UPSERT (enables promotion of recorded turns). |
| `PUT .../domains/{domainID}` | Extended to accept `recording: { enabled: bool }` in request body. |

### Unchanged Endpoints

| Endpoint | Notes |
|----------|-------|
| `GET .../feedback/{feedbackID}/thread` | Deprecated. Keep working with old response shape (`feedback` key). |
| `GET /v1/feedback-reasons` | Static reason code list. |

### RBAC

| Endpoint | Permission | Notes |
|----------|-----------|-------|
| `GET .../chat-review` | `AgentDomainReviewConversations` | Renamed from `AgentDomainViewFeedback`. |
| `GET .../chat-review/{entryID}/thread` | `AgentDomainViewUserConversations` | Existing permission, generic enough. |
| `PUT .../domains/{domainID}` (recording toggle) | `AgentDomainUpdate` | Existing permission. Recording is a domain setting. |
| `GET .../feedback` (existing) | `AgentDomainReviewConversations` | Same permission, renamed. |

No new permissions needed. Files to update for the rename:
- `agentdomain.yaml` — permission definition
- `graph/authz.go:385-415` — GraphQL permission mapping
- `feedbackhandler.go` — action constant in `ProxyListFeedback`

### Full API Surface

| Method | Path | Auth | Purpose | Status |
|--------|------|------|---------|--------|
| `GET` | `.../domains/{domainID}/chat-review` | RBAC: `AgentDomainReviewConversations` | List entries | **New** |
| `GET` | `.../domains/{domainID}/chat-review/{entryID}/thread` | RBAC: `AgentDomainViewUserConversations` | Thread drill-down | **New** |
| `POST` | `.../domains/{domainID}/feedback` | OBO passthrough | Submit feedback | Unchanged |
| `GET` | `.../domains/{domainID}/feedback` | RBAC: `AgentDomainReviewConversations` | List feedback only | Backward-compat filter added |
| `GET` | `.../domains/{domainID}/feedback/{feedbackID}/thread` | RBAC: `AgentDomainViewUserConversations` | Legacy thread | Deprecated |
| `GET` | `/v1/feedback-reasons` | Bearer | Reason codes | Unchanged |
| `PUT` | `.../domains/{domainID}` | RBAC: `AgentDomainUpdate` | Update domain | Extended |

## 13. Migration Strategy

1. **Deploy auracontextstore v11 migration** — Adds `type` column with default `'feedback'`, creates composite index. Metadata-only operation on SingleStore. No data rewrite. Existing rows automatically get `type = 'feedback'`. Rating stays NOT NULL; recorded turns use `rating = 0`.
2. **Deploy auracontext service** — New chat-review handlers, recording capture in checkpoint path, `WHERE type = 'feedback'` on existing `ListFeedback`, `type = 'feedback'` on existing `SubmitFeedback` UPSERT.
3. **Deploy nova-gateway** — New proxy routes for `/chat-review` and `/chat-review/{entryID}/thread`. RBAC permission rename.
4. **Deploy frontend** — Tab rename, Chat Review tab, Settings tab with recording toggle.

Order matters: schema first, then backend, then gateway, then frontend. The schema migration and backend changes are backward-compatible — existing functionality is unaffected until the frontend exposes the new UI.

## 14. Edge Cases & Error Handling

| Scenario | Handling |
|----------|----------|
| Recording goroutine fails (DB error, timeout) | Swallowed. Log error, increment `recording_turn_failures_total` metric. Checkpoint response unaffected. |
| Duplicate recording (same turn processed twice) | Deterministic ID (`SHA256(checkpoint_id:session_id)`) → second write is a no-op. |
| Recording enabled, then disabled, then re-enabled | Each enable sets a new `recording_enabled_at`. Only turns after the latest timestamp are captured. Gap turns are never captured. |
| Legacy session (no domain) | `maybeRecordTurn` short-circuits if no domain can be resolved from the session. |
| Checkpoint timestamp is before `recording_enabled_at` | Short-circuit. Do not record. |
| `starting_after` cursor references a deleted/nonexistent entry | Cursor resolution fails → return 400 with clear error. |
| Filter combination yields zero results | API returns empty `entries` array with `has_more: false`. Frontend shows: "No entries match the current filters." |
| New `type` field breaks strict schema validators on existing `/feedback` consumers | Mitigated: TypeScript `Feedback` type extended with `type?: string` as optional. Document in OQ1 for consumer audit. |

### Empty States

| Condition | Message |
|-----------|---------|
| Recording OFF, no feedback exists | "No feedback yet. Enable recording in the Settings tab to capture analyst conversations for review." |
| Recording OFF, historical data exists | Show table normally. |
| Recording ON, no entries yet | "Recording is enabled. Entries will appear here as users interact with the analyst." |
| Filters applied, no matches | "No entries match the current filters." (Each active filter shows clear/reset control.) |

## 15. Code References

### Nova Gateway

| File | Change |
|------|--------|
| `cmd/nova-gateway/routes.go` | Add two new route registrations for `/chat-review` and `/chat-review/{entryID}/thread`. |
| `cmd/nova-gateway/constants/constants.go` | Add `EntryID PathVariable = "entryID"`. |
| `cmd/nova-gateway/handlers/feedbackhandler.go:43-98` | Reference pattern for `ProxyListChatReview`. |
| `cmd/nova-gateway/handlers/feedbackhandler.go:104-147` | Reference pattern for `ProxyGetChatReviewThread`. |
| `cmd/nova-gateway/handlers/feedbackhandler.go:163-190` | Reuse `checkDomainPermission()` helper. |
| `agentdomain.yaml` | Rename `AgentDomainViewFeedback` → `AgentDomainReviewConversations`. |
| `graph/authz.go:385-415` | Update GraphQL permission mapping for rename. |

### Aura Context Service

| File | Change |
|------|--------|
| `handlers/chatreview/handlers.go` | **New file.** `ListChatReview` and `GetChatReviewThread` handlers. |
| `cmd/auracontext/main.go` | Register chat-review route prefix. |
| `handlers/checkpoints/handlers.go` | Add `go func() { maybeRecordTurn(...) }()` after checkpoint commit. |
| `handlers/feedback/handlers.go:248-331` | Add `WHERE type = 'feedback'` to `ListFeedback` query. |
| `handlers/feedback/handlers.go` (SubmitFeedback) | Always set `type = 'feedback'` in UPSERT. |
| `handlers/domains/types.go` | Extend `UpdateDomainRequest` with `Recording *UpdateRecordingConfig`. |

### Aura Context Store

| File | Change |
|------|--------|
| `v11/alter_ddl.sql` | **New migration.** ADD `type` column, CREATE composite index. Rating stays NOT NULL (0 = unrated). |

### Frontend

| File | Change |
|------|--------|
| `api/routes.ts` | Add `listChatReview` and `getChatReviewThread` to `INTELLIGENCE_ROUTES`. |
| `api/chat-review.ts` | **New file.** Types, fetch functions, React hooks. |
| `api/domains.ts:43-53` | Extend `Domain` type with `recording` field. |
| `configure-domains-flyout.tsx` | Update `TabID` union: rename `"details"` → `"settings"`, add `"chat-review"`. |
| `chat-review-tab.tsx` | **New component.** Filter controls, paginated table, state management. |
| `chat-review-table.tsx` | **New component.** Table rendering with type badge, question preview, user, rating, timestamp. |
| `chat-review-thread-flyout.tsx` | **New component.** Thread flyout (same pattern as existing feedback-thread-flyout). |
| `details-tab.tsx` → `settings-tab.tsx` | Rename file. Add recording toggle (switch component). |
| `view/common/date-range-picker.tsx` | **Reused.** Date range filter with trimmed presets (7d/30d/90d/custom). |
| `view/common/notebook-apps/pagination.tsx` | **Reused.** Pagination controls (omit total count indicators). |

## 16. Open Technical Questions

| # | Question | Status |
|---|----------|--------|
| OTQ1 | Confirm no existing consumers of `GET .../feedback` use strict runtime schema validation that would break on the new `type` field. | Unresolved — requires consumer audit. |
| OTQ2 | Determine if the existing `extractQuestionPreview` helper in feedback handlers is directly reusable or needs adaptation for the recording goroutine context. | Needs code review during implementation. |
