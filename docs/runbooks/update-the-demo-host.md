# Updating the demonstration host

_Last updated: 2026-10-11 · v0.54.6_

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

The host runs Docker Compose with a hand-maintained `docker-compose.yml`. Three
of the statements that stood here until 11/10/2026 were no longer true, and one
of them had become a defect. Measured, host against `install/docker-compose.yml`,
comments and image tags normalised away:

- **Zero differences.** The base file is in sync with the published one. The
  comparison was controlled before being believed: against the compose published
  at v0.53.3 and at v0.52.0 it reports six differing lines, so it does detect.
- **`caddy` no longer mounted `./static` — and that broke the demo.** The
  04/10/2026 synchronisation took the published file wholesale, which is exactly
  what the warning here said not to do, and the mount went with it.
  `https://demo.vibops.ai/whisper` and `/whisper-demo` answered **404** from that
  day until 11/10, while `docs/demo-script.md` sends a viewer to
  `https://demo.vibops.ai/whisper-demo` in bold. The content had never left
  (`/opt/vibops/static/whisper.html` and `whisper-demo.html` are still there);
  only the mount was gone, and `docker compose exec caddy ls /static` said so.
  Restored on 11/10 as `- ./static:/static:ro` on the `caddy` service, and both
  paths answer 200.
- **Image tags are not written out.** They are `${VIBOPS_VERSION:-v<old>}` and
  `.env` carries `VIBOPS_VERSION=v<old>`, so step 3 is an edit to `.env`, not a
  `sed` over the compose file.

`core` still publishes no port — that one held — and a separate
`vibops_port_fwd` container forwards `127.0.0.1:8000`.

> **Why this drifted silently — and what now stops it.** The host's `Caddyfile`
> was not in this repository; it existed only on the host, so nothing here could
> notice that it served a path from a directory no compose file mounts. It is
> versioned as of 11/10/2026:
>
> - `install/Caddyfile.demo` — the host's, comments and measured lessons included
> - `install/docker-compose.demo.yml` — the one deviation, the `./static` mount
> - `install/static/whisper-demo.html` — which was never in the repository at all
> - `tests/test_what_caddy_serves_is_mounted.py` — checks that every `root *` in
>   a versioned Caddyfile is mounted into `caddy`, and that every file a
>   `rewrite` names exists on the host side of that mount
>
> **Versioning synchronises nothing.** The host keeps its own copy and CI cannot
> reach it. After changing either side, copy to the other:
>
> ```bash
> scp root@<host-ip>:/opt/vibops/Caddyfile install/Caddyfile.demo   # host → repo
>
> # repo ↔ host, ignoring this repository's own header
> diff <(awk 'f || (!/^#/ && NF) {f=1; print}' install/Caddyfile.demo) \
>      <(ssh root@<host-ip> cat /opt/vibops/Caddyfile) && echo identical
> ```
>
> The `awk` prints from the first line that is neither a comment nor blank, so it
> does not care how long the header is. It replaced `tail -n +22`, which was
> written here on 11/10/2026 and was wrong by three lines the first time it was
> run — the header is 24 lines, and the comparison reported a drift that was
> only my own preamble. Verified the same day: with the `awk`, repository and
> host are identical.
>
> A non-empty diff means the two have really drifted, and step 4's check of the
> three public paths is what catches the consequence.

`docker-compose.override.yml` carries the worker's kubeconfig, its stable gateway
identity, and the `demo_pulse` service.

**Synchronised on 04/10/2026**, 385 → 670 lines, after drifting far enough that
the host still ran the pre-v0.52.0 backup. What landed: the reworked `backup`
service (Debian image for `openssl`, encryption in the pipe, retention suspended
unless the archive reads back), `backup-offsite` and `connect` (both behind their
profiles, so inert), and `llm-proxy`'s `127.0.0.1:8004`. Everything else was
compared service by service and is byte-identical.

The worker's gateway identity was **not** copied into the base file: the override
already sets it and mounts `worker_data`, and two definitions of the same mount
point is how you get a container that will not start.

> **`BACKUP_PASSPHRASE` is empty on this host, so its archives are not
> encrypted.** The mechanism is in place and falls back to cleartext by design
> when no key is set — `vibops_2026-10-04.sql.gz`, no `.enc`. Setting it is a
> custody decision, not a configuration one: an archive encrypted with a key
> nobody kept is an archive nobody can restore. ADR 0048 covers this.

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
for p in / /whisper /whisper-demo; do
  printf '%-14s ' "$p"
  curl -s -o /dev/null -w '%{http_code}\n' "https://demo.vibops.ai$p"
done
```

The three paths must all answer 200. `/whisper` and `/whisper-demo` are in this
list because they are the ones that silently broke: see above.

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
