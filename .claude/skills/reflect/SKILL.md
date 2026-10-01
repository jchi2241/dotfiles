---
name: reflect
description: Turn corrections and friction from the current session into proposed edits to Justin's personal skills, applied only after approval. Use for /reflect.
disable-model-invocation: true
---

# Reflect

Mine the current session for durable learnings and route each one to an edit in `~/.claude`.
Skip the run when the session was trivial or every skill used worked as written. One-offs are not learnings.

## 1. Find the transcript

Use the active workspace's transcript only. Never read another project's chats.

- Cursor: the system prompt names the `agent-transcripts/` directory. Files are `<uuid>/<uuid>.jsonl`.
- Claude Code: `~/.claude/projects/<workspace-slug>/<uuid>.jsonl`.

Take the newest file whose first user message matches this session's opening prompt. If none matches, write a tight digest of the session and pass that instead.

## 2. Two reviewers in parallel

One message, two `Task` calls, `subagent_type: generalPurpose`, not readonly (reviewers need MCPs to look up tickets and threads the transcript cites). Fill [`references/reviewer-prompt.md`](references/reviewer-prompt.md) with the transcript path and the lens.

| Lens | Model | Looks for |
|---|---|---|
| Judgment | model role `judgment` | Corrections from Justin, the principle beneath them, second-order effects missed, checks that were self-reported instead of proven |
| Tooling | model role `contrast` | Commands, flags, paths, and quirks that cost time, and context Justin pasted that an MCP or skill could have fetched |

## 3. Synthesize

Do this yourself. Read each target file before accepting a finding against it.

Accept a finding only when it is:

- **Durable:** still true after paths, SHAs, and versions change.
- **Decision-changing:** a future agent acts differently because of it.
- **Not already covered.** If the guidance exists but was skipped, propose moving or sharpening it, not adding a duplicate.
- **About something the session used,** or a skill that should have triggered and didn't.

Move a finding to Backlog when a script, hook, or lint can enforce it. Prefer extending `~/.dotfiles/scripts/check-claude-skills.py` over adding prose.

Route each accepted finding to its single owner:

| Kind of learning | Home |
|---|---|
| A rule for writing code that applies across tasks | A `principle-*` skill, plus its row in the `~/.claude/CLAUDE.md` index |
| A step in a kind of work | That `chi-mode` playbook |
| How to cut PRs, migrations, rollout order | `chi-mode/references/helios-prs.md` |
| A tool's mechanics | That tool skill or command |
| A skill that should have fired and didn't | That skill's `description` |
| Always-on behavior | `~/.claude/CLAUDE.md` |
| A Helios repo skill under `agent/skills/` | Not editable here. List it as a suggested Helios PR. |

Propose a new skill only when no existing home fits and the pattern recurred.

## 4. Approve

Show the table below, then ask with `AskQuestion` (multi-select, one option per row). Apply nothing until Justin picks.

| # | Problem | Proposal | Home |
|---|---|---|---|

Under it, list rejected findings with a one-word reason (`drift`, `covered`, `one-off`, `unused`, `structural`) and the Backlog items.

## 5. Apply

- Make each approved edit. A new skill or a section longer than about ten lines goes through `create-skill`.
- Append Backlog items to `~/.claude/thoughts/skills-backlog.md` with the date.
- Run `~/.dotfiles/scripts/check-claude-skills.py` and fix what it reports.
- Offer `/dotfiles-sync`. Do not commit without Justin's go.

**Reply:** edits applied (path and one line each), Backlog items filed, suggested Helios PRs, and the checker result.
