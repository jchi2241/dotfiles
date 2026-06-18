---
name: babysit-init-analyst
description: Use when the user asks to run, babysit, or complete `init-analyst` (excluding `make frontend-start`) in the helios repo, or asks to bring up the local Analyst stack (kube-init + nova workspace + analyst setup). Also trigger when they mention `nukefreyadb`, corrupted heliospg, or crashlooping local cluster pods during Analyst bring-up.
---

# Babysit init-analyst

Run the first three steps of the `init-analyst` shell alias to completion, auto-recover from the common corrupted-postgres failure, and leave the local cluster in a state where the user can start `make frontend-start` themselves.

## What init-analyst is

The user's shell alias is:

```
init-analyst='NOVA=1 SINGLESTORE_NEXUS=/home/jchi/projects/singlestore-nexus make kube-init && make start-nova-workspace && make setup-analyst && make frontend-start'
```

This skill runs the first three commands only. Skip `make frontend-start` — it is a long-lived dev server the user starts on their own.

## Sequence

All commands run from `~/projects/helios` with `direnv exec .` as the project's CLAUDE.md requires. Each step can take several minutes; stream output and do not fail fast on transient waits.

1. **kube-init** (5–10 min): `NOVA=1 SINGLESTORE_NEXUS=/home/jchi/projects/singlestore-nexus direnv exec . make kube-init`
2. **start-nova-workspace** (3–5 min, waits up to 15 min for pods): `direnv exec . make start-nova-workspace`
3. **setup-analyst** (3–5 min): `direnv exec . make setup-analyst`

Between steps, a quick `direnv exec . kubectl get pods --all-namespaces` sanity check is cheap and catches problems early. After step 3, tell the user the stack is ready and they can run `make frontend-start` whenever.

Because these are long running, prefer background execution (write output to a temp file) and poll. Read the user's Bash tool docs for the exact mechanism — the goal is to avoid blocking the conversation for 20+ minutes and to keep transcript noise down.

## The nukefreyadb recovery path

The single most common failure mode on this machine is a corrupted local postgres. `heliospg` crashloops with the signature:

```
PANIC: could not locate a valid checkpoint record
LOG:  startup process (PID N) was terminated by signal 6: Aborted
LOG:  aborting startup due to startup process failure
```

This cascades: `authsvc`, `statesvc`, `kubera`, `monitoringagent`, and `jobworker` all enter CrashLoopBackOff because they can't reach postgres. The user's `nukefreyadb` alias wipes the local postgres data:

```
nukefreyadb='hel && make kube-delete && sudo rm -rf ~/.helios-pgdata'
```

### Detect before running

Before starting step 1, probe cluster health. If pods exist and `heliospg` is crashlooping with the checkpoint-record signature, run recovery *before* attempting kube-init — kube-init on top of broken state just wastes 10 minutes. Detection:

```
direnv exec . kubectl get pods -n default -l app=heliospg -o name 2>/dev/null \
  | head -1 \
  | xargs -r -I{} direnv exec . kubectl logs -n default {} --tail=20
```

If the logs contain `could not locate a valid checkpoint record`, recover. You can also check cluster-wide for cascaded crashloops (`kubectl get pods --all-namespaces | grep CrashLoop`) — two or more crashloops accompanying a bad heliospg is the strong signal.

If kube-init fails mid-run, re-check for the same signature before retrying.

### Recovery without sudo

The pgdata directory (`~/.helios-pgdata`) is owned by uid 70 (the postgres container user), so the raw alias requires sudo. Since this skill must not prompt for a password, use docker — the docker daemon runs as root and can delete it:

```
cd ~/projects/helios && direnv exec . make kube-delete \
  && docker run --rm -v "$HOME:/h" alpine rm -rf /h/.helios-pgdata
```

Confirm deletion (`ls -la ~/.helios-pgdata` should say "No such file or directory") before retrying from step 1.

Why this works: Docker mounts `$HOME` into an alpine container and runs `rm -rf` as the container's root, which has permission to remove uid-70-owned files. No host sudo needed.

#### The "in-place" variant (cluster already running)

If the cluster is up but heliospg is corrupted, `make kube-delete` is overkill — it tears down everything. Instead, nuke just the pgdata in place. But there's a subtle trap:

The k3d node container has a live bind mount `~/.helios-pgdata -> /helios-pg-data` (visible via `docker inspect k3d-helios-infra-local-dev-server-0`). Bind mounts hold a reference to the *inode*, not the path. So if you `rm -rf` the host dir and let postgres recreate it, the k3d node keeps pointing at the deleted-but-pinned inode. Symptoms:

- `heliospg` pod fails with `RunContainerError: failed to create containerd task ... error mounting "/helios-pg-data" to rootfs at "/pg-data" ... no such file or directory`
- `docker exec k3d-<node> ls -la /helios-pg-data` shows it empty even after postgres wrote to `~/.helios-pgdata` on the host.

The fix is to restart the k3d node so the bind mount re-resolves:

```
# 1. Nuke pgdata (containers holding it must be gone first)
direnv exec ~/projects/helios kubectl scale deploy heliospg -n default --replicas=0
docker run --rm -v "$HOME:/h" alpine rm -rf /h/.helios-pgdata

# 2. Refresh the bind mount by restarting the k3d node
docker restart k3d-helios-infra-local-dev-server-0

# 3. Remove the postgres init-step markers so kube-init re-seeds the fresh DB
rm -f ~/projects/helios/scripts/init-steps/{wait-postgres,setup-postgres,setup-helioss2}

# 4. Scale heliospg back up and rerun kube-init
direnv exec ~/projects/helios kubectl scale deploy heliospg -n default --replicas=1
cd ~/projects/helios && NOVA=1 SINGLESTORE_NEXUS=/home/jchi/projects/singlestore-nexus direnv exec . make kube-init
```

Why the init-step markers matter: `make kube-init` is idempotent via `scripts/init-steps/<name>` touch-files. If those markers exist from a previous run, `postgres-reset` (which creates the `local` role and the `freya`/`grafanadb`/`keycloak` databases) won't re-run against the new empty DB. Services like statesvc/authsvc/kubera will then crashloop with `pq: role "local" does not exist`.

When in doubt, prefer the full `make kube-delete` path above — it's slower but doesn't leave stale bind mounts or stale markers.

### Announce, don't silently nuke

Even though recovery is automated, tell the user *before* running it: "heliospg is corrupted (`could not locate a valid checkpoint record`), running nukefreyadb via docker." Then do it. This keeps them informed without blocking on a y/n.

## Other known failure signatures

### statesvc/authsvc/kubera crashloop with `pq: role "local" does not exist`

This means postgres came up with a *fresh empty DB* but the seed step that creates the `local` role and the `freya`/`grafanadb`/`keycloak` databases never ran. Usually caused by a half-recovered nuke that left the init-step markers in place. Recovery:

```
rm -f ~/projects/helios/scripts/init-steps/{wait-postgres,setup-postgres,setup-helioss2}
cd ~/projects/helios && NOVA=1 SINGLESTORE_NEXUS=/home/jchi/projects/singlestore-nexus direnv exec . make kube-init
```

This causes kube-init to re-run only the missing steps. It will also trigger Tilt to rebuild service binaries (~3–5 min), which is the price of this recovery.

### heliospg `RunContainerError: no such file or directory` on `/pg-data` mount

Stale k3d bind mount after a nuke. See "The in-place variant" under nukefreyadb — the fix is to restart the k3d server node container.

### Other failures

For anything that doesn't match the signatures above, stop and surface the error to the user instead of guessing a recovery. Examples: images failing to pull, k3d unable to bind ports, disk full, kafka timing out. The skill's value is handling the common case cleanly; novel failures deserve human judgement.

If `setup-analyst` fails specifically, rerunning it is usually safe (it's mostly idempotent — creates publishers/versions by name). Mention that and let the user decide.

## Completion signal

You'll know setup-analyst finished when the output contains:

```
Setup Complete! 🚀
...
✓ Analyst has been successfully set up
```

At that point, report back: what was run, whether nukefreyadb recovery fired, and that `make frontend-start` is the user's next step.
