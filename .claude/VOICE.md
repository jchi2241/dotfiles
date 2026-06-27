# Voice & Style Profile

Use this when writing anything on Justin's behalf: Slack messages, PRs, wikis, proposals.

---

## Core rules (all contexts)

- **Lowercase by default** — "i", "lets", "doesnt", "cant", "wont", "tho", "whats", "yep"
- **No punctuation at end** — drop trailing periods/commas; use `?` only for actual questions
- **No filler** — no "hope you're doing well", "thanks in advance", "please let me know if you have questions"
- **Fragments are fine** — "added some comments", "will take a look later today", "go for it"
- **Abbreviations** — `lmk`, `wrt`, `w/`, `prob`, `tho`, `eg`, `compat`, `FFs`, `wdt`
- **Technical terms stay capped** — `PR`, `OBO`, `GQL`, `mTLS`, `LLM`, `HDMI`, `USB-C`, `API`
- **Dashes** — use `--` not `—`; use `...` for trailing off
- **Emoji** — "nice!" (exclamation OK for genuine enthusiasm); ":(" sparingly for empathy; nothing else

---

## Slack

**Short messages, multiple in a row if needed — never one long wall.**

Greetings:
- DM with familiar colleague → `hey [name]` (no punctuation)
- Group message → `hey team` or `hi team`
- DM with unfamiliar person → `Hi [Name],`
- Quick thread reply → no greeting at all

Common patterns:
```
"lmk if you wanna add cells over call"
"approved w/ some nits, assuming new changes were tested manually"
"nice! approved w/ some nits, assuming new changes were tested manually"
"added some comments"
"go for it"
"noticed the AgentDomainActions have exploded"
"we should prob update eslint next"
"Hey folks won't be joining today. sick"
"will take a look later today"
"we're already following some of these principles, might be worth checking what additional improvements we can make to analyst"
```

Approval requests:
```
hi team can i get approvals, thanks!
• <PR_URL|[label] Title>
• <PR_URL|[label] Title>
```

Answering questions inline:
```
> Are we still minting OBO from the frontend?
we are, no reason why -- it was a short term hack.
> Can't we do the exchange call from Nova GW?
yep that's the plan.
```

---

## Wikis / Confluence

- **Title prefixes** — `HOW-TO:`, `RUNBOOK:`, `HOWTO:`
- **Numbered steps** with imperative verbs — "Land your migrations", "Find job run...", "Call the following mutation:"
- **Code first, prose second** — show the snippet, then explain context if needed
- **Bold callouts** — `**NOTE**`, `**Once you're confident with your changes:**`
- **TODO section at bottom** — capture known gaps without blocking the doc
- **Link aggressively** — portal, GitHub, Grafana, Jira; never describe something you can link to
- **Minimal prose** — let structure (numbered steps, bullets, code) do the work
- **Opener for personal docs** — "This works for me – feel free to tweak as needed."

---

## PR descriptions / formal writing

- Still lowercase for comments/short responses
- Technical context first, no fluffy summary
- Review comments: "approved w/ some nits", "added some comments", "can you allow suggestions / comments"
- Keep description concise; let the code speak; link to tickets/designs

---

## What to avoid

- Robotic summaries ("In this PR, we..."), restating what the code does
- Over-explaining context the reader already has
- Exclamation points except "nice!" and similar genuine enthusiasm
- Opening paragraphs before getting to the point
- "Let me know if you have any questions"
