# Updating the demonstration host

_Last updated: 2026-10-02 · v0.51.2_

> **When to use this runbook:** a release has been tagged and the public demo
> should run it.

---

## Nothing updates this host for you

The `Deploy` workflow does **not** touch it. Its `Helm Deploy` job targets a
Kubernetes cluster through a `KUBECONFIG` secret that is not set; until
02/10/2026 it skipped every step and still reported success, so the workflow
announced six successful deployments while the host stayed on v0.49.2 — with a
`beat` container marked `unhealthy` that one of those releases had fixed. The job
is now skipped rather than green, and the run says so, but the conclusion stands:
**this host is updated by hand.**

The host runs Docker Compose with a hand-maintained `docker-compose.yml`. It is
close to `install/docker-compose.yml` but not identical, and the differences are
deliberate — do not overwrite it wholesale:

- `caddy` mounts `./static`, which the host's own `Caddyfile` serves `/whisper`
  and `/whisper-demo` from. The published file dropped that mount.
- `core` publishes no port; a separate `vibops_port_fwd` container forwards
  `127.0.0.1:8000`. Adding the published port mapping collides with it.
- `docker-compose.override.yml` carries the worker's kubeconfig and the
  `demo_pulse` service.

## Procedure

### 1. Back up, and verify the backup's contents

A dump that exists is not a dump that holds anything.

```bash
cd /opt/vibops
mkdir -p /root/before-<version>
docker compose exec -T postgres pg_dump -U vibops -d vibops_db > /root/before-<version>/vibops_db.sql
cp -a .env docker-compose.yml docker-compose.override.yml Caddyfile /root/before-<version>/

grep -c '^CREATE TABLE' /root/before-<version>/vibops_db.sql     # 57 at v0.51.2
docker compose exec -T postgres psql -U vibops -d vibops_db \
  -tAc 'select count(*) from gateways' -tAc 'select count(*) from users'
```

Note those counts. They are what you compare against afterwards.

### 2. Check what the release changes for a Compose deployment

```bash
git log --oneline <old>..<new> -- core/alembic/versions/   # empty = no migration
diff <(grep -vE '^\s*#' /opt/vibops/docker-compose.yml) \
     <(grep -vE '^\s*#' install/docker-compose.yml)
```

The second command is the one that matters: it shows which fixes landed in the
published file and have not reached this host. Port the ones that are real
defects; leave the host's deliberate differences alone.

### 3. Bump the image tags and apply the fixes you chose

```bash
sed -i 's|:v<old>|:v<new>|g' docker-compose.yml
docker compose config -q          # must be silent
docker compose pull
docker compose up -d
until ! docker compose ps --format '{{.Status}}' | grep -q 'health: starting'; do sleep 10; done
docker compose ps
```

### 4. Verify what is served, not what is tagged

```bash
curl -s http://127.0.0.1:8000/api/v1/health            # "version" must be the new one
docker compose logs core | grep -i isolation           # the database role core connects as
docker compose exec -T postgres psql -U vibops -d vibops_db \
  -tAc 'select count(*) from gateways' -tAc 'select count(*) from users'
curl -s -o /dev/null -w '%{http_code}\n' https://demo.vibops.ai/
```

Every container must read `healthy`. An `unhealthy` one that answers requests is
still a defect: it is how the `beat` scheduler sat broken across six releases.

## What this host still carries

- `APP_ENV=development`, so core's anonymous access is enabled. Caddy only
  exposes the console and two gateway paths, which bounds it — but it is not the
  production posture the manual describes.
- Core connects as `vibops`, a superuser, so the row level security of ADR 0047
  does not apply. Core says so on every start, at `warning` level.
- No Cloudflare Origin CA certificate in `/etc/ssl/cloudflare`, so the
  Cloudflare → origin leg is still in clear — see `origin-tls.md`.
