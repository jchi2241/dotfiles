---
type: research
title: API Contract Options for Aura Context Service to Portal Frontend
project: helios, heliosai
area: cmd/nova-gateway/auracontext, services/auracontext, frontend/intelligence
tags: [api-contract, openapi, typescript-codegen, aura-context, nova-gateway, portal, type-safety]
date: 2026-02-09
status: complete
related_plans: []
---

# API Contract Options: Aura Context Service -> Nova Gateway -> Portal Frontend

## 1. Overview

This report documents the current architecture of the aura context service API pipeline and explores options for introducing a formal API contract that enables TypeScript type generation in the portal frontend. The goal is to make API changes produce compile-time errors in the frontend, minimizing the risk of runtime breakage and reducing triple-maintenance of types across three codebases.

### The Pipeline

```
Aura Context Service (Go, REST/JSON)
        |
        | HTTP proxy (some routes are pure passthrough, some have pre/post-processing)
        v
Nova Gateway (Go, REST/JSON gateway)
        |
        | HTTP REST (via safeFetch)
        v
Portal Frontend (React/TypeScript)
```

### The Problem

Today, API types are manually defined **three separate times**:

1. **Aura Context Service** — Go structs with `json:` tags (`heliosai/services/auracontext/cmd/auracontext/handlers/*/types.go`)
2. **Nova Gateway** — Separate Go structs in client packages (`helios/cmd/nova-gateway/auracontext/clients/*/types.go`)
3. **Portal Frontend** — Hand-written TypeScript types in `contract.ts` (`helios/frontend/src/pages/organizations/intelligence/api/contract.ts`)

These types already diverge in small ways (e.g., Nova Gateway uses typed UUIDs like `uuid.NotebookCodeService` while aura context uses generic `uuid.UUID`; some field names differ). There is no automated mechanism to detect drift.

---

## 2. Current State: How It Works Today

### 2.1 Aura Context Service (Source of Truth)

- **Repo:** `/home/jchi/projects/heliosai/services/auracontext/`
- **Language:** Go
- **API:** REST/JSON over HTTP on port 8080
- **Type definitions:** Go structs in handler packages:
  - `cmd/auracontext/handlers/domains/types.go` — `DomainResponse`, `CreateDomainRequest`, `DomainTableInfo`, etc.
  - `cmd/auracontext/handlers/feedback/types.go` — `FeedbackResponse`, `SubmitFeedbackRequest`, etc.
  - `cmd/auracontext/handlers/agents/types.go` — `AgentResponse`, `PublishAgentRequest`, etc.
  - `cmd/auracontext/handlers/knowledge/` — knowledge base types
  - `cmd/auracontext/handlers/conversations/` — session/message types
  - `cmd/auracontext/handlers/checkpoints/` — checkpoint types
- **Existing docs:** Markdown API specs in `docs/CONVERSATIONS_API_SPEC.md` and `docs/DOMAINS_API_SPEC.md` (human-readable, not machine-parseable)
- **No existing machine-readable contract** (no protobuf, OpenAPI, or JSON Schema)

### 2.2 Nova Gateway (Proxy Layer)

- **Repo:** `/home/jchi/projects/helios/singlestore.com/helios/cmd/nova-gateway/auracontext/`
- **Language:** Go
- **Role:** HTTP reverse proxy with middleware (auth, CORS, tracing, RBAC filtering)
- **Route registration:** `routes.go` — maps ~40 REST endpoints under `/auracontext/v1/organizations/{org_id}/projects/{project_id}/...`
- **Two proxy modes:**
  1. **Pure passthrough** (`proxyHandler`) — most knowledgebase endpoints. Request/response forwarded unchanged.
  2. **Smart proxy handlers** — agents, domains, feedback. Pre-process request (e.g., create State Service resources), post-process response (e.g., RBAC filtering of agent list).
- **Client types:** Separate Go structs in `clients/agents/types.go`, `clients/common/types.go`, `clients/conversations/` — these are *independently maintained* copies, not imports from the aura context service.
- **Key observation:** Nova Gateway adds the `/auracontext` prefix and mounts everything under it. The aura context service itself does not use this prefix.

### 2.3 Portal Frontend (Consumer)

- **Repo:** `/home/jchi/projects/helios/frontend/`
- **Language:** TypeScript / React
- **API layer:** Custom contract-first REST client at `src/pages/organizations/intelligence/api/`
  - `contract.ts` (739 lines) — Single source of truth for all 34+ endpoints. Declares path, method, typed params/search/body/response, and auth metadata per endpoint.
  - `intelligence-client.ts` — Imperative client factory (`createIntelligenceClient`) that resolves `:param` placeholders and calls `safeFetch`.
  - `intelligence-hooks.ts` — React hooks layer (`useIntelligenceQuery`, `useIntelligenceMutation`) providing cache-and-network semantics.
- **Type definitions:** All manually written inline in `contract.ts` (lines 77-241): `Domain`, `DomainTable`, `DomainInsight`, `Feedback`, `SavedQuery`, `AgentBasicInfo`, etc.
- **No code generation** for these REST types. (The GraphQL-based parts of the portal use `graphql-codegen`, but the intelligence/aura context REST layer is entirely manual.)
- **Gateway URL:** Obtained dynamically via GraphQL query (`useNovaGateway` hook), then used as base URL for all REST calls.

### 2.4 Existing Precedent in the Codebase

The helios repo already has one OpenAPI + codegen pipeline:

- **Management API:** `cmd/api-service/mainimpl/docs/management-api.yaml` (OpenAPI 3.0, ~284KB)
- **Code generator:** `oapi-codegen` v1.12.4
- **Config:** `.oapi-config.yaml` — generates Go client + models
- **Script:** `scripts/backend-api-service-client-update`

This establishes organizational precedent for OpenAPI-based contract-first development.

---

## 3. Options for Introducing an API Contract

### Option A: OpenAPI Spec Defined in Aura Context Service

**How it works:**
1. Write an OpenAPI 3.x YAML/JSON spec in the aura context service repo (`heliosai/services/auracontext/api/openapi.yaml`)
2. Use `oapi-codegen` (already in the helios toolchain) to generate Go server types/handlers in the aura context service
3. Export/copy the same OpenAPI spec to the nova gateway repo (via git submodule, shared artifact, or CI pipeline)
4. Use `oapi-codegen` to generate Go client types in nova gateway
5. Use `openapi-typescript` (npm package) or `openapi-typescript-codegen` to generate TypeScript types in the portal frontend
6. Frontend `contract.ts` either imports generated types directly or is itself generated

**Where the contract lives:** `heliosai/services/auracontext/api/openapi.yaml`

**Type flow:**
```
openapi.yaml (aura context service repo)
    |
    ├─> oapi-codegen ──> Go server types (aura context service)
    ├─> oapi-codegen ──> Go client types (nova gateway)
    └─> openapi-typescript ──> TypeScript types (portal frontend)
```

**Advantages:**
- Single source of truth in the service that owns the API
- Matches existing helios precedent (`management-api.yaml` + `oapi-codegen`)
- Rich ecosystem: linting (`spectral`), diffing (`oasdiff`), documentation generation, mock servers
- OpenAPI is widely understood and tooling-agnostic
- Can generate validation logic alongside types
- Supports describing response wrappers (`{ results: { ... } }`) natively via schema composition
- `openapi-typescript` generates zero-runtime types (pure `.d.ts`) — no bundle impact
- Can be introduced incrementally (start with one resource, e.g., domains)

**Disadvantages:**
- Spec maintenance is a manual process — the YAML must be kept in sync with Go handler code (unless generating the spec from Go annotations, which inverts the flow)
- Nova Gateway transformations (RBAC filtering, field enrichment) mean the gateway-to-frontend contract may differ from the service-to-gateway contract
- Distribution of the spec across repos needs a mechanism (submodule, package publish, or mono-repo spec)

**Variation A1: Generate OpenAPI from Go code (annotations/comments)**

Use a tool like `swaggo/swag` or `ogen` to generate OpenAPI from Go struct tags and handler annotations. This avoids maintaining a separate YAML file.

- *Pro:* Go structs remain the authoring surface; spec is always in sync
- *Con:* Annotation-driven generation can be limiting for complex schemas; less control over spec quality

**Variation A2: Generate Go code from OpenAPI (spec-first)**

Write the OpenAPI spec first, then generate Go server stubs with `oapi-codegen` or `ogen`.

- *Pro:* The spec is the single source of truth, not Go code — cleaner contract-first workflow
- *Con:* Requires changing how the aura context service is developed; existing handlers would need refactoring to match generated interfaces

---

### Option B: Protobuf / Connect-RPC

**How it works:**
1. Define `.proto` files for all aura context service resources
2. Use `buf` or `protoc` to generate:
   - Go server/client code (protobuf structs + optional gRPC/Connect handlers)
   - TypeScript types (via `@bufbuild/protobuf` or `ts-proto`)
3. Services communicate via Connect-RPC (supports HTTP/JSON, gRPC, and gRPC-Web) or continue using REST with protobuf as the schema language only

**Where the contract lives:** `.proto` files in a shared location (e.g., a `proto/` directory in heliosai or a dedicated `api-schemas` repo)

**Type flow:**
```
auracontext.proto
    |
    ├─> protoc / buf ──> Go types + server stubs (aura context service)
    ├─> protoc / buf ──> Go client types (nova gateway)
    └─> protoc / buf ──> TypeScript types (portal frontend)
```

**Advantages:**
- Strongest type guarantees — protobuf schema is unambiguous
- Code generation for all languages from one source
- `buf` ecosystem provides linting, breaking change detection, schema registry
- helios already has 40+ `.proto` files for other services (cellagent, cstore, nova-manager) — organizational familiarity
- Connect-RPC could simplify the nova gateway proxy layer if adopted end-to-end

**Disadvantages:**
- Aura context service currently has zero protobuf usage — significant migration effort
- REST semantics (query params, path params, HTTP methods, status codes) don't map cleanly to protobuf service definitions without annotations
- Nova Gateway's response transformations (RBAC filtering, field enrichment) are awkward to express in protobuf
- Frontend would need to adopt protobuf-ts or Connect-Web client libraries — departure from current `safeFetch` pattern
- Heavier toolchain (`buf`, `protoc`, plugins) vs. OpenAPI
- The portal frontend uses REST idioms extensively; switching to protobuf/Connect is a larger paradigm shift

---

### Option C: Shared TypeSpec / JSON Schema Definition

**How it works:**
1. Define API schemas using TypeSpec (Microsoft's API description language) or raw JSON Schema
2. Generate OpenAPI from TypeSpec (TypeSpec compiles to OpenAPI 3.x)
3. From the generated OpenAPI, produce Go and TypeScript types

**Where the contract lives:** `.tsp` files or `.json` schema files in a shared location

**Type flow:**
```
*.tsp (TypeSpec files)
    |
    └─> tsp compile ──> openapi.yaml
                            |
                            ├─> oapi-codegen ──> Go types
                            └─> openapi-typescript ──> TypeScript types
```

**Advantages:**
- TypeSpec is more concise and readable than raw OpenAPI YAML
- Produces standard OpenAPI as intermediate format — retains full ecosystem compatibility
- Good for teams that find YAML-heavy OpenAPI specs hard to maintain

**Disadvantages:**
- Extra layer of tooling (TypeSpec compiler) on top of OpenAPI toolchain
- Relatively new tool — smaller community and ecosystem
- Adds complexity without fundamentally solving anything that OpenAPI alone doesn't

---

### Option D: Code-First with Runtime Schema Extraction

**How it works:**
1. Keep Go structs as the source of truth in the aura context service
2. Add a build-time step that uses Go reflection or AST analysis to extract a JSON Schema or OpenAPI spec from the Go types
3. Publish the extracted spec as a build artifact
4. Frontend consumes the spec via `openapi-typescript` or similar

**Tools:** `go-jsonschema`, custom Go AST tool, or `swaggo/swag` annotations

**Where the contract lives:** Go structs (authored); JSON Schema / OpenAPI (derived artifact)

**Type flow:**
```
Go handler structs (aura context service)
    |
    └─> swag / reflection ──> openapi.yaml (build artifact)
                                    |
                                    ├─> oapi-codegen ──> Go client types (nova gateway)
                                    └─> openapi-typescript ──> TypeScript types (portal)
```

**Advantages:**
- No new authoring surface — developers continue writing Go structs
- Lower adoption friction than spec-first approaches
- Spec is always derived from actual code — can't drift

**Disadvantages:**
- Generated specs from code are often lower quality (missing descriptions, examples, constraints)
- `swaggo/swag` requires inline comments/annotations — still some maintenance overhead
- Hard to express complex contract details (discriminated unions, conditional fields) through Go struct tags alone
- The "source of truth" is implicit (scattered across handler types) rather than explicit (one spec file)

---

### Option E: Hybrid — OpenAPI Spec at Nova Gateway Level

**How it works:**
1. Define the OpenAPI spec at the **Nova Gateway** level, not the aura context service level
2. This spec describes what the frontend actually sees (post-transformation)
3. Generate TypeScript types for the frontend from this spec
4. Nova Gateway's Go types are generated from or validated against this spec
5. The aura context service continues using its own internal types; the gateway contract is the "public API"

**Where the contract lives:** `helios/cmd/nova-gateway/auracontext/api/openapi.yaml`

**Type flow:**
```
openapi.yaml (nova gateway repo)
    |
    ├─> oapi-codegen ──> Go handler/client types (nova gateway)
    └─> openapi-typescript ──> TypeScript types (portal frontend)

Aura context service types remain independent (internal API)
```

**Advantages:**
- The spec describes exactly what the frontend consumes — no ambiguity about gateway transformations
- Only two layers to keep in sync (gateway spec <-> frontend types) instead of three
- Aura context service can evolve independently as long as the gateway adapts
- Matches the reality that nova gateway is the "public API surface" for the frontend
- Lower blast radius — doesn't require changes to the aura context service repo

**Disadvantages:**
- Doesn't address drift between aura context service and nova gateway (that contract remains informal)
- Two specs may eventually be needed (one internal, one external) if the internal contract also needs formalization
- Gateway maintainers must update the spec whenever the aura context service API changes and they adapt the proxy

---

## 4. Key Architectural Considerations

### 4.1 Nova Gateway is Not a Pure Proxy

This is the most important consideration. Several endpoints have **non-trivial transformations** in nova gateway:

| Endpoint | Gateway Behavior | File |
|----------|-----------------|------|
| `POST /agents` | Creates a State Service resource, injects `serviceID` into request body before proxying | `handlers/agentshandler.go:178-273` |
| `GET /agents` | Proxies, then filters response by RBAC permissions | `handlers/agentshandler.go:127-143` |
| `PUT /agents` | Updates State Service, enriches request | `handlers/agentshandler.go` |
| `DELETE /agents/{id}` | Deletes State Service resource, then proxies | `handlers/agentshandler.go` |
| `POST /domains` | Creates State Service workspace, enriches request | `handlers/domainshandler.go` |
| `GET /domains` | Proxies, then enriches with State Service data | `handlers/domainshandler.go` |
| Knowledgebase routes | Pure passthrough | `routes.go:72-114` |
| Conversation routes | Pure passthrough | `routes.go:40-42` |
| Feedback routes | Mostly passthrough, some with state svc enrichment | `routes.go:65-67` |

**Implication:** For passthrough routes, the aura context service types and the gateway-to-frontend types are identical. For smart proxy routes, they may differ. Any contract approach must account for this.

### 4.2 The Frontend Already Has a Contract Pattern

The existing `contract.ts` file is well-structured and already uses a contract-first pattern with typed endpoints, path params extraction via template literal types, and generic hooks. This means:

- A code generation approach needs to produce output that integrates cleanly with (or replaces) this pattern
- The `t<...>()` type-carrier pattern, `AuthStrategy`, and `parseAs` metadata would need equivalents in any generated code
- The frontend team is clearly comfortable with explicit contract definitions

### 4.3 Separate Repos

The three components live in different repos:
- **Aura context service:** `heliosai/services/auracontext/`
- **Nova gateway:** `helios/singlestore.com/helios/cmd/nova-gateway/`
- **Portal frontend:** `helios/frontend/`

Nova gateway and portal frontend are in the same monorepo (`helios`), which simplifies sharing artifacts between them. The aura context service is in a separate repo (`heliosai`), requiring cross-repo distribution of any contract artifact.

### 4.4 Existing Tooling

| Tool | Already Used | Where |
|------|-------------|-------|
| `oapi-codegen` | Yes | `helios` for management-api |
| `protoc` / `protoc-gen-go` | Yes | `helios` for cellagent, cstore, etc. |
| `graphql-codegen` | Yes | `helios/frontend` for GraphQL types |
| `buf` | No | — |
| `openapi-typescript` | No | — |
| `swaggo/swag` | No | — |

---

## 5. Comparison Matrix

| Criterion | A: OpenAPI (spec-first) | A1: OpenAPI (from Go) | B: Protobuf | C: TypeSpec | D: Code-first extraction | E: OpenAPI at Gateway |
|-----------|------------------------|-----------------------|-------------|-------------|--------------------------|----------------------|
| Source of truth | YAML spec | Go structs | .proto files | .tsp files | Go structs | YAML spec |
| Go server types | Generated | Native (source) | Generated | Generated (via OpenAPI) | Native (source) | N/A (aura context) |
| Go client types (gateway) | Generated | Generated | Generated | Generated (via OpenAPI) | Generated | Generated |
| TS frontend types | Generated | Generated | Generated | Generated (via OpenAPI) | Generated | Generated |
| Adoption effort | Medium | Low-Medium | High | Medium-High | Low | Low-Medium |
| Handles gateway transforms | Needs two specs | Needs two specs | Needs two specs | Needs two specs | Needs two specs | Yes (spec is post-transform) |
| Existing tooling in repo | oapi-codegen | swag (new) | protoc (yes) | None | swag (new) | oapi-codegen |
| Breaking change detection | oasdiff | oasdiff | buf breaking | oasdiff | oasdiff | oasdiff |
| Ecosystem maturity | Very high | High | Very high | Medium | Medium | Very high |

---

## 6. Code References

### Aura Context Service Types
- `heliosai/services/auracontext/cmd/auracontext/handlers/domains/types.go` — Domain, DomainTable request/response types
- `heliosai/services/auracontext/cmd/auracontext/handlers/feedback/types.go` — Feedback request/response types
- `heliosai/services/auracontext/cmd/auracontext/handlers/agents/types.go` — Agent request/response types
- `heliosai/services/auracontext/cmd/auracontext/handlers/knowledge/handler.go` — Knowledge base route registration
- `heliosai/services/auracontext/cmd/auracontext/handlers/conversations/handlers.go` — Conversation handlers
- `heliosai/services/auracontext/docs/CONVERSATIONS_API_SPEC.md` — Markdown API spec
- `heliosai/services/auracontext/docs/DOMAINS_API_SPEC.md` — Markdown API spec

### Nova Gateway
- `helios/cmd/nova-gateway/auracontext/routes.go` — All route registrations (lines 1-122)
- `helios/cmd/nova-gateway/auracontext/handlers/agentshandler.go` — Smart proxy with State Service integration
- `helios/cmd/nova-gateway/auracontext/handlers/domainshandler.go` — Smart proxy for domains
- `helios/cmd/nova-gateway/auracontext/handlers/utils.go` — Request/response transformation utilities
- `helios/cmd/nova-gateway/auracontext/clients/common/types.go` — `WrappedResponse[T]`, `ErrorResponse`
- `helios/cmd/nova-gateway/auracontext/clients/agents/types.go` — Gateway's copy of agent types
- `helios/cmd/nova-gateway/auracontext/middleware/auth.go` — JWT/RBAC middleware

### Portal Frontend
- `helios/frontend/src/pages/organizations/intelligence/api/contract.ts` — All 34+ endpoint definitions with types (739 lines)
- `helios/frontend/src/pages/organizations/intelligence/api/intelligence-client.ts` — Imperative client factory
- `helios/frontend/src/pages/organizations/intelligence/api/intelligence-hooks.ts` — React hooks layer
- `helios/frontend/src/pages/organizations/intelligence/api/utils/build-headers.ts` — Auth header construction
- `helios/frontend/src/pages/organizations/intelligence/api/chat-session.ts` — SSE streaming chat
- `helios/frontend/src/pages/organizations/intelligence/api/domains.ts` — Domain API consumers
- `helios/frontend/src/pages/organizations/intelligence/api/feedback.ts` — Feedback API consumers
- `helios/frontend/src/pages/organizations/intelligence/api/agents.ts` — Agent API consumers
- `helios/frontend/src/pages/organizations/intelligence/use-nova-gateway.tsx` — Gateway URL discovery via GraphQL

### Existing OpenAPI Precedent
- `helios/.oapi-config.yaml` — oapi-codegen configuration
- `helios/cmd/api-service/mainimpl/docs/management-api.yaml` — Existing OpenAPI 3.0 spec (~284KB)
- `helios/scripts/backend-api-service-client-update` — Generation script
- `helios/Makefile.backend-deps` — oapi-codegen tool installation

### Existing Protobuf Precedent
- `helios/cmd/cellagent/proto/` — 30+ .proto files
- `helios/singlestore.com/nova-manager/proto/nova_manager.proto`
- `helios/singlestore.com/helios/cstore/api/proto/` — 6 .proto files

---

## 7. Type Divergence Examples

Concrete examples of where types currently drift across the three layers:

### Domain Types

| Field | Aura Context Service (`DomainResponse`) | Frontend (`Domain`) |
|-------|----------------------------------------|---------------------|
| `id` | `uuid.UUID` (json: `"id"`) | `string` |
| `project_id` | `uuid.UUID` (json: `"project_id"`) | `projectID` (camelCase) |
| `created_by` | `uuid.UUID` (json: `"created_by"`) | `createdBy` (camelCase) |
| `created_at` | `time.Time` (json: `"created_at"`) | `createdAt: string` (camelCase) |
| `status` | `DomainStatusInfo { State string }` | `DomainStatus { state: DomainStatusState }` (enum in TS) |
| `tables` | `[]DomainTableInfo` (always present) | Not in `Domain` type (separate endpoint) |
| `updated_by` | `*uuid.UUID` (json: `"updated_by"`) | `updatedBy?: string` (camelCase) |

**Key observations:**
- The aura context service uses `snake_case` JSON keys for domain types but `camelCase` for agent/feedback types — inconsistent
- Frontend normalizes everything to `camelCase`
- UUID types serialize to strings; frontend types are `string` — semantically equivalent but not enforced
- Frontend `DomainStatusState` is an enum; backend is a plain string

### Agent Types

| Field | Aura Context Service | Nova Gateway | Frontend |
|-------|---------------------|--------------|----------|
| `serviceID` | `uuid.UUID` | `uuid.NotebookCodeService` | Not in `Agent` contract type |
| `projectID` | `uuid.UUID` | `uuid.Project` | Not in `Agent` contract type |
| `id` | `uuid.UUID` | `uuid.ObjectID` | Part of `Agent` (imported from context) |

The Nova Gateway uses domain-specific UUID types that don't exist in the aura context service. These serialize identically to JSON but add type safety within the Go codebase. This is a gateway-internal concern that doesn't affect the wire format.

---

## 8. Endpoint Coverage Analysis

Routes in Nova Gateway (`routes.go`) and their proxy behavior:

| Category | # Endpoints | Proxy Type | Contract Needed |
|----------|-------------|------------|-----------------|
| Conversations | 3 | Pure passthrough | Aura context spec suffices |
| Agents | 5 | Smart proxy (State Service integration) | Gateway-level spec needed |
| Domains | 8 | Smart proxy (State Service integration) | Gateway-level spec needed |
| Feedback | 4 | Mixed (some smart, some passthrough) | Likely gateway-level |
| Knowledgebase/Insights | 4 | Pure passthrough | Aura context spec suffices |
| Knowledgebase/Databases | 10 | Pure passthrough | Aura context spec suffices |
| Knowledgebase/Queries | 4 | Pure passthrough | Aura context spec suffices |
| Knowledgebase/Functions | 2 | Pure passthrough | Aura context spec suffices |
| Knowledgebase/Relationships | 7 | Pure passthrough | Aura context spec suffices |
| Conversation Starters | 1 | Pure passthrough | Aura context spec suffices |
| Feedback Reasons | 1 | Smart proxy | Gateway-level |
| **Total** | **49** | ~35 passthrough, ~14 smart | |

**~71% of routes are pure passthrough** — for these, a single spec at the aura context service level would be sufficient. The remaining ~29% require either a separate gateway-level spec or explicit documentation of the transformation.
