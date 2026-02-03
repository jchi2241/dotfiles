---
type: plan
title: Fix TypeScript 7 Preview Cypress Type Compatibility
project: helios
area: frontend/cypress
tags: [typescript, cypress, type-checking, module-resolution, typescript-7]
date: 2026-01-30
status: pending
research_doc: ~/.claude/thoughts/research/2026-01-30_typescript-7-preview-cypress-type-issues.md
task_list_id: null
phases_total: 2
phases_complete: 0
tasks_total: 2
tasks_complete: 0
---

# Fix TypeScript 7 Preview Cypress Type Compatibility

## Overview

Fix two TypeScript 7 preview compatibility errors in `frontend/cypress/support/commands.ts` caused by stricter module resolution that respects package.json `exports` field. The import `cypress/types/net-stubbing` fails because Cypress doesn't export this path in its package.json.

## Current State Analysis

### Error Details

1. **Line 22 - Module Resolution Error:**
   ```typescript
   import type { CyHttpMessages } from "cypress/types/net-stubbing";
   // TS2307: Cannot find module 'cypress/types/net-stubbing'
   ```

2. **Line 1032 - Implicit Any Error (cascading):**
   ```typescript
   req.on("response", (res) => { ... });
   // TS7006: Parameter 'res' implicitly has an 'any' type
   ```

### Key Discoveries:
- TypeScript 7 enforces package.json `exports` field strictly
- Cypress exports only: `.`, `./vue`, `./react`, `./react18` - NOT `./types/net-stubbing`
- `CyHttpMessages` namespace is included via triple-slash directive in Cypress's main types
- The type is only used in `interceptRequest()` function at line 1014-1020
- TypeScript 5.4.2 passes because it falls back to file-based resolution

### Type Analysis

The `CyHttpMessages.IncomingHttpRequest` interface is defined in `net-stubbing.d.ts:166` and includes:
- `body: any`
- `headers: { [key: string]: string | string[] }`
- `method: string`
- `url: string`
- `alias?: string`
- `on(eventName: 'response', cb: (res) => void): this`

The callback `res` parameter should be typed as `CyHttpMessages.IncomingHttpResponse`.

## Desired End State

Both TypeScript 5.4.2 and TypeScript 7 preview pass without errors:
- `pnpm run tsc` (TS 5) - passes
- `pnpm run tsgo` (TS 7) - passes

### Verification Criteria:
- `direnv exec ~/projects/helios pnpm -C ~/projects/helios/frontend run tsgo` exits with code 0
- `direnv exec ~/projects/helios pnpm -C ~/projects/helios/frontend run tsc` exits with code 0
- No loss of type safety in the affected code

## What We're NOT Doing

- Modifying Cypress package or its type definitions
- Adding path mappings or module resolution workarounds in tsconfig
- Suppressing errors with `@ts-ignore` or `@ts-expect-error`
- Duplicating large type definitions unnecessarily

## Implementation Approach

Use TypeScript's type inference from `cy.intercept` callback parameters. When Cypress's `cy.intercept` is called, the callback parameter `req` is already correctly typed via Cypress's global type declarations. We can:

1. Extract the request type from the callback using `Parameters` utility type
2. Use `Cypress.RequestBody` and related types that ARE available globally
3. Define a minimal local interface for just the properties we use

The cleanest solution: **Use type inference from the intercept callback parameter type**, which is available via `Cypress.Request` or can be inferred from the callback signature.

---

## Task Breakdown

> **IMPORTANT:** Each task below is designed to be independently executable by an agent with fresh context. After creating tasks with `TaskCreate`, update each task's "Claude Code Task" field with its system ID (e.g., `#1`). Tasks are stored in `~/.claude/tasks/<task-list-id>/`.

### Task 1: Fix CyHttpMessages Import and Type Annotations

**Claude Code Task:** _#N_ _(fill in after TaskCreate)_
**Blocked By:** None
**Phase:** 1

#### Description
Remove the failing `cypress/types/net-stubbing` import and replace `CyHttpMessages.IncomingHttpRequest` type annotation with a locally inferred type or minimal interface.

#### Files to Modify
- `frontend/cypress/support/commands.ts` - Lines 22 and 1014-1039

#### Implementation Notes

**Option A (Preferred): Use Cypress's typed callback inference**

The `cy.intercept` callback already provides correctly typed parameters. We can extract the type:

```typescript
// Remove line 22 entirely:
// import type { CyHttpMessages } from "cypress/types/net-stubbing";

// At line 1014, change:
// Before:
function interceptRequest({
    req,
    label,
}: {
    req: CyHttpMessages.IncomingHttpRequest;
    label: "public" | "private";
}) {

// After - use Parameters to extract type from intercept callback:
type InterceptCallback = Parameters<typeof cy.intercept>[1];
type InterceptRequest = InterceptCallback extends ((req: infer R) => any) ? R : never;

function interceptRequest({
    req,
    label,
}: {
    req: InterceptRequest;
    label: "public" | "private";
}) {
```

**Option B: Define minimal local interface**

If Option A doesn't work cleanly, define only what we use:

```typescript
// Replace the import with a local interface
interface CypressHttpRequest {
    body: any;
    alias?: string;
    on(event: "response", callback: (res: { body: any }) => void): void;
}

function interceptRequest({
    req,
    label,
}: {
    req: CypressHttpRequest;
    label: "public" | "private";
}) {
```

**Option C: Use first-party Cypress global types**

Check if `Cypress.Request` or similar exists in the global namespace that we can use.

#### Success Criteria
- [ ] Import `cypress/types/net-stubbing` removed from line 22
- [ ] `interceptRequest` function has valid type annotation
- [ ] `req.on("response", (res) => ...)` callback has `res` properly typed (not implicit any)
- [ ] Type check passes: `direnv exec ~/projects/helios pnpm -C ~/projects/helios/frontend run tsgo`

#### Actual Implementation
> _To be filled in by the implementing agent upon completion_

---

### Task 2: Verify TypeScript 5 and 7 Compatibility

**Claude Code Task:** _#N_ _(fill in after TaskCreate)_
**Blocked By:** Task 1
**Phase:** 2

#### Description
Run both TypeScript 5.4.2 (stable) and TypeScript 7.0.0-dev (preview) to verify the fix works with both versions and doesn't introduce regressions.

#### Files to Modify
- None (verification only)

#### Implementation Notes

Run these commands and verify they pass:

```bash
# TypeScript 7 preview (the failing one)
direnv exec ~/projects/helios pnpm -C ~/projects/helios/frontend run tsgo

# TypeScript 5.4.2 stable (should continue to pass)
direnv exec ~/projects/helios pnpm -C ~/projects/helios/frontend run tsc

# Or use make target
direnv exec ~/projects/helios make -C ~/projects/helios cp-tsc
```

If either fails, investigate the error and adjust Task 1's implementation.

#### Success Criteria
- [ ] `pnpm run tsgo` exits with code 0 (no TypeScript 7 errors)
- [ ] `pnpm run tsc` exits with code 0 (no TypeScript 5 regressions)
- [ ] No new type errors introduced elsewhere

#### Actual Implementation
> _To be filled in by the implementing agent upon completion_

---

## Phases

### Phase 1: Type Fix Implementation

#### Overview
Implement the type annotation fix that works with TypeScript 7's stricter module resolution.

#### Tasks in This Phase
- Task 1: Fix CyHttpMessages Import and Type Annotations

#### Success Criteria

**Automated Verification:**
- [ ] TypeScript 7 check passes: `direnv exec ~/projects/helios pnpm -C ~/projects/helios/frontend run tsgo`

**Manual Verification:**
- [ ] Code review shows appropriate type safety maintained

**Implementation Note:** After completing this phase and TypeScript 7 verification passes, proceed to Phase 2 for full verification.

---

### Phase 2: Full Verification

#### Overview
Verify the fix works with both TypeScript versions and document the change.

#### Tasks in This Phase
- Task 2: Verify TypeScript 5 and 7 Compatibility

#### Success Criteria

**Automated Verification:**
- [ ] TypeScript 5 check passes: `direnv exec ~/projects/helios pnpm -C ~/projects/helios/frontend run tsc`
- [ ] TypeScript 7 check passes: `direnv exec ~/projects/helios pnpm -C ~/projects/helios/frontend run tsgo`

**Manual Verification:**
- [ ] Changes are minimal and don't over-engineer

---

## Testing Strategy

### Unit Tests:
- Not applicable - this is a type-only change with no runtime behavior

### Integration Tests:
- Existing Cypress tests should continue to work unchanged
- Type checking is the verification mechanism

### Manual Testing Steps:
1. Run `direnv exec ~/projects/helios pnpm -C ~/projects/helios/frontend run tsgo` - should pass
2. Run `direnv exec ~/projects/helios pnpm -C ~/projects/helios/frontend run tsc` - should pass

## Performance Considerations

None - this is a compile-time type annotation change only.

## Migration Notes

None - no runtime changes, no API changes.

## References

- Research: `~/.claude/thoughts/research/2026-01-30_typescript-7-preview-cypress-type-issues.md`
- Affected file: `frontend/cypress/support/commands.ts:22,1014-1039`
- Cypress types: `node_modules/cypress/types/net-stubbing.d.ts`

---

## Changelog

| Date | Task | Claude Code Task ID | Changes |
|------|------|---------------------|---------|
| 2026-01-30 | - | - | Initial plan created |
