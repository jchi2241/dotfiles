---
type: research
title: Analyst Feedback Feature & Chat Review - Full Stack Analysis
project: helios, heliosai
area: frontend/intelligence, cmd/nova-gateway, auracontext service, auracontextstore
tags: [feedback, chat-review, domain-configuration, recording, pagination, analyst, aura-context]
date: 2026-02-09
status: complete
related_plans: []
---

# Analyst Feedback Feature - Full Stack Research

## 1. Overview

The Analyst Feedback feature allows end-users to rate analyst responses (thumbs up/down) and optionally provide a reason code and comment for negative ratings. Domain owners can view all feedback for their domain and drill into the full conversation thread for each feedback entry. The feature spans four layers: the Helios frontend, Nova Gateway (reverse proxy with RBAC), Aura Context Service (business logic), and Aura Context Store (SingleStore database).

A **"Feedback" tab already exists** in the domain configuration flyout (`configure-domains-flyout.tsx`), with a full implementation including feedback listing, filtering, and a thread drill-down flyout. Feedback is also submitted at the **response level** (inline thumbs up/down on each assistant message). There is **no "recording" concept** today; no domain setting controls whether turns are captured.

---

## 2. Key Components

### 2.1 Frontend (Helios)

**Base path:** `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/`

| File | Purpose |
|------|---------|
| `api/domains.ts:43-53` | `Domain` type definition (id, name, description, projectID, status, etc.) |
| `api/feedback.ts:22-70` | Feedback types: `Feedback`, `FeedbackFilters`, `FeedbackListResponse`, `FeedbackThreadResponse`, `ReasonCode`, `FEEDBACK_RATING`, `FEEDBACK_SENTIMENT` |
| `api/feedback.ts:89-236` | Feedback API functions: `submitFeedbackAPI`, `useListFeedback`, `getFeedbackThreadAPI`, `useGetReasonCodes` |
| `api/domains.ts:111-266` | Domain API functions: `useListDomains`, `useGetDomain`, `createDomainAPI`, `updateDomainAPI`, `deleteDomainAPI` |
| `api/routes.ts:130-147` | Route definitions: `submitFeedback`, `listFeedback`, `getFeedbackThread`, `getReasonCodes` |
| `api/conversations.ts:65-76` | `SessionMessagesResponse` type (title, messages, follow_up_suggestions, latest_settings) |
| `components/response-feedback/response-feedback.tsx` | `ResponseFeedback` component - thumbs up/down UI on each response |
| `components/response-feedback/feedback-reason-selector.tsx` | `FeedbackReasonSelector` - reason code picker + comment for negative feedback |
| `components/response-feedback-details/response-feedback-details.tsx` | `ResponseFeedbackDetails` - alternative card-based reason UI |
| `components/response-actions/response-actions.tsx` | `ResponseActions` - renders feedback alongside copy/regenerate buttons |
| `components/intelligence-response/intelligence-response.tsx` | `IntelligenceResponse` - passes feedback to ResponseActions |
| `context/intelligence-context.tsx:83-89` | `OnResponseFeedbackProps` type and `onResponseFeedback` callback |
| `components/configure-domains-flyout/configure-domains-flyout.tsx` | Domain configuration flyout with tab system |
| `components/configure-domains-flyout/details-tab.tsx` | "Details" tab - domain name, description, delete |
| `components/configure-domains-flyout/feedback-tab/feedback-tab.tsx` | "Feedback" tab - lists domain feedback with filters |
| `components/configure-domains-flyout/feedback-tab/feedback-list.tsx` | Feedback list component |
| `components/configure-domains-flyout/feedback-tab/feedback-filter-select.tsx` | Feedback filter dropdown |
| `components/configure-domains-flyout/feedback-tab/feedback-metadata-card.tsx` | Feedback entry card display |
| `components/configure-domains-flyout/feedback-tab/feedback-thread-flyout.tsx` | Thread drill-down flyout for viewing full conversation |

**Domain Configuration Flyout Tabs** (`configure-domains-flyout.tsx:57-63, 249-373`):

```typescript
type TabID =
    | "data"
    | "insights"
    | "access-controls"
    | "feedback"
    | "api-keys"
    | "details";
```

Current tabs (in order):
1. **Data** (`"data"`) - Domain tables and relationships
2. **Context** (`"insights"`) - Domain instructions and learned context
3. **Access Controls** (`"access-controls"`) - User/team permissions
4. **Feedback** (`"feedback"`) - Domain feedback listing, filtering, and thread drill-down
5. **API Keys** (`"api-keys"`) - Conditional, behind `AnalystEmbedAPI` feature flag
6. **Details** (`"details"`) - Domain name, description, delete

The tab list is built in `DomainsTabsView` (line 249). The tab titles are constructed in a `useMemo` (line 261). The API Keys tab is conditionally pushed (line 268-280). The Details tab is always appended last (line 281).

**Domain Type** (`domains.ts:43-53`):

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
};
```

No `recording` or `chatReviewEnabled` field exists today.

**Frontend Feedback Data Flow:**
```
User sees response (IntelligenceResponse)
  -> ResponseActions rendered
  -> ResponseFeedback shows thumbs up/down
  -> User clicks thumbs up -> submitFeedback with rating: 1
  -> User clicks thumbs down -> FeedbackReasonSelector opens
  -> User selects reason + optional comment -> submitFeedback with rating: -1
  -> POST /auracontext/v1/.../domains/:domainID/feedback
  -> Toast: "Thank you for your feedback!"
```

**Frontend API Architecture:** Routes are defined in `api/routes.ts` as the `INTELLIGENCE_ROUTES` object (route path + HTTP method). Each domain area has its own API file (`api/domains.ts`, `api/feedback.ts`) that defines types, fetch functions, and React hooks directly. Hooks use `useAuraContextFetch` (for domain-scoped OBO calls) or `useSafeFetch` (for general calls). Adding a new endpoint requires: (1) a route entry in `routes.ts`, (2) types and a fetch function/hook in the relevant API file.

---

### 2.2 Nova Gateway

**Base path:** `/home/jchi/projects/helios/singlestore.com/helios/cmd/nova-gateway/auracontext/`

| File | Purpose |
|------|---------|
| `routes.go` | All route registrations |
| `handlers/feedbackhandler.go` | Feedback proxy handlers with RBAC |
| `handlers/feedbackhandler_test.go` | Comprehensive test suite |
| `handlers/domainshandler.go` | Domain CRUD proxy handlers with RBAC |
| `handlers/statesvc_interface.go` | StateService interface for RBAC |
| `middleware/auth.go` | JWT auth middleware |
| `constants/constants.go` | Path variable constants |

**Feedback Routes** (`routes.go:65-67, 126`):

```
POST  /v1/organizations/{orgID}/projects/{projectID}/domains/{domainID}/feedback
GET   /v1/organizations/{orgID}/projects/{projectID}/domains/{domainID}/feedback
GET   /v1/organizations/{orgID}/projects/{projectID}/domains/{domainID}/feedback/{feedbackID}/thread
GET   /v1/feedback-reasons  (unscoped)
```

**Feedback Proxy Handlers** (`feedbackhandler.go`):

| Handler | Lines | Auth |
|---------|-------|------|
| `ProxySubmitFeedback` | 25-34 | OBO token passthrough |
| `ProxyListFeedback` | 43-98 | If `session_id` param: user's own (adds `user_id`); otherwise requires `AgentDomainViewFeedback` (to be renamed `AgentDomainReviewConversations`) |
| `ProxyGetFeedbackThread` | 104-147 | Requires `AgentDomainViewUserConversations` |
| `ProxyGetFeedbackReasons` | 153-161 | Public, no auth |

**RBAC helper** (`feedbackhandler.go:163-190`):
`checkDomainPermission()` calls `stateSvc.QueryAgentDomains()` and checks if the required action exists in `GrantedActions`.

**Relevant RBAC Actions:**
- `AgentDomainViewFeedback` → **renaming to `AgentDomainReviewConversations`** - List all feedback (and recorded turns) for domain
- `AgentDomainViewUserConversations` - View full conversation threads
- `AgentDomainUpdate` - Update domain settings (used by `ProxyUpdateDomain`)

**Domain Update Route** (`routes.go:58`):
```
PUT /v1/organizations/{orgID}/projects/{projectID}/domains/{domainID}
```
Handled by `ProxyUpdateDomain` (`domainshandler.go:363`). Performs RBAC check via `stateSvc.UpdateAgentDomain()`, then proxies to upstream.

**Middleware Chain** (applied to all routes):
1. `LogTraceMiddleware` - OpenTelemetry tracing
2. `CorsMiddleware` - CORS headers
3. `ValidateAndSanitizePath` - Path param validation
4. `Authorize` - JWT validation and claims extraction

---

### 2.3 Aura Context Service

**Base path:** `/home/jchi/projects/heliosai/services/auracontext/`

#### Feedback Handlers

| File | Purpose |
|------|---------|
| `cmd/auracontext/handlers/feedback/handlers.go` | HTTP handlers (SubmitFeedback, ListFeedback, GetFeedbackThread, GetReasonCodes) |
| `cmd/auracontext/handlers/feedback/helpers.go` | Helper functions (thread retrieval, question preview extraction) |
| `cmd/auracontext/handlers/feedback/types.go` | Request/response DTOs |

**Handler Methods** (`handlers.go`):

| Handler | Lines | Description |
|---------|-------|-------------|
| `SubmitFeedback` | 170-245 | Validates, derives session from checkpoint, generates deterministic ID, upserts |
| `ListFeedback` | 248-331 | Parses query params, applies filters, returns paginated list |
| `GetFeedbackThread` | 334-390 | Gets feedback + full conversation thread from checkpoint blobs |
| `GetReasonCodes` | 393-407 | Returns predefined reason codes |

**ListFeedback query parameters** (`handlers.go:248-331`):
- `session_id` (string)
- `user_id` (string)
- `rating` (int: 1 or -1)
- `reason_code` (string)
- `start_date` (RFC3339)
- `end_date` (RFC3339)
- `limit` (int, default: 100, max: 1000)
- `offset` (int, default: 0)

**ListFeedback response** (`types.go:57-59`):
```go
type ListFeedbackResponse struct {
    Feedback []FeedbackResponse `json:"feedback"`
}
```
Note: The response does **not** include a `total_count` field. The frontend has no way to know the total number of results for pagination without an additional API call.

**SubmitFeedback flow** (`handlers.go:170-245`):
1. Parse + validate request body
2. Get `thread_id` from checkpoint via DB lookup (`helpers.go:55-74`)
3. Get `domain_id` from session via DB lookup (`helpers.go:78-101`)
4. Verify session belongs to requested domain
5. Extract question preview from thread (truncated to 150 chars) (`helpers.go:169-205`)
6. Generate deterministic feedback ID: `SHA256(checkpoint_id + ":" + session_id)`
7. Upsert feedback record

**Request Context** (`handlers.go:30-37`):
```go
type RequestContext struct {
    OrgID     uuid.UUID
    ProjectID uuid.UUID
    DomainID  uuid.UUID
    UserID    string
    DB        *s2.DB
    OBOClaims *auth.OBOClaims
}
```

#### Domain Handlers

| File | Purpose |
|------|---------|
| `cmd/auracontext/handlers/domains/handler.go` | Domain CRUD handlers |
| `cmd/auracontext/handlers/domains/types.go` | Request/response DTOs for domains |

**UpdateDomain handler** (`handler.go:259-318`):
- Accepts: `name`, `description`, `state` (all optional)
- Validates input, checks uniqueness, applies changes, saves to DB

**UpdateDomainRequest** (`types.go:58-62`):
```go
type UpdateDomainRequest struct {
    Name        *string `json:"name"`
    Description *string `json:"description"`
    State       *string `json:"state"`
}
```

**DomainResponse** (`types.go:185-196`):
```go
type DomainResponse struct {
    ID          uuid.UUID         `json:"id"`
    Name        string            `json:"name"`
    Description *string           `json:"description"`
    ProjectID   uuid.UUID         `json:"project_id"`
    CreatedBy   uuid.UUID         `json:"created_by"`
    UpdatedBy   *uuid.UUID        `json:"updated_by"`
    CreatedAt   time.Time         `json:"created_at"`
    UpdatedAt   time.Time         `json:"updated_at"`
    Status      DomainStatusInfo  `json:"status"`
    Tables      []DomainTableInfo `json:"tables"`
}
```

**Service initialization** (`cmd/auracontext/main.go:211-226`):
```go
feedbackHandler := feedback.NewFeedbackHandler(logger, connections, jwtHandler, opts.UseDomainIDInToken)
router.PathPrefix(commonPrefix + "/domains/{domain_id}/feedback").Handler(feedbackHandler.Handler())
router.PathPrefix("/v1/feedback-reasons").Handler(feedbackHandler.Handler())
```

---

### 2.4 Aura Context Store (Database)

**Base path:** `/home/jchi/projects/helios/singlestore.com/helios/auracontextstore/sql/schema/`

Schema migrations are versioned directories: `v1/` through `v10/`. Currently at v10.

#### Database Schema

**Domains table** (`v1/table_ddl.sql:31-45`):
```sql
CREATE TABLE IF NOT EXISTS domains (
    id VARCHAR(36) NOT NULL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    projectid VARCHAR(36) NOT NULL,
    config JSON NOT NULL DEFAULT '{}',
    createdby VARCHAR(36) NOT NULL,
    updatedby VARCHAR(36) NOT NULL,
    createdat TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updatedat TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deletedat TIMESTAMP NULL,
    INDEX idx_projectid (projectid),
    INDEX idx_deletedat (deletedat),
    INDEX idx_domain_name_project (projectid, name, deletedat)
);
```

The `config` column is a JSON field storing `DomainConfig` (currently only holds table configs). This is a potential place to store a `recording_enabled` setting.

**Sessions table** (`v1/table_ddl.sql:51-58` + `v7/alter_ddl.sql`):
```sql
CREATE TABLE IF NOT EXISTS sessions (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    title TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW() ON UPDATE NOW(),
    domain_id VARCHAR(36) NULL,  -- Added in v7
    INDEX idx_user_id_updated_at (user_id, updated_at DESC),
    INDEX idx_sessions_domain_id_updated_at (domain_id, updated_at DESC)
);
```

The `domain_id` column (v7 migration) binds sessions to domains. NULL means legacy session.

**Checkpoints table** (`v1/table_ddl.sql:62-72`):
```sql
CREATE TABLE IF NOT EXISTS checkpoints (
    thread_id TEXT NOT NULL,
    checkpoint_ns TEXT NOT NULL DEFAULT '',
    checkpoint_id TEXT NOT NULL,
    parent_checkpoint_id TEXT,
    type TEXT,
    checkpoint JSON NOT NULL,
    metadata JSON NOT NULL DEFAULT '{}',
    PRIMARY KEY (thread_id, checkpoint_ns, checkpoint_id)
);
```

**Checkpoint blobs table** (`v1/table_ddl.sql:76-85`):
```sql
CREATE TABLE IF NOT EXISTS checkpoint_blobs (
    thread_id TEXT NOT NULL,
    checkpoint_ns TEXT NOT NULL DEFAULT '',
    channel TEXT NOT NULL,
    version TEXT NOT NULL,
    type TEXT NOT NULL,
    blob LONGBLOB NULL,
    PRIMARY KEY (thread_id, checkpoint_ns, channel, version)
);
```

**Feedback table** (`v9/table_ddl.sql:11-34`):
```sql
CREATE TABLE IF NOT EXISTS feedback (
    id VARCHAR(64) NOT NULL PRIMARY KEY,
    domain_id VARCHAR(36) NOT NULL,
    session_id VARCHAR(36) NOT NULL,
    checkpoint_id VARCHAR(64) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    rating TINYINT NOT NULL,          -- 1=thumbs_up, -1=thumbs_down
    reason_code VARCHAR(64) NULL,
    comment TEXT NULL,
    question_preview VARCHAR(200) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    SORT KEY (created_at DESC),
    INDEX idx_feedback_domain_rating (domain_id, rating, created_at DESC),
    INDEX idx_feedback_session (session_id),
    INDEX idx_feedback_checkpoint (checkpoint_id, session_id)
);
```

**Shared Chat table** (`v10/table_ddl.sql:5-12`):
```sql
CREATE TABLE IF NOT EXISTS shared_chat (
    session_id VARCHAR(36) NOT NULL PRIMARY KEY,
    checkpoint_id VARCHAR(36) NOT NULL,
    creator_id VARCHAR(36) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL
);
```

#### Data Access Layer

**Base path:** `/home/jchi/projects/heliosai/services/auracontext/data/`

| File | Purpose |
|------|---------|
| `feedback/feedback.go` | CRUD operations (GetFeedback, UpsertFeedback, ListFeedback, ListFeedbackByDomain, CountFeedback, DeleteFeedback) |
| `feedback/types.go` | Data models (Feedback struct, UpsertFeedbackParams, ListFeedbackParams, rating constants, reason codes) |
| `feedback/filter.go` | Query filter builder pattern |
| `feedback/id.go` | Deterministic ID generation: `SHA256(checkpoint_id + ":" + session_id)` |
| `feedback/db.go` | Database wrapper |
| `domain/domain.go` | Domain CRUD (QueryDomain, GetDomain, CreateDomain, UpdateDomain, DeleteDomain) |

**Domain Go model** (`domain/domain.go:94-106`):
```go
type Domain struct {
    ID          uuid.UUID    `json:"id"`
    Name        string       `json:"name"`
    Description *string      `json:"description,omitempty"`
    ProjectID   uuid.UUID    `json:"projectID"`
    Config      DomainConfig `json:"config"`
    Status      DomainStatus `json:"status,omitempty"`
    CreatedBy   uuid.UUID    `json:"createdBy"`
    CreatedAt   time.Time    `json:"createdAt"`
    UpdatedAt   time.Time    `json:"updatedAt"`
    UpdatedBy   *uuid.UUID   `json:"updatedBy,omitempty"`
    DeletedAt   *time.Time   `json:"deletedAt,omitempty"`
}
```

**DomainConfig** (`domain/domain.go:44-52`):
```go
type DomainConfigData struct {
    Tables []DomainTableConfig `json:"tables,omitempty"`
}

type DomainConfig struct {
    Data *DomainConfigData `json:"data,omitempty"`
}
```

`DomainConfig` is serialized to/from the JSON `config` column. It currently only stores table configurations. New domain-level settings can be added here.

**Feedback data model** (`feedback/types.go`):
```go
type Feedback struct {
    ID              string
    DomainID        string
    SessionID       string
    CheckpointID    string
    UserID          string
    Rating          int       // 1 or -1
    ReasonCode      *string
    Comment         *string
    QuestionPreview string
    CreatedAt       time.Time
    UpdatedAt       time.Time
}
```

**Reason codes** (`feedback/types.go`):
- `values_look_off` - "Values look off"
- `missing_data` - "Missing data"
- `misunderstood_question` - "Misunderstood question"
- `made_something_up` - "Analyst made something up"
- `other` - "Other"

**ListFeedbackByDomain** (`feedback/feedback.go:214-253`):
```go
type ListFeedbackParams struct {
    DomainID   string
    SessionID  *string
    UserID     *string
    Rating     *string
    ReasonCode *string
    StartDate  *time.Time
    EndDate    *time.Time
    Limit      int
    Offset     int
}
```

**Filter builder** (`feedback/filter.go`): Provides composable filters for `ListFeedback()`:
- `ByID`, `ByDomainID`, `BySessionID`, `ByCheckpointID`, `ByUserID`, `ByRating`, `ByReasonCode`
- `ByDateRange`, `ByStartDate`, `ByEndDate`
- `OrderByCreatedDesc`, `OrderByCreatedAsc`
- `WithLimit`, `WithOffset`

---

## 3. Data Flow

### 3.1 Feedback Submission Flow

```
Frontend (ResponseFeedback component)
  -> POST /auracontext/v1/organizations/{org}/projects/{proj}/domains/{domain}/feedback
  -> Nova Gateway (ProxySubmitFeedback) -- passthrough with OBO auth
  -> Aura Context Service (SubmitFeedback handler)
     -> Lookup thread_id from checkpoints table
     -> Lookup domain_id from sessions table
     -> Verify session belongs to domain
     -> Extract question_preview from checkpoint blob (150 char truncation)
     -> Generate deterministic ID: SHA256(checkpoint_id:session_id)
     -> UPSERT into feedback table
  -> Response: { results: { feedback: FeedbackResponse } }
```

### 3.2 Feedback Listing Flow (Domain Owner)

```
Frontend (FeedbackTab in configure-domains-flyout)
  -> GET /auracontext/v1/.../domains/{domain}/feedback?rating=&reason_code=&start_date=&end_date=&limit=&offset=
  -> Nova Gateway (ProxyListFeedback)
     -> No session_id param -> RBAC check: AgentDomainReviewConversations (renamed from AgentDomainViewFeedback)
  -> Aura Context Service (ListFeedback handler)
     -> Parse query params
     -> Build filters
     -> Query feedback table with filters
  -> Response: { results: { feedback: [...] } }
```

### 3.3 Feedback Thread Flow (Domain Owner)

```
Frontend (FeedbackThreadFlyout)
  -> GET /auracontext/v1/.../domains/{domain}/feedback/{feedbackID}/thread
  -> Nova Gateway (ProxyGetFeedbackThread)
     -> RBAC check: AgentDomainViewUserConversations
  -> Aura Context Service (GetFeedbackThread handler)
     -> Get feedback by ID
     -> Verify feedback belongs to domain
     -> Verify session belongs to domain
     -> Retrieve checkpoint blob data
     -> Decode msgpack -> APIResponse
  -> Response: { results: { feedback: {...}, thread: {...} } }
```

---

## 4. API Contracts

### 4.1 Existing Endpoints

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/auracontext/v1/.../domains/:domainID/feedback` | OBO-domain | Submit/update feedback |
| GET | `/auracontext/v1/.../domains/:domainID/feedback` | OBO-domain + RBAC | List feedback with filters |
| GET | `/auracontext/v1/.../domains/:domainID/feedback/:feedbackID/thread` | OBO-domain + RBAC | Get feedback + conversation thread |
| GET | `/auracontext/v1/feedback-reasons` | Bearer-only | Get reason code list |
| PUT | `/auracontext/v1/.../domains/:domainID` | OBO-domain + RBAC | Update domain (name, description, state) |
| GET | `/auracontext/v1/.../domains/:domainID` | OBO-domain | Get domain details |

### 4.2 SubmitFeedback Request/Response

**Request:**
```json
{
    "checkpoint_id": "string",
    "rating": 1,
    "reason_code": "values_look_off",
    "comment": "optional text"
}
```

**Response:**
```json
{
    "results": {
        "feedback": {
            "id": "sha256-hex",
            "domainID": "uuid",
            "sessionID": "uuid",
            "checkpointID": "string",
            "userID": "uuid",
            "rating": 1,
            "reasonCode": null,
            "comment": null,
            "questionPreview": "What is the total...",
            "createdAt": "2026-02-09T...",
            "updatedAt": "2026-02-09T..."
        }
    }
}
```

### 4.3 ListFeedback Response

```json
{
    "results": {
        "feedback": [
            {
                "id": "...",
                "domainID": "...",
                "sessionID": "...",
                "checkpointID": "...",
                "userID": "...",
                "rating": -1,
                "reasonCode": "missing_data",
                "comment": "Some data was wrong",
                "questionPreview": "Show me all...",
                "createdAt": "...",
                "updatedAt": "..."
            }
        ]
    }
}
```

**No `totalCount` field.** Pagination relies on limit/offset without knowing total.

### 4.4 UpdateDomain Request/Response

**Request:**
```json
{
    "name": "My Domain",
    "description": "Updated description",
    "state": "ready"
}
```

All fields optional.

---

## 5. Dependencies

### 5.1 What Feedback Depends On

- **Checkpoints table** - To derive `thread_id` and retrieve conversation blobs
- **Sessions table** - To verify domain ownership and get `domain_id`
- **Domains** - Feedback is scoped to a domain
- **OBO Auth** - On-behalf-of tokens for domain-scoped API calls
- **State Service** - RBAC permission checks in Nova Gateway
- **Squirrel query builder** - For composable SQL queries in data layer

### 5.2 What Depends on Feedback

- **ResponseFeedback component** - Inline thumbs up/down on each response
- **FeedbackReasonSelector** - Reason picker for negative feedback
- **Intelligence context** - `onResponseFeedback` callback
- **FeedbackTab** - Domain configuration flyout tab listing all feedback with filters
- **FeedbackThreadFlyout** - Drill-down view showing full conversation for a feedback entry

---

## 6. Configuration

### 6.1 Feature Flags

- `FeatureFlagID.AnalystEmbedAPI` - Controls whether "API Keys" tab appears in domain config flyout. Could be used as a pattern for a new feature flag.

### 6.2 Environment Variables

- `AuraContextServiceURL` - Upstream service URL used by Nova Gateway (default: `http://aura-context-svc.fission.svc.cluster.local:8080`)

### 6.3 Domain Config (JSON column)

The `domains.config` JSON column currently stores:
```json
{
    "data": {
        "tables": [...]
    }
}
```

This is a flexible JSON structure that can be extended with new settings (e.g., `recording_enabled`, `recording_started_at`).

---

## 7. Code References - Quick Lookup

### Frontend
- Tab system: `configure-domains-flyout.tsx:57-63` (TabID type), `249-373` (DomainsTabsView)
- Details tab: `details-tab.tsx:42-47`
- Feedback tab: `feedback-tab/feedback-tab.tsx`
- Feedback list: `feedback-tab/feedback-list.tsx`
- Feedback thread flyout: `feedback-tab/feedback-thread-flyout.tsx`
- Domain type: `domains.ts:43-53`
- Feedback types: `feedback.ts:22-70`
- Feedback API functions: `feedback.ts:89-236`
- Domain API functions: `domains.ts:111-266`
- Route definitions: `routes.ts:130-147` (feedback routes)
- Response feedback component: `response-feedback.tsx:1-215`
- Reason selector: `feedback-reason-selector.tsx:1-118`

### Nova Gateway
- All routes: `routes.go:1-129`
- Feedback handlers: `feedbackhandler.go:25-190`
- Domain update handler: `domainshandler.go:363`
- RBAC check helper: `feedbackhandler.go:163-190`
- Constants: `constants/constants.go`

### Aura Context Service
- Feedback handlers: `handlers/feedback/handlers.go:170-407`
- Feedback helpers: `handlers/feedback/helpers.go:21-205`
- Feedback types: `handlers/feedback/types.go:1-99`
- Domain handler (UpdateDomain): `handlers/domains/handler.go:259-318`
- Domain types (UpdateDomainRequest): `handlers/domains/types.go:58-94`
- Service init: `cmd/auracontext/main.go:211-226`

### Aura Context Store (Data Layer)
- Feedback CRUD: `data/feedback/feedback.go:48-253`
- Feedback types: `data/feedback/types.go:1-126`
- Feedback filters: `data/feedback/filter.go:1-127`
- Feedback ID generation: `data/feedback/id.go:1-16`
- Feedback tests: `data/feedback/feedback_test.go:1-505`
- Domain model: `data/domain/domain.go:94-106`
- DomainConfig model: `data/domain/domain.go:44-52`
- Domain CRUD: `data/domain/domain.go:123-258`

### Database Schema
- Domains table: `v1/table_ddl.sql:31-45`
- Sessions table: `v1/table_ddl.sql:51-58`
- Sessions domain_id migration: `v7/alter_ddl.sql`
- Checkpoints table: `v1/table_ddl.sql:62-72`
- Checkpoint blobs table: `v1/table_ddl.sql:76-85`
- Feedback table: `v9/table_ddl.sql:11-34`
- Shared chat table: `v10/table_ddl.sql:5-12`
- Schema versions: `v1/` through `v10/` (next migration would be `v11/`)

---

## 8. Patterns and Conventions

### 8.1 Adding a New API Endpoint (Frontend)

1. Add a route entry to `INTELLIGENCE_ROUTES` in `api/routes.ts` (route path + HTTP method)
2. Add types and a fetch function or React hook in the relevant API file (e.g., `api/feedback.ts`, `api/domains.ts`)
3. Hooks use `useAuraContextFetch` for domain-scoped OBO calls or `useSafeFetch` for general calls

### 8.2 Adding a New Gateway Route

1. Add handler function in `handlers/` directory
2. Register in `routes.go` with appropriate HTTP method and path
3. Apply RBAC checks as needed using `checkDomainPermission()`

### 8.3 Database Migrations

Create a new versioned directory (e.g., `v11/`) with `alter_ddl.sql` or `table_ddl.sql`.

### 8.4 Response Envelope

All API responses follow: `{ "results": { ...data } }` or `{ "error": { "code": "...", "message": "..." } }`

### 8.5 JSON Response Field Naming

- Backend Go structs use `camelCase` JSON tags (e.g., `domainID`, `sessionID`, `checkpointID`, `questionPreview`)
- Domain handler uses `snake_case` (e.g., `project_id`, `created_by`, `updated_by`)
- Inconsistency exists between handlers - feedback uses camelCase, domains use snake_case
