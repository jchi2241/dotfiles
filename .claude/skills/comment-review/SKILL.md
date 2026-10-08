---
name: comment-review
description: Use when reviewing a diff's code comments, running the comments lane in review-lanes.md, or when asked to strip, audit, or "no-comments" a change before review.
---

# Comment review

A comment survives only if it states something the code cannot show. Everything else is noise to delete. A comment that explains how our own surprising code works is a signal that the code should change instead; a comment that records why (a business rule, a product decision, a domain fact) is knowledge, and stays.

Report only. Never edit code or comments; the writer applies the findings.

## Scope

- Comments the diff adds or edits, in any language: Go, TypeScript, SQL, GraphQL, YAML, shell.
- Existing comments the diff makes false (the code under them changed).
- Not generated files (`*_gen.go`, `__generated__/**`, `*.pb.go`), not vendored code, not comments the diff doesn't touch.

## What survives

The test for every comment: could a reader get this from the code nearby (the function, its callers, its types and names)? If yes, it goes. If no, it stays. When unsure whether a comment is noise, it goes; when unsure whether it carries knowledge the code can't show, it stays.

- Knowledge the code can't carry: business or billing rules, product decisions and why they were made ("on-demand orgs can't raise their own cap; Sales owns that"), domain facts, unit conventions, operational or rollout constraints, and other esoteric context a careful reader would not infer from the code. Keep these even when they explain our own code; a rename can't encode a product decision.
- License or legal headers.
- A constraint forced by something we can't change: an external API, vendor, protocol, platform, or library quirk. Our own code's surprises don't qualify.
- A link to an issue, incident, or RFC that explains a constraint the code can't express.
- Doc comments on an exported or public API that state its contract (Go exported identifiers, GraphQL schema descriptions, public TS exports). A doc comment that restates the name ("GetUser gets the user") is still noise.
- Tool directives: `//go:build`, `//go:generate`, `//go:embed`, `// prettier-ignore`. Lint suppressions (`//nolint`, `eslint-disable`, `@ts-ignore`, `@ts-expect-error`) only when the rule is style-only or wrong for this line; read the rule before deciding.

## What goes

- Narration of what the next line does, section banners, restated names, changelog or history ("was X, now Y", "added for PR-4"), reviewer-facing justifications ("this is safe because").
- Commented-out code.
- TODOs without an owner and ticket key.
- Comments that are stale or false against the code they sit on.

## Workaround comments

"IMPORTANT", "do not remove", "too risky", "fine for now", and long justifications are claims, not proof. Read the surrounding code and its callers; use `git log -S` or `git log -L` on the line if the reason is historical. Then:

- The claim is a foreign constraint, true today on a live path: it survives. Say so in the report only if it's borderline.
- The claim carries knowledge the code can't show (a product or business decision, a domain fact, a rollout constraint): it survives, even in our own code.
- The claim only explains how our own code works: the comment goes, and the finding names the exact symbol to rename, extract, type, or restructure so the behavior is obvious without prose. Don't propose a shorter version of the comment.
- A suppression that hides a rule which catches real bugs: the suppression goes, and the finding names the code that must change to satisfy the rule.

## Severity

| Finding | Severity |
|---|---|
| Comment states something false about behavior a caller relies on | blocker |
| Stale or false comment; suppression hiding a real-bug rule; our-code workaround needing a refactor | should-fix |
| Narration, banner, restated name, history, reviewer-facing justification, commented-out code, ownerless TODO | low |
| Wording of a comment that survives | nit |

Each finding: the comment's location, why it goes (one line, from the lists above), and the fix: delete it, or the code change that replaces it.
