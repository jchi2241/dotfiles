# Analyst chat turn

A user opens Analyst in the portal, asks a question, watches the answer stream in, and finds the conversation saved when they come back. One turn crosses the portal, Nova Gateway, AuraCtx, the sqlbot container, and UMG.

## Sub-features

- `chat-install` installs Analyst for the org and gives it a domain to chat against.
- `chat-send` sends a prompt and streams an assistant answer.
- `chat-persist` reopens the saved session and shows both turns.
- `chat-hops` shows the turn in Nova Gateway, AuraCtx, sqlbot routing, and UMG logs.

## How to get to it (user POV)

- Sidebar **Analyst** in SingleStore Org: `/organizations/d7d4c050-3ced-49e1-8cff-a7e8eb95e691/analyst`.
- Fullscreen: `/organizations/d7d4c050-3ced-49e1-8cff-a7e8eb95e691/singlestore-analyst`.
- An existing session: `/organizations/<org>/analyst/<sessionID>?domainID=<domain>`, or a `chat-session-item` in the sidebar.

## Driving it

Preconditions:

- `scripts/doctor.sh` passes.
- `make setup-analyst` has run since the last database reseed (it prints `Analyst has been successfully set up`).
- `EVIDENCE=~/Pictures/verify-helios/<YYYY-MM-DD_HHMM>_analyst-chat` exists, and `SINCE=$(date -u +%Y-%m-%dT%H:%M:%SZ)` is written to `$EVIDENCE/since.txt` right before the send step.
- Every `playwright-cli` call runs from `~/projects/helios`. Sessions are tied to the working directory.

Steps:

- **Log in.** `playwright-cli -s="$S" open http://localhost:8001/organizations/d7d4c050-3ced-49e1-8cff-a7e8eb95e691/analyst`, or `state-load "$EVIDENCE/auth.json"` from an earlier run. Then:

  ```bash
  playwright-cli -s="$S" run-code "async page => {
    await page.getByLabel('Email address').fill('employee@singlestore.com');
    await page.getByRole('button', { name: 'Continue' }).click();
    await page.getByLabel('Password').fill('Password!');
    // The Keycloak page's only 'Sign in' button is the SAML broker; submit with Enter.
    await page.getByLabel('Password').press('Enter');
    const mfa = page.getByPlaceholder('Enter 6 digit code here');
    if (await mfa.isVisible({ timeout: 8000 }).catch(() => false)) {
      await mfa.fill('123456');
      await page.getByRole('button', { name: 'Submit' }).click();
    }
    await page.waitForURL(u => u.host === 'localhost:8001' && u.pathname.includes('/analyst'), { waitUntil: 'domcontentloaded' });
  }"
  ```

  Keycloak sometimes shows email and password on one page, with a hidden `Continue` button. Pressing Enter in the password field submits either layout. The MFA field may instead be labeled `Enter the 6-digit verification code`, so match it with `getByRole('textbox', { name: /verification code/i })`. The saved `auth.json` expires within hours, so expect to log in again.

  On a fresh database, also handle the cookie banner (`Reject All`) and Terms of Service (`getByRole('checkbox', { name: /I agree to the Privacy Notice/ }).check({ force: true })`, then `Continue`).
- **Install (`chat-install`).** Two stages, each only when it shows:
  1. The card `Talk to Your Data. Get Answers. Predict Outcomes.`: click `Get Started`, then the region modal's `page.getByRole('button', { name: 'Submit' })`. The modal has no accessible name, so don't scope to the dialog. When it finishes, the page reads `The fastest path from curiosity to clarity.`
  2. The empty state with `Create domain`: reuse an existing `verify-helios` domain from the composer's domain picker if one exists. Otherwise click `Create domain`, fill `getByPlaceholder(/e.g. Sales/)` with `verify-helios` and `getByPlaceholder(/e.g. Product insights/)` with a description, expand the `nova` database under `novaworkspace`, click the text `cells` (the checkbox input is hidden), and click `getByRole('button', { name: 'Create', exact: true })`. The URL gains `?domainID=`. Screenshot `$EVIDENCE/00-installed.png`.
- **Record.** Run the send and persist steps inside one `run-code`, between `page.video().start({ size: page.viewportSize() })` and `page.video().stop({ path: '$EVIDENCE/chat-turn.webm' })`. A `run-code` call is one script, so put both steps in it. The clip covers the send, the stream, and the reload.
- **Send (`chat-send`).** A new domain shows `Setting up domain... chat will be available shortly` for about 3 minutes, with `Ask` disabled. Wait for it to enable, then send:

  ```bash
  playwright-cli -s="$S" run-code "async page => {
    const ask = page.getByRole('button', { name: 'Ask', exact: true });
    await page.getByPlaceholder('Explore your data...').fill('In one sentence, what can you help me with?');
    await page.waitForFunction(() => { const b = document.querySelector('button[aria-label=Ask]'); return b && !b.disabled; }, null, { timeout: 600000, polling: 2000 });
    await ask.click();
    await page.waitForURL(u => /[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}/.test(u.pathname), { timeout: 60000, waitUntil: 'domcontentloaded' });
    await page.getByRole('button', { name: 'Stop', exact: true }).waitFor({ state: 'detached', timeout: 300000 }).catch(() => {});
    await ask.waitFor({ timeout: 300000 });
    await page.screenshot({ path: '$EVIDENCE/01-answer.png' });
    return page.url();
  }"
  ```

  Record the session UUID from the returned URL path as `SID`. The screenshot shows the answer and follow-up suggestions.
- **Persist (`chat-persist`).** Reload, then wait for both the prompt text and the start of the answer. Screenshot `$EVIDENCE/02-reloaded.png`. `getByTestId('chat-session-item')` has a count of at least 1.
- **Hops (`chat-hops`).** `direnv exec ~/projects/helios scripts/hop-evidence.sh "$SID" "$EVIDENCE" "$(cat $EVIDENCE/since.txt)"`. All four hops report `PASS`.
- **Cleanup.** Delete the session: hover its `chat-session-item`, click its `Session actions` button, then `getByRole('menuitem', { name: 'Delete' })`, then the dialog's `Delete` button. The `chat-session-item` count drops by one. Keep the `verify-helios` domain, so the next run skips the 3-minute domain setup. Keep `$EVIDENCE`.

## Gotchas

- Log in as `employee@singlestore.com`. `customer@email.com` lands in Local Dev Org, which has no Analyst flags.
- Without a domain, the composer never renders, so install alone is not enough to chat.
- `getByRole('button', { name: 'Ask' })` also matches the header's `Ask SQrL`. Always pass `exact: true`.
- Don't `waitForURL(/\/analyst/)` after login. It matches the Keycloak callback and times out on `load`.
- The CLI `screenshot` command can return a stale image. Use `page.screenshot({ path })` inside `run-code`.
- sqlbot writes nothing to stdout per turn, and Nova replaces notebook pods often. The sqlbot hop is proven by Nova Gateway's `container URL: http://heliosnotebook-<id>` line plus UMG's `claude-*/converse` calls, which only sqlbot makes. UMG gets Bedrock `converse` and `invoke` paths here, not `chat/completions`.
- A `sandbox-cpu-ti-*` pod in `ImagePullBackOff` (`nova-sandbox:latest` missing from the local registry) is unrelated to chat.
- A database reseed wipes the install and the domain. Expect both install stages again after `babysit-init-analyst` recovery.
- UMG needs the AWS Bedrock secrets that `setup-analyst` loads. If the turn fails with a model error, read `logs/umg.log` before blaming the change.
- A streamed answer alone does not prove persistence. Reload and confirm both turns come back from the server.
