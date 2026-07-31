---
name: codeowner-approval
description: Use when the user wants a codeowner approval or review for a Helios PR, or asks to post/ping #helios-shiproom for review.
---

# Request Codeowner Approval

Post a short approval request for one or more Helios PRs in `#helios-shiproom`, written in the user's voice. Core principle: draft first, send only after the user approves the exact text.

## Channel

`#helios-shiproom` — channel ID `C0810H8DD0D`

## Process

1. **Confirm the PR is worth asking for.** Check `gh pr view <N> --json title,url,reviewDecision,mergeStateStatus,statusCheckRollup`. Ask the user before posting if CI has failing checks or unresolved review threads remain — a codeowner shouldn't be pinged for a PR that still needs work. CI still running is fine.
2. **Draft the message** using the format below and show it to the user in chat.
3. **Wait for explicit approval.** Never post unprompted, and never post a version the user hasn't seen.
4. **Send** with the Slack MCP `slack_send_message` tool to `C0810H8DD0D`, then return the message permalink.

## Message Format

Single PR:

```
hi team can i get a codeowner approval, thanks!
[<PR title>](<PR url>)
```

Multiple PRs — one bullet each:

```
hi team, can i get codeowner approvals, thanks!
- [<PR title>](<PR url>)
- [<PR title>](<PR url>)
```

When the change isn't self-explanatory from the title, add a short clause to the first line instead of a second paragraph:

```
hi team, can i get codeowner approval for a portal admin change? fixes search on the /nexusapps page
[<PR title>](<PR url>)
```

## Voice

- Lowercase, brief, friendly; one line of ask plus links.
- Openers the user actually uses: `hi team`, `hey team`, `hi folks`, `hey folks`, or no opener at all.
- Ends with `thanks!` most of the time.
- Never add signatures, formatting flourishes, emoji, headers, or @-mentions of individuals.

## Link Rules

- Use markdown links: `[title](url)`. The Slack MCP tool renders markdown — it does **not** accept Slack's raw `<url|title>` or `url|title` syntax.
- Use the PR title verbatim **except** strip the trailing `#closes` directive (keep the `MCDB-NNNNN` ID if the title has one).
- Never put the bare URL and the title on separate lines.

## Follow-up

The Slack MCP server has no edit or delete tool. A wrong message can't be fixed in place — it has to be corrected with a new message, which is why the draft must be approved first.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Posting `url\|title` | Use `[title](url)` markdown |
| Leaving `#closes` in the linked title | Strip it; keep the Jira ID |
| Formal/capitalized phrasing | Match the user's lowercase, short style |
| Sending before the user approves the text | Always show the draft and wait |
| Asking for approval while CI is red or threads are unresolved | Confirm with the user first |
