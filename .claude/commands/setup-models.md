---
description: Update the subagent model roles in ~/.claude/CLAUDE.md to models this session can use
---

# Setup models

Rewrite the table between `<!-- models:begin -->` and `<!-- models:end -->` in `~/.claude/CLAUDE.md`. Change nothing else in the file.

1. **Detect.** List the model slugs this session can pass to a `Task` subagent. That list is the only source. Never write a slug you have not seen in it. `inherit` is always valid.
2. **Compare.** Read the current table. Mark each value that is not in the detected list as stale.
3. **Propose.** For each stale value, propose the detected model of the same family with the nearest effort at or below the current one, else the nearest above. Keep the three families in `panel` distinct when the detected list allows.
4. **Confirm.** Show every role with its current and proposed model. Ask with `AskQuestion` whether to accept, or which roles to change, offering the detected models plus `inherit`.
5. **Write.** Replace the table rows. Keep the `Role` and `Used for` columns as they are. Run `~/.dotfiles/scripts/check-claude-skills.py`.
6. **Report.** List the roles that changed. The table applies to new sessions. Offer `/dotfiles-sync`.

To add a role: add a row here, then reference it from the skill as model role `<name>`. The checker fails on a role nobody references, and on a skill that names a model directly.
