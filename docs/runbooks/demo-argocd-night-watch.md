# The demonstration's ArgoCD, and the night watch on it

_Last updated: 2026-11-11 · sixth brick of the 3 a.m. scenario (ADR 0074, 0075)_

> **When to use this runbook:** to run, reset or repair the night-watch
> demonstration — an ArgoCD sync that fails on the demo cluster, a trigger rule
> that starts the agent without anyone present, and the receipt read the morning
> after. Everything below was measured on 11/11/2026 on the demo host.

---

## What runs where

The demo host (`2.29.47.12`, Hetzner, 4 vCPU, 8 GB) runs the VibOps Compose
stack **and** a single-node k3s. ArgoCD lives in that k3s, in namespace
`argocd`, and applies a Git repository to the same cluster. The VibOps gateway
of the demo organisation on that cluster is `k3s-live` (cluster `dc-live`,
container `vibops_connect_demo`).

| Piece | Where | How to reach it |
|---|---|---|
| ArgoCD v3.6.1 | k3s, ns `argocd` — API server in plain HTTP (`server.insecure`), dex and applicationset scaled to 0, reconciliation every 60 s | NodePort `30444` — `http://127.0.0.1:30444/api/version` on the host, `http://host.docker.internal:30444` from a container |
| ArgoCD admin password | secret `argocd-initial-admin-secret` in ns `argocd` | `k3s kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 -d` |
| ArgoCD account for the gateway | local account `vibops` (`accounts.vibops: apiKey, login` in `argocd-cm`, `g, vibops, role:admin` in `argocd-rbac-cm`), token `vibops-gateway-dc-live` | the token is in `/opt/vibops/connect-demo.env` (`ARGOCD_TOKEN`), nowhere else |
| The gateway `k3s-live` | container `vibops_connect_demo`, env file `/opt/vibops/connect-demo.env` (600): `VIBOPS_*`, `KUBECONFIG`, `ARGOCD_SERVER=http://host.docker.internal:30444`, `ARGOCD_TOKEN`, `ARGOCD_INSECURE=true` | its ping reports `connectors.configured: ["ArgoCD"]` — read `connector_status` on the `gateways` row |
| The Git repository | `github.com/davidmacamara-boop/vibops-demo-gitops` (private) — Kustomize package `apps/inference/base`, overlay `clusters/dc-live/inference`, two prepared branches `scenario/bad-image` and `scenario/bad-manifest` | ArgoCD reads it with the read-only deploy key `/opt/vibops/argocd-deploy-key` (secret `repo-vibops-demo-gitops` in ns `argocd`) |
| The Application | `inference` in ns `argocd` → ns `gitops-demo`, automated sync, prune, self-heal, `CreateNamespace` | `k3s kubectl -n argocd get app inference` |
| ArgoCD → VibOps | `argocd-notifications-cm`: webhook service `vibops` → `https://demo.vibops.ai/api/v1/webhooks/argocd`, one template (`event` derived from the three status fields), triggers `on-sync-failed`, `on-health-degraded`, `on-sync-succeeded`; the Application subscribes to the three | the organisation API token is in secret `argocd-notifications-secret` (key `vibops-token`); on the VibOps side it is the `api_tokens` row `argocd-notifications-dc-live`, user `demo-admin`, org VibOps Demo |
| Caddy | `install/Caddyfile.demo` — `@argocd path /api/v1/webhooks/argocd` short-circuits the console to core, like the gateway paths | copy to `/opt/vibops/Caddyfile` without the repository header, then `docker exec vibops_caddy caddy reload --config /etc/caddy/Caddyfile` |

Measured on 11/11/2026, in this order: the Application synced and reported
Healthy 15 s after creation; the notifications controller sent
`on-sync-succeeded` to the webhook with the documented body; core, still at
v0.68.0, answered 404 — the door exists from v0.71.0.

## What is still missing for a night to run end to end

1. **The release.** The ArgoCD door, the `argocd` trigger source, the
   unattended run and the receipt are in `main` and not in any image. The host
   runs v0.68.0. Tag the release and update the host
   (`docs/runbooks/update-the-demo-host.md`); the migration `b7e2a9c4d1f3`
   runs with it.
2. **The rule**, once the host runs the release — through the agent
   (`create_trigger`) or the API, as `demo-admin`:

   ```json
   {"name": "night-watch-dc-live", "source": "argocd", "metric": "*",
    "action": "agent_diagnosis", "cooldown_minutes": 10,
    "payload": {"cluster": "dc-live", "gateway_id": "51af9cc5-23bd-470d-8da2-f69d0f1c78e2",
                "language": "en"}}
   ```

3. **The mandate.** The demo organisation already carries a tool-policy row for
   `argocd_rollback` with `requires_confirmation` unset (the connector's
   default: ask). Leave it to show the *propose* tier — the night run stops at
   the gate and the morning finds the proposal; set it to `false` (Admin →
   Tool policy) to show the *act* tier — the run rolls back and reads it back.
   Decide before the room arrives; the receipt cites the decision either way.
4. `AGENT_API_URL` is set in the host's `.env` and the worker reaches the agent
   on the Compose network — the run needs nothing more.

## Running a night

```bash
# on your machine, in a clone of vibops-demo-gitops
git checkout main && git pull
git merge --no-ff scenario/bad-image -m "night: bad image tag" && git push
# ArgoCD syncs within 60 s; the Deployment never becomes available; health is
# Degraded after progressDeadlineSeconds (60 s) → on-health-degraded → VibOps.
```

`scenario/bad-manifest` is the other night: `replicas: one` makes the sync
itself fail → `on-sync-failed`, within 60 s of the push.

What to read afterwards, in the console: *"What did ArgoCD report tonight?"*
(`list_audit_logs` on `argocd_event`), *"Show me last night's receipts"*
(`list_intervention_receipts`), *"Give me the receipt of the inference
incident as a document"* (`get_intervention_receipt`).

## Resetting

```bash
git checkout main && git revert -m 1 HEAD && git push        # heal in Git
k3s kubectl -n argocd get app inference                      # Synced / Healthy again within 60 s
```

If the night run rolled back (act tier), ArgoCD's history now holds that
rollback; the revert in Git is still what the morning review merges — the
rollback changed the cluster, not the repository, and self-heal would re-apply
`main` otherwise. That is the third rule of the brief: *when the robot fails,
VibOps looks at why and proposes the fix; Git stays the source of truth.*

## Repairing

- **ArgoCD pods gone** (the host rebooted, the disk filled): `k3s kubectl -n
  argocd get pods`; the install is `kubectl apply -n argocd -f
  https://raw.githubusercontent.com/argoproj/argo-cd/v3.6.1/manifests/install.yaml`
  plus the three patches (`server.insecure`, the NodePort service, dex and
  applicationset to 0) — all in this runbook's first table.
- **The gateway lost ArgoCD** (`connectors.configured` without `ArgoCD`): the
  container was recreated without the env file. Recreate it from
  `/opt/vibops/connect-demo.env` with the runbook sequence of
  `update-the-demo-host.md` step 5 — keep `--add-host host.docker.internal:host-gateway`.
- **The notification never arrives**: `k3s kubectl -n argocd logs
  deploy/argocd-notifications-controller | grep vibops`. A 404 is core without
  the door (release not deployed); a 401 is the token (`api_tokens` row deleted
  or expired); a timeout is Caddy (the `@argocd` handle is missing on the host).
- **Disk.** The host was at 99 % on 11/11/2026 with 117 GB of old images;
  `docker image prune -a` brought it to 18 %. Pulling a release needs room.
