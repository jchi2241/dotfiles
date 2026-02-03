---
type: research
title: Analyst Feedback Feature - Complete Flow and Access Control
project: helios, heliosai
area: frontend/intelligence, cmd/nova-gateway, services/auracontext
tags: [analyst, feedback, rbac, access-control, auracontext, nova-gateway]
date: 2026-02-02
status: complete
related_plans: []
---

# Analyst Feedback Feature - Complete Flow and Access Control

## Overview

The Analyst feedback feature allows users to provide thumbs up/down ratings on AI-generated responses, with optional reason codes and comments for negative feedback. The feature spans across three main components: the Helios frontend, Nova Gateway (proxy layer), and AuraContext service (backend storage). Access control is enforced through RBAC permissions at multiple levels.

## Key Components

### Frontend (Helios)

**Main Components:**
- `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/response-feedback/response-feedback.tsx` - UI component for collecting feedback
- `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/response-feedback/feedback-reason-selector.tsx` - Reason selector for negative feedback
- `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/hooks/use-submit-feedback.ts` - Hook for submitting feedback
- `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/api/feedback.ts` - API client for feedback operations

**Admin Components:**
- `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-tab.tsx` - Domain admin feedback tab
- `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-list.tsx` - Feedback list display
- `/home/jchi/projects/helios/frontend/src/pages/organizations/intelligence/components/configure-domains-flyout/feedback-tab/feedback-thread-flyout.tsx` - Thread viewer for feedback context

### Nova Gateway (Helios)

**Handlers:**
- `/home/jchi/projects/helios/singlestore.com/helios/cmd/nova-gateway/auracontext/handlers/feedbackhandler.go` - Proxy handlers with RBAC checks
- `/home/jchi/projects/helios/singlestore.com/helios/cmd/nova-gateway/auracontext/routes.go` - Route configuration (lines 64-68, 119)

**Key Functions:**
- `ProxySubmitFeedback` - Proxies feedback submission (no RBAC, OBO validation in AuraContext)
- `ProxyListFeedback` - Lists feedback with RBAC check for domain owners
- `ProxyGetFeedbackThread` - Gets conversation thread with RBAC check
- `ProxyGetReasonCodes` - Public endpoint for reason code list

### AuraContext Service (Heliosai)

**Handlers:**
- `/home/jchi/projects/heliosai/services/auracontext/cmd/auracontext/handlers/feedback/handlers.go` - Main feedback handlers
- `/home/jchi/projects/heliosai/services/auracontext/cmd/auracontext/handlers/feedback/types.go` - Request/response types
- `/home/jchi/projects/heliosai/services/auracontext/cmd/auracontext/handlers/feedback/helpers.go` - Helper functions

**Data Layer:**
- `/home/jchi/projects/heliosai/services/auracontext/data/feedback/feedback.go` - Database operations
- `/home/jchi/projects/heliosai/services/auracontext/data/feedback/types.go` - Feedback model types

**Database Schema:**
- `/home/jchi/projects/helios/singlestore.com/helios/auracontextstore/sql/schema/v8/alter_ddl.sql` - Feedback table definition

## Data Flow

### 1. Feedback Submission Flow

```
User clicks thumbs up/down in UI
       ↓
ResponseFeedback component (response-feedback.tsx:75-81)
       ↓
useSubmitFeedback hook (use-submit-feedback.ts:32-62)
       ↓
submitFeedbackAPI (feedback.ts:75-103)
       ↓
POST /v1/organizations/{org_id}/projects/{project_id}/domains/{domain_id}/feedback
       ↓
Nova Gateway: ProxySubmitFeedback (feedbackhandler.go:25-34)
       ↓
AuraContext: SubmitFeedback handler (handlers.go:170-245)
       ↓
Derive thread_id from checkpoint_id (handlers.go:187-197)
       ↓
Validate domain ownership (handlers.go:199-215)
       ↓
UPSERT feedback to database (handlers.go:224-241)
```

### 2. Feedback Listing Flow (Domain Admin)

```
Domain admin opens feedback tab
       ↓
FeedbackTab component checks permissions (feedback-tab.tsx:20-23)
       ↓
FeedbackList component (feedback-list.tsx)
       ↓
useListFeedback hook (feedback.ts:112-165)
       ↓
GET /v1/organizations/{org_id}/projects/{project_id}/domains/{domain_id}/feedback
       ↓
Nova Gateway: ProxyListFeedback (feedbackhandler.go:43-98)
       ↓
RBAC check: AgentDomainViewFeedback permission (feedbackhandler.go:77-92)
       ↓
AuraContext: ListFeedback handler (handlers.go:248-331)
       ↓
Return filtered feedback list
```

### 3. Feedback Thread View Flow

```
Admin clicks on feedback item
       ↓
FeedbackThreadFlyout component
       ↓
getFeedbackThreadAPI (feedback.ts:234-261)
       ↓
GET /v1/organizations/{org_id}/projects/{project_id}/domains/{domain_id}/feedback/{feedback_id}/thread
       ↓
Nova Gateway: ProxyGetFeedbackThread (feedbackhandler.go:104-147)
       ↓
RBAC check: AgentDomainViewUserConversations permission (feedbackhandler.go:127-142)
       ↓
AuraContext: GetFeedbackThread handler (handlers.go:334-392)
       ↓
Return feedback + conversation thread
```

## API Contracts

### Submit Feedback
**Endpoint:** `POST /v1/organizations/{org_id}/projects/{project_id}/domains/{domain_id}/feedback`

**Request Body:**
```json
{
    "checkpoint_id": "string",
    "rating": 1 | -1,
    "reason_code": "string | null",
    "comment": "string | null"
}
```

**Response:**
```json
{
    "results": {
        "feedback": {
            "id": "string",
            "domainID": "string",
            "sessionID": "string",
            "checkpointID": "string",
            "userID": "string",
            "rating": 1 | -1,
            "reasonCode": "string | null",
            "comment": "string | null",
            "questionPreview": "string",
            "createdAt": "timestamp",
            "updatedAt": "timestamp"
        }
    }
}
```

### List Feedback
**Endpoint:** `GET /v1/organizations/{org_id}/projects/{project_id}/domains/{domain_id}/feedback`

**Query Parameters:**
- `session_id` - Filter by session (optional)
- `user_id` - Filter by user (optional, auto-added when session_id provided)
- `rating` - Filter by rating (1 or -1)
- `reason_code` - Filter by reason code
- `start_date` - RFC3339 timestamp
- `end_date` - RFC3339 timestamp
- `limit` - Max results (default 100, max 1000)
- `offset` - Pagination offset

### Get Feedback Thread
**Endpoint:** `GET /v1/organizations/{org_id}/projects/{project_id}/domains/{domain_id}/feedback/{feedback_id}/thread`

**Response:**
```json
{
    "results": {
        "feedback": { /* feedback object */ },
        "thread": { /* conversation messages */ }
    }
}
```

### Get Reason Codes
**Endpoint:** `GET /v1/feedback-reasons`

**Response:**
```json
{
    "results": {
        "reasonCodes": [
            {
                "code": "values_look_off",
                "displayName": "Values look off"
            },
            {
                "code": "missing_data",
                "displayName": "Missing data"
            },
            {
                "code": "misunderstood_question",
                "displayName": "Misunderstood question"
            },
            {
                "code": "made_something_up",
                "displayName": "Analyst made something up"
            },
            {
                "code": "other",
                "displayName": "Other"
            }
        ]
    }
}
```

## Access Control

### RBAC Permissions

**AgentDomain Resource** (`/home/jchi/projects/helios/singlestore.com/helios/authz/model/yaml/agentdomain.yaml`):

- **Owner role** (lines 5-13):
  - `View Agent Domain Feedback` - View all feedback for the domain
  - `View Agent Domain User Conversations` - View conversation threads
  - `Update`, `Delete`, `Control Access`, `Use` - Full domain control

- **User role** (lines 14-17):
  - `Use` - Can use the domain (submit feedback)

### Permission Checks

1. **Submit Feedback** (Any domain user):
   - Requires valid OBO token with domain access
   - OBO token validation in AuraContext (handlers.go:76-128)
   - Domain ownership validation of checkpoint (handlers.go:199-215)

2. **List Feedback** (Conditional):
   - **With session_id param**: User can view their own feedback (feedbackhandler.go:67-74)
   - **Without session_id**: Requires `AgentDomainViewFeedback` permission (feedbackhandler.go:77-92)

3. **View Feedback Thread** (Domain owners only):
   - Requires `AgentDomainViewUserConversations` permission (feedbackhandler.go:127-142)
   - Additional domain validation in AuraContext (handlers.go:357-374)

4. **Get Reason Codes** (Public):
   - No authentication required

### Security Validations

1. **OBO Token Validation** (handlers.go:76-128):
   - Validates token presence and claims
   - Checks project_id matches token claims
   - Checks domain_id matches token claims (when `useDomainIDInToken` is true)

2. **Domain Ownership** (handlers.go:199-215):
   - Derives session_id from checkpoint_id
   - Validates checkpoint exists
   - Validates session belongs to the requested domain

3. **Feedback Deduplication** (feedback.go):
   - Uses deterministic SHA-256 hash: `checkpoint_id:user_id:session_id`
   - Ensures one feedback per user per checkpoint
   - UPSERT operation allows updates

## Configuration

### Environment Variables
- `useDomainIDInToken` - Whether to enforce domain ID validation in OBO tokens (AuraContext)

### Database Schema
**feedback table** (alter_ddl.sql:11-35):
- Primary key: `id` (SHA-256 hash)
- Indexes:
  - `idx_feedback_domain_rating` - For listing by domain with rating filter
  - `idx_feedback_session` - For session-based lookups
  - `idx_feedback_checkpoint_user` - For deduplication checks

### Reason Codes
Defined in `/home/jchi/projects/heliosai/services/auracontext/data/feedback/types.go`:
- `values_look_off` - Values look off
- `missing_data` - Missing data
- `misunderstood_question` - Misunderstood question
- `made_something_up` - Analyst made something up
- `other` - Other

## Code References

### Key Functions

**Frontend:**
- Submit feedback: `response-feedback.tsx:54-103` (handleFeedback)
- Load feedback list: `feedback-list.tsx:48-51` (useListFeedback)
- View thread: `feedback-thread-flyout.tsx` (component)

**Nova Gateway:**
- RBAC check: `feedbackhandler.go:165-190` (checkDomainPermission)
- Route setup: `routes.go:64-68` (feedback routes)

**AuraContext:**
- Derive thread from checkpoint: `helpers.go` (getThreadIDFromCheckpoint)
- Generate feedback ID: `helpers.go` (generateDeterministicFeedbackID)
- Extract question preview: `helpers.go` (extractQuestionPreview)
- Create/update feedback: `handlers.go:236-241` (createFeedback call)

### Recent Changes

**Session ID Removal** (Latest commits):
- Backend: Removed `SessionID` from `SubmitFeedbackRequest` type
- Backend: Added `getThreadIDFromCheckpoint` to derive session from checkpoint
- Frontend: Removed `sessionId` from feedback submission parameters
- Frontend: Updated all API calls to exclude session_id from request body

This change simplifies the API by deriving the session_id internally from the checkpoint_id, reducing the information clients need to provide while maintaining the same security guarantees.

## Dependencies

**Frontend:**
- Auth token from Keycloak
- OBO token from State Service
- Nova Gateway URL from cluster configuration

**Nova Gateway:**
- State Service for RBAC queries
- AuraContext Service for data operations
- JWT validation middleware

**AuraContext Service:**
- Database connection per project
- OBO token validation
- Checkpoint and session tables for validation