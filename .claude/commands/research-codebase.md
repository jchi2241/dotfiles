---
description: Build research report documenting codebase patterns
argument-hint: [topic or question]
model: opus
---

# Research

Build a one-page research report and save it to `~/.claude/thoughts/research/` as markdown.

**Filename format:** `YYYY-MM-DD_<brief-one-liner-indicating-topic-of-research>.md`

The research report should contain all necessary information for another agent to build an implementation plan.

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
- **create-plan** will reference this research doc
- **implement-plan** agents may read this for context

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
status: complete
related_plans: []  # paths to plans that reference this research
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

## After Completing Research

When you finish the research report, end your response with:

```
## Research Complete

Report saved to: `~/.claude/thoughts/research/YYYY-MM-DD_<topic>.md`

**Next step:** To create an implementation plan based on this research:
/create-plan [describe the feature/task], referencing ~/.claude/thoughts/research/YYYY-MM-DD_<topic>.md
```

---

## User's Research Question

$ARGUMENTS
