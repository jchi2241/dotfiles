---
description: Dialogue-driven exploration to surface constraints before specing
argument-hint: [problem or fuzzy feature idea]
model: opus
---

# Brainstorm

Explore a problem or feature idea through back-and-forth dialogue *before* committing to a spec. The goal is to surface constraints, tradeoffs, and unknowns — especially when you're unsure where the limitations are.

Save the output to `~/.claude/thoughts/briefs/` as markdown.

**Filename format:** `YYYY-MM-DD_<brief-one-liner-indicating-topic>.md`

Ensure the output directory exists: `mkdir -p ~/.claude/thoughts/briefs/`

---

## CRITICAL CONSTRAINTS

**YOUR JOB IS TO FIGURE OUT WHAT THE REAL PROBLEM IS AND WHERE THE WALLS ARE.**

- DO NOT jump to solutions or pick an approach
- DO NOT produce a spec-grade artifact — that's `/create-spec`'s job
- DO NOT write production code, scaffolding, or migrations
- DO ask questions one at a time; prefer multiple-choice when possible
- DO research aggressively and in parallel before asking questions that research can answer for you
- DO surface constraints the user hasn't thought of — system limits, conflicting patterns, prior decisions, external dependencies
- DO flag when the idea is too big and should be decomposed before going further
- DO flag when the idea is small enough that brainstorming is overkill and suggest jumping straight to `/create-spec`

**You are producing a brief: a short document that frames the problem, maps the solution space, names the tradeoffs, and lists open questions — so that `/map-codebase` and `/create-spec` have a sharp target.**

---

## Scope Check (First Response)

Before anything else, assess the request:

| Signal | Action |
|--------|--------|
| Multiple independent subsystems in one ask | Flag it. Suggest decomposing into sub-brainstorms. |
| Crisp, well-scoped, user already knows what they want | Suggest skipping straight to `/create-spec`. |
| One fuzzy feature/problem with unknown limits | Proceed with brainstorming. |
| Pure bug or small fix | Suggest `/create-plan` directly or just fix it. |

State your read in one paragraph, then ask the user to confirm or redirect before going deeper.

---

## Research Phase — Go Hard

**Once the user confirms this is the right problem to brainstorm, research aggressively before asking refinement questions.** Research that the user has to answer for you wastes their time; research you do yourself sharpens the questions you ask.

### Think first, then parallelize

Spend real thinking effort on: *What do I need to know to ask the user good questions?* Produce a list of concrete research threads — each one a self-contained question that a subagent can answer without further input from you.

Then spawn subagents **in parallel** (multiple Agent tool calls in a single message). Typical research threads for a brainstorm:

- **Codebase threads** (use `Explore` subagent, `thorough` level):
  - "How does X currently work? Files, entry points, data flow."
  - "Where else in the codebase is pattern Y used? What are the variants?"
  - "What are the integration points for Z? What calls it, what it calls."
  - "Are there existing partial implementations, feature flags, or abandoned branches related to this?"
  - "What tests exist in this area and what do they cover?"

- **Cross-repo threads** (if the problem spans services — see CLAUDE.md for repo map):
  - Spawn a separate Explore agent per repo. Don't make one agent hop repos.

- **Web / external threads** (use `general-purpose` with WebSearch/WebFetch):
  - Prior art: "How do tools like {competitor, library, spec} handle this?"
  - Protocol/standard details when touching OAuth, WebSockets, streaming protocols, etc.
  - Library capabilities/limitations when the problem might be solved by something off-the-shelf.
  - **Skip web research if the problem is purely internal.** Don't make work for yourself.

### Instructions for subagents

Each subagent prompt should:
- State the brainstorm topic in one sentence so they have context
- Ask a specific question with clear scope
- Request concrete citations (file paths, line numbers, URLs)
- Cap the response length (e.g., "under 400 words") to keep results digestible
- Ask for *facts and constraints*, not recommendations — recommendations are your job after synthesis

**Do not delegate synthesis.** Once subagents return, read their findings yourself and form your own picture. Then write a short "what I found" message to the user before asking your first refinement question.

---

## Dialogue Phase

After you've presented the research summary, enter the one-question-at-a-time loop.

**Principles:**
- **One question per message.** If a topic needs breadth, break it into multiple turns.
- **Prefer multiple-choice.** Easier to answer, forces you to have formed a hypothesis. Open-ended is fine when the space is genuinely unbounded.
- **Lead with a hypothesis.** "I'm leaning toward A because X — does that match your intent, or am I missing something?"
- **Surface constraints the user didn't mention.** If your research found a system limit, existing pattern, or conflicting decision, name it before asking the user to choose.
- **Go back when needed.** If an answer reveals an earlier assumption was wrong, say so and reopen that thread. Don't plow forward.
- **YAGNI ruthlessly.** Push back on features that aren't motivated by the stated problem.

**Topics to cover, roughly in order:**
1. Problem framing — what pain point, for whom, cost of not solving it
2. Success criteria — what does "working" look like; what's measurable
3. Non-goals — what you're explicitly *not* trying to do
4. Constraints — performance, compat, timeline, team context
5. Solution space — 2–3 candidate approaches with tradeoffs (present, don't pick)
6. Open questions — what still needs research, prototyping, or a stakeholder decision

When you've covered enough to write a useful brief, stop asking and draft.

---

## Writing the Brief

Save to `~/.claude/thoughts/briefs/YYYY-MM-DD_<topic>.md`.

### Frontmatter

```yaml
---
type: brief
title: <Descriptive Title>
project: <project name, e.g., helios, heliosai, singlestore-nexus>
area: <relevant area>
tags: [tag1, tag2, tag3]
date: YYYY-MM-DD
status: draft | complete
---
```

### Structure

1. **Problem** — what we're trying to solve, for whom, and why now. 3–6 sentences.
2. **What We Know** — facts surfaced during research, with citations (`path/to/file:line`, URLs). Bullet list.
3. **What's Unknown** — questions research couldn't resolve; things that need a prototype, stakeholder input, or data we don't have yet.
4. **Constraints** — hard limits (performance, compat, auth, deadlines) discovered or confirmed during dialogue.
5. **Candidate Approaches** — 2–3 options with one-paragraph summary + pros/cons each. **Do not pick one here.** That's the spec's job.
6. **Recommended Next Step** — one of:
   - `/map-codebase <topic>` to formalize codebase understanding before specing (typical)
   - `/create-spec <topic>` if the brief already captures enough context
   - Decompose into sub-briefs if the problem is still too big
   - Stop — the brainstorm revealed this isn't worth doing

---

## After the Brief

End your response with:

```
## Brainstorm Complete

Brief saved to: `~/.claude/thoughts/briefs/YYYY-MM-DD_<topic>.md`

**Recommended next step:** [one of the four options above, with the concrete command]
```

---

## Key Principles

- **Research before asking** — don't spend the user's attention on questions tools can answer
- **Parallelize ruthlessly** — multiple subagent calls in a single message, not sequential
- **One question at a time** during dialogue
- **Surface, don't decide** — name the tradeoffs; let the spec pick
- **Know when to stop** — a brief that's 80% sharp beats a spec that's 40% right

---

## User's Brainstorm Request

$ARGUMENTS
