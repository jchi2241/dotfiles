---
description: Define what to build and how - product requirements and technical spec
argument-hint: [feature description] [map path]
model: opus
---

# Create Spec

Create a combined product requirements and technical specification document. Save it to `~/.claude/thoughts/specs/` as markdown.

**Filename format:** `YYYY-MM-DD_<brief-one-liner-indicating-topic>.md`

Ensure the output directory exists: `mkdir -p ~/.claude/thoughts/specs/`

---

## CRITICAL CONSTRAINTS

**YOUR JOB IS TO DEFINE WHAT TO BUILD AND HOW TO BUILD IT.**

This is a two-part process:
1. **Requirements (WHAT):** Define the problem, users, scope, and acceptance criteria
2. **Technical Design (HOW):** Propose approaches, evaluate trade-offs, detail the chosen approach

- DO NOT fill in gaps with guesses — if something is ambiguous, call it out and ask
- Challenge vague requirements — "make it faster" is not a requirement; "reduce p95 latency to under 200ms" is
- DO propose multiple technical approaches and evaluate trade-offs honestly
- DO reference concrete code locations from the map (file paths, line numbers) in the technical design
- DO NOT pick an approach without presenting options to the user first
- DO NOT proceed past approach selection without explicit user approval
- If you find a requirement that is technically infeasible or much harder than expected, flag it — don't silently work around it

**You are producing a document that an implementation plan can be written against. By the time this spec is finalized, all design decisions should be made.**

---

## Input Context

If the user references a map/research document, you MUST read it first:
```
Read ~/.claude/thoughts/research/YYYY-MM-DD_<topic>.md
```

Use the map to understand the current system. The map tells you where you are; the spec defines where you want to go and how to get there.

If no map is referenced, explore the codebase as needed to establish context.

---

## Spec Process

### Step 1: Understand the Problem

Read any referenced documents. Then ask the user clarifying questions if the intent is unclear. Do not proceed until you understand:
- What pain point or opportunity this addresses
- Who the users/stakeholders are
- What success looks like

### Step 2: Present Requirements Draft

Write a complete first draft of the requirements section and present it inline. Explicitly invite feedback:

```
Here's the requirements draft. I want to pressure-test this before moving to technical design:

1. Are the scope boundaries correct? Anything I've included that should be out, or excluded that should be in?
2. Do the acceptance criteria capture what "done" actually means for you?
3. Are there user stories I'm missing?
4. Any open questions you can resolve now?
```

**Wait for user feedback before proceeding to technical design.**

### Step 3: Propose Technical Approaches

After requirements are solid, present 2-3 distinct technical approaches. For each:

```
### Approach [N]: [Name]

**Summary:** [1-2 sentences]

**How it works:**
[Brief description of the architecture and key decisions]

**Code touchpoints:** (from the map)
- `path/to/file.ext:line` — [what changes and why]

**Trade-offs:**
| Dimension | Assessment |
|-----------|------------|
| Complexity | [Low/Med/High] — [why] |
| Risk | [Low/Med/High] — [why] |
| Performance | [impact] |
| Maintainability | [impact] |

**Pros:** [bullets]
**Cons:** [bullets]
```

End with a recommendation and rationale, but make clear this is a suggestion:

```
**My recommendation:** Approach [N] because [reasoning].

Which approach do you want to go with? Or should I explore a different direction?
```

**WAIT for user to pick an approach. Do not proceed until they decide.**

### Step 4: Flesh Out the Chosen Approach

After the user picks an approach, write the full technical design covering:
- Architecture and component design
- Data models and schema changes
- API contracts (request/response shapes, error codes)
- Migration strategy (if applicable)
- Edge cases and error handling
- Integration points with existing code (specific file paths from the map)

Present and invite pushback:

```
Here's the detailed technical design for Approach [N]. Review and let me know:
- Anything over-engineered or under-engineered?
- Edge cases I missed?
- Anything that doesn't sit right?
```

**Wait for feedback. Iterate as needed.**

### Step 5: Finalize and Save

Combine the finalized requirements and technical design into a single document. Save to `~/.claude/thoughts/specs/YYYY-MM-DD_<topic>.md`.

---

## Spec Output Structure

The spec MUST begin with YAML frontmatter:

```yaml
---
type: spec
title: <Descriptive Title>
project: <project name>
area: <relevant area>
tags: [tag1, tag2, tag3]
date: YYYY-MM-DD
status: draft | complete
research_doc: <path to map, or null>
---
```

After the frontmatter:

### Part 1: Requirements

1. **Problem Statement** — What problem are we solving? Why now? What's the cost of not solving it?
2. **Users & Stakeholders** — Who is affected? Who are the primary users?
3. **User Stories / Use Cases** — Concrete scenarios: "As a [role], I want [thing] so that [reason]"
4. **Requirements** — Specific, testable requirements (functional and non-functional)
5. **Acceptance Criteria** — How do we know this is done? What does the user see/experience?
6. **Scope Boundaries**
   - **In scope:** [explicit list]
   - **Out of scope:** [explicit list with brief rationale for each exclusion]
7. **Open Questions** — Unresolved ambiguities that need answers before implementation
8. **Dependencies & Risks** — External dependencies, timeline risks, unknowns

### Part 2: Technical Design

9. **Approach Decision** — Which approach was chosen, why, and what was rejected
10. **Architecture** — Component design, data flow, system interactions
11. **Data Models** — Schema changes, new types, modified types (with actual type definitions)
12. **API Contracts** — Endpoints, request/response shapes, error codes
13. **Migration Strategy** — How to get from current state to desired state safely
14. **Edge Cases & Error Handling** — What can go wrong and how we handle it
15. **Code References** — Specific files and line numbers from the map that will be modified
16. **Open Technical Questions** — Anything still unresolved (should be minimal by finalization)

---

## After Completing Spec

When you finish the spec, end your response with:

```
## Spec Complete

Saved to: `~/.claude/thoughts/specs/YYYY-MM-DD_<topic>.md`

**Next step:** To create the implementation plan:
/create-plan [topic], referencing spec at ~/.claude/thoughts/specs/YYYY-MM-DD_<topic>.md
```

---

## User's Spec Request

$ARGUMENTS
