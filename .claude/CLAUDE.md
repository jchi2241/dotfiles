# Justin's Agent Instructions

## Voice & Writing Style

When writing anything on Justin's behalf (Slack messages, PRs, GitHub review comments, wiki pages, proposals), follow the profile in `~/.claude/VOICE.md`.

## System & Environment

- jchi uses Linux (Ubuntu 24.04 LTS Noble) as their laptop OS. Tailor installation instructions and system-specific answers to Linux accordingly.
- For clipboard operations, use `wl-copy` (Wayland) instead of `xclip` or `xsel`.
- User's name is Justin Chi. When searching git commits, use author filters like: --author="jchi" or --author="Justin Chi" (email: [jchi@memsql.com](mailto:jchi@memsql.com))
- When asked to fix Claude settings, commands, or skills, look in `~/.claude/` rather than `.claude/`.

## General Guidelines

- **Evidence-Based Reasoning:** Ground all findings and decisions on concrete evidence from search, grep, tests, and tools.
- **No Shortcuts (Instant Execution):** Prioritize quality, simplicity, robustness, and maintainability over development cost. Do not take shortcuts based on human-like time constraints. You write code instantly; always choose the correct, long-term architectural solution.
- **One Sentence Per Line:** Put each full sentence on its own line when writing or editing long Markdown files.

## Workflows

For a Helios or Analyst coding task, or when the user says `/chi-mode`, read `~/.claude/skills/chi-mode/SKILL.md` and pick a playbook.

## Subagent models

Skills name a model role, written as model role `<name>`, instead of a model. Pass the role's value as the Task `model`.

<!-- models:begin -->
| Role | Model | Used for |
|---|---|---|
| `explorers` | `cursor-grok-4.6-high` | Fast read-only fan-out: `how` explorers, `why` investigators |
| `judgment` | `claude-opus-5-5-medium` | Synthesis and prose: `how` explainer, `why` synthesizer, `/reflect` judgment |
| `contrast` | `gpt-5.6-sol-xhigh` | A second family for a different read: `/reflect` tooling |
| `code workers` | `cursor-grok-4.6-high` | Implementers and fixers in `/implement-plan` |
| `reviewers` | `claude-opus-5-5-medium` | Pre-flight, spec, code-quality, and integration reviewers in `/implement-plan` |
| `panel` | `claude-opus-5-5-medium`, `gpt-5.6-sol-xhigh`, `cursor-grok-4.6-high` | One subagent per entry: `arena` and `architect` runners, `interrogate` reviewers, and the `arena` judge pool |
<!-- models:end -->

- `inherit` as a value: omit the Task `model` so the subagent runs on the parent's model.
- In Claude Code, pass the family alias (`opus`, `sonnet`, `haiku`) for a Claude value, and omit `model` for any other family.
- If the Task tool rejects a value, use the closest available model of the same family and say which one you used. Then run `/setup-models`.

## Principles

When a trigger below matches, read the linked file in full before you act. It holds the rule. In your reply, name each principle that changed a decision.

| Principle | Trigger | File |
|---|---|---|
| Laziest correct solution | Writing, refactoring, or reviewing any code | `~/.claude/skills/ponytail/SKILL.md` |
| Readable code | Writing or reviewing any code | `~/.claude/skills/principle-readable-code/SKILL.md` |
| Strong invariants | Designing types, schemas, signatures, columns, API shapes | `~/.claude/skills/principle-strong-invariants/SKILL.md` |
| Fail early | Error handling, validation, defaults, fallbacks, retries | `~/.claude/skills/principle-fail-early/SKILL.md` |
| Refactor over accumulation | Adding a conditional, wrapper, flag, or fallback to make new work fit old code | `~/.claude/skills/principle-refactor-over-accumulation/SKILL.md` |
| Make operations idempotent | Backfills, install hooks, data migrations, retries, upserts, setup scripts | `~/.claude/skills/principle-make-operations-idempotent/SKILL.md` |
| Build the lever | More than a few obvious edits, or the same change across many files, rows, or repos | `~/.claude/skills/principle-build-the-lever/SKILL.md` |
| Fix root causes | A bug, failing test, or unexpected behavior | `~/.claude/skills/principle-fix-root-causes/SKILL.md` |
| Only referenced code | Deciding what goes into a PR or commit | `~/.claude/skills/principle-only-referenced-code/SKILL.md` |
| Test behavior, not implementation | Writing, changing, or keeping a test | `~/.claude/skills/principle-test-behavior-not-implementation/SKILL.md` |
| Prove it works | Before saying a task is done | `~/.claude/skills/principle-prove-it-works/SKILL.md` |

To add a principle: create `~/.claude/skills/principle-<name>/SKILL.md` with `disable-model-invocation: true`, then add one row here.

