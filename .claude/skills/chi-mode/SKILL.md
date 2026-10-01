---
name: chi-mode
description: Justin's way of doing Helios and Analyst work. Routes each task to a playbook: feature, small change, UI change, bug fix, investigation, PR review, incident, or hotfix. Use for /chi-mode or "work in my style".
disable-model-invocation: true
---

# Chi mode

You own the spec, the design, the plan, and the review.
Delegate code to subagents with complete briefs.
The operator owns product calls and every gate listed below.

## Start

1. Classify the task and pick one row.
2. Say the playbook in one sentence.
3. Open a todo list whose first items are that playbook's steps.

| Task | Playbook |
|---|---|
| PRD-backed feature, story, or epic. More than one PR. | [`playbooks/feature.md`](playbooks/feature.md) |
| One backend or tooling PR. The approach is clear from the code. | [`playbooks/small-change.md`](playbooks/small-change.md) |
| One portal UI PR: a feature or a UI bug | [`playbooks/ui-change.md`](playbooks/ui-change.md) |
| Bug, failing test, or unexpected behavior | [`playbooks/bug-fix.md`](playbooks/bug-fix.md) |
| A question answered with evidence, not code: how, why, what breaks | [`playbooks/investigate.md`](playbooks/investigate.md) |
| Review a teammate's PR or stack | [`playbooks/pr-review.md`](playbooks/pr-review.md) |
| PagerDuty page, production error spike, outage | [`playbooks/incident.md`](playbooks/incident.md) |
| Urgent production fix outside the release | [`playbooks/hotfix.md`](playbooks/hotfix.md) |
| An open PR must stay green | Helios `agent/skills/pr-babysitter/SKILL.md` |

If a single-PR task grows past one PR, needs a migration, changes GraphQL that gateways read, or raises a product question, switch to `feature.md`.

To add a workflow: write `playbooks/<name>.md` as numbered steps that name the skills they run, then add one row here.

## Gates (always stop and ask)

- Creating a branch, commit, push, or PR, unless the operator asked for it in this session.
- Any request that says "don't make changes yet" or "don't take action yet". Stay read-only.
- Creating, editing, or moving Jira tickets between sprints.
- Editing the PRD body. Propose wording in chat instead.
- Applying or merging a migration.
- Enabling a codegate, running a backfill, or anything else that changes production data.
- A product or preference call that no experiment can settle. Use `AskQuestion` with a recommended option first.

Reversible local work proceeds without asking: reading, research, local edits to thoughts files, prototypes on a scratch branch.

## Sources of truth

- The PRD (Google Doc) holds product intent. The team agrees on it before work starts.
- The spec holds behavior. If the spec and the PRD disagree, stop and list the gaps.
- The design document holds the shapes that cross PRs.
- The plan holds phases, PRs, tasks, and rollout order. Implementation details live here and in the spec.
- Jira tracks outcomes. The story is the finest-grained ticket. Several PRs share one story key.

Artifacts live under `~/.claude/thoughts/`. Run `/workflow` to see the chain.

| Artifact | Made by | Path |
|---|---|---|
| Spec | `/create-spec` | `specs/YYYY-MM-DD_<topic>.md` |
| Design | `architect` | `plans/YYYY-MM-DD_<topic>-design.md` |
| Plan | `/create-plan` | `plans/YYYY-MM-DD_<topic>.md` |

## Who owns what

Each concern has one owner. Do not restate an owner's rules here.

| Concern | Owner |
|---|---|
| Stages of the work | The commands: `/create-spec`, `/create-plan`, `/implement-plan`, `/review-implementation` |
| How to cut work into PRs | [`references/helios-prs.md`](references/helios-prs.md) |
| Per-task implement and review loop | `subagent-driven-development` |
| Commit messages | `commit` |
| PR title, sections, and `gh pr create` | `pr-create` |
| PR body prose | `writing-pr-descriptions` |
| Capturing UI screenshots | `helios-ui-visual-proof` |
| Uploading screenshots to PRs | `pr-image-upload` |
| Stacks | `gh-stack` |
| Helios repo rules (codegates, GraphQL, migrations, testing) | Helios `agent/skills/` and `agents/policies/` |

## Principles

The principles index lives in `~/.claude/CLAUDE.md` and is always loaded. Playbooks name the principle a step depends on. Helios PR rules live in [`references/helios-prs.md`](references/helios-prs.md).

## Subagents

- Give each subagent pointers, not pasted content: the plan path, the PR section, the spec sections, and file paths.
- Delegate implementation through `/implement-plan`, which uses `subagent-driven-development`.
- You own every subagent's output. Read the diff. Do not repeat its summary as fact.
- Review is done by a different agent from the author.

## Reply

- Lead with the outcome.
- Every claim names its evidence: a command, a `file:line`, or a link.
- Write anything sent on Justin's behalf (Slack, PRs, Jira, review comments) per `~/.claude/VOICE.md`.
- End with the open decisions, and the next gate that needs the operator.
