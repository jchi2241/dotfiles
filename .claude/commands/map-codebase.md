---
description: Build a codebase map documenting architecture and patterns
argument-hint: [topic or area to map]
model: opus
---

# Map Codebase

Build a codebase map and save it to `~/.claude/thoughts/research/` as markdown.

**Filename format:** `YYYY-MM-DD_<brief-one-liner-indicating-topic-of-research>.md`

The map should contain all necessary information for subsequent workflow steps (spec, plan).

---

## CRITICAL CONSTRAINTS

**YOUR ONLY JOB IS TO DOCUMENT AND EXPLAIN THE CODEBASE AS IT EXISTS TODAY**

- DO NOT suggest improvements or changes unless the user explicitly asks for them
- DO NOT perform root cause analysis unless the user explicitly asks for them
- DO NOT propose future enhancements unless the user explicitly asks for them
- DO NOT critique the implementation or identify problems
- DO NOT recommend refactoring, optimization, or architectural changes
- ONLY describe what exists, where it exists, how it works, and how components interact

**You are creating a technical map/documentation of the existing system.**

---

## Output Format

The research report filename and path will be used by subsequent workflow steps:
- **create-spec** will use this map for requirements context and architectural context
- **create-plan** and **implement-plan** agents may read this for context

Always include the full path in your response so the user can easily reference it in the next step.

---

## Research Report Structure

The report MUST begin with YAML frontmatter for indexing and searchability:

```yaml
---
type: research
title: <Descriptive Title>
project: <project name, e.g., helios, heliosai, singlestore-nexus>
area: <codebase area, e.g., frontend/intelligence, cmd/nova-gateway>
tags: [tag1, tag2, tag3]  # relevant keywords for searching
date: YYYY-MM-DD
status: draft | complete
---
```

After the frontmatter, include (as relevant to the topic):

1. **Overview** - Brief summary of what this area/feature does
2. **Key Components** - Files, services, classes involved with their paths
3. **Data Flow** - How data moves through the system
4. **API Contracts** - Endpoints, request/response shapes, protocols
5. **Dependencies** - What this component depends on and what depends on it
6. **Configuration** - Environment variables, feature flags, settings
7. **Code References** - Specific file paths and line numbers for key logic

---

## Instructions

1. Thoroughly explore the codebase using Glob, Grep, and Read tools
2. Trace connections between components
3. Document concrete file paths and line numbers
4. Write the report in clear, factual prose
5. Save to `~/.claude/thoughts/research/YYYY-MM-DD_<topic>.md`

---

## After Completing Map

When you finish the map, end your response with:

```
## Map Complete

Report saved to: `~/.claude/thoughts/research/YYYY-MM-DD_<topic>.md`

**Next step:** To define what to build and how, based on this map:
/create-spec [describe what you want to build], referencing ~/.claude/thoughts/research/YYYY-MM-DD_<topic>.md
```

---

## User's Mapping Request

$ARGUMENTS
