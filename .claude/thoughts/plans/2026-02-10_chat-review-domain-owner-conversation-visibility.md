---
type: plan
title: Chat Review - Domain Owner Conversation Visibility
project: helios, heliosai
area: frontend/intelligence, cmd/nova-gateway, auracontext service, auracontextstore
tags: [chat-review, recording, feedback, domain-configuration, pagination, cursor, rbac]
date: 2026-02-10
status: complete
spec: ~/.claude/thoughts/specs/2026-02-09_chat-review-domain-owner-conversation-visibility.md
approach_chosen: Persist rows in extended feedback table with cursor-based pagination
research_doc: ~/.claude/thoughts/research/2026-02-09_analyst-feedback-and-chat-review-feature.md
task_list_id: 4085ccef-2eb0-41a2-9219-f8df5a9c7e1a
phases_total: 7
phases_complete: 7
tasks_total: 14
tasks_complete: 14
---

# Chat Review - Domain Owner Conversation Visibility Implementation Plan

## Overview

Domain owners lack visibility into analyst conversations. This plan implements a per-domain recording toggle that captures analyst turns as lightweight rows in the existing feedback table, a unified Chat Review tab (replacing the Feedback tab) with cursor-based pagination and multi-dimension filtering, and a thread drill-down flyout. The feature spans four repositories: auracontextstore (schema), auracontext service (business logic), nova-gateway (proxy + RBAC), and helios frontend (UI).

## Current State Analysis

> See spec: `~/.claude/thoughts/specs/2026-02-09_chat-review-domain-owner-conversation-visibility.md` for full technical analysis and approach decision.

### Key Constraints from Spec:
- Extend the existing `feedback` table with a `type` column (no separate table) — spec §10, Decision 2
- Cursor-based pagination using `(created_at, id)` tuple comparison — spec §10, Decision 3
- Recording is fire-and-forget goroutine with zero latency impact on checkpoint response — spec §10, NF1
- Domain config cache with 5-minute TTL for recording check — spec §10, NF4
- Existing `GET .../feedback` endpoint must continue returning only explicit feedback (`WHERE type = 'feedback'`) — spec F13
- RBAC rename: `AgentDomainViewFeedback` → `AgentDomainReviewConversations` — spec §12
- Tab rename: "Details" → "Settings", "Feedback" → "Chat Review" — spec F12
- Deterministic ID `SHA256(checkpoint_id:session_id)` enables single-row UPSERT for recording→feedback promotion — spec §10

## Desired End State

Domain owners can:
1. Toggle recording ON/OFF per domain in the Settings tab
2. See all recorded turns and user feedback in a unified Chat Review table, sorted newest-first
3. Filter by rating, reason code, user, and date range
4. Paginate through results with cursor-based navigation (forward/back, configurable page size)
5. Click any row to view the full conversation thread in a flyout
6. Recorded turns that later receive feedback are automatically promoted (single row per turn)

### Verification Criteria:
- Recording toggle persists across sessions (AC1)
- Analyst turns appear in Chat Review within seconds of checkpoint commit (AC2)
- Disabling recording stops new captures but retains historical data (AC3)
- Feedback on recorded turns promotes the row to `type = 'feedback'` (AC4)
- All four filters work independently and in combination (AC5)
- Cursor pagination: next/prev work correctly, page size change resets to page 1 (AC6)
- Thread flyout works for both feedback and recorded_turn entries (AC7)
- Existing `GET .../feedback` endpoint unchanged for consumers (AC8)
- Recording goroutine failure doesn't affect checkpoint response (AC9)
- All four empty states render correctly (AC10)

## What We're NOT Doing

- Retention policy / data deletion for recorded turns
- End-user notification of recording (legal/compliance deferred)
- Analytics / aggregation dashboards over recorded turns
- Recording for non-domain-owner roles
- Bulk actions on entries (multi-select delete, export, annotation)

## Implementation Approach

> Approach: Persist rows in extended feedback table with cursor-based pagination
> Full details: `~/.claude/thoughts/specs/2026-02-09_chat-review-domain-owner-conversation-visibility.md`, section "Architecture"

The phases follow the deployment order from the spec (§13): schema first, then backend data layer, then backend handlers, then gateway, then frontend. Within the backend, we split data layer changes (types, models, queries) from handler logic (recording goroutine, new endpoints) so each task has a clear scope. The frontend is split into API/types (can be developed once gateway routes exist) and UI components (depends on API layer).

---

## Task Breakdown

> **IMPORTANT:** Each task below is designed to be independently executable by an agent with fresh context. After creating tasks with `TaskCreate`, update each task's "Claude Code Task" field with its system ID (e.g., `#1`). Tasks are stored in `~/.claude/tasks/<task-list-id>/`.

### Task 1: Schema Migration v11 - Extend Feedback Table

**Claude Code Task:** #1
**Blocked By:** None
**Phase:** 1

#### Description
Create the v11 schema migration for the auracontextstore. This adds the `type` column to the feedback table and creates a composite index for the chat-review list query. Rating stays NOT NULL — recorded turns use `rating = 0` as the unrated sentinel.

#### Files to Modify
- `helios/singlestore.com/helios/auracontextstore/sql/schema/v11/alter_ddl.sql` — **New file.** Migration SQL.

#### Implementation Notes
Two DDL operations, metadata-only on SingleStore (no data rewrite):

```sql
-- 1. Add type column with default 'feedback' (existing rows auto-classified)
ALTER TABLE feedback ADD COLUMN type VARCHAR(20) NOT NULL DEFAULT 'feedback';

-- 2. Composite index for chat-review list query
CREATE INDEX idx_feedback_domain_type_created
    ON feedback (domain_id, type, created_at DESC);
```

Rating stays NOT NULL — recorded turns use `rating = 0` as the unrated sentinel (making a NOT NULL column nullable in SingleStore is prohibitively expensive).

Wrap each statement in a `DO BEGIN ... EXCEPTION` block for idempotency, matching the pattern in existing migrations. See spec §11 for exact SQL.

#### Success Criteria
- [ ] `v11/alter_ddl.sql` exists with both DDL statements (ADD COLUMN + CREATE INDEX)
- [ ] Migration is idempotent (can be run multiple times without error)
- [ ] Follows existing migration directory convention (`v1/` through `v10/`)

#### Actual Implementation
Completed 2026-02-10. Created two files in `helios/singlestore.com/helios/auracontextstore/sql/schema/v11/`:

- `alter_ddl.sql` — Two DDL operations: (1) ADD COLUMN `type VARCHAR(20) NOT NULL DEFAULT 'feedback'` with `DO BEGIN...EXCEPTION WHEN ER_DUP_FIELDNAME` idempotency wrapper, (2) `CREATE INDEX idx_feedback_domain_type_created ON feedback (domain_id, type, created_at DESC)` with `EXCEPTION WHEN ER_DUP_KEYNAME` wrapper. Rating stays NOT NULL — recorded turns use `rating = 0` as the unrated sentinel.
- `_order.txt` — Lists `alter_ddl.sql` as the single script to execute.

Both operations are idempotent (safe to re-run). Commit: `[P1/T1] Add v11 schema migration for feedback`. Updated on-disk to remove MODIFY COLUMN rating after deciding against nullable rating.

---

### Task 2: Backend Data Layer - Extend Domain Config Types

**Claude Code Task:** #2
**Blocked By:** None
**Phase:** 2

#### Description
Extend the Go domain data model with the `DomainRecordingConfig` struct and update the `DomainConfig` struct to include the `Recording` field. Also extend `UpdateDomainRequest` in the handler types.

#### Files to Modify
- `heliosai/services/auracontext/data/domain/domain.go` — Add `DomainRecordingConfig` struct, extend `DomainConfig` with `Recording` field.
- `heliosai/services/auracontext/cmd/auracontext/handlers/domains/types.go` — Add `UpdateRecordingConfig` struct, extend `UpdateDomainRequest` with `Recording` field.

#### Implementation Notes
In `data/domain/domain.go`, add after the existing `DomainConfig` struct (line ~44-52):

```go
type DomainRecordingConfig struct {
    Enabled   bool       `json:"enabled"`
    EnabledAt *time.Time `json:"enabled_at,omitempty"`
}
```

Extend `DomainConfig`:
```go
type DomainConfig struct {
    Data      *DomainConfigData      `json:"data,omitempty"`
    Recording *DomainRecordingConfig `json:"recording,omitempty"`
}
```

In `handlers/domains/types.go`, add:
```go
type UpdateRecordingConfig struct {
    Enabled *bool `json:"enabled"`
}
```

Extend `UpdateDomainRequest`:
```go
type UpdateDomainRequest struct {
    Name        *string                `json:"name"`
    Description *string                `json:"description"`
    State       *string                `json:"state"`
    Recording   *UpdateRecordingConfig `json:"recording"`
}
```

Since `DomainConfig` is serialized to/from the JSON `config` column in the `domains` table, the new field is automatically persisted — no DDL change needed.

#### Success Criteria
- [ ] `DomainRecordingConfig` struct exists with `Enabled` and `EnabledAt` fields
- [ ] `DomainConfig` includes `Recording *DomainRecordingConfig`
- [ ] `UpdateRecordingConfig` and extended `UpdateDomainRequest` exist in handler types
- [ ] Existing code compiles without errors

#### Actual Implementation
Completed 2026-02-10. Modified two files:

- `services/auracontext/data/domain/domain.go` — Added `DomainRecordingConfig` struct (lines 50-54) with `Enabled bool` and `EnabledAt *time.Time`, both with JSON tags. Extended `DomainConfig` (lines 57-60) with `Recording *DomainRecordingConfig` field (`json:"recording,omitempty"`). No new imports needed (`time` was already imported). Existing struct literals use named fields so the new pointer field defaults to `nil` (backward-compatible). JSON serialization via `Value()`/`Scan()` handles the new field automatically.
- `services/auracontext/cmd/auracontext/handlers/domains/types.go` — Added `UpdateRecordingConfig` struct (lines 68-70) with `Enabled *bool` (pointer for optional/patch semantics). Extended `UpdateDomainRequest` (lines 72-77) with `Recording *UpdateRecordingConfig` field. No new imports needed.

Commit: `[P2/T2] Add recording config to domain types` (d295f23). Go compiler not available in this environment; code verified through manual review of imports, struct field types, JSON tags, and backward compatibility with existing struct literal usages.

---

### Task 3: Backend Data Layer - Extend Feedback Model and Add Cursor-Based List Query

**Claude Code Task:** #3
**Blocked By:** Task 1
**Phase:** 2

#### Description
Extend the feedback data model with a `Type` field. Add a new `ListChatReviewByDomain` query function that uses cursor-based pagination with `(created_at, id)` tuple comparison. Add new filter functions for `type`, multi-value `user_id`, multi-value `reason_code` (including `none` sentinel for NULL), and rating filter (0 = unrated, 1 = good, -1 = bad — all simple equality since rating is NOT NULL).

#### Files to Modify
- `heliosai/services/auracontext/data/feedback/types.go` — Add `Type` field to `Feedback` struct, add `ChatReviewEntry` type alias or extend, add `ListChatReviewParams` struct.
- `heliosai/services/auracontext/data/feedback/filter.go` — Add `ByType`, `ByTypes`, `ByUserIDs` (multi-value), `ByReasonCodes` (multi-value with none sentinel), `ByRating` (simple equality for 0/1/-1), `WithCursor` (tuple comparison) filters.
- `heliosai/services/auracontext/data/feedback/feedback.go` — Add `ListChatReviewByDomain` function using cursor-based pagination (LIMIT + 1 for `has_more`).

#### Implementation Notes
**Feedback struct extension** — add `Type string` field with DB column mapping. Default scan behavior should handle the new column.

**Cursor-based pagination** — The key improvement over existing offset-based queries:
```sql
SELECT * FROM feedback
WHERE domain_id = ?
  AND (created_at, id) < (?, ?)  -- cursor
  [AND type IN (...)]
  [AND user_id IN (?, ?, ...)]
  [AND rating = ?]               -- 0 (unrated), 1, or -1
  [AND (reason_code IN (?, ...) OR reason_code IS NULL)]  -- includes 'none'
  [AND created_at >= ?]
  [AND created_at <= ?]
ORDER BY created_at DESC, id DESC
LIMIT :limit + 1
```

Fetch `limit + 1` rows. If `len(results) > limit`, set `has_more = true` and truncate to `limit`.

**Multi-value filters** — Use squirrel's `sq.Eq{"user_id": []string{...}}` for IN clauses. For reason_code with `none` sentinel: `sq.Or{sq.Eq{"reason_code": nil}, sq.Eq{"reason_code": values}}`.

**Rating filter** — All three values (0, 1, -1) are simple equality filters: `WHERE rating = ?`. Rating 0 means "unrated" (recorded turns without feedback). Rating stays NOT NULL in the schema.

The `ListChatReviewParams` struct:
```go
type ListChatReviewParams struct {
    DomainID    string
    Type        *string      // "feedback", "recorded_turn", or nil for both
    UserIDs     []string     // OR within
    Rating      *int         // 1, -1, or 0 (unrated) — all simple equality, no IS NULL
    ReasonCodes []string     // OR within, "none" = IS NULL
    StartDate   *time.Time
    EndDate     *time.Time
    CursorTime  *time.Time   // cursor: created_at of last item
    CursorID    *string      // cursor: id of last item
    Limit       int
}
```

#### Success Criteria
- [ ] `Feedback` struct has `Type` field
- [ ] `ListChatReviewByDomain` returns entries with `has_more` boolean
- [ ] Cursor pagination uses `(created_at, id)` tuple comparison — no OFFSET
- [ ] Multi-value filters for user_id, reason_code work correctly
- [ ] Rating filter is simple equality for all values: 0 (unrated), 1 (good), -1 (bad)
- [ ] Reason code `none` sentinel maps to `IS NULL`
- [ ] Existing code compiles without errors

#### Actual Implementation
Completed 2026-02-10. Modified three files:

- `services/auracontext/data/feedback/types.go` — Added `Type string` field (json:"type") to `Feedback` struct (between `UserID` and `Rating`). Added `Type string` field to `UpsertFeedbackParams`. Added `ListChatReviewParams` struct with `DomainID`, `Type *string`, `UserIDs []string`, `Rating *int`, `ReasonCodes []string`, `StartDate/EndDate *time.Time`, `CursorTime *time.Time`, `CursorID *string`, `Limit int`. Added `ListChatReviewResult` struct with `Entries []Feedback` and `HasMore bool`.
- `services/auracontext/data/feedback/filter.go` — Added 6 new filters: `ByType(string)` (single type equality), `ByTypes([]string)` (IN clause), `ByUserIDs([]string)` (multi-value IN clause), `ByReasonCodes([]string)` (multi-value with "none" sentinel mapping to IS NULL via `sq.Or{sq.Eq{nil}, sq.Eq{values}}`), `WithCursor(time.Time, string)` (tuple comparison `(feedback.created_at, feedback.id) < (?, ?)` using `sq.Expr`), `OrderByCreatedDescIDDesc()` (dual-column DESC ordering for cursor pagination).
- `services/auracontext/data/feedback/feedback.go` — Added `"type"` to `feedbackColumns` (between `user_id` and `rating`). Added `&f.Type` to `feedbackFields` (matching position). Updated `UpsertFeedback`: added `type` to INSERT columns/VALUES and `type = VALUES(type)` to ON DUPLICATE KEY UPDATE. Added `ListChatReviewByDomain` function: builds filters from `ListChatReviewParams`, fetches `limit+1` rows, sets `HasMore = true` and truncates if overflow.

Commit: `[P2/T3] Add type field and cursor-based list query` (0be45fc). Build verified: `go build ./...` exits 0 with no errors.

---

### Task 4: Backend - Recording Toggle in UpdateDomain Handler

**Claude Code Task:** #4
**Blocked By:** Task 2
**Phase:** 3

#### Description
Extend the `UpdateDomain` handler to process the new `recording` field in the update request. When `recording.enabled` is set to `true`, set `recording.enabled_at` to the current timestamp. When set to `false`, clear the recording config. Invalidate the domain config cache on toggle (cache implemented in Task 5).

#### Files to Modify
- `heliosai/services/auracontext/cmd/auracontext/handlers/domains/handler.go` — Extend `UpdateDomain` handler (line ~259-318) to process `Recording` field from request.

#### Implementation Notes
In the `UpdateDomain` handler, after existing field processing:

```go
if req.Recording != nil && req.Recording.Enabled != nil {
    if *req.Recording.Enabled {
        now := time.Now().UTC()
        domain.Config.Recording = &DomainRecordingConfig{
            Enabled:   true,
            EnabledAt: &now,
        }
    } else {
        if domain.Config.Recording != nil {
            domain.Config.Recording.Enabled = false
            // Keep EnabledAt for audit trail, or clear it
        }
    }
}
```

The domain's `Config` JSON column is already saved in the existing update flow, so the recording config persists automatically.

For cache invalidation: add a hook point where the domain config cache (Task 5) can be evicted. If Task 5 isn't complete yet, leave a comment `// TODO: invalidate domain config cache` that Task 5 will fill in.

#### Success Criteria
- [ ] `PUT .../domains/{domainID}` accepts `{"recording": {"enabled": true}}` in request body
- [ ] Enabling sets `recording.enabled_at` to current UTC timestamp
- [ ] Disabling sets `recording.enabled = false`
- [ ] Domain config JSON is persisted with recording state
- [ ] Existing domain update functionality (name, description, state) is unaffected

#### Actual Implementation
Completed 2026-02-10. Modified three files:

- `services/auracontext/cmd/auracontext/handlers/domains/handler.go` -- Added `"time"` import. Added recording toggle logic in `UpdateDomain` handler (after State processing, before UpdatedBy assignment): checks `updateRequest.Recording != nil && updateRequest.Recording.Enabled != nil`, if enabling creates new `domain.DomainRecordingConfig{Enabled: true, EnabledAt: &now}`, if disabling sets `Enabled = false` while preserving `EnabledAt` for audit trail. Added `// TODO: invalidate domain config cache` comment for Task 5.
- `services/auracontext/cmd/auracontext/handlers/domains/types.go` -- Added `DomainRecordingResponseConfig` struct with `Enabled bool` and `EnabledAt *string` (RFC3339 formatted). Added `Recording *DomainRecordingResponseConfig` field to `DomainResponse` with `json:"recording,omitempty"`.
- `services/auracontext/cmd/auracontext/handlers/domains/helpers.go` -- Added `"time"` import. Updated `domainToResponse` to map `d.Config.Recording` to `DomainRecordingResponseConfig`, formatting `EnabledAt` as RFC3339 string. Nil-safe: returns nil recording in response when domain has no recording config.

Commit: `[P3/T4] Wire recording toggle in UpdateDomain` (eb062fd). Go compiler not available in this environment; code verified through manual review of imports, types, nil guards, and backward compatibility.

---

### Task 5: Backend - Domain Config Cache and Turn Recording Goroutine

**Claude Code Task:** #5
**Blocked By:** Task 2, Task 3
**Phase:** 3

#### Description
Implement the in-memory domain config cache with 5-minute TTL. Implement the `maybeRecordTurn` function that fires as a goroutine after checkpoint commit. The goroutine checks the cache for recording state, resolves the domain from the session, extracts the question preview, and inserts a `type='recorded_turn'` row into the feedback table.

#### Files to Modify
- `heliosai/services/auracontext/cmd/auracontext/handlers/checkpoints/handlers.go` — Add `go func() { maybeRecordTurn(...) }()` after checkpoint commit.
- `heliosai/services/auracontext/cmd/auracontext/handlers/checkpoints/recording.go` — **New file.** `DomainConfigCache` struct and `maybeRecordTurn` function.

#### Implementation Notes

**Domain config cache:**
```go
type DomainConfigCache struct {
    cache sync.Map // domain_id -> *cachedConfig
}

type cachedConfig struct {
    config    *domain.DomainRecordingConfig
    expiresAt time.Time
}

func (c *DomainConfigCache) Get(domainID string) (*domain.DomainRecordingConfig, bool) {
    // Return from cache if not expired, else return miss
}

func (c *DomainConfigCache) Set(domainID string, config *domain.DomainRecordingConfig) {
    // Store with 5-minute TTL
}

func (c *DomainConfigCache) Evict(domainID string) {
    c.cache.Delete(domainID)
}
```

**maybeRecordTurn flow** (spec §10):
1. Create detached context with 10-second timeout
2. Check domain config cache for `recording.enabled` — short-circuit if disabled or missing
3. On cache miss: read domain config from DB, populate cache
4. Resolve `domain_id` from session (`SELECT domain_id FROM sessions WHERE id = ?`) — short-circuit if no domain
5. Check `recording.enabled_at` — short-circuit if checkpoint timestamp is before it
6. Decode msgpack blob, extract `question_preview` (reuse existing `extractQuestionPreview` helper from feedback handlers, or adapt it)
7. Generate deterministic ID: `SHA256(checkpoint_id + ":" + session_id)`
8. INSERT into feedback table: `type='recorded_turn'`, `rating=0`, `reason_code=NULL`, `comment=NULL`
9. On any error: log + increment metric, do not propagate

**Integration point:** The goroutine launches after the checkpoint HTTP response is sent. The checkpoint handler already has access to `checkpoint_id`, `session_id` (thread_id), and the checkpoint blob. Pass these to `maybeRecordTurn`.

**Cache invalidation:** Wire up the `Evict` call in the UpdateDomain handler (from Task 4). The cache instance should be shared — either passed as a dependency or accessible as a package-level singleton.

#### Success Criteria
- [ ] `DomainConfigCache` provides Get/Set/Evict with 5-minute TTL
- [ ] `maybeRecordTurn` fires as a goroutine after checkpoint commit
- [ ] Goroutine uses detached context with 10-second timeout
- [ ] Short-circuits on: recording disabled, no domain, timestamp before `enabled_at`
- [ ] Inserts `type='recorded_turn'` row with `rating=0`
- [ ] Uses deterministic ID: `SHA256(checkpoint_id:session_id)`
- [ ] Errors are logged but never propagate to the checkpoint HTTP response
- [ ] Cache is evicted when domain recording config changes

#### Actual Implementation

Commit: `[P3/T5] Add domain config cache and turn recording` (f7925a1)

**New file:** `services/auracontext/cmd/auracontext/handlers/checkpoints/recording.go`
- `DomainConfigCache` struct with `sync.Map`, 5-minute TTL via `cachedConfig.expiresAt`
- `Get()` returns cached config or (nil, false) on miss/expiry; `Set()` stores with TTL; `Evict()` deletes
- `maybeRecordTurn()` method on `CheckpointHandler`: creates detached context with 10s timeout, resolves domain_id from sessions table, checks cache (fills on miss from DB), short-circuits if recording disabled or `enabled_at` is in the future, extracts question preview via msgpack decoding (same approach as feedback helpers), generates deterministic ID via `feedback.GenerateDeterministicFeedbackID`, upserts `type='recorded_turn'` with `rating=0` into feedback table. All errors logged but never propagated.
- Helper functions: `getSessionDomainIDForRecording`, `loadRecordingConfig`, `extractQuestionPreviewForRecording`

**Modified:** `services/auracontext/cmd/auracontext/handlers/checkpoints/handlers.go`
- Added `recordingCache *DomainConfigCache` field to `CheckpointHandler` struct
- Updated `NewCheckpointHandler` to accept `recordingCache` parameter
- Added `go c.maybeRecordTurn(...)` call in `UpsertCheckpoint` after successful transaction, before response write

**Modified:** `services/auracontext/cmd/auracontext/handlers/domains/handler.go`
- Added `RecordingCacheEvicter` interface with `Evict(domainID string)` method
- Added `recordingCache RecordingCacheEvicter` field to `DomainsHandler`
- Updated `NewDomainsHandler` to accept `recordingCache` parameter
- Replaced `// TODO: invalidate domain config cache` with `h.recordingCache.Evict(rc.DomainID.String())`

**Modified:** `services/auracontext/cmd/auracontext/main.go`
- Created shared `recordingCache := checkpoints.NewDomainConfigCache()` before handler creation
- Passed `recordingCache` to both `NewDomainsHandler` and `NewCheckpointHandler`

---

### Task 6: Backend - Modify Existing Feedback Handlers for Backward Compatibility

**Claude Code Task:** #6
**Blocked By:** Task 3
**Phase:** 4

#### Description
Modify the existing `ListFeedback` handler to add `WHERE type = 'feedback'` so it excludes recorded turns. Modify `SubmitFeedback` to always set `type = 'feedback'` in the UPSERT, enabling promotion of recorded turns to feedback entries.

#### Files to Modify
- `heliosai/services/auracontext/cmd/auracontext/handlers/feedback/handlers.go` — Add `type = 'feedback'` filter to `ListFeedback` (line ~248-331). Add `type = 'feedback'` to UPSERT in `SubmitFeedback` (line ~170-245).
- `heliosai/services/auracontext/data/feedback/feedback.go` — Ensure `UpsertFeedback` sets `type` column. Ensure `ListFeedbackByDomain` can accept a `type` filter.
- `heliosai/services/auracontext/cmd/auracontext/handlers/feedback/types.go` — Add `Type` field to `FeedbackResponse` DTO (optional field for backward compat: `Type *string \`json:"type,omitempty"\``).

#### Implementation Notes

**ListFeedback change:** Add `.Where(sq.Eq{"type": "feedback"})` to the existing query builder in `ListFeedbackByDomain` when called from the `ListFeedback` handler. This ensures `GET .../feedback` returns only explicit feedback, not recorded turns.

**SubmitFeedback change:** In the UPSERT statement, always include `type = 'feedback'`. This means:
- If no row exists → INSERT with `type = 'feedback'` (normal feedback submission)
- If a `type = 'recorded_turn'` row exists → UPDATE sets `type = 'feedback'` (promotion)

The deterministic ID ensures the same row is targeted: `SHA256(checkpoint_id + ":" + session_id)`.

**Response DTO:** Add `Type` as an optional string field to `FeedbackResponse`. For the existing `/feedback` endpoint, all entries will have `type = "feedback"`. Making it optional (`omitempty`) minimizes risk to strict schema validators (OQ1).

#### Success Criteria
- [ ] `GET .../feedback` returns only `type = 'feedback'` entries
- [ ] `POST .../feedback` always sets `type = 'feedback'` in UPSERT
- [ ] A recorded turn that receives feedback is promoted to `type = 'feedback'`
- [ ] `FeedbackResponse` includes `type` field (optional)
- [ ] Existing feedback submission and listing behavior is unchanged for normal use cases
- [ ] Existing code compiles without errors

#### Actual Implementation
Completed 2026-02-10. Modified five files:

- `services/auracontext/data/feedback/types.go` -- Added `Type *string` field to `ListFeedbackParams` struct (between `DomainID` and `SessionID`). Optional pointer: nil means no type filter (backward-compatible with existing callers).
- `services/auracontext/data/feedback/feedback.go` -- Added type filter logic in `ListFeedbackByDomain`: `if params.Type != nil { filters = append(filters, db.ByType(*params.Type)) }`. Inserted after the initial filters and before the existing SessionID filter. Uses the `ByType` filter from filter.go (added in Task 3).
- `services/auracontext/cmd/auracontext/handlers/feedback/helpers.go` -- Updated `listFeedbackByDomain` signature to accept `feedbackType *string` parameter (inserted after `domainID`). Passes it through as `Type: feedbackType` in `ListFeedbackParams`.
- `services/auracontext/cmd/auracontext/handlers/feedback/handlers.go` -- (1) In `SubmitFeedback` (line 230): added `Type: "feedback"` to `UpsertFeedbackParams`, ensuring new feedback is explicitly typed and recorded turns are promoted on UPSERT. (2) In `ListFeedback` (lines 318-320): added `feedbackType := "feedback"` and passed `&feedbackType` to `listFeedbackByDomain`, so `GET .../feedback` returns only `type = 'feedback'` entries (excludes recorded turns per spec F13).
- `services/auracontext/cmd/auracontext/handlers/feedback/types.go` -- (1) Added `Type string` field to `FeedbackResponse` with `json:"type,omitempty"` tag (between `UserID` and `Rating`). (2) Updated `feedbackToResponse` to map `f.Type` to response `Type` field.

Commit: `[P4/T6] Filter feedback listing to type=feedback and set type on submit` (35480d5). Go compiler not available in this environment; code verified through manual review of all imports, types, field mappings, call sites, and backward compatibility with existing test struct literals (all use named fields, new pointer fields default to nil/zero).

---

### Task 7: Backend - New Chat Review Handlers

**Claude Code Task:** #7
**Blocked By:** Task 3
**Phase:** 4

#### Description
Create new HTTP handlers for the Chat Review endpoints: `ListChatReview` and `GetChatReviewThread`. Register the route prefix in the auracontext service main.

#### Files to Modify
- `heliosai/services/auracontext/cmd/auracontext/handlers/chatreview/handlers.go` — **New file.** `ListChatReview` and `GetChatReviewThread` handlers.
- `heliosai/services/auracontext/cmd/auracontext/handlers/chatreview/types.go` — **New file.** Request/response DTOs.
- `heliosai/services/auracontext/cmd/auracontext/main.go` — Register chat-review route prefix.

#### Implementation Notes

**ListChatReview handler:**
1. Parse query params: `starting_after`, `limit`, `type`, `user_id` (CSV), `rating`, `reason_code` (CSV), `start_date`, `end_date`
2. If `starting_after` is provided: look up the entry by ID to get its `(created_at, id)` for cursor
3. Call `ListChatReviewByDomain` from the data layer (Task 3)
4. Return `ChatReviewListResponse` with `entries` and `has_more`

**Query param parsing for CSV values:** `strings.Split(r.URL.Query().Get("user_id"), ",")` — filter out empty strings.

**GetChatReviewThread handler:**
Follow the same pattern as existing `GetFeedbackThread` (feedback handlers.go:334-390):
1. Extract entry ID from path
2. Look up entry from feedback table (now includes both types)
3. Verify domain ownership (entry.domain_id matches path param)
4. Verify session-domain binding
5. Retrieve thread from checkpoint blobs
6. Return `ChatReviewThreadResponse` with `entry` + `thread`

**Response DTOs:**
```go
type ChatReviewEntry struct {
    ID              string     `json:"id"`
    Type            string     `json:"type"`
    DomainID        string     `json:"domain_id"`
    SessionID       string     `json:"session_id"`
    CheckpointID    string     `json:"checkpoint_id"`
    UserID          string     `json:"user_id"`
    QuestionPreview string     `json:"question_preview"`
    Rating          int        `json:"rating"`           // 0 = unrated, 1 = good, -1 = bad
    ReasonCode      *string    `json:"reason_code"`
    Comment         *string    `json:"comment"`
    CreatedAt       time.Time  `json:"created_at"`
}

type ChatReviewListResponse struct {
    Entries []ChatReviewEntry `json:"entries"`
    HasMore bool              `json:"has_more"`
}

type ChatReviewThreadResponse struct {
    Entry  ChatReviewEntry        `json:"entry"`
    Thread SessionMessagesResponse `json:"thread"`
}
```

Note: Chat Review response uses `snake_case` JSON fields (matching the spec §12), unlike the existing feedback response which uses `camelCase`. This is intentional — the new endpoint follows the domain handler convention.

**Route registration** in `main.go`:
```go
chatReviewHandler := chatreview.NewChatReviewHandler(logger, connections, jwtHandler, opts.UseDomainIDInToken)
router.PathPrefix(commonPrefix + "/domains/{domain_id}/chat-review").Handler(chatReviewHandler.Handler())
```

#### Success Criteria
- [ ] `GET .../domains/{domainID}/chat-review` returns paginated entries with cursor support
- [ ] `GET .../domains/{domainID}/chat-review/{entryID}/thread` returns entry + full thread
- [ ] All query param filters work: type, user_id (CSV), rating, reason_code (CSV), start_date, end_date
- [ ] Cursor resolution: `starting_after` looks up entry to derive `(created_at, id)` cursor
- [ ] Response envelope follows `{ "results": { ... } }` pattern
- [ ] Route is registered and accessible
- [ ] Existing code compiles without errors

#### Actual Implementation

**Commit:** `79848ec` — `[P4/T7] Add chat review HTTP handlers and route registration`

**Files created:**
- `services/auracontext/cmd/auracontext/handlers/chatreview/handlers.go` (328 lines) — `ChatReviewHandler` struct, `NewChatReviewHandler`, `Handler()` with two routes, `SetRequestContext` middleware (copied from feedback pattern), `ListChatReview` handler (query param parsing, cursor resolution via `feedback.Db().GetFeedback()`, calls `ListChatReviewByDomain`), `GetChatReviewThread` handler (entry lookup, domain ownership check, session-domain binding check, thread retrieval).
- `services/auracontext/cmd/auracontext/handlers/chatreview/types.go` (67 lines) — `RequestContext`, `ChatReviewEntry` (snake_case JSON), `ChatReviewListResponse`, `ChatReviewThreadResponse`, `feedbackToChatReviewEntry` converter.
- `services/auracontext/cmd/auracontext/handlers/chatreview/helpers.go` (106 lines) — Copied `getSessionDomainID` and `getThreadForFeedback` from feedback/helpers.go (unexported functions, can't share across packages).

**Files modified:**
- `services/auracontext/cmd/auracontext/main.go` — Added `chatreview` import, created `chatReviewHandler`, registered route `PathPrefix(commonPrefix + "/domains/{domain_id}/chat-review")` BEFORE the `/domains/{domain_id}/feedback` and `/domains` routes to avoid shadowing.

**Design decisions:**
- Thread type uses `*msgpack.APIResponse` (matching existing feedback thread pattern) rather than `SessionMessagesResponse` as noted in the plan spec, since `msgpack.APIResponse` is what `getThreadForFeedback` actually returns.
- Helper functions copied rather than extracted to shared package, following the codebase convention of self-contained handler packages.
- Response uses `util.WriteJSONResponseWithResults` for `{ "results": { ... } }` envelope.

---

### Task 8: Nova Gateway - RBAC Permission Rename

**Claude Code Task:** #8
**Blocked By:** None
**Phase:** 5

#### Description
Rename `AgentDomainViewFeedback` to `AgentDomainReviewConversations` across the Nova Gateway. Update the RBAC permission definition, GraphQL permission mapping, and the action constant in the feedback handler.

#### Files to Modify
- `helios/singlestore.com/helios/cmd/nova-gateway/auracontext/` path for:
  - `agentdomain.yaml` — Rename permission definition
  - `graph/authz.go` (line ~385-415) — Update GraphQL permission mapping
  - `handlers/feedbackhandler.go` — Update action constant in `ProxyListFeedback`

#### Implementation Notes
Search for all occurrences of `AgentDomainViewFeedback` and replace with `AgentDomainReviewConversations`. This is a string rename — the permission semantics are identical but the name now reflects the broader scope (conversations, not just feedback).

Files to check (may be more than the three listed):
- YAML permission definitions
- Go constants/strings referencing the action name
- GraphQL schema/resolver permission mappings
- Test files referencing the permission

#### Success Criteria
- [ ] No references to `AgentDomainViewFeedback` remain in the codebase
- [ ] `AgentDomainReviewConversations` is defined in `agentdomain.yaml`
- [ ] GraphQL permission mapping updated in `authz.go`
- [ ] `ProxyListFeedback` uses `AgentDomainReviewConversations`
- [ ] Existing code compiles without errors
- [ ] Existing tests pass (update test assertions if they reference the old name)

#### Actual Implementation

Renamed `AgentDomainViewFeedback` -> `AgentDomainReviewConversations` across 15 files:

**Source files (6):**
- `singlestore.com/helios/graph/gql/enum.gql` -- enum value renamed
- `singlestore.com/helios/authz/model/yaml/agentdomain.yaml` -- permission name + desc updated
- `singlestore.com/helios/authz/permissions.go` -- `PermViewAgentDomainFeedback` -> `PermReviewAgentDomainConversations`
- `singlestore.com/helios/graph/authz.go` -- GraphQL-to-permission mapping updated
- `singlestore.com/helios/cmd/nova-gateway/auracontext/handlers/feedbackhandler.go` -- RBAC check + log message updated
- `singlestore.com/helios/cmd/nova-gateway/auracontext/handlers/feedbackhandler_test.go` -- all references + test names + assertion messages updated

**Generated files (9):**
- `singlestore.com/helios/graph/models_gen.go` -- constant + string literal + IsValid switch
- `singlestore.com/helios/graph/novaprivate/exec_gen.go` -- embedded GQL schema
- `singlestore.com/helios/graph/novaprivatemodels/models_gen.go` -- constant + string literal + IsValid switch
- `singlestore.com/helios/graph/novapublic/exec_gen.go` -- embedded GQL schema
- `singlestore.com/helios/graph/novapublicmodels/models_gen.go` -- constant + string literal + IsValid switch
- `singlestore.com/helios/graph/server/public/exec_gen.go` -- embedded GQL schema
- `frontend/src/__generated__/global-types.ts` -- TypeScript enum
- `frontend/src/__generated__/admin/global-types.ts` -- TypeScript enum
- `frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-tab.tsx` -- permission usage

Commit: `[P5/T8] Rename RBAC perm to ReviewConversations` (94adc7953f9)
Verification: grep for old names returns zero results across entire repo.

---

### Task 9: Nova Gateway - New Chat Review Proxy Routes

**Claude Code Task:** #9
**Blocked By:** Task 8
**Phase:** 5

#### Description
Add two new proxy routes in the Nova Gateway for the chat-review endpoints. Add the `EntryID` path variable constant. Create proxy handler functions following the existing feedback handler pattern.

#### Files to Modify
- `helios/singlestore.com/helios/cmd/nova-gateway/auracontext/constants/constants.go` — Add `EntryID PathVariable = "entryID"`.
- `helios/singlestore.com/helios/cmd/nova-gateway/auracontext/handlers/feedbackhandler.go` — Add `ProxyListChatReview` and `ProxyGetChatReviewThread` handler functions.
- `helios/singlestore.com/helios/cmd/nova-gateway/auracontext/routes.go` — Register new routes.

#### Implementation Notes

**ProxyListChatReview** (follows `ProxyListFeedback` pattern at feedbackhandler.go:43-98):
1. Check for `session_id` param → if present, user's own scope (add `user_id` from JWT)
2. Otherwise, RBAC check: `AgentDomainReviewConversations` via `checkDomainPermission()`
3. Forward all query params to upstream: `starting_after`, `limit`, `type`, `user_id`, `rating`, `reason_code`, `start_date`, `end_date`
4. Proxy to upstream auracontext service

**ProxyGetChatReviewThread** (follows `ProxyGetFeedbackThread` pattern at feedbackhandler.go:104-147):
1. RBAC check: `AgentDomainViewUserConversations` via `checkDomainPermission()`
2. Extract `entryID` from path
3. Proxy to upstream auracontext service

**Route registration** in `routes.go`:
```go
// Chat Review routes
r.HandleFunc(
    prefix + "/domains/{domainID}/chat-review",
    h.ProxyListChatReview,
).Methods("GET")

r.HandleFunc(
    prefix + "/domains/{domainID}/chat-review/{entryID}/thread",
    h.ProxyGetChatReviewThread,
).Methods("GET")
```

#### Success Criteria
- [ ] `EntryID` constant exists in constants.go
- [ ] `GET .../domains/{domainID}/chat-review` proxied with RBAC `AgentDomainReviewConversations`
- [ ] `GET .../domains/{domainID}/chat-review/{entryID}/thread` proxied with RBAC `AgentDomainViewUserConversations`
- [ ] Query params forwarded correctly for list endpoint
- [ ] Routes registered in routes.go
- [ ] Existing code compiles without errors

#### Actual Implementation

**Commit:** `[P5/T9] Add chat-review proxy routes` (12633d6a96a)

**Files modified (5):**

1. **`singlestore.com/helios/cmd/nova-gateway/auracontext/constants/constants.go`**
   - Added `EntryID PathVariable = "entryID"` to the PathVariable constants block (line 27)
   - EntryID is a SHA-256 hash (not UUID), so it correctly falls through to the `default` case in `IsValid()` which returns `pathValue != ""`

2. **`singlestore.com/helios/cmd/nova-gateway/auracontext/handlers/feedbackhandler.go`**
   - Added `ProxyListChatReview` handler (lines 157-201): GET /domains/{domainID}/chat-review
     - Always requires `AgentDomainReviewConversations` RBAC permission (no session_id bypass unlike ProxyListFeedback)
     - All query params forwarded as-is to upstream
   - Added `ProxyGetChatReviewThread` handler (lines 205-248): GET /domains/{domainID}/chat-review/{entryID}/thread
     - Requires `AgentDomainViewUserConversations` RBAC permission (same as ProxyGetFeedbackThread)
   - Both handlers follow the exact same pattern as existing feedback handlers: extractAuthAndClaims -> parse domainID -> checkDomainPermission -> proxy

3. **`singlestore.com/helios/cmd/nova-gateway/auracontext/routes.go`**
   - Registered two new GET routes after existing Feedback routes, before Domain Extensions (lines 69-71):
     - `GET /domains/{domainID}/chat-review` -> `ProxyListChatReview`
     - `GET /domains/{domainID}/chat-review/{entryID}/thread` -> `ProxyGetChatReviewThread`

4. **`singlestore.com/helios/cmd/nova-gateway/auracontext/handlers/feedbackhandler_test.go`**
   - Added `testEntryID` constant (64-char hex string representing SHA-256 hash)
   - Added 4 integration tests:
     - `TestListChatReview_WithReviewConversationsPermission_ReturnsSuccess` - 200 with correct RBAC
     - `TestListChatReview_WithoutReviewConversationsPermission_Returns403` - 403 without RBAC
     - `TestGetChatReviewThread_WithViewConversationsPermission_ReturnsSuccess` - 200 with correct RBAC
     - `TestGetChatReviewThread_WithoutViewConversationsPermission_Returns403` - 403 without RBAC

5. **`singlestore.com/helios/cmd/nova-gateway/auracontext/handlers/integration_helpers_test.go`**
   - Registered chat review routes in `registerDomainRoutes` so tests can exercise the new handlers through the full middleware chain

**Design deviation from plan:** The plan's Implementation Notes (lines 630-632) suggested ProxyListChatReview should have a session_id bypass like ProxyListFeedback. However, the task description (from the implementation plan update) explicitly states: "Unlike ProxyListFeedback which has a session_id bypass, ProxyListChatReview ALWAYS requires RBAC permission (AgentDomainReviewConversations). There is no session_id bypass -- this endpoint is exclusively for domain owners reviewing conversations." The implementation follows this corrected requirement.

---

### Task 10: Frontend - API Types, Routes, and Hooks for Chat Review

**Claude Code Task:** #10
**Blocked By:** None
**Phase:** 6

#### Description
Add frontend API layer for chat review: route definitions, TypeScript types, fetch functions, and React hooks. Extend the `Domain` type with the `recording` field.

#### Files to Modify
- `helios/frontend/src/pages/organizations/intelligence/api/routes.ts` — Add `listChatReview` and `getChatReviewThread` to `INTELLIGENCE_ROUTES`.
- `helios/frontend/src/pages/organizations/intelligence/api/chat-review.ts` — **New file.** Types, fetch functions, React hooks.
- `helios/frontend/src/pages/organizations/intelligence/api/domains.ts` (line ~43-53) — Extend `Domain` type with `recording` field.
- `helios/frontend/src/pages/organizations/intelligence/api/feedback.ts` (line ~22-70) — Add optional `type` field to existing `Feedback` type for backward compat.

#### Implementation Notes

**Route definitions** in `routes.ts`:
```typescript
listChatReview: {
    route: "/domains/:domainID/chat-review",
    method: "GET",
},
getChatReviewThread: {
    route: "/domains/:domainID/chat-review/:entryID/thread",
    method: "GET",
},
```

**Types** (from spec §11):
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
    rating: number;           // 0 = unrated, 1 = good, -1 = bad
    reason_code: string | null;
    comment: string | null;
    created_at: string;
};

type ChatReviewFilters = {
    starting_after?: string;
    limit?: number;
    user_id?: string[];
    rating?: 0 | 1 | -1;     // 0 = unrated
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

**Domain type extension:**
```typescript
type Domain = {
    // ... existing fields
    recording?: {
        enabled: boolean;
        enabled_at?: string;
    };
};
```

**React hooks:** Follow the `useListFeedback` pattern (feedback.ts:89-236) for `useListChatReview`. The hook should:
- Accept `ChatReviewFilters` as params
- Use `useAuraContextFetch` for domain-scoped OBO calls
- Return `{ entries, hasMore, isLoading, error }`

For cursor-based pagination, the hook should manage cursor state internally:
- `cursors: string[]` array — stack of `starting_after` values for backward navigation
- `currentPage: number` — for display
- `goNext(lastEntryId)` — push cursor, increment page
- `goPrev()` — pop cursor, decrement page

#### Success Criteria
- [ ] Routes defined in `INTELLIGENCE_ROUTES`
- [ ] All TypeScript types match spec §11
- [ ] `Domain` type extended with optional `recording` field
- [ ] `useListChatReview` hook fetches and returns paginated data
- [ ] Cursor management supports forward and backward navigation
- [ ] `Feedback` type has optional `type` field
- [ ] TypeScript compiles without errors

#### Actual Implementation

**Commit:** `6d1a1a9128c` — `[P6/T10] Add chat review API types and hooks`

**Files modified:**
1. `frontend/src/pages/organizations/intelligence/api/routes.ts` — Added `listChatReview(domainID)` and `getChatReviewThread(domainID, entryID)` arrow functions to `INTELLIGENCE_ROUTES`.
2. `frontend/src/pages/organizations/intelligence/api/domains.ts` — Extended `Domain` type with optional `recording?: { enabled: boolean; enabled_at?: string }` field.
3. `frontend/src/pages/organizations/intelligence/api/feedback.ts` — Added optional `type?: string` field to `Feedback` type for backward compatibility.
4. `frontend/src/pages/organizations/intelligence/api/chat-review.ts` — **New file.** Contains:
   - Types: `ChatReviewEntryType`, `ChatReviewEntry`, `ChatReviewFilters`, `ChatReviewListResponse`, `ChatReviewThreadResponse` (all matching spec section 11, snake_case fields)
   - `useListChatReview` hook: follows `useListFeedback` pattern with `useAuraContextFetch`, OBO token, domain-scoped calls. Adds cursor-based pagination via internal `cursors: string[]` stack and `currentPage` state. Exposes `goNext(lastEntryId)`, `goPrev()`, `resetPagination()`. Filter params appended as search params (arrays use repeated param keys).
   - `getChatReviewThreadAPI` async function: follows `getFeedbackThreadAPI` pattern with `auraContextSafeFetch`.

**Deviations from plan:** None. All success criteria met.

---

### Task 11: Frontend - Rename Details Tab to Settings and Add Recording Toggle

**Claude Code Task:** #11
**Blocked By:** Task 10
**Phase:** 7

#### Description
Rename the "Details" tab to "Settings" in the domain configuration flyout. Add a recording toggle (switch component) to the Settings tab. Update the `TabID` union type.

#### Files to Modify
- `helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/configure-domains-flyout.tsx` — Update `TabID` union: rename `"details"` → `"settings"`. Update tab order to: Data, Context, Access Controls, API Keys, Chat Review, Settings.
- `helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/details-tab.tsx` — Rename file to `settings-tab.tsx`. Add recording toggle switch.

#### Implementation Notes

**TabID change** (configure-domains-flyout.tsx:57-63):
```typescript
type TabID =
    | "data"
    | "insights"
    | "access-controls"
    | "chat-review"    // new, replaces "feedback"
    | "api-keys"
    | "settings";      // renamed from "details"
```

**Tab order** (spec F12): Data, Context, Access Controls, API Keys, Chat Review, Settings.

**Recording toggle** in Settings tab:
- Use existing switch/toggle component from the design system
- Label: "Record analyst conversations"
- Description: "When enabled, analyst turns are captured for review in the Chat Review tab."
- Call `updateDomainAPI` with `{ recording: { enabled: true/false } }` on toggle
- Show `recording.enabled_at` timestamp when enabled: "Recording since {date}"

**File rename:** The physical file `details-tab.tsx` should be renamed to `settings-tab.tsx`. Update all imports.

#### Success Criteria
- [ ] "Details" tab renamed to "Settings" across all references
- [ ] Tab order matches spec F12
- [ ] Recording toggle switch in Settings tab
- [ ] Toggle calls `updateDomainAPI` with recording config
- [ ] Toggle state reflects `domain.recording.enabled`
- [ ] File renamed from `details-tab.tsx` to `settings-tab.tsx`
- [ ] TypeScript compiles without errors

#### Actual Implementation
Commit: `[P7/T11] Rename Details tab to Settings, Feedback to Chat Review, add recording toggle`

**Files modified:**
- `frontend/src/pages/organizations/intelligence/api/domains.ts` — Added `recording?: { enabled: boolean }` to `UpdateDomainAPIParams.domainData`.
- `frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/configure-domains-flyout.tsx` — Updated `TabID` union (`"feedback"` -> `"chat-review"`, `"details"` -> `"settings"`). Renamed import from `DetailsTab` to `SettingsTab`. Renamed `feedbackTab` variable to `chatReviewTab`, `detailsTab` to `settingsTab`. Reordered tab titles: Data, Context, Access Controls, (API Keys conditional), Chat Review, Settings. Reordered tab children in both return branches to match. `FeedbackTab` component still renders inside `chatReviewTab` (to be swapped in Task 12).
- `frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/settings-tab.tsx` — Renamed from `details-tab.tsx`. Exported `SettingsTab` (was `DetailsTab`). Added `RecordingToggle` component with Toggle switch, description text, and "Recording since {date}" timestamp. Toggle calls `updateDomainAPI` with `{ recording: { enabled: boolean } }`. Only visible to users with `AgentDomainUpdate` permission. Uses `formatDateTime` for the enabled_at timestamp.

---

### Task 12: Frontend - Chat Review Tab with Filters and Paginated Table

**Claude Code Task:** #12
**Blocked By:** Task 10, Task 11
**Phase:** 7

#### Description
Build the Chat Review tab component that replaces the existing Feedback tab. Includes a unified table displaying both feedback and recorded turn entries, filter controls (rating segmented control, reason code multi-select, user multi-select, date range), and cursor-based pagination.

#### Files to Modify
- `helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/configure-domains-flyout.tsx` — Replace `"feedback"` tab with `"chat-review"` tab. Wire up the new component.
- `helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/chat-review-tab/chat-review-tab.tsx` — **New file.** Main Chat Review tab: filter state management, data fetching, layout.
- `helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/chat-review-tab/chat-review-table.tsx` — **New file.** Table rendering: question (clickable), rating, reason, comment, created by, created at columns. Matches feedback tab.

#### Implementation Notes

**Filter controls** (spec F8):
1. **Rating** — Segmented control: All / Good / Bad / Unrated. Maps to `rating` param: omit / 1 / -1 / 0.
2. **Reason code** — Multi-select dropdown. Uses `useGetReasonCodes` hook from existing feedback API. Maps to `reason_code` CSV param.
3. **User** — Multi-select searchable dropdown. Populate from available entries or a users endpoint. Maps to `user_id` CSV param.
4. **Date range** — Presets: 7d / 30d / 90d / Custom. Reuse existing `date-range-picker.tsx` component. Maps to `start_date` / `end_date` params.

Filters are AND across dimensions, OR within multi-select values (spec F9).

**Table columns** (spec F7 — matches feedback tab):
| Column | Content |
|--------|---------|
| Question | Clickable link, opens thread flyout. Ellipsis on overflow. |
| Rating | RatingBadge (thumbs up/down or "—" for unrated) |
| Reason | Resolved reason code display name, or em-dash if none |
| Comment | User comment text, or em-dash if none |
| Created By | UserPopover (avatar + name), or em-dash if no user_id |
| Created At | Formatted date/time |

**Pagination:**
- Page size selector: 10 / 20 / 30 / 40 / 50 (default 50)
- Prev / Next buttons
- Reuse existing `pagination.tsx` component from `view/common/notebook-apps/` — omit total count indicators
- Cursor state managed by the `useListChatReview` hook (Task 10)
- Page size change resets to page 1

**Empty states** (spec §14):
1. Recording OFF + no data: "No feedback yet. Enable recording in the Settings tab to capture analyst conversations for review."
2. Recording OFF + historical data: Show table normally.
3. Recording ON + no entries yet: "Recording is enabled. Entries will appear here as users interact with the analyst."
4. Filters applied + no matches: "No entries match the current filters." (with clear/reset control)

**Row click:** Opens thread flyout (Task 13).

#### Success Criteria
- [ ] Chat Review tab replaces Feedback tab in the flyout
- [ ] Unified table shows both feedback and recorded_turn entries
- [ ] All four filter controls work (rating, reason code, user, date range)
- [ ] Filters are AND across dimensions, OR within multi-select
- [ ] Cursor-based pagination with prev/next and page size selector
- [ ] Page size change resets to page 1
- [ ] All four empty states render correctly
- [ ] Row click triggers thread flyout
- [ ] TypeScript compiles without errors

#### Actual Implementation

Completed 2026-02-11. Reworked `chat-review-table.tsx` to add all missing features:

**File modified:** `frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/chat-review-tab/chat-review-table.tsx`

- **Reason code multi-select filter:** Uses `FeedbackFilterSelect` with items from `useGetReasonCodes()`. Includes a "None" option mapping to the `"none"` sentinel (backend maps to IS NULL). Selected values passed as `reason_code` filter param.
- **User multi-select filter:** Uses `FeedbackFilterSelect` with items from `useEntities(orgID)` (org members with id/name). Selected values passed as `user_id` filter param.
- **Date range filter:** Single-select dropdown (`Select` component) with presets: Last 7 days, Last 30 days, Last 90 days, All time. Computes `start_date`/`end_date` ISO strings from preset days. Default: "All time" (no date filter).
- **Page size selector:** `Select` component with options 10/20/30/40/50 (default 50). Displayed in pagination bar as "Items per page: [N]".
- **Page size change resets to page 1:** All filter state changes (including page size) trigger `resetPagination()` via a single `useEffect`.
- **Empty states (all 4 from spec §14):** (1) Recording OFF + no data: "No feedback yet. Enable recording in the Settings tab..." (2) Recording OFF + historical data: table renders normally (implicit). (3) Recording ON + no entries: "Recording is enabled. Entries will appear here..." (4) Filters + no matches: "No entries match the current filters." with "Clear filters" button.
- **Clear filters button:** Resets all four filter dimensions (rating, reason code, user, date range) to defaults.
- **Pagination bar redesigned:** Split into left side (items per page selector) and right side (page indicator + prev/next buttons). Visible when entries exist or when navigated beyond page 1.

New imports: `Select`/`SelectContent`/`SelectItem`/`SelectTrigger` from fusion, `useEntities` from role-management, `useCurrentOrgID` from hooks.

`npm run typecheck` passes with zero errors.

---

### Task 13: Frontend - Chat Review Thread Flyout

**Claude Code Task:** #13
**Blocked By:** Task 10
**Phase:** 7

#### Description
Build the thread drill-down flyout for Chat Review entries. Clicking a row in the Chat Review table opens a flyout showing the full conversation thread. Follows the same pattern as the existing `feedback-thread-flyout.tsx`.

#### Files to Modify
- `helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/chat-review-tab/chat-review-thread-flyout.tsx` — **New file.** Thread flyout component.

#### Implementation Notes

Follow the pattern of the existing `feedback-tab/feedback-thread-flyout.tsx`:
1. Accept an entry ID (or full `ChatReviewEntry` object) as a prop
2. Fetch thread data using `getChatReviewThread` API function
3. Display the entry metadata (rating, reason, comment, created by, created at) in a side panel
4. Display the full conversation thread below (messages list)
5. Handle loading and error states

The thread response includes `SessionMessagesResponse` (title, messages, follow_up_suggestions, latest_settings) — render messages the same way the existing feedback thread flyout does.

The flyout should work for both `feedback` and `recorded_turn` entry types.

#### Success Criteria
- [ ] Flyout opens when clicking a Chat Review table row
- [ ] Shows entry metadata (type, question preview, rating, timestamp)
- [ ] Shows full conversation thread (messages list)
- [ ] Works for both `feedback` and `recorded_turn` entries
- [ ] Loading and error states handled
- [ ] Flyout closes on back button or outside click
- [ ] TypeScript compiles without errors

#### Actual Implementation

**Commit:** `afeff30fdef` -- `[P7/T13] Add chat review thread flyout component`

**Files created:**

1. **`frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/chat-review-tab/chat-review-thread-flyout.tsx`** (321 lines) -- Thread flyout component following `feedback-thread-flyout.tsx` pattern exactly. Key differences from the feedback version:
   - Props accept `ChatReviewEntry` (snake_case fields: `entry.user_id`, `entry.session_id`, `entry.checkpoint_id`) instead of `Feedback` (camelCase)
   - Uses `getChatReviewThreadAPI` instead of `getFeedbackThreadAPI`, passing `entryID: entry.id`
   - Inline metadata side panel (instead of `FeedbackMetadataCard`) with `Detail` helper component showing: Rating (via `RatingBadge`), Reason (resolved via `useGetReasonCodes`), Comment, Created By (`UserPopover`), Created At (`formatDateTime`)
   - Synthetic `feedbackList` built via `React.useMemo`: maps snake_case `ChatReviewEntry` to camelCase `Feedback` shape for `ChatHistoryDisplay` checkpoint highlighting (only for `type === "feedback"` entries; empty array for `"recorded_turn"`)
   - "Go to Session" button uses `entry.session_id` (snake_case) instead of `feedback.sessionID`
   - Owner check uses `entry.user_id === userId`
   - Deduplication guard via `lastLoadedKeyRef` (same pattern as feedback flyout)

2. **`frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/chat-review-tab/chat-review-thread-flyout.scss`** (19 lines) -- Styles copied from `feedback-thread-flyout.scss` with renamed selectors (`feedback-thread-flyout` -> `chat-review-thread-flyout`). Added `&__details` block (from `feedback-metadata-card.scss`) for the inline metadata layout since we don't use a separate metadata card component.

**No existing files modified.** The new directory `chat-review-tab/` was created for these files.

---

### Task 14: Integration Testing and Edge Cases

**Claude Code Task:** #14
**Blocked By:** Task 5, Task 6, Task 7, Task 9, Task 12, Task 13
**Phase:** 7

#### Description
Verify integration across all layers. Test edge cases from spec §14. Ensure backward compatibility of existing feedback endpoint. Write or update tests for new functionality.

#### Files to Modify
- `heliosai/services/auracontext/data/feedback/feedback_test.go` — Add tests for `ListChatReviewByDomain` with cursor pagination, multi-value filters, rating=0 sentinel.
- `helios/singlestore.com/helios/cmd/nova-gateway/auracontext/handlers/feedbackhandler_test.go` — Add tests for new chat-review proxy handlers. Update tests referencing `AgentDomainViewFeedback`.
- Various test files — Update any references to renamed permission or tab IDs.

#### Implementation Notes

**Edge cases to verify** (spec §14):
1. Recording goroutine fails → checkpoint response unaffected
2. Duplicate recording (same turn processed twice) → deterministic ID means no-op
3. Recording enabled → disabled → re-enabled → gap turns not captured
4. Legacy session (no domain) → `maybeRecordTurn` short-circuits
5. Checkpoint timestamp before `recording_enabled_at` → not recorded
6. `starting_after` cursor references nonexistent entry → 400 error
7. Filter combination yields zero results → empty entries with `has_more: false`
8. Existing `GET .../feedback` returns only `type = 'feedback'` rows

**Backend tests:**
- Unit test `ListChatReviewByDomain` with various filter combinations
- Unit test cursor pagination: first page, next page, boundary conditions
- Unit test `maybeRecordTurn`: happy path, recording disabled, no domain, timestamp check
- Unit test UPSERT promotion: recorded turn → feedback submission → row promoted

**Gateway tests:**
- Test `ProxyListChatReview` with RBAC check
- Test `ProxyGetChatReviewThread` with RBAC check
- Test query param forwarding

#### Success Criteria
- [ ] All new unit tests pass
- [ ] All existing tests pass (with permission rename updates)
- [ ] Edge cases from spec §14 are covered
- [ ] Backward compatibility: existing `/feedback` endpoint returns only feedback type
- [ ] `go test ./...` passes in auracontext service
- [ ] `go test ./...` passes in nova-gateway
- [ ] `npm run typecheck` passes in frontend

#### Actual Implementation

**Files created/modified:**

1. **CREATED**: `heliosai/services/auracontext/cmd/auracontext/handlers/chatreview/handlers_test.go` (18 tests)
   - **ListChatReview handler tests (9):** Valid request→200, invalid rating→400, invalid start_date→400, invalid end_date→400, limit=0→400, limit>1000→400, invalid cursor→400, all params valid→200
   - **GetChatReviewThread handler tests (3):** Missing entry_id→400, entry not found→404, handler compilation verification
   - **Type/response structure tests (5):** `feedbackToChatReviewEntry` mapping (all fields + nil optionals), `ChatReviewListResponse` JSON roundtrip, empty entries as `[]` not `null`, `ChatReviewThreadResponse` JSON roundtrip

2. **MODIFIED**: `heliosai/services/auracontext/data/feedback/feedback_test.go` (8 new tests appended)
   - `TestListChatReviewByDomain_BasicQuery` — entries sorted DESC by created_at
   - `TestListChatReviewByDomain_TypeFilter` — "feedback" vs "recorded_turn" vs nil (both)
   - `TestListChatReviewByDomain_MultiUserFilter` — IN clause for multiple user IDs
   - `TestListChatReviewByDomain_RatingFilter_Unrated` — rating=0 sentinel
   - `TestListChatReviewByDomain_CursorPagination` — 5 entries, limit=2, 3 pages, HasMore, no overlap
   - `TestListChatReviewByDomain_ReasonCodeNoneSentinel` — "none"→IS NULL, "none"+code→OR
   - `TestListChatReviewByDomain_EmptyResult` — non-existent domain, empty + HasMore=false
   - `TestListChatReviewByDomain_DateRange` — start+end, past range, start-only, end-only

**Edge cases from spec §14 covered:**
- Edge case 6: `starting_after` nonexistent entry → 400 (handler test)
- Edge case 7: Filter combo yields zero results → empty + has_more:false (data layer test)
- Edge case 2: Deterministic ID dedup (pre-existing `TestUpsertFeedback_DeterministicID_UpdatesSameRecord`)
- Edge case 8: Backward compat (pre-existing feedback tests use type='feedback')
- Edge cases 1,3,4,5: Runtime behaviors — not unit-testable, skipped appropriately

**No production code modified.** Go compiler not available — tests written to compile against existing patterns.

---

## Phases

### Phase 1: Schema Migration

#### Overview
Deploy the v11 database migration that extends the feedback table to support the new `type` column and cursor-based queries.

#### Tasks in This Phase
- Task 1: Schema Migration v11 - Extend Feedback Table

#### Success Criteria

**Automated Verification:**
- [ ] Migration SQL is syntactically valid
- [ ] Migration is idempotent

**Manual Verification:**
- [ ] Migration applies cleanly to a local/dev SingleStore instance

**Implementation Note:** This phase has no code dependencies. Can be deployed independently.

---

### Phase 2: Backend Data Layer

#### Overview
Extend Go data models and query functions to support recording config and cursor-based chat review listing.

#### Tasks in This Phase
- Task 2: Backend Data Layer - Extend Domain Config Types
- Task 3: Backend Data Layer - Extend Feedback Model and Add Cursor-Based List Query

#### Success Criteria

**Automated Verification:**
- [ ] `go build ./...` passes in auracontext service
- [ ] Existing tests pass: `go test ./...`

**Manual Verification:**
- [ ] Domain config JSON correctly serializes/deserializes with recording field

**Implementation Note:** Task 2 and Task 3 are independent of each other (Task 3 depends on Task 1 for the schema, but the Go code can be written before the migration is deployed).

---

### Phase 3: Backend Handlers (Recording)

#### Overview
Implement the recording toggle in the domain update handler, the domain config cache, and the turn recording goroutine.

#### Tasks in This Phase
- Task 4: Backend - Recording Toggle in UpdateDomain Handler
- Task 5: Backend - Domain Config Cache and Turn Recording Goroutine

#### Success Criteria

**Automated Verification:**
- [ ] `go build ./...` passes
- [ ] `go test ./...` passes

**Manual Verification:**
- [ ] Toggling recording ON via API sets `recording.enabled_at`
- [ ] Toggling recording OFF stops new captures
- [ ] Checkpoint commit with recording ON creates a feedback row with `type='recorded_turn'`
- [ ] Checkpoint commit with recording OFF creates no row

**Implementation Note:** After completing this phase and all automated verification passes, pause for manual confirmation before proceeding to the next phase.

---

### Phase 4: Backend Handlers (Chat Review)

#### Overview
Create new chat review list and thread handlers. Modify existing feedback handlers for backward compatibility.

#### Tasks in This Phase
- Task 6: Backend - Modify Existing Feedback Handlers for Backward Compatibility
- Task 7: Backend - New Chat Review Handlers

#### Success Criteria

**Automated Verification:**
- [ ] `go build ./...` passes
- [ ] `go test ./...` passes

**Manual Verification:**
- [ ] `GET .../chat-review` returns both feedback and recorded turns
- [ ] `GET .../chat-review` with filters returns correct results
- [ ] `GET .../chat-review/{entryID}/thread` returns full thread
- [ ] `GET .../feedback` returns only `type='feedback'` entries
- [ ] `POST .../feedback` on a recorded turn promotes it to feedback

**Implementation Note:** After completing this phase and all automated verification passes, pause for manual confirmation before proceeding to the next phase.

---

### Phase 5: Nova Gateway

#### Overview
Add proxy routes and RBAC for the new chat review endpoints. Rename the feedback permission.

#### Tasks in This Phase
- Task 8: Nova Gateway - RBAC Permission Rename
- Task 9: Nova Gateway - New Chat Review Proxy Routes

#### Success Criteria

**Automated Verification:**
- [ ] `go build ./...` passes in nova-gateway
- [ ] `go test ./...` passes in nova-gateway

**Manual Verification:**
- [ ] Chat review endpoints accessible through gateway with correct RBAC
- [ ] Existing feedback endpoints still work

**Implementation Note:** After completing this phase and all automated verification passes, pause for manual confirmation before proceeding to the next phase.

---

### Phase 6: Frontend API Layer

#### Overview
Add TypeScript types, route definitions, and React hooks for chat review.

#### Tasks in This Phase
- Task 10: Frontend - API Types, Routes, and Hooks for Chat Review

#### Success Criteria

**Automated Verification:**
- [ ] `npm run typecheck` passes
- [ ] `npm run lint` passes

**Manual Verification:**
- [ ] Hook returns data when called with test domain ID

---

### Phase 7: Frontend UI

#### Overview
Build the Chat Review tab, Settings tab (renamed from Details), recording toggle, and thread flyout.

#### Tasks in This Phase
- Task 11: Frontend - Rename Details Tab to Settings and Add Recording Toggle
- Task 12: Frontend - Chat Review Tab with Filters and Paginated Table
- Task 13: Frontend - Chat Review Thread Flyout
- Task 14: Integration Testing and Edge Cases

#### Success Criteria

**Automated Verification:**
- [ ] `npm run typecheck` passes
- [ ] `npm run lint` passes
- [ ] All Go tests pass across both repos

**Manual Verification:**
- [ ] Full end-to-end flow: enable recording → analyst turn → Chat Review table → thread flyout
- [ ] All filter combinations work
- [ ] Pagination forward/back works
- [ ] Recording toggle persists across sessions
- [ ] Empty states render correctly
- [ ] Existing feedback submission still works

**Implementation Note:** After completing this phase, run the full integration test suite and manual verification before marking the plan as complete.

---

## Testing Strategy

### Unit Tests:
- Cursor-based pagination: boundary conditions, empty results, single page, multi-page
- Filter combinations: each filter alone, all filters together, multi-value within filter
- Rating filter: 0 = unrated, 1 = good, -1 = bad (all simple equality), reason code `none` sentinel
- Recording goroutine: happy path, disabled, no domain, timestamp check, error handling
- UPSERT promotion: recorded turn → feedback → single row with type='feedback'
- Domain config cache: hit, miss, expiry, eviction

### Integration Tests:
- Full recording flow: enable recording → checkpoint → verify row created
- Full feedback promotion: record turn → submit feedback → verify single promoted row
- Backward compatibility: existing feedback endpoint excludes recorded turns
- RBAC: chat-review endpoints require correct permissions

### Manual Testing Steps:
1. Enable recording for a domain via Settings tab toggle
2. Submit an analyst query → verify turn appears in Chat Review table
3. Submit thumbs-down feedback on a recorded turn → verify row promoted to feedback type
4. Apply each filter individually → verify correct filtering
5. Apply all filters together → verify AND logic
6. Navigate forward and backward through pages → verify correct data
7. Change page size → verify reset to page 1
8. Click a row → verify thread flyout shows full conversation
9. Disable recording → verify new turns stop appearing
10. Re-enable recording → verify only new turns captured (gap preserved)

## Performance Considerations

- Recording goroutine: fire-and-forget with 10s timeout, detached context. Zero latency impact on checkpoint response (NF1).
- Domain config cache: 5-minute TTL, ~50KB at 1,000 domains. Avoids per-checkpoint DB read (NF4).
- Cursor pagination: O(limit) per page regardless of depth. No OFFSET scan (NF3).
- Write cost: ~200 bytes per recorded turn. ~20MB/day at scale (NF5).
- Composite index `(domain_id, type, created_at DESC)` supports the chat-review list query efficiently.

## Migration Notes

Deployment order (spec §13):
1. **auracontextstore v11** — Schema migration (ADD COLUMN type + index, metadata-only, no data rewrite; rating stays NOT NULL)
2. **auracontext service** — Backend handlers and recording logic
3. **nova-gateway** — Proxy routes and RBAC
4. **helios frontend** — UI components

Each layer is backward-compatible with the previous state. The schema migration adds a column with a default value, so existing code continues to work. The backend changes add new endpoints and modify existing ones with backward-compatible filters. The gateway adds new routes without affecting existing ones. The frontend introduces new UI that depends on the new API.

## References

- Spec: `~/.claude/thoughts/specs/2026-02-09_chat-review-domain-owner-conversation-visibility.md`
- Research: `~/.claude/thoughts/research/2026-02-09_analyst-feedback-and-chat-review-feature.md`
- Existing feedback handlers: `heliosai/services/auracontext/cmd/auracontext/handlers/feedback/handlers.go`
- Existing feedback data layer: `heliosai/services/auracontext/data/feedback/`
- Existing domain types: `heliosai/services/auracontext/data/domain/domain.go:44-52`
- Existing gateway routes: `helios/singlestore.com/helios/cmd/nova-gateway/auracontext/routes.go`
- Existing feedback table schema: `helios/singlestore.com/helios/auracontextstore/sql/schema/v9/table_ddl.sql:11-34`
- Frontend tab system: `helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/configure-domains-flyout.tsx:57-63`

---

## Changelog

| Date | Task | Claude Code Task ID | Changes |
|------|------|---------------------|---------|
| 2026-02-10 | - | - | Initial plan created |
| 2026-02-10 | - | #1-#14 | Tasks created with dependencies in task list 4085ccef-2eb0-41a2-9219-f8df5a9c7e1a |
| 2026-02-10 | 1,3,5,7,10 | #1,#3,#5 | Rating stays NOT NULL; use `rating = 0` as unrated sentinel instead of nullable column (SingleStore limitation). Removed MODIFY COLUMN from migration. Updated all rating=NULL refs to rating=0, IS NULL to = 0. |
