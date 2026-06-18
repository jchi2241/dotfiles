---
name: helios-migration-jira-ticket
description: Use when creating or updating Jira tickets for Helios database migrations, especially when a migration PR needs the required MCDB migration-application ticket.
---

# Helios Migration Jira Ticket

Use this for Helios migration PRs under `migrations/postgres/` or `migrations/singlestore/`.

Reference: [Helios database migrations](https://memsql.atlassian.net/wiki/spaces/MCDB/pages/1550451054/Helios+database+migrations).

## Required Process

1. Confirm the migration PR is the migration-only PR in the stack.
2. Confirm the migration file name and derive `NAME` from the generated migration name, without the timestamp prefix and without `.sql`.
   - Example: `2026-06-16T1781637321-create-appcellavailability-table.sql` -> `create-appcellavailability-table`.
3. Create an MCDB Jira `Task` titled exactly:
   - `apply migration NAME`
4. The ticket description must link the approved PR with passing tests.
5. Assign the ticket to the requested migration applier. The wiki names:
   - `dsharnoff` for US hours
   - `jmonteiro` for EU hours
   - `kanitsharma` for India hours
6. Update the migration PR's `## JIRA Issues` section to include the new migration ticket.

## MCP Details

Use the `user-atlassian` MCP server when available. Always read the tool schema first.

Useful tools:
- `jira_create_issue`
- `jira_update_issue`
- `jira_get_user_profile`
- `jira_search`
- `confluence_get_page`

Project:
- Use `MCDB`.

Component:
- MCDB requires a component. Use `Database Migration` for Helios migration application tickets.

Assignee:
- Prefer the assignee email if username or account ID does not stick.
- For David Sharnoff, use `dsharnoff@singlestore.com`.
- For João Monteiro, use `jmonteiro@singlestore.com`.
- For Kanit Sharma, use `kanitsharma@singlestore.com`.
- Creating the issue with component `Database Migration` may apply a component default assignee first. If the returned issue is not assigned to the requested person, immediately call `jira_update_issue` with:

```json
{"assignee":"assignee-email@singlestore.com"}
```

## Description Template

```markdown
PR_URL
```

## PR Update

After creating the ticket, update the PR body minimally. In `## JIRA Issues`, replace any stale migration ticket with the new key, and preserve the product/project ticket if present.

Example:

```markdown
## JIRA Issues
MCDB-94509, MCDB-96421
```

## Notes From Prior Use

- The old migration ticket can become stale if the migration file is renamed. Create a new ticket whose title matches the current migration `NAME`.
- The wiki says not to merge migration PRs until the migration has been applied to staging/production.
- The migration PR Deployment Plan should say the rollout is to run the migration and rollback is to revert the migration PR.
