---
description: Generate a complete session handoff for seamless continuation
argument-hint: [focus area or intent, e.g. "continue debugging", "ready for review"]
model: opus
---

# Session Handoff

Generate a complete handoff document that allows a new Claude session to seamlessly continue this work.

**Output location:** `~/.claude/thoughts/handoffs/YYYY-MM-DD_HH-MM_<brief-topic>.md`

---

## Core Principle

The handoff must be **complete and uncompressed**. A new session reading this document should have full context without needing to re-explore files or re-discover decisions. Include actual code snippets, exact file paths with line numbers, and concrete details—not summaries or references.

---

## Handoff Document Structure

```markdown
---
type: handoff
created: YYYY-MM-DD HH:MM
project: <project name>
working_directory: <pwd>
intent: <user's stated intent if provided, otherwise "continue">
---

# Session Handoff: <Brief Title>

## Goal
<What we're trying to accomplish. Be specific about the end state.>

## Current State
<Where we are right now. What's done, what's in progress.>

## Key Files

### Modified
<List each file modified with:>
- `path/to/file.ts:line` - <what was changed and why>

### Examined (Unmodified)
<Files read for context that inform decisions:>
- `path/to/file.ts` - <why it matters>

## Decisions Made
<Each decision with rationale. Format:>
- **Decision:** <what we decided>
  - **Why:** <reasoning>
  - **Alternatives considered:** <what else was possible>

## Technical Context
<Paste actual code snippets, data structures, API shapes, or patterns discovered.
Do NOT say "see file X" - include the actual content.>

## Next Steps
<Ordered list of what to do next. Be specific.>
1. <step>
2. <step>

## Open Questions / Blockers
<Anything unresolved that needs attention>

## Commands / Build Info
<Any relevant commands, test results, or build states>
```

---

## Instructions

1. **Reflect on the entire conversation** - Review all context, decisions, and progress
2. **Gather concrete details** - Include actual code, not references
3. **Be explicit about state** - What works, what doesn't, what's partially done
4. **Preserve rationale** - Why decisions were made matters as much as what was decided
5. **Create the handoff file** - Save to the thoughts/handoffs directory

---

## Intent Modifier

If the user provides an intent argument, adjust the handoff focus:

| Intent | Emphasis |
|--------|----------|
| `continue` | Next steps and current state (default) |
| `debug` | Error details, stack traces, what's been tried |
| `review` | Changes made, rationale, testing status |
| `handoff-to-human` | High-level summary, key decisions, what needs human input |
| `pause` | State preservation, how to resume, dependencies |
| Custom | Tailor emphasis to the stated intent |

---

## After Generating Handoff

End your response with:

```
## Handoff Complete

Saved to: `~/.claude/thoughts/handoffs/YYYY-MM-DD_HH-MM_<topic>.md`

**To continue in a new session:**
Start a new Claude session and paste the contents of the handoff file, or run:
cat ~/.claude/thoughts/handoffs/YYYY-MM-DD_HH-MM_<topic>.md | pbcopy
```

---

## User Intent

$ARGUMENTS
