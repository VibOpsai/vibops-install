# VibOps — Installation Guide

Complete step-by-step guide from zero to a running VibOps instance with a connected
GPU cluster and a working agent conversation.

---

## Table of Contents

1. [Server requirements](#1-server-requirements)
2. [Prerequisites](#2-prerequisites)
3. [Get a licence](#3-get-a-licence)
4. [Choose your deployment mode](#4-choose-your-deployment-mode)
   - [Option A — Docker Compose (POC / pilot)](#option-a--docker-compose-poc--pilot)
   - [Option B — Helm (production)](#option-b--helm-production)
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


### Production (Helm, multi-tenant, multiple clients)

| Resource | Requirement |
|----------|-------------|
| Kubernetes | 3 nodes minimum, 4 vCPU / 16 GB each |
| PostgreSQL | Managed service (RDS, CloudSQL, AlloyDB) — 2 vCPU / 8 GB |
| Redis | Managed service (ElastiCache, Memorystore) |
| Storage | 200 GB+ for PostgreSQL data + backups |

### What VibOps does NOT need

- **No GPU** on the VibOps server itself — GPUs stay on the client GPU clusters, managed via gateways
- **No local LLM** if using `LLM_PROVIDER=claude` or `openai` — the model is called via external API

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

VibOps starts a **14-day trial** automatically with Starter limits (32 GPU / 5 users / 2 clusters).
No key required — skip to step 3 to install and come back here when ready to activate.

### Activate a paid licence

Once you receive your `VIBOPS_LICENCE_KEY` from VibOps:

**Docker Compose:** add it to your `.env` file:
```bash
VIBOPS_LICENCE_KEY=eyJ...
```

**Helm:** add it to your `my-values.yaml`:
```yaml
core:
  secret:
    licenceKey: "eyJ..."
```

The licence is a self-contained RS256 JWT — no network call is made to validate it.
Plan limits (GPU, users, clusters) are enforced directly in the product.

You can check your licence status at any time in the console: **Admin (⚙) → Licence**.
A countdown banner appears in the header as the trial or licence approaches expiry.

---

## 4. Choose your deployment mode

### Option A — Docker Compose (dev / POC)

Recommended for: local development, demos, POC with a client.
Everything runs in Docker on a single machine. No Kubernetes required.

#### Step 1 — Clone and authenticate

```bash
git clone https://github.com/VibOpsai/vibops-install.git
cd vibops-install

# Authenticate to the VibOps container registry (token provided by VibOps)
make login VIBOPS_REGISTRY_TOKEN=<your-token>
```

> **Registry token:** VibOps Docker images are hosted on a private registry. You will receive a `VIBOPS_REGISTRY_TOKEN` from VibOps alongside your installation package. This token is required to pull the Docker images. Contact david@vibops.ai if you did not receive one.

#### Step 2 — Run quickstart

```bash
make quickstart
```

`make quickstart` does the following automatically:
- Copies `.env.example` → `.env`
- Generates `SECRET_KEY` and `JWT_SECRET_KEY` via `openssl rand -hex 32`
- Starts the full stack with `docker compose up -d`
- Runs `make check` to verify all services are healthy

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

Then restart the agent: `docker compose restart agent`

> **POC mode:** `AUTH_PASSWORD_HASH` is empty by default — the console opens without a login
> screen. Suitable for a controlled POC environment. See Step 5 to enable auth.

#### Step 4 — Verify

```bash
make check
# or: curl http://localhost:8000/api/v1/health
```

Open **http://localhost:8003** in your browser (or **http://SERVER_IP:8003** if installing on a remote server). You should see the VibOps console.

Services started by the stack:

| Service | Port | Description |
|---------|------|-------------|
| `console` | **8003** | Web UI — open this in your browser |
| `core` | 8000 | REST API + job engine (Swagger: `/docs`) |
| `agent` | 8001 | LLM agent |
| `llm-proxy` | 8004 | LLM inference proxy — per-agent GPU cost attribution |
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
# → $2b$12$...
# Paste the output into AUTH_PASSWORD_HASH in .env, then:
docker compose restart core
```

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

### Option B — Helm (production)

Recommended for: CSP client deployments, enterprise on-prem, any production workload.

#### Step 1 — Add Helm dependencies

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add vibops  https://charts.vibops.io
helm repo update
```

#### Step 2 — Prepare your values file

Create `my-values.yaml` (never commit this file — store it in your secrets manager):

```yaml
# ── LLM provider ──────────────────────────────────────────────
agent:
  secret:
    llmApiKey: "sk-ant-..."            # REQUIRED (or configure on-prem LLM below)

# ── Security ──────────────────────────────────────────────────
core:
  secret:
    secretKey:        "a-random-32-char-string"   # REQUIRED — change in prod
    jwtSecretKey:     "a-random-32-char-string"   # REQUIRED — shared with agent
    authUsername:     "admin"
    authPasswordHash: ""               # generate below; empty = auth disabled

    # Licence — leave empty for 14-day trial
    licenceKey: ""

    # ── Email / SMTP (required for password reset in multi-user mode) ──
    smtpHost:     "smtp.yourprovider.com"   # e.g. smtp.sendgrid.net
    smtpPort:     "587"
    smtpUser:     "apikey"
    smtpPassword: "SG.xxx"
    smtpFrom:     "noreply@yourcompany.com"

# ── Database ──────────────────────────────────────────────────
postgresql:
  enabled: false   # use managed DB in prod (RDS, CloudSQL, AlloyDB…)

core:
  env:
    DATABASE_URL: "postgresql+asyncpg://vibops:pass@my-pg-host:5432/vibops"
    REDIS_URL:    "redis://my-redis-host:6379/0"
    APP_ENV:      "production"

# ── Ingress + TLS ─────────────────────────────────────────────
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

**Generate a password hash for the admin user:**

```bash
docker run --rm ghcr.io/vibopsai/core:latest python -c \
  "from app.auth import hash_password; print(hash_password('yourpassword'))"
# → $2b$12$...
# Paste the result in authPasswordHash above
```

#### Step 3 — Install

```bash
helm install vibops vibops/vibops \
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

```bash
curl https://vibops.mycompany.com/api/v1/health
# → {"status": "ok"}
```

Open `https://vibops.mycompany.com` in your browser.

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

**If auth is disabled** (empty `AUTH_PASSWORD_HASH`): the dashboard loads directly. Skip to the wizard.

**If auth is enabled**: log in with the username and password from the bootstrap step.

### Onboarding wizard

On first access, the onboarding wizard appears automatically. It guides you through:

**Step 1 — Register your first gateway**

The gateway is the VibOps Connect worker that runs inside (or alongside) your GPU cluster.
It polls the Core for jobs, auto-discovers available kubeconfig contexts, and reports cluster metrics in every heartbeat.

1. Enter a name for the gateway (e.g. `prod-gpu-cluster`, `h100-pool-eu`) and click **Register**
2. Copy the token shown — **it is displayed only once**
3. Copy the pre-filled Helm (or Docker) deploy command and run it on the target cluster
4. The wizard shows **"Waiting for worker to connect…"** — it advances automatically once the first heartbeat arrives
5. The wizard confirms "Gateway connected ✓" and lists the discovered clusters

**Step 2 — Connect your Git provider (optional)**

Link your GitHub or GitLab repository to enable:
- Pipeline triggers on PR merge / MR merge
- Deployment rollback from commit history
- Webhook-based automation

Set `GIT_PROVIDER=github` or `GIT_PROVIDER=gitlab` in `.env`, then add your Personal Access Token in `GIT_TOKEN`.

Click **Skip for now** if you want to set this up later (Admin → Integrations).

**Step 3 — Done**

Click **Go to dashboard**. The main interface loads.

---

## 6. Connect your first GPU cluster

If you skipped the wizard or need to add more clusters, use one of these methods:

### Method A — Via the console (recommended)

1. Open the **Fleet** tab → click **"Add a gateway"** (or **⚙ Admin → Gateways → New Gateway**)
2. Enter a name and click **Register**
3. Copy the token — shown only once — and the pre-filled Helm deploy command
4. Run the command on your GPU cluster; the wizard auto-detects the connection within 30 seconds

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

# 2. Deploy the Connect worker
helm upgrade --install vibops-connect vibops/vibops-connect \
  --namespace vibops-connect \
  --set gateway.name="prod-gpu-cluster" \
  --set vibops.coreUrl="https://vibops.mycompany.com" \
  --set vibops.existingSecret="vibops-connect-token" \
  --set prometheus.url="http://prometheus-operated.monitoring.svc.cluster.local:9090" \
  --wait
```

### Verify the gateway is online

In the console, open the **Fleet** tab (second tab in the navigation bar). The gateway should appear in the **Gateways** sub-tab with status **Online** within 30 seconds. The Fleet sub-tab will show the cluster and its GPU metrics.

The agent will automatically discover namespaces, deployments and GPU resources on the next
discovery cycle (triggered manually via the status bar or automatically every 5 minutes).

---

## 7. First conversation with the agent

Open the **Agent** chat panel (right side of the console).

Try these prompts to verify everything works:

```
List all Kubernetes namespaces
```
→ The agent calls `list_namespaces` and returns the list. You should see tool cards appear.

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
| **Licence** | `VIBOPS_LICENCE_KEY` | | optional (trial without) |
| **Database** | `POSTGRES_PASSWORD`, `DATABASE_URL` | ✓ `make quickstart` | |
| **Security** | `SECRET_KEY`, `JWT_SECRET_KEY`, `VAULT_KEY` | ✓ `make quickstart` | |
| **Auth** | `AUTH_PASSWORD_HASH` | | ✓ `make hash PASSWORD=…` |
| **LLM** | `LLM_PROVIDER`, `LLM_API_KEY` | | ✓ API key required |
| **LLM on-prem** | `LLM_BASE_URL` | | if `LLM_PROVIDER=openai` |
| **LLM local** | `OLLAMA_URL` | default set | if `LLM_PROVIDER=ollama` |
| **Grafana** | `GRAFANA_PASSWORD` | ✓ `make quickstart` | |
| **Git** | `GIT_PROVIDER`, `GIT_TOKEN`, `GIT_URL` | | optional |
| **Datadog** | `DATADOG_API_KEY`, `DATADOG_APP_KEY` | | optional |
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
| `AUTH_USERNAME` | `admin` | Legacy single-user login (dev mode only) |
| `AUTH_PASSWORD_HASH` | `""` | bcrypt hash — empty disables password auth |
| `VIBOPS_LICENCE_KEY` | `""` | RS256 JWT licence key — omit for 14-day trial |
| `VAULT_KEY` | `""` | Fernet key for secret encryption — generate: `python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"` |
| `APP_ENV` | `development` | `development` \| `production` |
| `LOG_LEVEL` | `INFO` | `DEBUG` \| `INFO` \| `WARNING` \| `ERROR` |
| `CORS_ORIGINS` | `http://localhost:8003` | Comma-separated allowed origins |
| `SMTP_HOST` | `""` | SMTP server hostname — empty disables email sending |
| `SMTP_PORT` | `587` | SMTP port (`587` STARTTLS, `465` SSL) |
| `SMTP_USER` | `""` | SMTP login (e.g. `apikey` for SendGrid) |
| `SMTP_PASSWORD` | `""` | SMTP password or API key |
| `SMTP_FROM` | `""` | Sender address (e.g. `noreply@yourcompany.com`) |

### Agent environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LLM_PROVIDER` | `claude` | `claude` \| `openai` (on-prem) \| `ollama` |
| `LLM_MODEL` | `claude-sonnet-4-6` | Model name — interpreted by the active provider |
| `LLM_API_KEY` | `""` | API key — required for `claude` and `openai`, leave empty for `ollama` |
| `LLM_BASE_URL` | `""` | On-prem endpoint when `LLM_PROVIDER=openai` (e.g. `http://vllm:8000/v1`) |
| `OLLAMA_URL` | `http://ollama:11434` | Ollama endpoint when `LLM_PROVIDER=ollama` |
| `CORE_API_URL` | `http://core:8000` | Internal URL of the Core service |
| `JWT_SECRET_KEY` | `change-me` | Must match Core's value |
| `AGENT_MAX_HISTORY` | `20` | Max conversation turns kept in context |
| `AGENT_BUDGET_TOKENS` | `5000` | Max thinking tokens per turn (Anthropic only) |

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
OPENAI_BASE_URL=http://SERVER_IP:8004/v1

# Add headers for agent attribution
curl -X POST http://SERVER_IP:8004/v1/chat/completions \
  -H "X-VibOps-Agent-Id: pricing-agent-v2" \
  -H "X-VibOps-Team: supply-chain" \
  -d '{"model": "mistral:7b", "messages": [...]}'
```

Results are visible in the console under **FinOps → Agent LLM Usage**.

### Verify

```bash
curl http://SERVER_IP:8004/health
# → {"status": "ok", "backend": "http://ollama:11434"}

curl http://SERVER_IP:8004/v1/models
# → lists available models from all backends
```

---

## 13. Upgrading

### Docker Compose

```bash
make update   # pulls latest images, restarts services, runs healthcheck
```

### Helm (quick reference)

```bash
helm repo update vibops
helm upgrade vibops vibops/vibops -n vibops -f my-values.yaml --wait
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
| Agent returns empty responses | `LLM_API_KEY` not set or invalid | Check `.env`, then `docker compose restart agent` |
| Console loads but chat doesn't work | Agent not healthy | `docker compose logs agent` — check LLM provider connectivity |
| `docker compose pull` fails with 401 | Registry token expired or missing | `make login VIBOPS_REGISTRY_TOKEN=<token>` |
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
