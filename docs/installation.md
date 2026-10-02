# VibOps — Installation Guide

Complete step-by-step guide from zero to a running VibOps instance with a connected
GPU cluster and a working agent conversation.

---

## Table of Contents

1. [Server requirements](#1-server-requirements)
2. [Prerequisites](#2-prerequisites)
3. [Get a licence](#3-get-a-licence)
4. [Choose your deployment mode](#4-choose-your-deployment-mode)
   - [Option A — One-line install (`install.sh`)](#option-a--one-line-install-installsh)
   - [Option B — Docker Compose (POC / pilot)](#option-b--docker-compose-poc--pilot)
   - [Option C — Helm (production)](#option-c--helm-production)
5. [First login & onboarding wizard](#5-first-login--onboarding-wizard)
6. [Connect your first GPU cluster](#6-connect-your-first-gpu-cluster)
7. [First conversation with the agent](#7-first-conversation-with-the-agent)
8. [Invite your team](#8-invite-your-team)
9. [Configuration reference](#9-configuration-reference)
10. [On-prem LLM (air-gapped / sovereign)](#10-on-prem-llm-air-gapped--sovereign)
11. [Billing model](#11-billing-model)
12. [LLM Inference Proxy](#12-llm-inference-proxy)
13. [Upgrading](#13-upgrading)
14. [Troubleshooting](#14-troubleshooting)
15. [Uninstalling](#15-uninstalling)

---

## 1. Server requirements

VibOps runs on a Linux server — not on a workstation. The server must be reachable from the internet so that GPU cluster gateways can connect to it.

### POC / pilot (Docker Compose, up to ~20 users)

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 4 vCPU | 8 vCPU |
| RAM | 8 GB | 16 GB |
| Disk | 50 GB SSD | 100 GB SSD |
| OS | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |
| Network | Public IP, port 443 open | + domain name with TLS |

**RAM breakdown:** core 512 MB · worker 512 MB · agent 512 MB · console 256 MB · PostgreSQL 1 GB · Redis 256 MB · Prometheus + Grafana 512 MB · OS headroom 2 GB = ~6 GB total. 8 GB minimum, 16 GB comfortable.


### Pilot (Helm, on an existing cluster)

What the chart actually needs. PostgreSQL and Redis are bundled, so nothing is
provisioned beside them.

| Resource | Requirement |
|----------|-------------|
| Kubernetes | 1.27+, `linux/amd64` |
| Schedulable capacity | **2 vCPU and 2 GiB free**, on one node or several |
| StorageClass | one marked `(default)`, whatever its name — the chart claims 31 Gi across three volumes |
| PostgreSQL | bundled |
| Redis | bundled |

The chart requests **1200m of CPU and 1280 Mi** in total. Add the node's own
system pods and 2 vCPU / 2 GiB of *free* capacity is the floor — the figure to
check is what `kubectl describe node` reports as unallocated, not the instance
size.

Measured on 01/10/2026, on two providers:

- **Scaleway Kapsule**, two nodes, bundled datastores, `sbs-default`: seven pods
  Ready in 65 seconds.
- **OVH Managed Kubernetes**, one `d2-4` node (1.84 vCPU / 1.93 GiB
  allocatable), default class `csi-cinder-high-speed-gen2`: the three volumes
  bound, migrations ran, core answered healthy — and the console stayed
  `Pending` on `Insufficient cpu, Insufficient memory`. Six of seven pods fit.
  That node is below the floor, and it is what established the floor.

The second run is also what proves the storage fix travels: a default class
named nothing like `standard` binds all three volumes without configuration.

The row below was the only Helm sizing this guide offered until then, and it is
a production recommendation, not a floor. Quoted as a prerequisite it asks a
prospect for roughly three times what a pilot uses, which is how an evaluation
gets postponed.

### Production (Helm, multi-tenant, multiple clients)

Recommended once the installation carries real tenants and real traffic.

| Resource | Recommendation |
|----------|----------------|
| Kubernetes | 3 nodes, 4 vCPU / 16 GB each |
| PostgreSQL | Managed service (RDS, CloudSQL, AlloyDB) — 2 vCPU / 8 GB |
| Redis | Managed service (ElastiCache, Memorystore) |
| Storage | 200 GB+ for PostgreSQL data + backups |

### What VibOps does NOT need

- **No GPU** on the VibOps server itself — GPUs stay on the client GPU clusters, managed via gateways
- **No local LLM** if using `LLM_PROVIDER=claude` or `openai` — the model is called via external API

### What an installation reaches on the network

An installation is not self-contained: it pulls images and, in one mode, a
script and a compose file. Everything it reaches is listed here, so a firewall
rule can be written once rather than discovered during a maintenance window.

| Destination | Why | Which mode |
|---|---|---|
| `ghcr.io` | the seven VibOps images | all |
| `docker.io` (Docker Hub) | PostgreSQL, Redis, Caddy, Grafana, Prometheus, the Docker socket proxy | all |
| `vibops.ai` | `install.sh` and `docker-compose.yml` | one-line install only |
| `download.docker.com` | installs Docker when absent, from Docker's signed apt repository | one-line install only |

Two of those are avoidable and one is not:

- **The Helm and Compose modes never touch `vibops.ai` or Docker's repository.**
  Clone the install repository (or take the release tarball), install Docker or
  Kubernetes with your own means, and the only destinations left are the two
  registries.
- **Nothing downloaded is executed as code**, with one exception you choose:
  `install.sh` itself, which you can download, verify against the published
  `SHA256SUMS`, and read before running. Docker
  arrives as signed packages from Docker's apt repository — the procedure their
  documentation gives for production — not as the `get.docker.com` convenience
  script, which Docker states is not for production use. Until v0.46.6 this
  script used that one; it configures Let's Encrypt and calls itself the
  production path, so it had no business doing so.
- **The registries are not avoidable in the general case.** Software has to come
  from somewhere. What an air-gapped site does instead is mirror them — see
  below.

**Nothing phones home.** Licence keys are RS256 JWTs verified with a public key
embedded in the product: no activation call, no licence server, no telemetry, no
version check. A VibOps that has pulled its images runs with no outbound
connection at all, except the two the operator configures:

- the **LLM provider**, when it is a hosted one (`api.anthropic.com`,
  `api.openai.com`…). Point `LLM_BASE_URL` at an on-premise endpoint and even
  that disappears.
- the **gateways**, which poll your VibOps server outbound over 443 — see the
  next section. They reach your server, not ours.

Optional integrations add their own destinations when enabled, and only then:
GitHub or GitLab webhooks, an SMTP server, a Slack or Teams webhook, an OIDC or
LDAP provider, an OTLP collector.

#### Verifying the images

Every VibOps image is signed at its digest by the release workflow, with no
private key involved: cosign obtains a short-lived certificate from Sigstore's
CA by presenting the workflow's OIDC token, signs, and records the signature in
the public Rekor transparency log. The signature therefore asserts *which
workflow, in which repository, at which tag* produced that digest — a claim a
stolen key could not make.

```bash
cosign verify \
  --certificate-identity-regexp '^https://github\.com/davidmacamara-boop/vibops/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/davidmacamara-boop/vibops-core:v0.51.0
```

The identity flags are not optional decoration. Without them you would be
checking that *someone* signed the image; with them you are checking that *we*
did, from our repository. Each image also carries a provenance attestation and
an SBOM — `cosign download sbom <image>` and
`cosign verify-attestation --type slsaprovenance <image>`.

**Our own images are pinned too, in what we distribute.** The Compose file
served at vibops.ai and the chart shipped in `vibops-install` carry digests,
resolved from the registry once the images exist; the repository itself keeps
tags so a local build still runs. A pinned Compose file belongs to one release:
`install.sh --version vX.Y.Z` therefore takes that release's own file from the
install repository, rather than swapping a tag under a digest that would ignore
it.

**Enforcing the signature, rather than hoping someone checks it.** A
verification an operator has to remember is a verification that does not happen,
and Kubernetes checks nothing by itself. `helm/vibops/policies/kyverno-verify-images.yaml`
is a Kyverno policy that refuses any `vibops-*` image without a signature issued
to our release workflow, and rewrites the reference to the verified digest so
the pod runs what was checked. It is not installed by the chart — Kyverno is a
cluster-wide decision.

It ships in `Enforce`: an unsigned `vibops-*` image is refused, not merely
reported. It spent its first days in `Audit` for the usual reason — a policy
that refuses before anyone has seen what it would refuse gets deleted during an
incident — and the audit was run on 22/09/2026 against the published images by
digest: `core`, `agent`, `console`, `connect`, `worker` and `llm-proxy` are all
signed at `v0.46.6`. Those are every image the chart deploys that the rule
matches; `postgres` and `redis` come from Docker Hub and are outside it.

Two things to know before applying it. If you build your own VibOps images,
sign them with the same identity or narrow `imageReferences` — the policy does
not care who built an image, only who signed it. And `failurePolicy: Fail`
means a cluster that cannot reach ghcr or Rekor refuses new pods rather than
admitting unverified ones; that is the intended trade, but it is a real
dependency on two external services, and an air-gapped cluster needs a mirrored
Rekor or this policy removed.

```bash
kubectl apply -f helm/vibops/policies/kyverno-verify-images.yaml
```

**Third-party images are pinned by digest** in both the Compose file and the
chart (`postgres`, `redis`, `caddy`, `grafana`, `prometheus`, the Docker socket
proxy). A tag is a moving pointer — its publisher can repoint it at different
content tomorrow, and every install after that pulls something nobody reviewed.
The digest is the content. Refreshing one is a commit that shows what changed.

#### Air-gapped installation

Mirror both registries into one of your own, then point the deployment at it.

```bash
# On a machine with network access — copies manifests by digest, no rebuild
for image in \
  ghcr.io/davidmacamara-boop/vibops-core:v0.51.0 \
  ghcr.io/davidmacamara-boop/vibops-agent:v0.51.0 \
  ghcr.io/davidmacamara-boop/vibops-console:v0.51.0 \
  ghcr.io/davidmacamara-boop/vibops-worker:v0.51.0 \
  ghcr.io/davidmacamara-boop/vibops-llm-proxy:v0.51.0 \
  ghcr.io/davidmacamara-boop/vibops-connect:v0.51.0 \
  docker.io/library/postgres:16-alpine \
  docker.io/library/redis:7-alpine \
  docker.io/library/caddy:2-alpine \
  docker.io/grafana/grafana:11.6.0 \
  docker.io/prom/prometheus:v3.4.0 \
  docker.io/tecnativa/docker-socket-proxy:0.2 ; do
    docker buildx imagetools create --tag registry.internal/vibops/${image##*/} "$image"
done
```

Then, for Helm, override the repositories in your values file (`images.core.repository`,
`images.agent.repository`, `images.console.repository`, `postgresql.image.repository`,
`redis.image.repository`); for Compose, set the image lines to your registry.

> **On PostgreSQL.** Until v0.46.6 the chart pulled a Bitnami image that existed
> only under `bitnamilegacy` — a copy that works and receives no updates,
> security ones included. The chart now runs its own PostgreSQL on the official
> `postgres:16-alpine`, the same image the Compose deployment has always used:
> one image to follow instead of two, and the CVE scan sees it.

### Network requirement for gateway connectivity

GPU cluster gateways connect to VibOps using **outbound HTTPS polling** (no inbound ports required on the cluster side). The only firewall rule needed on the cluster side:

```
Allow outbound HTTPS (port 443) → your-vibops-server.com
```

---

## 2. Prerequisites

### All deployments

| Tool | Minimum version | Check |
|------|----------------|-------|
| Docker | 24 | `docker --version` |
| Python | 3.11 | `python3 --version` |
| curl | any | `curl --version` |

### Production only (Helm)

| Tool | Minimum version | Check |
|------|----------------|-------|
| Kubernetes | 1.27 | `kubectl version` |
| Helm | 3.12 | `helm version` |
| PostgreSQL | 14 | (managed DB recommended) |

### API keys

| Key | Required | Where to get it |
|-----|----------|----------------|
| LLM API key | Depends on provider — not needed for Ollama | Claude: [console.anthropic.com](https://console.anthropic.com/settings/keys) · OpenAI: [platform.openai.com](https://platform.openai.com/api-keys) · or your own provider |
| VibOps licence key | No (14-day trial auto-starts) | david@vibops.ai |

---

## 3. Get a licence

VibOps starts a **14-day trial** automatically, with trial limits: **10 GPU, 5
users, 5 clusters**. No key required — skip to step 3 to install and come back
here when ready to activate.

| Plan | GPU | Users | Clusters |
|---|---|---|---|
| trial (no key) | 10 | 5 | 5 |
| starter | 10 | 5 | 2 |
| pro | 50 | 20 | 10 |
| enterprise | unlimited | unlimited | unlimited |

**"Clusters" counts gateways, not clusters.** `check_clusters` is called on
gateway creation with the number of `Gateway` rows in the organisation
(`core/app/api/v1/gateways.py`), so one site is one unit however many clusters
its gateway reports. The column keeps the name the plan uses; this is what it
measures. GPU is the sum reported by every gateway of the organisation, checked
on each heartbeat — a fleet that crosses it keeps running and the ping answers
`gpu_limit_exceeded` rather than dropping the metrics.

These are `PLAN_LIMITS` in `core/app/licence.py`, and `tests/test_licence_limits_documented.py`
fails if this table and that dictionary disagree. Until 01/10/2026 this
paragraph read "Starter limits (32 GPU / 5 users / 2 clusters)": it named the
wrong plan, and two of its three numbers were wrong — 32 appears nowhere in the
product. A prospect sizing a pilot against it would have planned for three
times the GPUs the trial allows.

### Activate a paid licence

Three routes. **Prefer the first** — it is the only one that needs no restart.

**Console** (recommended) — **Admin (⚙) → Licence**, paste the key, save. It is
validated, applied **hot**, and written to the database so it survives the next
restart. The page then shows which licence is active, where it came from, and
when the trial started.

**Docker Compose** — in `.env`:
```bash
LICENCE_KEY=eyJ...
```

**Helm** — in `my-values.yaml`:
```yaml
core:
  secret:
    licenceKey: "eyJ..."
```

Precedence is **database → environment → trial**. The database wins
deliberately: an operator who activates a licence in the console acts *after*
deployment, and an environment variable winning would silently undo that at the
first restart.

> **`LICENCE_KEY`, and `VIBOPS_LICENCE_KEY` also works.** Until 01/10/2026 the
> guide, the chart and `onboard-client.sh` all set `VIBOPS_LICENCE_KEY` while
> the setting is named `licence_key` — so pydantic dropped it (`extra="ignore"`)
> and **a licence installed through Helm never reached the product**. The
> deployment stayed on trial limits, in silence. Both spellings are accepted
> now, and `tests/test_deployment_env_names.py` fails if a deployment file sets
> a variable nothing reads.

The licence is a self-contained RS256 JWT, verified offline against a public key
compiled into the product. No activation call, no licence server, no telemetry —
and therefore **no revocation**: a key is valid until its `exp`.

### What happens when it expires

Expiry is checked in exactly three places, all returning **402**:

- creating a gateway
- creating a user
- sending an organisation invite

Everything else keeps running — gateways ping, metrics are stored, energy is
measured, the console works. **You can no longer add; you can still see.** The
countdown banner in the header is the only warning, so plan the renewal rather
than waiting for a refusal.

The GPU ceiling is separate and checked on every heartbeat. Crossing it does not
stop anything being recorded: the ping answers `gpu_limit_exceeded`, the gateway
logs it at the site, and the Licence page shows the real count against the
limit. Only *actions* are refused — a GPU deployment past quota returns 429.

Nothing renews itself: there is no reminder, no job, no mail. Contact
david@vibops.ai before the end date.

---

## 4. Choose your deployment mode

> **Architecture: linux/amd64 only.** The published images carry no arm64
> variant — it was withdrawn on 13/09/2026 because nothing pulled it. On an ARM
> host (AWS Graviton, Ampere, Apple Silicon) the pull fails with
> `no match for platform in manifest`, which names the symptom and not the cause.
> Verified on 20/09/2026 against a real cluster.

### Option A — One-line install (`install.sh`)

Fastest path on a fresh Linux VM (Ubuntu 22.04+ / Debian 12+). Installs Docker if
needed, generates secrets, pulls the images and starts the stack.

```bash
curl -fsSL https://vibops.ai/install.sh | bash
```

**Verify it first** — it runs as root, and a piped script is read by nobody:

```bash
curl -fsSLO https://vibops.ai/install.sh
curl -fsSL  https://vibops.ai/SHA256SUMS | sha256sum --ignore-missing -c -
# install.sh: OK
bash install.sh
```

`SHA256SUMS` is published beside the script at each release and covers
`install.sh` and `docker-compose.yml`; `SHA256SUMS.version` names the release it
belongs to. A mismatch prints `install.sh: FAILED` and exits non-zero, so it can
gate the run:

```bash
curl -fsSL https://vibops.ai/SHA256SUMS | sha256sum --ignore-missing -c - && bash install.sh
```

It is the protection you would want from any vendor asking you to run a script
as root, and it costs us one line in a workflow.

For anything beyond the defaults, pass options to the file you downloaded:

```bash
bash install.sh --domain vibops.example.com --llm-key sk-ant-xxx
```

#### Options

| Option | Default | Purpose |
|---|---|---|
| `--domain` | *(none)* | Domain for the reverse proxy. **Enables automatic HTTPS** — see below |
| `--version` | latest release | Image tag to deploy, e.g. `v0.51.0` |
| `--llm-key` | *(none)* | LLM provider API key. Can also be set later in `.env` |
| `--llm-model` | `claude-sonnet-5` | Model name, interpreted by the active provider |
| `--llm-provider` | `claude` | `claude`, `openai`, `ollama` or `nemotron` |
| `--admin-email` | `admin@vibops.local` | Console administrator account |
| `--admin-org` | `My Organisation` | Name of the organisation that account belongs to |
| `--admin-password` | *(generated)* | Random and printed at the end if omitted |
| `--dir` | `/opt/vibops` | Installation directory |

Every option also reads its environment variable of the same name
(`VIBOPS_DOMAIN`, `LLM_API_KEY`…), which is what you want for unattended installs.

#### HTTPS

**With `--domain`**, Caddy obtains a Let's Encrypt certificate on first start and
redirects HTTP to HTTPS. Nothing else to configure. Two prerequisites:

- the DNS record for that domain points to this machine;
- ports 80 and 443 are reachable from the internet (Let's Encrypt validates over
  port 80).

#### What it creates, and what it does not

The script creates the administrator **account** — an organisation, a user and the
password hash — by calling the product's own provisioning, and prints the password
if you did not pass one. You can log in as soon as it finishes.

Until 01/10/2026 it did not. It wrote an `AUTH_PASSWORD_HASH` into `.env`, which is
what *enables* authentication but creates no account, and it computed that hash with
PBKDF2-SHA512 while the product verifies with scrypt. `POST /auth/login`
authenticates against the `users` table only. So the install finished on
"Installation complete", announced `Admin: admin@vibops.local`, served a login page —
and the `users` table was empty. Nobody could get in. Found by running it.

**If you omit `--llm-key`**, the agent will restart in a loop and keep doing so: the
script sets `APP_ENV=production`, and in production the agent refuses to start with
no key when the provider is `claude`. That is deliberate. Set the key in `.env` and
run `docker compose up -d agent` — `up -d`, not `restart`, see Step 3 below.

**Without `--domain`**, the install falls back to plain HTTP on port 80 and says so.
That is acceptable behind a TLS-terminating proxy such as Cloudflare, or on a private
network — but **passwords and session tokens travel unencrypted** otherwise. Let's
Encrypt cannot issue certificates for bare IP addresses, which is why a domain is
required.

To switch an existing install to HTTPS, replace `:80` with the domain on the first
line of `/opt/vibops/Caddyfile`, then `docker compose restart caddy`.

#### Ports

Only Caddy publishes ports — 80 and 443. Core, agent, console, Grafana and Prometheus
stay on the internal Docker network and are reached through the proxy. Nothing else
needs to be opened in your firewall.

---

### Option B — Docker Compose (dev / POC)

Recommended for: local development, demos, POC with a client.
Everything runs in Docker on a single machine. No Kubernetes required.

#### Step 1 — Clone

```bash
git clone https://github.com/VibOpsai/vibops-install.git
cd vibops-install
```

That is the whole step. **The images are public** — no registry login, no token,
nothing to request. `scripts/check-connect-artifacts-public.sh` in the product
repository verifies it by pulling anonymously.

This section used to say the images were on a private registry and to run
`make login VIBOPS_REGISTRY_TOKEN=<your-token>`, asking the reader to contact us
for a credential. There is no `login` target in the Makefile: the command
answered `make: *** No rule to make target 'login'` on the very first line a
prospect typed, after they had waited for a token they never needed. Removed on
01/10/2026 after running this path from a fresh clone.

#### Step 2 — Run quickstart

```bash
make quickstart
```

`make quickstart` does the following automatically:
- Copies `.env.example` → `.env`
- Generates `SECRET_KEY`, `JWT_SECRET_KEY`, `POSTGRES_PASSWORD`,
  `REDIS_PASSWORD` and `GRAFANA_PASSWORD`
- Starts the full stack with `docker compose up -d`
- Runs `make check` to verify all services are healthy

Until 01/10/2026 it generated every one of those **except `REDIS_PASSWORD`**,
which the compose file requires. `docker compose up` therefore refused to start
with five interpolation errors — the documented happy path failed on a fresh
clone, at the second command.

#### Step 3 — Set your LLM provider

Open `.env` and set your API key:

```bash
# Default: Claude (recommended)
LLM_PROVIDER=claude
LLM_API_KEY=sk-ant-...

# Or: OpenAI-compatible on-prem endpoint
LLM_PROVIDER=openai
LLM_BASE_URL=http://your-llm-endpoint:8000/v1

# Or: Ollama (local, no API key required)
LLM_PROVIDER=ollama
```

Then apply it: `docker compose up -d agent`

**`up -d`, not `restart`.** This said `docker compose restart agent` until
01/10/2026. `restart` stops and starts the *existing* container, which keeps the
environment it was created with — it does not re-read `.env`. Measured on a
validation host: after setting `LLM_PROVIDER=ollama` and running `restart`, the
container still reported `LLM_PROVIDER=claude` and the agent kept failing on
`LLM_API_KEY missing`; `up -d agent` picked the new value up and the agent came
up healthy. So the documented way to install your own API key did nothing, and
the symptom was indistinguishable from an invalid key.

> **POC mode:** `AUTH_PASSWORD_HASH` is empty by default — the console opens without a login
> screen. Suitable for a controlled POC environment. See Step 5 to enable auth.

#### Step 4 — Verify

```bash
make check
# or: curl http://localhost:8000/api/v1/health
```

Open **http://localhost** in your browser — or **http://SERVER_IP** on a remote
server, or your domain once you have set one in `Caddyfile`.

**The console is not on a port of its own.** Caddy serves it on 80 and 443, and
that is the only way in: the compose file publishes nothing for core or console
except core's health port on the loopback. This section said to open port 8003
until 01/10/2026 — the port the console listens on *inside* its container, and
which nothing maps. It never answered.

Services started by the stack, and how each is reached:

| Service | Reached at | Description |
|---------|------------|-------------|
| `caddy` | **80 / 443** | The only published entry point — serves the console and relays the gateway routes |
| `console` | through Caddy, on `/` | Web UI — open this in your browser |
| `core` | `127.0.0.1:8000` | REST API + job engine (Swagger: `/docs`) — loopback only |
| `agent` | `127.0.0.1:8001` | LLM agent — loopback only |
| `llm-proxy` | `127.0.0.1:8004` | LLM inference proxy — per-agent GPU cost attribution; loopback only, it has no authentication of its own (see section 12) |
| `worker` | — | Celery worker (job execution) |
| `beat` | — | Celery Beat (scheduled tasks) |
| `postgres` | 5432 | Database (internal) |
| `redis` | 6379 | Job queue broker (internal) |
| `prometheus` | **9090** | Metrics scraping + alerting rules |
| `grafana` | **3000** | Dashboards — admin / `${GRAFANA_PASSWORD:-vibops}` |
| `backup` | — | Daily `pg_dump` → `/backups/` (30-day retention) |

#### Step 5 — Bootstrap the first admin user (if auth is enabled)

To enable login, generate a password hash and add it to `.env`:

```bash
make hash PASSWORD=yourpassword
# → 6e243a826c9e1d064c53ef577b5fa733:a5dc8542838e5faf... (salt:hash, scrypt)
# Paste the whole line, colon included, into AUTH_PASSWORD_HASH in .env, then:
docker compose up -d core
```

Again `up -d`, for the same reason as Step 3: `restart core` keeps the container's
old `AUTH_PASSWORD_HASH`, so the password you just set would still be refused.

This example said `$2b$12$...` until 01/10/2026. That is a bcrypt hash, and the
product does not use bcrypt: `hash_password` is scrypt and returns a hex salt
and a hex digest joined by a colon. A reader comparing the two would conclude
the command had misbehaved, and might truncate at the colon.

Create the first org + admin user:

```bash
make pilot-create-client ORG="My Company" EMAIL=admin@example.com PASSWORD=yourpassword
```

The script is **idempotent** — safe to re-run (password is updated on re-run).
It prints the JWT token directly, ready to use for the first API calls.

Log in at **http://localhost:8003** (or **http://SERVER_IP:8003** on a remote server) with the credentials shown.

> **Pilot clients** — to provision additional client orgs (each isolated), run `make pilot-create-client` once per client.

> **Password reset by email** — for the "Forgot password" flow to send emails, configure `SMTP_HOST`, `SMTP_USER`, `SMTP_PASSWORD`, and `SMTP_FROM` in `.env` before going live. Without SMTP, the reset token is returned directly in the API response (dev mode only — not suitable for production).

---

### Option C — Helm (production)

Recommended for: CSP client deployments, enterprise on-prem, any production workload.

#### Step 1 — Fetch the chart

The charts ship **in the public install repository**, alongside the compose
file and this guide. There is no Helm *repository* to add — no chart index is
served — so take the charts from the source tree.

```bash
git clone https://github.com/VibOpsai/vibops-install.git
cd vibops-install        # contains helm/vibops and charts/vibops-connect
```

That is the whole step: `helm/vibops` declares **no chart dependencies**, so
there is no `helm dependency update` to run and no repository to add. PostgreSQL
and Redis are deployed from the official `postgres` and `redis` images, not from
subcharts.

This step opened with `helm repo add bitnami … # PostgreSQL/Redis dependencies`
until 01/10/2026. Those dependencies do not exist: the two commands added a
repository nothing reads, and the comment asserted a chart structure the chart
does not have. Removed after installing the chart on k3s.

In an air-gapped installation, the same two charts are inside the delivery
archive produced by `scripts/package-delivery.sh`; no clone and no outbound flow
are required.

Wherever the steps below reference a chart, use its path in that tree.

#### Step 2 — Prepare your values file

`helm install vibops ./helm/vibops -n vibops --create-namespace` needs no values
file at all: every credential is generated on install and kept across upgrades.
A values file is for what only you can provide — your LLM key, your ingress host,
your SMTP server (never commit it; store it in your secrets manager):

```yaml
# ── LLM provider ──────────────────────────────────────────────
agent:
  secret:
    llmApiKey: "sk-ant-..."            # REQUIRED (or configure on-prem LLM below)

# ── Security ──────────────────────────────────────────────────
# Nothing to fill in. The chart generates every secret core needs on first
# install — signing keys, the vault key, the internal API key, both webhook
# secrets, the database and broker passwords — and keeps them for the life of
# the release. Set one of them only to impose your own value.
core:
  secret:
    authPasswordHash: ""               # generate below; empty = auth disabled

    # Licence — leave empty for 14-day trial
    licenceKey: ""

    # ── Email / SMTP (required for password reset in multi-user mode) ──
    smtpHost:     "smtp.yourprovider.com"   # e.g. smtp.sendgrid.net
    smtpPort:     "587"
    smtpUser:     "apikey"
    smtpPassword: "SG.xxx"
    smtpFrom:     "noreply@yourcompany.com"

# ── Database and broker ───────────────────────────────────────
# Bundled by default, with generated passwords. Nothing to supply.
#
# Managed instead (RDS, CloudSQL, AlloyDB, ElastiCache…): disable the bundled
# ones and give core the two URLs. They belong under core.secret, not core.env
# — core.env holds no connection string, and a URL placed there is read by
# nothing.
# postgresql:
#   enabled: false
# redis:
#   enabled: false
# core:
#   secret:
#     databaseUrl: "postgresql+asyncpg://vibops_app:pass@my-pg-host:5432/vibops"
#     redisUrl:    "redis://:pass@my-redis-host:6379/0"
#
# Use a role **without BYPASSRLS** in that URL. Tenant isolation is enforced by
# PostgreSQL row-level security (ADR 0047), and the policies do not apply to a
# role that bypasses them — which a database owner normally does. The chart
# creates `vibops_app` for exactly this and grants it what the product needs;
# point the URL at that role, not at the account that owns the database.
#
# Core states which it got, on every start:
#   Isolation : connecte en « vibops_app », RLS applicable.
#   Isolation : connecte en « vibops », qui contourne la Row Level Security…

# ── Ingress + TLS ─────────────────────────────────────────────
# Two prerequisites, neither installed by this chart — see below.
ingress:
  enabled: true
  className: nginx    # or alb, traefik…
  host: vibops.mycompany.com
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  tls:
    - secretName: vibops-tls
      hosts: [vibops.mycompany.com]
```

**`ingress.enabled: true` needs two things the chart does not provide**, and it
fails silently without them:

1. **An ingress controller** whose class matches `className` — ingress-nginx,
   AWS ALB, Traefik. The chart creates an `Ingress` object; something has to act
   on it.
2. **cert-manager, and a `ClusterIssuer` actually named as in the annotation.**
   The annotation is a reference, not an instruction: with no cert-manager, no
   one reads it.

Also check the DNS record for `host` resolves to the controller's external
address, and that ports 80 and 443 reach it — an HTTP-01 challenge is validated
over port 80.

This block was documented with no mention of either prerequisite until
01/10/2026. Installed as written on a bare Scaleway Kapsule, it gives:

```
helm install …                       → exit 0, STATUS: deployed
kubectl get ingress -n vibops        → created, NO address assigned
kubectl get secret vibops-tls        → Error: secrets "vibops-tls" not found
kubectl get events (Ingress)         → No resources found
curl http://host/  curl https://host/ → 000 and 000
```

A green install that serves nothing, and not one message anywhere saying why.
With ingress-nginx and cert-manager installed and a `letsencrypt-prod` issuer,
the same values file produced a real Let's Encrypt certificate in under a
minute, HTTPS 200 with verification passing, and a 308 from HTTP to HTTPS.

**Generate a password hash for the admin user:**

```bash
docker run --rm --entrypoint python \
  ghcr.io/davidmacamara-boop/vibops-core:v0.51.0 -c \
  "from app.auth import hash_password; print(hash_password('yourpassword'))"
# → 6e243a826c9e1d064c53ef577b5fa733:a5dc8542838e5faf... (salt:hash, scrypt)
# Paste the whole line, colon included, in authPasswordHash above
```

#### Step 3 — Install

The chart claims three volumes — 20 Gi for PostgreSQL, 10 Gi for the agent's
training data, 1 Gi for the console — from your **default StorageClass**. Check
you have one before installing; the pods stay `Pending` without it, and nothing
else says why:

```bash
kubectl get storageclass          # one line must be marked (default)
```

```bash
helm install vibops ./helm/vibops \
  -n vibops --create-namespace \
  -f my-values.yaml \
  --wait --timeout 10m
```

Watch the rollout:

```bash
kubectl -n vibops get pods -w
# All pods should reach Running/Ready state
# The core pod runs Alembic migrations before starting — this is normal
```

#### Step 4 — Bootstrap the first admin user

```bash
kubectl exec -n vibops deploy/vibops-core -- \
  python -m scripts.bootstrap \
    --org      "My Company" \
    --slug     my-company \
    --username admin \
    --email    admin@mycompany.com \
    --password "yourpassword"
```

#### Step 5 — Verify

**If you configured `ingress` in your values file**, use your host:

```bash
curl https://vibops.mycompany.com/api/v1/health
# → {"status": "ok"}
```

**If you did not** — and Step 2 says a values file is optional, so this is the
default — the chart creates **no Ingress and no LoadBalancer**: every service is
`ClusterIP`. Nothing is reachable from outside the cluster, by design. Reach it
through the API server instead:

```bash
kubectl -n vibops port-forward svc/vibops-core 8000:8000 &
curl http://localhost:8000/api/v1/health
# → {"status":"ok","environment":"production", …}

kubectl -n vibops port-forward svc/vibops-console 8003:8003 &
# then open http://localhost:8003
```

This step gave only the ingress URL until 01/10/2026. A reader who had followed
Steps 1 to 4 exactly — a correct, working install — had no way to verify it and
no way to open the console: the only command offered pointed at a host no
resource served.

Open the console, then continue with section 5 below.

#### Optional: use the automated onboarding script

For CSP or enterprise deployments, the `onboard-client.sh` script handles steps 1–4
automatically, including secret generation, Helm install and rollout verification:

```bash
# Enterprise deployment
./scripts/onboard-client.sh \
  --segment      enterprise \
  --org          mycompany \
  --host         vibops.internal.mycompany.com \
  --db-url       "postgresql+asyncpg://vibops:pass@db.internal:5432/vibops_db" \
  --redis        "redis://redis.internal:6379/0" \
  --anthropic-key sk-ant-... \
  --licence-key  "eyJ..."

# CSP deployment (for a specific client)
./scripts/onboard-client.sh \
  --segment      csp \
  --org          acme-corp \
  --host         vibops.acme.com \
  --db-url       "postgresql+asyncpg://vibops:pass@db.acme.com:5432/vibops_db" \
  --redis        "redis://cache.acme.com:6379/0" \
  --anthropic-key sk-ant-... \
  --licence-key  "eyJ..."

# Dry-run to preview what will be executed
./scripts/onboard-client.sh --segment enterprise --org mycompany ... --dry-run
```

---

## 5. First login & onboarding wizard

Open the console URL in your browser.

**First-run setup**: if no admin account exists, the console shows a setup form. Enter your organization name, admin email, and password to bootstrap the instance.

**Returning users**: log in with your credentials.

### Onboarding wizard

On first login, if no infrastructure is connected yet, a 5-step onboarding wizard appears automatically.

**Step 1 — AI Provider**

Configure which LLM powers the VibOps agent:

- **Anthropic (Claude)** — enter your Anthropic API key (`sk-ant-...`)
- **OpenAI-compatible** — works with OpenAI, vLLM, Mistral, Groq, Together, DeepSeek, or any OpenAI-compatible API. Enter API key + optional base URL for on-prem endpoints
- **Ollama (local)** — enter the Ollama base URL (default: `http://ollama:11434`)

The wizard stores the configuration as VibOps secrets. Restart the agent service to apply changes.

**Step 2 — Infrastructure type**

Choose what VibOps will manage:

- **Kubernetes Cluster** — connect via VibOps Connect gateway
- **Virtual Machines** — Proxmox VE, Xen Orchestra, or VMware vSphere
- **Both** — Kubernetes clusters and virtual machines

You can add more clusters and hypervisors later in Settings.

**Step 3 — Connect infrastructure**

Depending on your choice:

- **Kubernetes**: enter a gateway name → click Register → copy the token (shown once) and the Helm install command → run it on your cluster → the wizard polls for the gateway heartbeat
- **Hypervisor**: select the type (Proxmox VE / Xen Orchestra / VMware vSphere) → enter the API URL and credentials → click Register

Use the **Skip** button to proceed without waiting for a heartbeat (useful for remote clusters that take longer to connect).

**Step 4 — Notifications (optional)**

Enter a Slack webhook URL to receive GPU alerts, anomaly notifications, and approval requests. Email notifications can be configured later in Settings with SMTP details.

Click **Skip** if you want to set this up later.

**Step 5 — Ready**

A summary of what was configured is shown. Click **Start using VibOps** to enter the dashboard.

---

## 6. Connect your infrastructure

Without this step, the console is empty. VibOps Connect is the bridge between your infrastructure and the console — it discovers your VMs, GPUs, clusters, and starts reporting metrics automatically.

> **Full guide:** [Connect Quick Start](./connect-quickstart.md) — 5 minutes, covers all platforms (K8s, Proxmox, vSphere, XCP-ng, Slurm).

If you skipped the wizard or need to add more sites, use one of these methods:

### Method A — Via the console (recommended)

1. Open the **Fleet** tab and click **"+ Connect Infrastructure"**. The button is
   on that tab only — it is not on the Dashboard.
2. The modal asks *what do you want to connect?* and offers **four** paths:
   **Kubernetes** (on-prem or managed — EKS, GKE, AKS, OKS), **Hypervisor**
   (Proxmox VE, Xen Orchestra, VMware vSphere), **Bare metal server** (iDRAC,
   iLO, XCC over Redfish) and **HPC / Slurm**.
3. For Kubernetes: type a gateway name, pick an environment (`prod`, `staging`,
   `dev`), then click **Connect**. The console registers the gateway and shows
   the `helm install` line to run on the target cluster, with the token and the
   gateway id already filled in.
4. For a hypervisor: enter the API URL and credentials, then **Connect
   Hypervisor**.
5. The modal then polls for the gateway's first heartbeat.

Until 01/10/2026 this section named a button that does not exist
(**"+ Connect Gateway"**), said it was on any tab, offered two choices instead of
four, and called the final button **"Register Gateway"** instead of **Connect**.
Corrected by driving the console in a browser.

> **Check `vibops.coreUrl` in the generated command before running it.** The
> console builds that value from the address *you* are using. With the default
> Helm install the chart creates no ingress, so the console is usually reached
> through `kubectl port-forward` — and the command then reads
> `--set vibops.coreUrl=http://localhost:8003`, which no pod can reach. Replace
> it with the address the gateway will use:
>
> - same cluster as VibOps: `http://vibops-core.vibops.svc.cluster.local:8000`
> - a remote site: your public ingress host, e.g. `https://vibops.mycompany.com`

> **The command passes the token as `--set vibops.token=…`**, which leaves it in
> your shell history and in `helm get values`. Method C below creates a
> Kubernetes Secret and references it with `vibops.existingSecret` instead;
> prefer that for anything beyond a test.

> **The onboarding wizard covers the same ground, and step 1 cannot be skipped.**
> On a fresh install with no gateway, logging in opens the five-step wizard, and
> its step 1 (AI provider) offers only **Save & Next** — pick `Ollama (local)` if
> you have no API key, since it needs none. Steps 3 and 4 do have **Skip**. Its
> step 3 registers a gateway exactly as this method does.

### Method B — Via the setup script (local dev)

For a local cluster (kind, minikube, or a reachable K8s context):

```bash
# Register the gateway and start the worker in one command
./scripts/connect-setup.sh --name my-cluster --cluster vibops-dev --start
```

The script:
1. Calls `POST /api/v1/gateways` to register the gateway
2. Saves credentials to `.connect-env` (gitignored)
3. Starts the Connect worker via `docker compose --profile connect`

To reuse existing credentials (if already registered):
```bash
# Credentials are auto-reloaded from .connect-env
./scripts/connect-setup.sh --start
```

### Method C — Helm (production cluster)

Deploy `vibops-connect` on the GPU cluster using the token from the console:

```bash
# 1. Create the token secret on the GPU cluster
kubectl create namespace vibops-connect
kubectl create secret generic vibops-connect-token \
  -n vibops-connect \
  --from-literal=token="<token-from-console>"

# 2. Deploy the Connect worker.
# GATEWAY_ID : l'UUID rendu avec le token a la creation de la passerelle.
# Prometheus et le noeud Slurm se saisissent sur la passerelle dans la
# console, pas ici — le chart ne les rend dans aucun template.
helm upgrade --install vibops-connect ./charts/vibops-connect \
  --namespace vibops-connect \
  --set gateway.id="$GATEWAY_ID" \
  --set gateway.clusterName="$SITE_NAME" \
  --set vibops.coreUrl="https://vibops.mycompany.com" \
  --set vibops.existingSecret="vibops-connect-token" \
  --wait
```

**`vibops.coreUrl` when Connect runs in the same cluster as VibOps.** The value
above is an ingress host, which is right for a *remote* site. For the cluster
that hosts VibOps itself — the usual first site, and the only one a
single-cluster customer has — there is no need to leave the cluster, and with
the default install there is no ingress to leave through:

```bash
  --set vibops.coreUrl="http://vibops-core.vibops.svc.cluster.local:8000" \
```

Only the ingress form was documented until 01/10/2026, so the first site a
reader connects was the one case the step did not cover. Verified on k3s: the
gateway reported `online`, declared its cluster and sent metrics within forty
seconds.

`gateway.clusterName` (chart 0.29.0 and later) is the name this cluster
declares itself under, and a cluster name is a routing address: the platform
refuses a name another gateway in the same organisation already holds. Left
empty, every in-cluster install declares `in-cluster`, so the second Kubernetes
site collides with the first and appears in the fleet with no cluster — its
metrics arriving all the while. Name it after the site.

### Verify the gateway is online

In the console, open the **Fleet** tab (second tab in the navigation bar). The gateway should appear in the **Gateways** sub-tab with status **Online** within 30 seconds. The Fleet sub-tab will show the cluster and its GPU metrics.

A gateway that reads **Online** with no cluster beside it has usually hit that
name conflict. `kubectl logs -n vibops-connect deploy/vibops-connect` names the
gateway already holding the name; reinstall with a different
`gateway.clusterName`.

The agent will automatically discover namespaces, deployments and GPU resources on the next
discovery cycle (triggered manually via the status bar or automatically every 5 minutes).

---

## 7. First conversation with the agent

Open the **Agent** chat panel (right side of the console).

Try these prompts to verify everything works:

```
List all Kubernetes namespaces
```
→ The agent resolves your clusters, then proposes `kubectl get namespaces` **and
waits for your confirmation** — the policy engine (ADR 0001) gates `run_kubectl`,
read-only commands included. Confirm, and you get the list. Tool cards appear at
each step.

This said "the agent calls `list_namespaces` and returns the list" until
02/10/2026. There is no `list_namespaces` action anywhere in the product, and the
confirmation step was not mentioned — so the very first prompt a reader types
looked like it had stalled. Corrected by running the four prompts against a live
agent.

```
Show me the GPU status of the cluster
```
→ The agent calls `get_gpu_status`. If Prometheus is not installed, it will offer to install
`kube-prometheus-stack` via Helm.

```
Are there any failing pods?
```
→ The agent calls `get_pod_status` and filters by non-Running state.

```
Give me a health summary of the cluster
```
→ The agent runs `correlate_incident` — combines logs, events, metrics and deployment
status into a single diagnosis.

If the agent responds correctly, your installation is complete.

---

## 8. Invite your team

VibOps uses a three-level hierarchy: **Organisation → Team → Member**.

### Create a team

Open **Admin (⚙) → Teams → New Team**.

Or via API:

```bash
# Get your org ID from Admin → (org name shown at top)
TOKEN="<your-jwt>"
ORG_ID="<your-org-id>"

curl -X POST https://vibops.mycompany.com/api/v1/orgs/$ORG_ID/teams \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "mlops-prod",
    "allowed_namespaces": ["ai-prod", "gpu-prod"],
    "allowed_envs": ["prod", "staging"],
    "allowed_clusters": ["prod-gpu-cluster"],
    "gpu_quota": 16
  }'
```

Team scopes limit what the agent can act on. A developer on a team scoped to `["ai-staging"]`
cannot deploy to `ai-prod` — the agent enforces this at the prompt level.

### Invite a user

Open **Admin (⚙) → Users → Invite User**.

Or via API:

```bash
curl -X POST https://vibops.mycompany.com/api/v1/orgs/$ORG_ID/users \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "alice",
    "email": "alice@mycompany.com",
    "password": "temp-password-change-on-login",
    "is_org_admin": false
  }'
# Note: email is optional but required for password reset by email to work.
```

### Add a member to a team

```bash
curl -X POST https://vibops.mycompany.com/api/v1/orgs/$ORG_ID/teams/$TEAM_ID/members \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "<alice-user-id>", "role": "developer"}'
```

### Roles

| Role | Permissions |
|------|-------------|
| `admin` | Full access including team management |
| `developer` | Read + write (deploy, scale, restart, rollback…) |
| `readonly` | Read only — no mutations, no destructive actions |

### Change password

Users can change their own password via **header menu → Change password**,
or via API:

```bash
curl -X PATCH https://vibops.mycompany.com/api/v1/auth/me/password \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"current_password": "old", "new_password": "new-secure-password"}'
```

### Forgot password

Users who have lost their password can reset it from the login page via **Forgot password?**.

**With SMTP configured** — a reset code is sent to the user's email address. The user enters
the code on the login page and sets a new password. Requires `SMTP_HOST` to be set and the
user to have an `email` address in the database.

**Without SMTP (dev mode)** — the reset code is returned directly in the API response and
pre-filled in the UI. Do not use in production.

> **Tip:** always set the `email` field when creating users (see above) — it is the only
> way to receive a password reset link in production.

---

## 9. Configuration reference

### Quick reference — what to set at install

| Category | Variable | Auto-generated | Required |
|----------|----------|:--------------:|:--------:|
| **Licence** | `LICENCE_KEY` | | optional — 14-day trial without |
| **Database** | `POSTGRES_PASSWORD`, `DATABASE_URL` | ✓ `make quickstart` | |
| **Security** | `SECRET_KEY`, `JWT_SECRET_KEY`, `VAULT_KEY` | ✓ `make quickstart` | |
| **Auth** | `AUTH_PASSWORD_HASH` | | ✓ `make hash PASSWORD=…` |
| **LLM** | `LLM_PROVIDER`, `LLM_API_KEY` | | ✓ API key required |
| **LLM on-prem** | `LLM_BASE_URL` | | if `LLM_PROVIDER=openai` |
| **LLM local** | `OLLAMA_URL` | default set | if `LLM_PROVIDER=ollama` |
| **Grafana** | `GRAFANA_PASSWORD` | ✓ `make quickstart` | |
| **Git** | `GIT_PROVIDER`, `GIT_TOKEN`, `GIT_URL` | | optional |
| **Datadog** | `DATADOG_API_KEY`, `DATADOG_APP_KEY`, `DATADOG_SITE` | | optional |
| **OpenTelemetry** | `OTEL_EXPORTER_OTLP_ENDPOINT` | | optional — OTLP traces + metrics |
| **Proxmox VE** | `PROXMOX_URL`, `PROXMOX_USER`, `PROXMOX_TOKEN_ID`, `PROXMOX_TOKEN` | | optional — VM management |
| **Xen Orchestra** | `XO_URL`, `XO_TOKEN` | | optional — XCP-ng VM management |
| **SMTP** | `SMTP_HOST`, `SMTP_USER`, `SMTP_PASSWORD` | | optional |
| **Internal** | `CORE_API_URL`, `AGENT_API_URL` | ✓ do not change | |

**Minimum required after `make quickstart`:**
1. `LLM_API_KEY` — your LLM provider API key (not needed if `LLM_PROVIDER=ollama`)
2. `AUTH_PASSWORD_HASH` — run `make hash PASSWORD=yourpassword` and paste the result

---

### Core environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DATABASE_URL` | — | PostgreSQL asyncpg URL |
| `REDIS_URL` | `redis://redis:6379/0` | Redis broker URL |
| `SECRET_KEY` | `change-me` | AES key for the secrets vault — **change in prod** |
| `JWT_SECRET_KEY` | `change-me` | JWT signing key — shared with Agent — **change in prod** |
| `JWT_EXPIRE_HOURS` | `24` | Access token lifetime in hours |
| `AUTH_PASSWORD_HASH` | `""` | bcrypt hash — empty disables password auth (dev mode) |
| `LICENCE_KEY` | `""` | RS256 JWT licence key — omit for the 14-day trial. `VIBOPS_LICENCE_KEY` is accepted as an alias |
| `VAULT_KEY` | `""` | Fernet key for secret encryption — generate: `python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"` |
| `APP_ENV` | `development` | `development` \| `production` |
| `LOG_LEVEL` | `INFO` | `DEBUG` \| `INFO` \| `WARNING` \| `ERROR` |
| `CORS_ORIGINS` | `http://localhost:8003` | Comma-separated allowed origins |
| `SMTP_HOST` | `""` | SMTP server hostname — empty disables email sending |
| `SMTP_PORT` | `587` | SMTP port (`587` STARTTLS, `465` SSL) |
| `SMTP_USER` | `""` | SMTP login (e.g. `apikey` for SendGrid) |
| `SMTP_PASSWORD` | `""` | SMTP password or API key |
| `SMTP_FROM` | `""` | Sender address (e.g. `noreply@yourcompany.com`) |

`AUTH_USERNAME` was listed here, and in the chart, and in the installer, and was
read by no line of the product — only a comment in `tenant.py` mentions it.
A setting an operator could change to no effect, with no way to find out.
Removed on 01/10/2026; `tests/test_deployment_env_names.py` now fails if a
deployment file or this guide names a variable nothing reads.

### Agent environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LLM_PROVIDER` | `claude` | `claude` \| `openai` (on-prem) \| `ollama` |
| `LLM_MODEL` | `claude-sonnet-5` | Model name — interpreted by the active provider |
| `LLM_API_KEY` | `""` | API key — required for `claude` and `openai`, leave empty for `ollama` |
| `LLM_BASE_URL` | `https://api.openai.com/v1` | On-prem endpoint when `LLM_PROVIDER=openai` (e.g. `http://vllm:8000/v1`) |
| `OLLAMA_BASE_URL` | `http://ollama:11434` | Ollama endpoint when `LLM_PROVIDER=ollama` |
| `NEMOTRON_BASE_URL` | `http://nim:8000/v1` | NVIDIA NIM endpoint |
| `CORE_API_URL` | `http://localhost:8000` | Internal URL of the Core service |
| `INTERNAL_API_KEY` | `""` | Service-to-service auth — must match Core's value |
| `JWT_SECRET_KEY` | `change-me-jwt-secret-in-production` | Must match Core's value |
| `THINKING_MODE` | `auto` | `auto` \| `adaptive` \| `enabled` \| `disabled` — extended thinking, Claude only |
| `THINKING_EFFORT` | `high` | Effort level when thinking is adaptive |
| `THINKING_BUDGET_TOKENS` | `10000` | Thinking budget. **Rejected by Sonnet 5, Opus 5/4.8/4.7 and Fable** — a 400 if sent; those models use `THINKING_MODE=adaptive` |
| `VERIFY_DESTRUCTIVE_ACTIONS` | `true` | Dry-run preview before a destructive action |

`AGENT_MAX_HISTORY` and `AGENT_BUDGET_TOKENS` were documented here until
01/10/2026 with defaults of 20 and 5000. Neither exists anywhere in the product.
An operator who set them changed nothing, and had no way to find out — which is
the worst kind of documented knob. The real thinking settings are the three
`THINKING_*` rows above, and there is no history cap to configure.

### Optional connector variables

| Variable | Description |
|----------|-------------|
| `ARGOCD_SERVER` | ArgoCD server URL |
| `ARGOCD_TOKEN` | ArgoCD API token |
| `AWS_ACCESS_KEY_ID` | AWS credentials for EKS |
| `AWS_SECRET_ACCESS_KEY` | — |
| `AWS_REGION` | AWS region |
| `GIT_TOKEN` | GitHub/GitLab Personal Access Token |
| `GIT_PROVIDER` | `github` or `gitlab` |
| `GITHUB_WEBHOOK_SECRET` | Shared secret for incoming webhooks (GitHub or GitLab) |
| `DATADOG_API_KEY` | Datadog API key |
| `DATADOG_APP_KEY` | Datadog application key |
| `DATADOG_SITE` | Datadog site (default: `datadoghq.com`, EU: `datadoghq.eu`) |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | OTLP collector endpoint (e.g. `http://otel-collector:4317`) — enables traces + metrics export to Datadog, Grafana, New Relic, etc. |
| `NGC_API_KEY` | NVIDIA NGC key for NIM model pulls |

---

## 10. On-prem LLM (air-gapped / sovereign)

VibOps supports any OpenAI-compatible LLM as a drop-in replacement for Claude.
Recommended for clients who require full data sovereignty (no data leaves the network).

### Supported runtimes

| Runtime | Models | Notes |
|---------|--------|-------|
| vLLM | GLM-4, Mistral, LLaMA 3, Mixtral… | Best tool-use performance |
| Ollama | llama3, mistral, gemma… | Easiest local setup |
| TGI (HuggingFace) | Any HF model | Requires OpenAI-compatible mode |

### Configuration (Docker Compose)

```bash
# In .env
LLM_PROVIDER=openai
LLM_MODEL=glm-4
LLM_BASE_URL=http://glm.ai-infra.local:8000/v1
LLM_API_KEY=                             # leave empty if no auth
```

### Configuration (Helm)

```yaml
agent:
  env:
    LLM_PROVIDER: "openai"
    LLM_MODEL: "glm-4"
    LLM_BASE_URL: "http://glm.ai-infra.svc.cluster.local:8000/v1"
  secret:
    llmApiKey: ""
```

For Ollama:
```yaml
agent:
  env:
    LLM_PROVIDER: "ollama"
    LLM_MODEL: "llama3:8b"
    OLLAMA_BASE_URL: "http://ollama.ai-infra.svc.cluster.local:11434"
```

### Limitations

- **Extended thinking** (chain-of-thought) is Claude-only — disabled automatically for other providers
- **Tool-use quality** varies significantly by model — Claude Sonnet/Opus outperforms open models on complex multi-tool tasks; validate your target model before go-live
- **Raise the timeout on CPU-only inference.** The agent sends a system prompt
  carrying several hundred tool definitions, and processing that prompt alone
  exceeds a minute on a small model without a GPU. Measured on 02/10/2026 with
  `qwen2.5:3b` on four vCPUs: the agent gave up with `openai.APITimeoutError`,
  while the same model answered a bare prompt in four seconds. With the setting
  raised, the same question came back in **128 seconds** — above the default, so
  that path cannot answer at all until you raise it. Set
  `LLM_TIMEOUT_SECONDS` (`.env`) or `agent.env.LLM_TIMEOUT_SECONDS` (Helm) —
  default `120`. Until that release the value was fixed in the code, so this
  path had nothing to adjust.
- **A GPU is the real answer** for an on-prem model driving this many tools; the
  timeout makes CPU inference possible, not comfortable.

---

## 11. Billing model

VibOps uses a **split billing model**:

| Cost | Who pays | How |
|------|----------|-----|
| **Anthropic API** (LLM tokens) | Client | Directly on the client's Anthropic account |
| **VibOps licence** | Client | Invoiced by VibOps (monthly flat + GPU/hr) |

The client brings their own Anthropic API key. VibOps has no visibility into the client's
Anthropic usage or costs. The client controls their own spend caps and rate limits.

When using an on-prem LLM (`LLM_PROVIDER=openai` or `ollama`), no Anthropic key is needed
and LLM inference costs are absorbed by the client's own GPU infrastructure.

---

## 12. LLM Inference Proxy

VibOps includes a transparent OpenAI-compatible proxy (port 8004) that sits between your AI agents and your LLM inference servers. It tracks every inference with per-agent cost attribution.

### Why use it

- **FinOps per agent** — which agent costs how much in GPU
- **Budget enforcement** — block agents that exceed their monthly spend limit
- **Model policy** — control which agent can use which LLM model
- **Anomaly detection** — alert on cost spikes, request surges, error rate jumps

### Configuration

Set the backend routing in `.env`:

```bash
# Map model name prefixes to upstream LLM servers
BACKENDS='{"mistral": "http://vllm-mistral:8000", "llama": "http://vllm-llama:8001"}'

# Fallback if no prefix matches
DEFAULT_BACKEND_URL=http://ollama:11434
```

### Usage

Point your AI agents (n8n, LangChain, CrewAI, Dify, or any OpenAI-compatible client) to the proxy:

```bash
# Change your agent's base URL
OPENAI_BASE_URL=http://127.0.0.1:8004/v1   # see “reaching it” below

# Add headers for agent attribution
curl -X POST http://127.0.0.1:8004/v1/chat/completions \
  -H "X-VibOps-Agent-Id: pricing-agent-v2" \
  -H "X-VibOps-Team: supply-chain" \
  -d '{"model": "mistral:7b", "messages": [...]}'
```

Results are visible in the console under **FinOps → Agent LLM Usage**.

### Verify

```bash
curl http://127.0.0.1:8004/health
# → {"status":"ok","backend":"http://ollama:11434"}

curl http://127.0.0.1:8004/v1/models
# → lists available models from all backends
```

### Reaching it from another machine

The proxy is published on **`127.0.0.1:8004` only**, and that is deliberate:
**it does not authenticate its callers.** It relays to your inference servers and
attributes cost from an `X-VibOps-Agent-Id` header it takes on trust. Exposed to
the network, anyone could spend your inference budget under any agent's name.

So an agent on another machine reaches it one of two ways, both your decision:

- **A route on the reverse proxy**, with whatever authentication you put in front
  of it — Caddy supports basic auth, mTLS and forward-auth.
- **An SSH tunnel** from the machine running the agent:
  `ssh -L 8004:127.0.0.1:8004 user@SERVER_IP`.

Until 02/10/2026 this section said `http://SERVER_IP:8004` and the service was
published on no port at all: all four commands above returned 000, on a healthy
installation. Only `http://llm-proxy:8004/health` answered, from inside the
Docker network. Measured on an amd64 host.

---

## 13. Upgrading

### Docker Compose

```bash
make update   # refreshes the clone, pulls the images, recreates, runs make check
```

**The upgrade comes from the repository, not from the registry.** The compose
file you installed from pins every image by digest — deliberately, since a tag is
a pointer its owner can move. `docker compose pull` on a digest therefore always
returns the same bytes. `make update` refreshes the clone first (`git pull
--ff-only`), which brings the new compose file and its new digests, and only then
pulls. Your `.env` and `Caddyfile` are untracked and are never touched.

If you installed with `install.sh` rather than from a clone, there is no
repository to refresh: fetch the new `docker-compose.yml` from
`https://vibops.ai/docker-compose.yml` before running `make update`, and check
its checksum against `https://vibops.ai/SHA256SUMS`.

### Helm (quick reference)

```bash
git -C vibops-install pull          # refresh the chart you installed from
helm upgrade vibops ./helm/vibops -n vibops -f my-values.yaml --wait
```

Alembic migrations run automatically on startup (Docker Compose: on core start; Helm: via init container).

---

## 14. Troubleshooting

If something isn't working after installation, generate a debug bundle:

```bash
make debug
```

This produces a `vibops-debug-YYYY-MM-DD-HHMMSS.tar.gz` file containing:
- System info (OS, CPU, RAM, disk, Docker version)
- Container status and resource usage
- Logs (last 500 lines per service)
- Health check results
- PostgreSQL and Redis connectivity
- Environment configuration (all secrets automatically redacted)

Send this file to **david@vibops.ai** for support. No secrets are included.

### Common issues

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `make check` fails on core | Database not ready or migration error | `docker compose logs core` — check for Alembic errors |
| Agent returns empty responses, or restarts in a loop | `LLM_API_KEY` not set or invalid | Check `.env`, then `docker compose up -d agent` — `restart` does not re-read `.env` |
| Console loads but chat doesn't work | Agent not healthy | `docker compose logs agent` — check LLM provider connectivity |
| `docker compose pull` fails with 401 | The images are public, so this is not a missing token: either the tag does not exist, or your Docker is sending stale ghcr.io credentials | Check the tag against the [releases](https://github.com/VibOpsai/vibops-install/tags), then `docker logout ghcr.io` and retry |
| GPU cluster not appearing in Fleet | Gateway not connected | Check gateway logs on the cluster side, verify outbound HTTPS to VibOps server |

---

## 15. Uninstalling

### Docker Compose

```bash
docker compose down -v    # -v removes named volumes (PostgreSQL data)
```

Remove images:
```bash
docker compose down --rmi all
```

### Helm

```bash
helm uninstall vibops -n vibops
kubectl delete namespace vibops
```

> This does **not** delete the PostgreSQL data if you used an external database.
> Drop the `vibops` database manually if needed.
