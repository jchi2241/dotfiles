# Hotfix playbook

For an urgent production fix that cannot wait for the normal release.

1. **Confirm the fix exists.** It is a merged PR on `master`, or it goes through `bug-fix.md` first. Do not hotfix unreviewed code.
2. **Follow the `hotfix` skill** for the deployment tag, cherry-pick, branch, and PR.
3. **Gates.** Pushing the hotfix branch, opening the PR, and deploying each need the user's go. Deploys are irreversible.
4. **After deploy.** Verify the fix in production with the same signal that showed the bug (`querying-grafana`, `pulse-traces`). Note the hotfix in the incident write-up when there is one.

**Reply:** the hotfix PR link, the deploy state, and the production evidence.
