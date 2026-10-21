# Updating the demonstration host

_Last updated: 2026-10-21 · v0.57.1_

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

  The fallback is a trap worth knowing: measured on 21/10/2026, the host's seven
  fallbacks still read `:-v0.54.2` while `.env` pinned `v0.57.1`. They have never
  been wrong, because `.env` has always carried the variable — but the day it
  does not, `docker compose up -d` rolls this host back three minor versions
  without an error, and the comparison in step 2 reports those seven lines every
  time, which is how they stopped being read.

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

The command below is what the bullet above says: the version lives in `.env`,
not in the compose file. A `sed` over `docker-compose.yml` — which is what stood
here until 21/10/2026, contradicting that bullet by four paragraphs — changes
only the fallbacks and leaves the host on whatever `.env` still pins.

```bash
sed -i 's/^VIBOPS_VERSION=.*/VIBOPS_VERSION=v<new>/' .env
grep '^VIBOPS_VERSION' .env       # read it back before pulling
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
- ~~Core connects as `vibops`, a superuser, so the row level security of ADR 0047
  does not apply.~~ **No longer true, and nothing here said so.** Measured on
  21/10/2026 while upgrading to v0.57.1: core announces
  `Isolation : connecté en « vibops_app », RLS applicable` at `info` level on
  every start. The role changed under this paragraph at some release between
  v0.54.6 and v0.57.1, and the runbook kept describing the old posture for two
  weeks — the step that would have caught it is step 4's
  `docker compose logs core | grep -i isolation`, which was already in the
  procedure and whose output nobody compared to this list. Read what that line
  says rather than trusting this bullet.
- No Cloudflare Origin CA certificate in `/etc/ssl/cloudflare`, so the
  Cloudflare → origin leg is still in clear — see `origin-tls.md`.

## The host is not the whole demo: two gateways run elsewhere

Everything above updates the Compose host. The GPU part of the demonstration —
KAI queues, NVLink topology, training jobs — does not execute there. It executes
in a `vibops-connect` pod on the Scaleway Kapsule cluster, which polls this host
for jobs. A release that fixes a connector changes nothing visible in the demo
until that pod is upgraded too.

There are **two** of them on the same physical cluster, registering it under two
different names, and they are not interchangeable:

| release | namespace | registers as | gateway id | writes |
|---|---|---|---|---|
| `connect-demo` | `vibops-demo` | `scw-par` | `05695cd7-…` | `rbac.allowWrite=true` |
| `vibops-connect` | `vibops-connect` | `scw-par1` | `75321381-…` | default (read only) |

`connect-demo` is the one the demonstration drives. The second belongs to the
other organisation that coexists on this cluster; it holds no write verb on KAI
queues, which is the chart default and correct for it.

```bash
export KUBECONFIG=~/.kube/scw-par1.yaml
helm upgrade <release> oci://ghcr.io/davidmacamara-boop/charts/vibops-connect \
  --version <chart> -n <namespace> --reuse-values --atomic --wait --timeout 10m
kubectl get pods -n <namespace> \
  -o custom-columns='NAME:.metadata.name,IMAGE:.spec.containers[0].image,READY:.status.containerStatuses[0].ready'
```

`--reuse-values` keeps the token out of the command line, and `--atomic` returns
the release to its previous revision if the new pod never becomes ready.

> **A pinned `image.tag` defeats a chart upgrade silently.** On 21/10/2026
> `vibops-connect` carried `image.tag: v0.52.8` in its values, from its install
> on 05/10. `helm upgrade --version 0.30.11 --reuse-values` reported *Upgrade
> complete*, revision 8, chart 0.30.11 — and the pod kept running v0.52.8, same
> pod name, zero restarts. The chart moved; the image did not. `--reuse-values`
> reuses a user-supplied tag by design, and the empty-tag fallback to
> `appVersion` only applies when no tag is set.
>
> Read the pod's image after every upgrade, never the Helm output. To unpin:
> `--set image.tag=` in the same upgrade, after which the release follows the
> chart's `appVersion` the way `connect-demo` already did.
