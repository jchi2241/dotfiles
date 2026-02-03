# TypeScript 7 Compatibility Fix Handoff

## Summary

Fixed TypeScript 7 preview compatibility errors in `frontend/cypress/support/commands.ts`. One pre-existing error remains in `@single-js/common`.

## What Was Fixed

### Problem
TypeScript 7 enforces package.json `exports` fields strictly. The import `cypress/types/net-stubbing` failed because Cypress doesn't export this path.

### Solution
1. Removed the failing import
2. Added a minimal local interface for the request type
3. Added explicit return type annotations to prevent type inference from leaking internal Cypress types

### Files Changed
- `frontend/cypress/support/commands.ts`

### Verification
```bash
make frontend-tsc      # TS 5.4.2 - passes
make frontend-tsc-go   # TS 7 - Cypress errors fixed
```

---

## Remaining Issue: @single-js/common SqlString

### Error
```
node_modules/@single-js/common/src/mysqljs/lib/protocol/SqlString.js(1,1): error TS2742:
The inferred type of '(Missing)' cannot be named without a reference to
'@single-js/common/node_modules/@types/sqlstring'. This is likely not portable.
A type annotation is necessary.
```

### Root Cause
Same class of issue - TypeScript 7's stricter module resolution can't resolve `@types/sqlstring` through the package's exports field.

### Location
- **Error file**: `single-js/common/src/mysqljs/lib/protocol/SqlString.js`
- **Package**: `@single-js/common`
- **Dependency**: `@types/sqlstring`

### Investigation Steps
1. Check `single-js/common/package.json` for how `@types/sqlstring` is declared
2. Look at `SqlString.js` to see what type is being inferred
3. Either:
   - Add explicit type annotations to avoid inference
   - Fix the package.json exports/typesVersions configuration
   - Update how @types/sqlstring is referenced

### Likely Fix Pattern
Similar to the Cypress fix - add explicit type annotations to functions in `SqlString.js` (or its `.d.ts` file) to prevent TypeScript from needing to infer types that reference the internal @types/sqlstring path.

### Commands to Verify
```bash
# Check if fix works
make frontend-tsc-go

# Ensure no regression
make frontend-tsc
```
