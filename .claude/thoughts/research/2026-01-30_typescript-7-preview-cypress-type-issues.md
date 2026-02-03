---
type: research
title: TypeScript 7 Preview Cypress Type Issues
project: helios
area: frontend/cypress
tags: [typescript, cypress, type-checking, module-resolution, typescript-7]
date: 2026-01-30
status: complete
related_plans: []
---

# TypeScript 7 Preview Cypress Type Issues

## Overview

The Helios frontend project is testing TypeScript 7.0.0 preview (`@typescript/native-preview`: 7.0.0-dev.20260116.1) alongside the stable TypeScript 5.4.2. The preview version is accessible via the `tsgo` command, which reveals two type errors in Cypress test files that don't occur with TypeScript 5.

## Key Components

### TypeScript Configuration
- **Main config**: `/home/jchi/projects/helios/frontend/tsconfig.json`
- **Base config**: `/home/jchi/projects/helios/single-js/common/tsconfig.base.json`
- **Cypress config**: `/home/jchi/projects/helios/frontend/cypress/tsconfig.json`
- **TypeScript 5.4.2**: Installed as main TypeScript version
- **TypeScript 7.0.0-dev**: Installed as `@typescript/native-preview`

### Affected Files
- `/home/jchi/projects/helios/frontend/cypress/support/commands.ts:22` - Module resolution error
- `/home/jchi/projects/helios/frontend/cypress/support/commands.ts:1032` - Implicit any type error

### Package Versions
- **Cypress**: 13.10.0
- **TypeScript stable**: 5.4.2
- **TypeScript preview**: 7.0.0-dev.20260116.1

## Data Flow

### Module Resolution Process

TypeScript 7 uses stricter module resolution that respects the `exports` field in package.json:

1. **Import statement**: `import type { CyHttpMessages } from "cypress/types/net-stubbing"`
2. **TypeScript 7 resolution**:
   - Checks `cypress/package.json` exports field
   - Finds no export for `./types/net-stubbing`
   - Resolution fails with TS2307 error
3. **TypeScript 5 resolution**:
   - Falls back to file-based resolution
   - Finds `/node_modules/cypress/types/net-stubbing.d.ts`
   - Resolution succeeds

## API Contracts

### Cypress Package Structure

The Cypress package.json (`/home/jchi/projects/helios/frontend/node_modules/cypress/package.json`) defines explicit exports:

```json
"exports": {
  ".": { "types": "./types/index.d.ts", ... },
  "./vue": { ... },
  "./react": { ... },
  "./react18": { ... },
  // No export for "./types/net-stubbing"
}
```

### Type Definitions

The `CyHttpMessages` namespace exists in `/node_modules/cypress/types/net-stubbing.d.ts`:
- Exports `CyHttpMessages` namespace at line 74
- Contains interfaces for HTTP request/response handling
- Referenced via triple-slash directive in `/node_modules/cypress/types/index.d.ts:29`

## Dependencies

### Import Dependencies
- **Direct usage**: Only `cypress/support/commands.ts` imports `CyHttpMessages`
- **Type usage**: Used for typing GraphQL interceptor functions
- **Function affected**: `interceptRequest()` at line 1014-1020

### Build System
- **Make target**: `make frontend-tsc-go` runs TypeScript 7 preview
- **NPM script**: `pnpm run tsgo` executes `npx tsgo`
- **Regular check**: `pnpm run tsc` uses TypeScript 5.4.2 (passes without errors)

## Configuration

### TypeScript Compiler Options
The frontend uses:
- `moduleResolution: "node"`
- `module: "es2020"`
- `target: "es2020"`
- Custom path mappings for internal packages

### Execution Commands
- **TypeScript 5**: `direnv exec ~/projects/helios pnpm run tsc`
- **TypeScript 7**: `direnv exec ~/projects/helios pnpm run tsgo`

## Code References

### Error Locations

1. **Module Resolution Error** - `/home/jchi/projects/helios/frontend/cypress/support/commands.ts:22`
   ```typescript
   import type { CyHttpMessages } from "cypress/types/net-stubbing";
   ```
   Error: `TS2307: Cannot find module 'cypress/types/net-stubbing' or its corresponding type declarations.`

2. **Implicit Any Error** - `/home/jchi/projects/helios/frontend/cypress/support/commands.ts:1032`
   ```typescript
   req.on("response", (res) => {
       Cypress.log({
           name: `[GraphQL-response:${label}]  ${operationName}`,
           message: processArg(res.body),
       });
   });
   ```
   Error: `TS7006: Parameter 'res' implicitly has an 'any' type.`
   - The `res` parameter loses its type because `CyHttpMessages` import fails

### Type Definition Location
- **File exists**: `/home/jchi/projects/helios/node_modules/.pnpm/cypress@13.10.0/node_modules/cypress/types/net-stubbing.d.ts`
- **Namespace export**: Line 74 exports `CyHttpMessages` namespace
- **Type reference**: `/node_modules/cypress/types/index.d.ts:29` includes `/// <reference path="./net-stubbing.d.ts" />`

### Module Resolution Trace
TypeScript 7's trace shows it:
1. Attempts path mapping resolution first
2. Checks node_modules directories
3. Looks for export in package.json `exports` field
4. Fails because `./types/net-stubbing` is not in exports map

## Research Complete

Report saved to: `~/.claude/thoughts/research/2026-01-30_typescript-7-preview-cypress-type-issues.md`

**Next step:** To create an implementation plan based on this research:
/create-plan Fix TypeScript 7 preview compatibility issues with Cypress types, referencing ~/.claude/thoughts/research/2026-01-30_typescript-7-preview-cypress-type-issues.md