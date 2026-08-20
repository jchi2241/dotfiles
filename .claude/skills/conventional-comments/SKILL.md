---
name: conventional-comments
description: Use when writing GitHub pull request review comments, inline comments, or when the user mentions conventional comments. Also use when posting comments after a PR review.
---

# Conventional Comments

Comment format is [conventionalcomments.org](https://conventionalcomments.org/). Post **inline** on the diff, not as a top-level PR review body, unless the user asks for a summary review.

Do not post until the user asks. Draft in chat first if they have not said to comment.

## Format

```
<label> [optional decoration]: <subject>

<body>
```

One label. Subject is a complete thought, not a filename. Body is optional; skip it when the subject is enough.

| Label | When |
|---|---|
| `issue` | Defect or missing test that should block merge |
| `nit` | Polish. Author can ignore |
| `suggestion` | Better way; not required |
| `question` | Need an answer to finish the review |
| `thought` | Observation, no action |
| `todo` | Follow-up the author accepted in spirit |
| `praise` | Rare. Specific. Never filler |
| `note` | Context the author may not have |
| `chore` | Process (rebase, changelog) |

Decorations go in parentheses after the label: `(blocking)`, `(non-blocking)`, `(if-minor)`, `(security)`.

Blocking findings use `issue (blocking):`. Nits use `nit (non-blocking):`.

## Voice

GitHub comments are on Justin's behalf. Read `~/.claude/VOICE.md` (GitHub review comments section) and follow it. Do not invent a review persona.

## Where to put it

GitHub only accepts inline comments on lines in the PR diff. If the broken file was not touched, comment on the changed line that caused the break.

```bash
gh api repos/<owner>/<repo>/pulls/<n>/comments --input - <<'EOF'
{
  "commit_id": "<head SHA>",
  "path": "<file in the diff>",
  "line": 69,
  "side": "RIGHT",
  "body": "**issue (blocking):** …"
}
EOF
```

Multiline: add `start_line` / `start_side`. Head SHA from `gh pr view <n> --json commits`.

Skip duplicate **nits** Copilot already posted. Still post blocking issues even if Copilot said them.

Do not approve or request changes here. That is a separate user ask.
