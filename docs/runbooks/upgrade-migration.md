# VibOps — Upgrade & Migration Runbook

_Last updated: 2026-08-07 · v0.28.0_

---

## Overview

This runbook covers upgrading a running VibOps instance, including Alembic schema migrations, rollback procedures, and handling breaking changes between versions. It complements `docs/installation.md` and the backup/restore procedures in `backup-restore.md`.

**Golden rule:** always take a database backup before upgrading. Migrations are hard to reverse.

---

## Pre-Upgrade Checklist

- [ ] Read the CHANGELOG for the target version — note any **Breaking changes** or **Migration notes**
- [ ] Take a database backup (`make backup-now` or see `backup-restore.md`)
- [ ] Verify backup integrity (restore test to a scratch DB if possible)
- [ ] Check current migration head matches what is deployed:
  ```bash
  docker compose exec core alembic current
  ```
- [ ] Confirm no jobs are RUNNING or PENDING — drain the queue or plan for in-flight job cancellation
- [ ] Check available disk space — migrations can temporarily double index sizes:
  ```bash
  df -h
  ```
- [ ] For Helm: ensure `my-values.yaml` is committed to version control

---

## 1. Docker Compose Upgrade

### Standard upgrade (no breaking changes)

```bash
# Pull new code
git pull

# Rebuild images
docker compose build

# Restart services (core applies migrations on startup)
docker compose up -d

# Tail logs to watch migration complete
docker compose logs -f core | grep -E "alembic|migration|ERROR"

# Verify health
curl http://localhost:8000/api/v1/health | jq
```

### Upgrade with breaking schema change

If the CHANGELOG flags a breaking migration (e.g. column rename, constraint change):

```bash
# 1. Stop services except the database
docker compose stop core worker beat agent console

# 2. Take backup
make backup-now

# 3. Pull and build new images
git pull && docker compose build

# 4. Apply migration manually first (validate it runs cleanly)
docker compose run --rm core alembic upgrade heads

# 5. Check result
docker compose run --rm core alembic current

# 6. Bring services back up
docker compose up -d

# 7. Watch for startup errors
docker compose logs --tail=50 core worker
```

---

## 2. Helm Upgrade

### Standard upgrade

```bash
# Update chart index
helm repo update vibops

# Review diff before applying (requires helm-diff plugin)
helm diff upgrade vibops vibops/vibops -n vibops -f my-values.yaml

# Apply
helm upgrade vibops vibops/vibops \
  -n vibops \
  -f my-values.yaml \
  --wait \
  --timeout 10m

# Verify rollout
kubectl rollout status deployment/vibops-core -n vibops
kubectl rollout status deployment/vibops-worker -n vibops
```

The `vibops-core` init container runs `alembic upgrade heads` before the pod starts. The old pod remains live until the new one passes its health check — zero-downtime for non-destructive migrations.

### Upgrade with breaking schema change

```bash
# 1. Scale workers to zero (stop job processing)
kubectl scale deployment vibops-worker --replicas=0 -n vibops
kubectl scale deployment vibops-beat --replicas=0 -n vibops

# 2. Take backup (run the backup job or snapshot the PV)
kubectl create job --from=cronjob/vibops-backup vibops-backup-preupgrade -n vibops

# 3. Apply new chart
helm upgrade vibops vibops/vibops \
  -n vibops \
  -f my-values.yaml \
  --wait \
  --timeout 10m

# 4. Restore worker replicas
kubectl scale deployment vibops-worker --replicas=2 -n vibops
kubectl scale deployment vibops-beat --replicas=1 -n vibops
```

---

## 3. Alembic Migration Reference

### Check current state

```bash
# Current revision in DB
docker compose exec core alembic current

# Full revision history
docker compose exec core alembic history --verbose

# Show pending (not yet applied) migrations
docker compose exec core alembic heads
```

### Apply manually

```bash
# Upgrade to latest
docker compose exec core alembic upgrade heads

# Upgrade to specific revision
docker compose exec core alembic upgrade <revision_id>

# Downgrade one step
docker compose exec core alembic downgrade -1

# Downgrade to specific revision
docker compose exec core alembic downgrade <revision_id>
```

### Resolve revision collision

If `alembic upgrade heads` fails with "present more than once":

```bash
# Identify colliding revisions
docker compose exec core alembic history --verbose | grep "^Rev:"

# Check for duplicate revision IDs in alembic/versions/
grep -r "^revision = " core/alembic/versions/ | sort -k3
```

Fix: rename the newer file with a unique 12-char hex ID and update its `revision` and `down_revision` fields. Then re-run `alembic upgrade heads`.

---

## 4. Rollback Procedures

### Alembic downgrade (schema only)

Downgrades only reverse the schema — they do NOT restore data deleted or transformed by the migration. Always restore from backup when data is at risk.

```bash
# Downgrade one step
docker compose exec core alembic downgrade -1

# Downgrade to pre-upgrade revision (replace with actual ID)
docker compose exec core alembic downgrade <previous_head>

# Restart services after downgrade
docker compose restart core worker beat
```

### Full rollback (code + schema)

```bash
# Stop all services
docker compose down

# Restore database from backup (see backup-restore.md)
make restore BACKUP_FILE=vibops-backup-YYYYMMDD.sql.gz

# Check out the previous version
git checkout v0.14.0    # replace with previous tag

# Rebuild
docker compose build

# Start
docker compose up -d
```

### Helm rollback

```bash
# List release history
helm history vibops -n vibops

# Roll back to previous revision
helm rollback vibops -n vibops

# Roll back to specific revision
helm rollback vibops <REVISION> -n vibops

# If DB schema was changed: also run alembic downgrade in the core pod
kubectl exec -it deploy/vibops-core -n vibops -- alembic downgrade -1
```

---

## 5. Breaking Changes by Version

### v0.45.7 — the chart runs its own PostgreSQL

**New installations: nothing to do.** The chart bundles PostgreSQL on
`postgres:16-alpine`, the image the Compose deployment has always used.

**Existing Helm releases: the upgrade stops and tells you.** Until v0.45.6 the
database came from the Bitnami subchart, whose StatefulSet is
`<release>-postgresql` with a volume of its own, a different data layout and a
different uid. The chart now runs `<release>-vibops-db`. Upgrading in place
would start an *empty* database, core would migrate it, and the release would
come up healthy and blank with the old data still on disk and nobody told — so
the upgrade refuses instead, naming the volume it found.

Two ways out.

**Dump and restore** (a few minutes of downtime):

```bash
NS=vibops            # your namespace
REL=vibops           # your release name

# 1. Dump from the Bitnami pod, which is still running
kubectl -n $NS exec ${REL}-postgresql-0 -- \
  env PGPASSWORD="$(kubectl -n $NS get secret ${REL}-postgresql \
      -o jsonpath='{.data.password}' | base64 -d)" \
  pg_dump -U vibops -d vibops > vibops-backup.sql

# 2. Scale the application down so nothing writes during the move
kubectl -n $NS scale deploy --replicas=0 -l app.kubernetes.io/name=vibops

# 3. Upgrade: the new StatefulSet starts empty beside the old one
helm upgrade $REL ./helm/vibops -n $NS --set postgresql.legacyAcknowledged=true

# 4. Restore into it
kubectl -n $NS exec -i ${REL}-vibops-db-0 -- \
  env PGPASSWORD="$(kubectl -n $NS get secret ${REL}-vibops-db \
      -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)" \
  psql -U vibops -d vibops < vibops-backup.sql

# 5. Bring it back up
kubectl -n $NS rollout restart deploy -l app.kubernetes.io/name=vibops
```

The old PVC is left in place. Delete it once you have verified the restore —
`kubectl -n $NS delete pvc data-${REL}-postgresql-0` — and not before.

**Or keep the database you have**: set `postgresql.enabled=false` and point
`core.secret.databaseUrl` at it. That is also the right answer if you were
planning to move to a managed instance anyway.

Verified on a cluster: a release installed from the v0.45.6 chart, upgraded to
this one, is refused with the volume named; a fresh install on the new chart
reaches 7/7 with 54 tables created.

### v0.45.5 — every credential is generated and kept

Nothing to supply, on install or on upgrade, including from a release installed
with the broken v0.45.2 chart. `helm upgrade` is the whole procedure.

The chart generates each secret on first install — signing keys, the vault key,
the internal API key, both webhook secrets, the Redis password — and reuses the
live value on every later render. The database password belongs to the
PostgreSQL subchart, which does the same; core, the worker, beat and both init
containers read it from that Secret instead of holding a copy.

Placeholders are not preserved. A release installed before v0.45.3 holds
`change-me-in-production` in its Secret; the chart treats those as absent and
generates real values, because core refuses to start on exactly that string.

Two secrets are pinned once written, since changing them breaks what they
protect: `core.secret.vaultKey` (decrypts stored secrets) and
`core.secret.secretKey` (signs the audit chain; a new key does not re-sign what
is already written). Supplying a different value for either is ignored on an
existing release — rotate deliberately, after re-encrypting.

Verified on a cluster, all three from scratch:

| Scenario | Result |
|---|---|
| `helm install` with no values at all | 7/7 Running, 150 s |
| Two upgrades, still no values | every credential unchanged, no pod restarted |
| Install with a chosen PostgreSQL password, upgrade without repeating it | password kept |
| The broken v0.45.2 chart, then `helm upgrade` with no values | 7/7 Running, 90 s |

### v0.15.x

- **`Job.gateway_id` is VARCHAR** — internal code that compared against a Python `UUID` object required `str(gw.id)`. No action needed on upgrade; DB column unchanged.
- **Alembic revision `j6k7l8m9n0o1`** — adds composite indexes on `jobs`, `audit_logs`, `memories`. Safe to apply hot; index creation does not lock reads on PostgreSQL 14+.

### v0.14.x

- No breaking schema changes.

### v0.13.x → v0.14.x

- `Organization` gained a self-referential `parent_org_id` FK (Tier 3 reselling, ADR 0013). Migration is additive and nullable — no data migration required.

---

## 6. Post-Upgrade Checklist

- [ ] `GET /api/v1/health` returns 200 with `worker.status: "online"`
- [ ] `alembic current` matches `alembic heads` (no pending migrations)
- [ ] Run smoke test: submit a simple job and verify it completes
- [ ] Check Grafana API SLO dashboard — no error spike
- [ ] Confirm gateway heartbeat: `GET /api/v1/gateways` shows `online: true` and recent `last_ping_at`
- [ ] Check audit log for unexpected errors: `GET /api/v1/audit?limit=20`
- [ ] Update `docs/STATUS.md` with new version and date
- [ ] Tag the git commit: `git tag v0.X.Y && git push origin v0.X.Y`
