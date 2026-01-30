# Feedback Threads Endpoint Research Report

**Date:** January 28, 2026  
**Scope:** Implementing `.../feedback/{id}/threads` endpoint in AuraContext service  
**Focus:** RBAC, Security, and Integration with existing feedback infrastructure

---

## Executive Summary

The feedback threads endpoint (`GET /v1/organizations/{org_id}/projects/{project_id}/domains/{domain_id}/feedback/{feedback_id}/thread`) is partially implemented in AuraContext but requires completion of the thread retrieval logic. The endpoint already has robust RBAC and security checks in place via Nova Gateway proxy, but the backend needs to query checkpoints to reconstruct the full conversation thread associated with a feedback record.

**Key Finding:** Thread retrieval is marked as TODO in the handler - it needs to query the checkpoints table using the session_id and checkpoint_id from the feedback record.

---

## 1. Frontend Integration: How FeedbackTab Expects to Use Threads

### FeedbackThreadFlyout Component
**Location:** `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-thread-flyout.tsx`

The frontend component expects threads to be retrieved and displayed as a conversation history.

#### API Usage Pattern:
```typescript
// Retrieves full thread for a feedback record
const response = await getFeedbackThreadAPI({
    token,
    oboToken,
    novaGatewayURL,
    domainID,
    feedbackID: feedback.id,
    params: { orgID, projectID },
});

// Response contains thread data
if (response.data?.results?.thread) {
    const messages = transformSessionMessages(
        response.data.results.thread as SessionMessagesResponse
    );
    setThread(messages);
}
```

#### Expected Response Structure:
```typescript
type FeedbackThreadResponse = {
    feedback: Feedback;
    thread: SessionMessagesResponse;  // Array of conversation messages
};
```

#### Thread Display:
- Displays feedback metadata: rating, reason, comment, date
- Highlights the specific assistant message that was rated (by checkpoint_id match)
- Shows full conversation context (all messages before and after the rated response)
- Highlights rated message with border color based on feedback rating (positive=green, negative=red)

#### Key Requirements:
1. Thread must include ALL messages in the session up to and including the rated checkpoint
2. Each message must have `role` ("user" or "assistant") and `checkpointID`
3. Must transform `checkpointID` to match feedback's `checkpointID` for highlighting
4. Must support `transformSessionMessages()` conversion to ChatHistory format

---

## 2. Existing Feedback Infrastructure in AuraContext

### Data Models

#### Feedback Table Schema
**Location:** `/home/jchi/projects/heliosai/services/auracontext/data/feedback/`

```go
type Feedback struct {
    ID           string     // SHA-256 hash of checkpoint_id:user_id:session_id
    DomainID     string
    SessionID    string     // Links to sessions table
    CheckpointID string     // Specific checkpoint being rated
    UserID       string
    Rating       int        // 1 (thumbs up) or -1 (thumbs down)
    ReasonCode   *string    // Predefined codes: values_look_off, missing_data, etc.
    Comment      *string
    CreatedAt    time.Time
    UpdatedAt    time.Time
}

type ReasonCode string

const (
    ReasonCodeValuesLookOff        = "values_look_off"
    ReasonCodeMissingData          = "missing_data"
    ReasonCodeMisunderstoodQuestion = "misunderstood_question"
    ReasonCodeMadeSomethingUp      = "made_something_up"
    ReasonCodeOther                = "other"
)
```

**Key Characteristics:**
- Deterministic ID: SHA-256 hash enables natural UPSERT via primary key
- Links to sessions via session_id
- Each feedback references a specific checkpoint_id (the response being rated)
- Supports rating and optional reason/comment

#### Related Tables:
1. **sessions table** - stores conversation sessions
   - Columns: id, domain_id, user_id, created_at, updated_at
   - Used to validate session belongs to domain

2. **checkpoints table** - stores conversation message history
   - Contains session message data up to that checkpoint
   - Used to reconstruct full thread

### Existing Handlers

#### FeedbackHandler Structure
**Location:** `/home/jchi/projects/heliosai/services/auracontext/cmd/auracontext/handlers/feedback/handlers.go`

```go
type FeedbackHandler struct {
    logger             *zerolog.Logger
    connections        store.ConnectionHandler
    jwtHandler         *auth.JWTHandler
    useDomainIDInToken bool
}

type RequestContext struct {
    OrgID     uuid.UUID
    ProjectID uuid.UUID
    DomainID  uuid.UUID
    UserID    string
    DB        *s2.DB
    OBOClaims *auth.OBOClaims
}
```

#### Implemented Endpoints:

1. **POST /domains/{domain_id}/feedback** - Submit feedback
   - Any domain user can submit
   - Validates session belongs to domain (security check)
   - Generates deterministic feedback ID

2. **GET /domains/{domain_id}/feedback** - List feedback
   - Requires `AgentDomainViewFeedback` permission (checked in Nova Gateway)
   - Supports filtering: session_id, user_id, rating, reason_code, date range
   - Paginated (limit, offset)

3. **GET /domains/{domain_id}/feedback/{feedback_id}/thread** - Get thread
   - **Status:** Partially implemented
   - Requires `AgentDomainViewUserConversations` permission (checked in Nova Gateway)
   - Currently returns feedback + empty thread (TODO)
   - TODO: Implement checkpoints query to retrieve actual thread

4. **GET /feedback-reasons** - Public endpoint
   - Returns all valid reason codes with display names
   - No authentication required

#### SetRequestContext Pattern
**Location:** `/home/jchi/projects/heliosai/services/auracontext/cmd/auracontext/handlers/feedback/handlers.go`

All handlers use a middleware pattern to extract and validate context:

```go
func (h *FeedbackHandler) SetRequestContext(handler func(w http.ResponseWriter, r *http.Request, rc RequestContext)) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        // Extract OBO claims (required)
        oboClaims, err := h.jwtHandler.GetOBOClaimsFromRequest(h.logger, r)
        
        // Extract path parameters: org_id, project_id, domain_id
        orgID, projectID, domainID := extractPathParams(r)
        
        // Validate project matches OBO token
        if oboClaims.LimitToProjectID != projectID {
            // Forbidden
        }
        
        // Validate domain matches OBO token (if enabled)
        if h.useDomainIDInToken && domainID != oboClaims.AgentDomainInfo.AgentDomainID {
            // Forbidden
        }
        
        // Get database connection
        conn, err := h.connections.GetConnection(projectID)
        
        // Set metrics context
        ctx := metrics.SetCtxMetrics(r.Context(), ...)
        
        handler(w, r, RequestContext{...})
    }
}
```

**Security Layers:**
1. OBO claims extraction and validation
2. Project ID validation against OBO token
3. Domain ID validation against OBO token (when enabled)
4. Database connection isolation by project
5. Metrics context setup

---

## 3. RBAC and Security Patterns

### RBAC Implementation

#### Three-Tier RBAC Model:

1. **Nova Gateway (First Line of Defense)**
   - Located: `/home/jchi/projects/helios/singlestore.com/helios/cmd/nova-gateway/auracontext/handlers/feedbackhandler.go`
   - Checks user permissions via State Service BEFORE proxying to AuraContext
   - Uses `checkDomainPermission()` helper

   **ProxyListFeedback Logic:**
   ```go
   if sessionID provided {
       // User querying own feedback for specific session
       // Add user_id to query, AuraContext filters by both session_id AND user_id
   } else {
       // No session filter - requires AgentDomainViewFeedback permission
       hasPermission := checkDomainPermission(authToken, orgID, domainID, 
           graph.AgentDomainActionAgentDomainViewFeedback, stateSvc)
       if !hasPermission {
           return 403 Forbidden
       }
   }
   ```

   **ProxyGetFeedbackThread Logic:**
   ```go
   // ALWAYS requires AgentDomainViewUserConversations permission
   hasPermission := checkDomainPermission(authToken, orgID, domainID,
       graph.AgentDomainActionAgentDomainViewUserConversations, stateSvc)
   if !hasPermission {
       return 403 Forbidden
   }
   ```

   **Permission Functions:**
   - `checkDomainPermission()` - Queries State Service for user's domain actions
   - Validates action against `domains[0].GrantedActions` array
   - Returns false if user has no access to domain at all

2. **AuraContext Token Validation (Second Line of Defense)**
   - OBO token must be present
   - OBO token must contain valid project_id
   - OBO token must contain valid domain_id (if enabled)

3. **AuraContext Data Validation (Third Line of Defense)**
   - Feedback record must belong to the requested domain
   - Session must belong to the requested domain
   - "Defense in depth" - even if feedback record is corrupted

### Authorization Permissions

| Endpoint | Permission | Notes |
|----------|-----------|-------|
| POST /feedback | None (user with OBO token) | Any domain user can rate |
| GET /feedback (no session_id) | AgentDomainViewFeedback | Domain admin/owner |
| GET /feedback (with session_id) | None | Users see only their own |
| GET /feedback/{id}/thread | AgentDomainViewUserConversations | Domain admin only |

### Security Checks in Practice

#### Domain Ownership Verification
**Source:** `/home/jchi/projects/heliosai/services/auracontext/cmd/auracontext/handlers/feedback/handlers.go`

```go
// In SubmitFeedback:
// 1. Verify session belongs to domain
sessionDomainID, err := getSessionDomainID(ctx, db, sessionID)
if *sessionDomainID != rc.DomainID.String() {
    return 403 SESSION_DOMAIN_MISMATCH
}

// In GetFeedbackThread:
// 1. Verify feedback belongs to domain
if feedbackRecord.DomainID != rc.DomainID.String() {
    return 404 FEEDBACK_NOT_FOUND
}

// 2. Defense in depth: Also verify session belongs to domain
sessionDomainID, err := getSessionDomainID(ctx, db, feedbackRecord.SessionID)
if *sessionDomainID != rc.DomainID.String() {
    return 404 THREAD_NOT_FOUND
}
```

#### Session-to-Domain Mapping
```go
func getSessionDomainID(ctx context.Context, db *s2.DB, sessionID string) (*string, error) {
    // Query: SELECT domain_id FROM sessions WHERE id = ?
    // Returns nil if session doesn't exist or has no domain (legacy)
    // This prevents cross-domain session access
}
```

---

## 4. Data Models and Database Integration

### Key Database Relationships

```
feedback record
    ├─ feedback.session_id → sessions.id
    └─ feedback.checkpoint_id → checkpoints.id (within session)

sessions table
    ├─ id (UUID)
    ├─ domain_id (UUID) ← Cross-domain security check
    ├─ user_id
    └─ created_at, updated_at

checkpoints table
    ├─ id (UUID)
    ├─ thread_id (references sessions)
    ├─ checkpoint_id (UUID)
    └─ [message data]
```

### Response DTOs

#### FeedbackResponse (used in list and detail)
```go
type FeedbackResponse struct {
    ID           string    `json:"id"`
    DomainID     string    `json:"domainID"`
    SessionID    string    `json:"sessionID"`
    CheckpointID string    `json:"checkpointID"`
    UserID       string    `json:"userID"`
    Rating       int       `json:"rating"`
    ReasonCode   *string   `json:"reasonCode"`
    Comment      *string   `json:"comment"`
    CreatedAt    time.Time `json:"createdAt"`
    UpdatedAt    time.Time `json:"updatedAt"`
}
```

#### ThreadResponse (for thread endpoint - NEEDS COMPLETION)
```go
type ThreadResponse struct {
    Feedback *FeedbackResponse `json:"feedback"`
    Thread   interface{}       `json:"thread"`  // TODO: Define proper type
}
```

### Filtering Patterns

**ListFeedback Query Support:**
- `session_id` - Get feedback for specific session
- `user_id` - Get feedback from specific user
- `rating` - Filter by positive (1) or negative (-1)
- `reason_code` - Filter by specific reason
- `start_date` / `end_date` - Date range filtering (RFC3339 format)
- `limit` / `offset` - Pagination (limit: 1-1000, default 100)

All filters use Squirrel query builder with flexible filter composition:
```go
filters := []FeedbackFilter{
    db.ByDomainID(params.DomainID),
    db.OrderByCreatedDesc(),
    db.BySessionID(*params.SessionID),      // Optional
    db.ByUserID(*params.UserID),            // Optional
    db.WithLimit(params.Limit),
    db.WithOffset(params.Offset),
}
```

---

## 5. Similar Endpoint Implementations for Reference

### ConversationHandler Pattern
**Location:** `/home/jchi/projects/heliosai/services/auracontext/cmd/auracontext/handlers/conversations/handlers.go`

```go
type ConversationHandler struct {
    logger      *zerolog.Logger
    connHandler store.ConnectionHandler
    jwtHandler  *auth.JWTHandler
}

// SetRequestContext extracts and validates auth
func (c *ConversationHandler) SetRequestContext(handler func(w http.ResponseWriter, r *http.Request, requestContext RequestContext)) http.HandlerFunc {
    // Extract JWT claims (required)
    claims, err := c.jwtHandler.GetUserJWTClaimsFromRequest(logger, r)
    
    // Extract OBO claims (optional, may be analyst flow)
    oboClaims, _ := c.jwtHandler.GetOBOClaimsFromRequest(logger, r)
    
    // Extract and validate path params: user_id, project_id, session_id
    userID := util.ExtractPathParam[uuid.UUID](r, "user_id")
    projectID := util.ExtractPathParam[uuid.UUID](r, "project_id")
    
    // Validate JWT limits (user can only access their own data)
    if userID.String() != claims.UserID && !oboClaims.IsAnalystAPIFlow() {
        return 403 Forbidden
    }
    
    // Get database connection by project
    conn := c.connHandler.GetConnection(projectID)
    
    // Pass context to handler
    handler(w, r, RequestContext{...})
}
```

### CheckpointHandler Pattern
**Location:** `/home/jchi/projects/heliosai/services/auracontext/cmd/auracontext/handlers/checkpoints/handlers.go`

```go
type CheckpointHandler struct {
    logger      *zerolog.Logger
    connHandler store.ConnectionHandler
    jwtHandler  *auth.JWTHandler
}

// SetRequestContext with optional user_id validation
func (c *CheckpointHandler) SetRequestContext(handler func(w http.ResponseWriter, r *http.Request, requestContext RequestContext)) http.HandlerFunc {
    // Similar pattern: extract claims, validate, get connection
    
    // Note: user_id is optional for backward compatibility
    var userID *uuid.UUID
    tmpUserID, err := util.ExtractPathParamWithError[uuid.UUID](r, "user_id")
    if err != nil {
        if !errors.Is(err, util.ErrParamEmpty) {
            return 400 Bad Request
        }
        // Skip user_id check if not provided (legacy s2ai)
    } else {
        // Validate user_id matches claims
        if userID.String() != claims.UserID && !oboClaims.IsAnalystAPIFlow() {
            return 403 Forbidden
        }
    }
    
    // Extract thread_id and checkpoint_id from path
    threadID, _ := util.ExtractPathParamWithError[uuid.UUID](r, "thread_id")
    checkpointID, _ := util.ExtractPathParamWithError[uuid.UUID](r, "checkpoint_id")
}
```

### Key Patterns to Follow:

1. **Middleware Pattern:** All handlers use `SetRequestContext()` middleware
2. **JWT Validation:** Extract and validate JWT claims (user or OBO)
3. **Parameter Validation:** Extract path params with type safety
4. **Permission Checks:** 
   - User can only access their own data (unless analyst flow)
   - Project ID from JWT must match request
5. **Connection Management:** Get database connection by project_id
6. **Metrics:** Set request metrics context for observability
7. **Error Responses:** Use `util.WriteErrorResponse()` with standard error codes

---

## 6. Thread Retrieval Implementation Strategy

### Current TODO in GetFeedbackThread
**Location:** `/home/jchi/projects/heliosai/services/auracontext/cmd/auracontext/handlers/feedback/handlers.go:356`

```go
// TODO: Retrieve the conversation thread from checkpoints table
// For now, we return the feedback with an empty thread
// The thread retrieval will need to query the checkpoints table using feedbackRecord.SessionID
// and return the conversation messages up to feedbackRecord.CheckpointID
```

### Implementation Requirements:

1. **Query Strategy:**
   - Use session_id from feedback record
   - Retrieve all checkpoints for that session (ordered chronologically)
   - Filter to include only checkpoints up to and including the rated checkpoint_id
   - Transform checkpoint data to SessionMessagesResponse format

2. **Data Transformation:**
   - Frontend expects `SessionMessagesResponse` type
   - Must include message role, content, and checkpoint_id
   - Each message needs `checkpointID` for highlighting the rated response

3. **Performance Considerations:**
   - Consider pagination if sessions are long
   - Cache if multiple threads accessed frequently
   - Optimize checkpoint query (indexed on session_id, checkpoint_id)

4. **Security:**
   - Double-verify session belongs to domain (already done)
   - Ensure no cross-domain thread leakage
   - All data already behind OBO token validation

### Response Format Expected:

```typescript
// From frontend API expectation:
type SessionMessagesResponse = Array<{
    role: "user" | "assistant";
    output?: Array<{
        content?: Array<{
            text?: string;
        }>;
    }>;
    checkpointID?: string;
}>;

// Transformed to ChatHistory:
type ChatHistory = Array<{
    role: "user" | "assistant";
    output?: Array<...>;
    checkpointID?: string;
}>;
```

---

## 7. API Routes and Nova Gateway Configuration

### Route Definitions
**Location:** `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/api/routes.ts`

```typescript
INTELLIGENCE_ROUTES = {
    getFeedbackThread(domainID: string, feedbackID: string) {
        return {
            route: `/v1/organizations/{org_id}/projects/{project_id}/domains/${domainID}/feedback/${feedbackID}/thread`,
            method: "GET"
        };
    }
};
```

### Nova Gateway Routing
**Location:** `/home/jchi/projects/helios/singlestore.com/helios/cmd/nova-gateway/auracontext/handlers/feedbackhandler.go`

```go
// GET /v1/organizations/{org_id}/projects/{project_id}/domains/{domain_id}/feedback/{feedback_id}/thread
func ProxyGetFeedbackThread(upstreamURL *url.URL, stateSvc StateServiceClient) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        // 1. Extract auth token and claims
        authToken, claim, ok := extractAuthAndClaims(r, w, tracer)
        
        // 2. Extract path params: org_id, domain_id
        orgID := r.PathValue(string(constants.OrgID))
        domainID := r.PathValue(string(constants.DomainID))
        
        // 3. RBAC check - verify AgentDomainViewUserConversations permission
        hasPermission, err := checkDomainPermission(r.Context(), authToken, orgID, domainID, 
            graph.AgentDomainActionAgentDomainViewUserConversations, stateSvc, tracer)
        
        // 4. Proxy to AuraContext
        proxy := httputil.NewSingleHostReverseProxy(upstreamURL)
        proxy.ServeHTTP(w, r)
    }
}
```

---

## 8. Error Handling and Status Codes

### Standard Error Response Format
```json
{
    "error": {
        "code": "ERROR_CODE",
        "message": "Human-readable message"
    }
}
```

### Common Status Codes in Feedback Handlers:

| Status | Error Code | Scenario |
|--------|-----------|----------|
| 400 | INVALID_REQUEST_BODY | Malformed JSON |
| 400 | VALIDATION_ERROR | Missing required fields, invalid data |
| 400 | INVALID_RATING | Rating not 1 or -1 |
| 400 | INVALID_SESSION | Session not found or invalid |
| 400 | INVALID_FEEDBACK_ID | feedback_id format invalid |
| 400 | SESSION_DOMAIN_MISMATCH | Session belongs to different domain |
| 401 | UNAUTHORIZED | OBO token missing or invalid |
| 403 | FORBIDDEN | Project/domain ID doesn't match OBO token |
| 403 | DOMAIN_FORBIDDEN | User lacks required permission |
| 404 | FEEDBACK_NOT_FOUND | Feedback record doesn't exist |
| 404 | THREAD_NOT_FOUND | Thread not found for feedback |
| 500 | DATABASE_ERROR | Query failed |
| 500 | CONNECTION_ERROR | Can't get DB connection |

---

## 9. Implementation Checklist

### Complete Implementation Requires:

- [ ] **Thread Retrieval Logic**
  - Query checkpoints table by session_id
  - Filter by checkpoint_id order
  - Transform to SessionMessagesResponse format
  - Handle empty/missing threads gracefully

- [ ] **Response Transformation**
  - Map checkpoint data to message format
  - Ensure checkpointID is included in each message
  - Handle nested content structure

- [ ] **Error Handling**
  - Database query failures
  - Session/checkpoint not found
  - Malformed checkpoint data

- [ ] **Performance**
  - Consider result limits (prevent huge thread returns)
  - Index on sessions.id for checkpoint queries
  - Possible caching for frequently accessed threads

- [ ] **Testing**
  - Unit tests for thread retrieval logic
  - Integration tests with sample checkpoints data
  - RBAC permission edge cases
  - Cross-domain access prevention

- [ ] **Documentation**
  - Update API documentation
  - Document response schema
  - Add examples to Swagger/OpenAPI spec

---

## 10. Security Considerations

### Defense in Depth Strategy:

1. **Token Level:**
   - OBO token must be present and valid
   - OBO token project_id must match request
   - OBO token domain_id must match request (if enabled)

2. **Permission Level:**
   - User must have AgentDomainViewUserConversations permission
   - Permission checked by Nova Gateway before proxying
   - State Service validates user's domain access

3. **Data Level:**
   - Feedback must belong to requested domain
   - Session must belong to requested domain
   - User can only see threads for domains they have access to

4. **SQL Level:**
   - Parameterized queries prevent SQL injection
   - Database connection isolated by project_id
   - No direct user input in queries

### Critical Security Notes:

1. **Never skip RBAC checks** - Different from list endpoint
   - List: Users can see own feedback with session_id filter
   - Thread: Only domain admins can view (no user-level access)

2. **Session validation is critical:**
   - Prevents users from accessing threads across domains
   - getSessionDomainID() must succeed before returning thread

3. **OBO token scoping:**
   - OBO tokens are domain-scoped
   - Limit token lifetime appropriately
   - Log all thread access for audit

---

## 11. Code Structure Summary

### File Organization in AuraContext:

```
cmd/auracontext/handlers/feedback/
├── handlers.go       # Main handler functions (GetFeedbackThread, etc.)
├── types.go          # Request/response DTOs
├── helpers.go        # Helper functions (getSessionDomainID, etc.)
└── [test files]

data/feedback/
├── types.go          # Domain models (Feedback, ReasonCode)
├── feedback.go       # Database operations (CRUD)
├── filter.go         # Query filters
└── [test files]
```

### Integration Points:

1. **Nova Gateway:** Proxy layer with RBAC checks
2. **State Service:** Permission verification
3. **AuraContext DB:** Feedback and session storage
4. **Checkpoints:** Conversation message retrieval (TO BE IMPLEMENTED)

---

## Recommendations

### For Implementation:

1. **Start with checkpoint query logic** - This is the core work
2. **Use existing patterns** - Follow SetRequestContext middleware style
3. **Add comprehensive logging** - For debugging thread retrieval issues
4. **Test with real feedback data** - Use production-like datasets
5. **Performance test** - Ensure large threads don't timeout

### For Security Review:

1. Validate OBO token scope during thread access
2. Audit logging for all thread retrievals
3. Consider rate limiting (prevent thread spam attacks)
4. Test cross-domain access prevention thoroughly
5. Document threat model and mitigation strategies

### For Frontend:

1. Verify SessionMessagesResponse format matches expectations
2. Test thread highlighting with various checkpoint positions
3. Handle loading and error states gracefully
4. Consider pagination for very long threads
5. Cache threads in Redux to reduce API calls

---

## References

### Code Locations:
- Frontend API: `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/api/feedback.ts`
- Frontend Component: `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/`
- Nova Gateway Handler: `/home/jchi/projects/helios/singlestore.com/helios/cmd/nova-gateway/auracontext/handlers/feedbackhandler.go`
- AuraContext Handler: `/home/jchi/projects/heliosai/services/auracontext/cmd/auracontext/handlers/feedback/handlers.go`
- AuraContext Data: `/home/jchi/projects/heliosai/services/auracontext/data/feedback/`

### Related Handlers (Reference Implementations):
- CheckpointHandler: `/home/jchi/projects/heliosai/services/auracontext/cmd/auracontext/handlers/checkpoints/`
- ConversationHandler: `/home/jchi/projects/heliosai/services/auracontext/cmd/auracontext/handlers/conversations/`

---

**End of Research Report**

Generated: 2026-01-28  
Thoroughness Level: Comprehensive  
Status: Ready for Implementation Planning
