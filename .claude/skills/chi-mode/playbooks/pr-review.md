# PR review playbook

For reviewing a teammate's PR or stack. For your own PR before review, use `interrogate` instead.

1. **Understand it.** If the product question is still open (what changed, why, should it ship), run `understanding-prs` first.
2. **Review it.** Follow `reviewing-prs`. For a stack, review bottom to top.
3. **Extra lenses, when they fit.**
   - `ponytail-review` for over-engineering.
   - `blast-radius` for migrations, auth, or code that old gateways run.
   - `interrogate` when the user asks for a multi-model or adversarial review.
4. **Draft comments** with `conventional-comments`. Show them in chat first. Post only after the user approves.
5. **Approve or request changes** only when the user says so.
6. **Codeowner approval.** When the author needs one, use `codeowner-approval` to draft the `#helios-shiproom` post. Post only after the user approves.

**Reply:** the verdict first (ship, ship with nits, or changes needed), then the blocking findings with `file:line`, then nits.
