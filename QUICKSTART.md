# VibOps — Quick Start Guide

Three paths — pick yours:

- **[Option A — Install on your PC](#option-a--install-on-your-pc)** — for testing locally on your own machine
- **[Option B — Install on a CSP internal server](#option-b--install-on-a-csp-internal-server)** — recommended for CSPs hosting VibOps on their own infrastructure
- **[Option C — Install on a cloud server](#option-c--install-on-a-cloud-server)** — for POC with external clients, shared access over the internet

---

# Option A — Install on your PC

This runs VibOps locally on your Mac or Windows machine.
No technical background required.

---

## What you need before starting

### 1. Docker Desktop

Docker is the software that runs VibOps on your computer.

- **Mac:** download at https://www.docker.com/products/docker-desktop — click "Download for Mac"
- **Windows:** same link — click "Download for Windows"

After installing, open Docker Desktop and wait until you see **"Docker Desktop is running"** in the bottom left corner. Keep it open.

> **Check it works:** open a terminal and type:
> ```
> docker --version
> ```
> You should see something like `Docker version 26.1.0`. If you get an error, Docker is not running — go back and start Docker Desktop.

---

### 2. An AI provider

VibOps uses an AI to understand your requests. You have three options — pick the one that fits your situation:

| Option | Best for | What you need |
|--------|----------|---------------|
| **Claude (Anthropic)** | Best results, cloud | An Anthropic API key |
| **Any OpenAI-compatible API** | Your own provider or on-prem endpoint | An API key + the endpoint URL |
| **Ollama (local)** | Air-gapped, no API key, free | Just install Ollama |

**Option A — Claude (Anthropic)**
1. Go to https://console.anthropic.com/settings/keys
2. Sign in (or create a free account)
3. Click **"Create Key"** and copy it — it looks like `sk-ant-api03-...`

**Option B — Another provider (OpenAI, Mistral, Azure OpenAI…)**
You will need:
- The API endpoint URL (e.g. `https://api.openai.com/v1`)
- Your API key for that provider

**Option C — Ollama (local, no account needed)**
Install Ollama at https://ollama.com, then run `ollama pull llama3` to download a model.
See [Using a local AI](#using-a-local-ai-no-api-key) for the full setup.

> You will configure your chosen provider in Step 3 after the initial install.

---

### 3. A terminal

A terminal is the window where you type commands.

- **Mac:** press `Cmd + Space`, type `Terminal`, press Enter
- **Windows:** press `Windows + R`, type `cmd`, press Enter

---

## Installation

### Step 1 — Download VibOps

In your terminal, type these two commands one at a time (press Enter after each):

```
git clone https://github.com/vibops/vibops-install.git
```

```
cd vibops
```

You should now be inside the VibOps folder.

> **"git: command not found"?**
> - Mac: run `xcode-select --install` and follow the prompts
> - Windows: download Git at https://git-scm.com/download/win

---

### Step 2 — Start VibOps

Type this command:

```
make quickstart
```

This command does three things automatically:
1. Creates your configuration file
2. Generates your security keys
3. Starts all VibOps services

You will see a lot of text scrolling — this is normal. Wait until you see:

```
✓ GET /api/v1/health → 200
✓ Worker status: online
✓ PostgreSQL connected
All checks passed. VibOps is operational.
```

This takes about 30–60 seconds on first run (Docker needs to download the services).

> **"make: command not found"?**
> - Mac: run `xcode-select --install`
> - Windows: install Make via https://gnuwin32.sourceforge.net/packages/make.htm
>   — or replace `make quickstart` with: `docker compose up -d`

---

### Step 3 — Configure your AI provider

Open the file called `.env` that was just created in the `vibops` folder.

> **Can't find it?** The file starts with a dot — it may be hidden.
> - Mac Finder: press `Cmd + Shift + .` to show hidden files
> - Windows Explorer: go to View → Show → Hidden items
> - Or open it from the terminal: `open .env` (Mac) or `notepad .env` (Windows)

Find the `LLM_PROVIDER` line and set it to match your chosen provider:

**Claude (Anthropic):**
```
LLM_PROVIDER=claude
LLM_API_KEY=sk-ant-...
```

**Another provider (OpenAI, Mistral, or any OpenAI-compatible endpoint):**
```
LLM_PROVIDER=openai
LLM_API_KEY=your-api-key
LLM_BASE_URL=https://api.openai.com/v1
```
Replace `LLM_BASE_URL` with your provider's endpoint if it is not OpenAI.

**Ollama (local, no API key):**
```
LLM_PROVIDER=ollama
```

Save the file, then restart the AI service:

```
docker compose restart agent
```

---

### Step 4 — Open VibOps

Open your browser and go to:

**http://localhost:8003**

You should see the VibOps console. If you see a blank page or an error, wait 10 seconds and refresh.

---

### Step 5 — Create your account

VibOps starts without a password (open access — fine for a local POC).
To create a protected account with login:

**5a — Generate a password hash:**

```
make hash PASSWORD=choose-a-password-here
```

This prints a long string starting with `$2b$12$...` — copy it.

**5b — Add it to your configuration:**

Open `.env` again, find this line:

```
AUTH_PASSWORD_HASH=
```

Paste your copied string after the `=`. Example:

```
AUTH_PASSWORD_HASH=$2b$12$abc123...
```

Save the file.

**5c — Create your organisation and user:**

```
make pilot-create-client ORG="My Company" EMAIL=you@yourcompany.com PASSWORD=choose-a-password-here
```

Replace the values with your own. Press Enter.

You will see a confirmation message. You can now log in at **http://localhost:8003** with your email and password.

---

## Your first conversation

Once you are in the console, click on the **Agent** panel on the right side.

Try typing:

```
List all Kubernetes namespaces
```

The agent will respond and show the tool it used. If you see a response (even an error saying no cluster is connected), the agent is working correctly.

---

## Connect a GPU cluster

VibOps manages GPU clusters through a small connector called a **Gateway**.

1. In the console, go to the **Fleet** tab and click **"Add a gateway"** (or **⚙ Admin → Gateways → New Gateway**)
2. Enter a name (e.g. `my-gpu-cluster`) and click **Register**
3. Copy the token — **shown only once** — and the pre-filled Helm command
4. On the machine that has `kubectl` access to your GPU cluster, run:

```
# Add the VibOps Helm repo (once per machine)
helm repo add vibops https://charts.vibops.io
helm repo update

# Deploy the gateway
helm upgrade --install vibops-connect vibops/vibops-connect \
  --namespace vibops-connect --create-namespace \
  --set gateway.name="my-gpu-cluster" \
  --set vibops.coreUrl="http://YOUR_MACHINE_IP:8000" \
  --set vibops.token="PASTE_YOUR_TOKEN_HERE"
```

5. The wizard shows **"Waiting for worker to connect…"** and advances automatically when the first heartbeat arrives

The worker auto-discovers all kubeconfig contexts on the node where it runs — no manual cluster registration needed.

**To connect a second or third cluster**, repeat from step 1 with a different gateway name.

**If the gateway does not go Online**, check the pod logs:
```
kubectl logs -n vibops-connect deployment/vibops-connect
```

**If a token is compromised**, go to **Settings → Gateways**, delete the gateway and register a new one — the old token is immediately invalidated.

> **No GPU cluster yet?** You can still explore VibOps — the agent can answer questions, run diagnostics, and plan deployments. Connect a cluster when you are ready.

---

## Verify everything is healthy

At any time, run:

```
make check
```

You will see the status of each component:

```
✓ GET /api/v1/health → 200
✓ Worker status: online (2 active)
✓ PostgreSQL connected
✓ Token valid
✓ 1/1 gateway(s) online
✓ Agent API reachable
✓ Console reachable
All checks passed.
```

If something shows ✗, the output tells you exactly what to do.

---

## Stop and restart VibOps

```
make down    # stop everything
make up      # start again (your data is preserved)
```

---

## Using a local AI (no API key)

If you do not have an Anthropic API key, VibOps can use **Ollama** — a free AI that runs entirely on your machine.

**1. Install Ollama:** https://ollama.com — download and install for your OS.

**2. Download a model** (in a new terminal window):

```
ollama pull llama3
```

This downloads about 4 GB. Wait for it to finish.

**3. Configure VibOps:**

Open `.env` and change these two lines:

```
LLM_PROVIDER=ollama
```

**4. Restart the agent:**

```
docker compose restart agent
```

> **Note:** Ollama works well for simple tasks. For complex multi-step operations (deploy, rollback, incident triage), Claude gives significantly better results.

---

## Common problems

**"Port 8003 is already in use"**
Another application is using that port. Stop it, or change the port in `docker-compose.yml`.

**"Cannot connect to Docker daemon"**
Docker Desktop is not running. Open it and wait for it to say "running".

**The console loads but the agent does not respond**
Check your API key in `.env`. Run `make check` — it will tell you what is wrong.

**"make: command not found" on Windows**
Use the full docker commands instead:
```
docker compose up -d      # instead of make up
docker compose down       # instead of make down
```

---

## Getting help

- Run `make check` — it diagnoses the most common issues automatically
- Full installation guide (for technical users): [`docs/installation.md`](docs/installation.md)
- Incident runbook: [`docs/runbooks/incident-response.md`](docs/runbooks/incident-response.md)
- Support: david@vibops.ai

---

# Option B — Install on a CSP internal server

VibOps runs on a server inside the CSP's own infrastructure.
Users and GPU clusters access it via the internal network — no internet exposure required.

**Best for:** CSPs hosting VibOps for their own operations team, with GPU clusters on the same private network.

---

## What you need

### 1. A Linux server (internal)

A VM or physical server on the CSP's internal network.

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 4 vCPU | 8 vCPU |
| RAM | 8 GB | 16 GB |
| Disk | 50 GB SSD | 100 GB SSD |
| OS | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |
| Network | Reachable from GPU clusters on internal network | Internal hostname recommended |

> **No GPU needed on this server.** VibOps itself is lightweight — the GPUs stay on the GPU clusters.

### 2. An AI provider

Choose one:
- An internal LLM endpoint (Ollama, vLLM, or any OpenAI-compatible API hosted internally)
- A cloud API (Claude, OpenAI) if outbound internet access is available from this server

### 3. SSH access to the server

---

## Installation

### Step 1 — Connect to your server

```
ssh ubuntu@INTERNAL_SERVER_IP
```

### Step 2 — Install Docker, Make, Git

```
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER && newgrp docker
sudo apt-get update && sudo apt-get install -y make git
```

### Step 3 — Download and start VibOps

```
git clone https://github.com/vibops/vibops-install.git
cd vibops
make quickstart
```

Wait until you see:

```
✓ GET /api/v1/health → 200
✓ Worker status: online
✓ PostgreSQL connected
All checks passed. VibOps is operational.
```

### Step 4 — Configure your AI provider

```
nano .env
```

For an internal LLM endpoint:
```
LLM_PROVIDER=openai
LLM_API_KEY=                               # leave empty if no auth
LLM_BASE_URL=http://your-llm-host:8000/v1
```

For Ollama running on this same server:
```
LLM_PROVIDER=ollama
```

Save (`Ctrl+O`, `Ctrl+X`), then:
```
docker compose restart agent
```

### Step 5 — Access the console

Open your browser and go to:

**http://INTERNAL_SERVER_IP:8003**

This URL is accessible to anyone on the internal network — no internet exposure.

### Step 6 — Create your account

```
make hash PASSWORD=choose-a-password
```

Paste the result in `AUTH_PASSWORD_HASH` in `.env`, then:

```
make pilot-create-client ORG="My Company" EMAIL=admin@mycompany.com PASSWORD=choose-a-password
docker compose restart core
```

### Step 7 — Connect GPU cluster gateways

**Prerequisites on the GPU cluster side:** `kubectl` configured + `helm` installed.

For each GPU cluster:

1. In the console, go to the **Fleet** tab → click **"Add a gateway"** (or **⚙ Admin → Gateways → New Gateway**)
2. Enter a name and click **Register** — copy the token (**shown once only**) and the pre-filled Helm command
3. From a machine with `kubectl` access to that cluster, run:

```
# Add the VibOps Helm repo (once per machine)
helm repo add vibops https://charts.vibops.io
helm repo update

# Deploy the gateway
helm upgrade --install vibops-connect vibops/vibops-connect \
  --namespace vibops-connect --create-namespace \
  --set gateway.name="my-gpu-cluster" \
  --set vibops.coreUrl="http://INTERNAL_SERVER_IP:8000" \
  --set vibops.token="PASTE_YOUR_TOKEN_HERE"
```

4. The wizard auto-detects the connection and shows **Online** within 30 seconds

The gateway uses **outbound polling only** — no inbound ports needed on the cluster side. The worker auto-discovers all kubeconfig contexts on the node where it runs.

**To add more clusters**, repeat from step 1 with a different gateway name (e.g. `gpu-cluster-2`).

**If the gateway does not go Online**, check the pod logs:
```
kubectl logs -n vibops-connect deployment/vibops-connect
```

**If a token is compromised**, delete the gateway in the console and register a new one — the old token is immediately invalidated.

---

## Verify

```
make check
```

---

## Stop and restart

```
make down
make up
```

---

# Option C — Install on a cloud server

VibOps runs on a cloud VM with a public IP.
Accessible from anywhere over the internet — suitable for remote teams or clients connecting from outside the CSP network.

**Best for:** POC with external clients, geographically distributed teams, or when GPU clusters are in a different network from the VibOps server.

---

## What you need

### 1. A Linux cloud server

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU | 4 vCPU | 8 vCPU |
| RAM | 8 GB | 16 GB |
| Disk | 50 GB SSD | 100 GB SSD |
| OS | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |
| Network | Public IP, port 443 open | + domain name with TLS |


### 2. An AI provider

Same options as Option A — Claude, any OpenAI-compatible API, or Ollama.

### 3. SSH access to the server

---

## Installation

### Step 1 — Connect to your server

```
ssh ubuntu@YOUR_PUBLIC_IP
```

### Step 2 — Install Docker, Make, Git

```
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER && newgrp docker
sudo apt-get update && sudo apt-get install -y make git
```

### Step 3 — Download and start VibOps

```
git clone https://github.com/vibops/vibops-install.git
cd vibops
make quickstart
```

Wait until you see:

```
✓ GET /api/v1/health → 200
✓ Worker status: online
✓ PostgreSQL connected
All checks passed. VibOps is operational.
```

### Step 4 — Configure your AI provider

```
nano .env
```

```
# Claude
LLM_PROVIDER=claude
LLM_API_KEY=sk-ant-...

# Or: OpenAI-compatible
LLM_PROVIDER=openai
LLM_API_KEY=your-key
LLM_BASE_URL=https://api.openai.com/v1
```

Save (`Ctrl+O`, `Ctrl+X`), then:
```
docker compose restart agent
```

### Step 5 — Open the firewall

```
sudo ufw allow 22     # SSH
sudo ufw allow 80     # HTTP
sudo ufw allow 443    # HTTPS
sudo ufw allow 8000   # VibOps API (for gateways)
sudo ufw allow 8003   # VibOps console
sudo ufw enable
```

> If using a cloud provider (AWS, Hetzner, OVH…), also open these ports in the cloud console firewall / security group.

### Step 6 — Access the console

**http://YOUR_PUBLIC_IP:8003**

Share this URL with your client — they open it in a browser, no installation needed.

> **For a professional setup:** point a domain name to your server IP and add HTTPS with Let's Encrypt. See [`docs/installation.md`](docs/installation.md) for the Nginx + Certbot procedure.

### Step 7 — Create your account

```
make hash PASSWORD=choose-a-password
```

Paste the result in `AUTH_PASSWORD_HASH` in `.env`, then:

```
make pilot-create-client ORG="My Company" EMAIL=admin@mycompany.com PASSWORD=choose-a-password
docker compose restart core
```

### Step 8 — Connect GPU cluster gateways

**Prerequisites on the GPU cluster side:** `kubectl` configured + `helm` installed.

For each GPU cluster:

1. In the console, go to the **Fleet** tab → click **"Add a gateway"** (or **⚙ Admin → Gateways → New Gateway**)
2. Enter a name and click **Register** — copy the token (**shown once only**) and the pre-filled Helm command
3. From a machine with `kubectl` access to that cluster, run:

```
# Add the VibOps Helm repo (once per machine)
helm repo add vibops https://charts.vibops.io
helm repo update

# Deploy the gateway
helm upgrade --install vibops-connect vibops/vibops-connect \
  --namespace vibops-connect --create-namespace \
  --set gateway.name="my-gpu-cluster" \
  --set vibops.coreUrl="https://your-domain.com" \
  --set vibops.token="PASTE_YOUR_TOKEN_HERE"
```

4. The wizard auto-detects the connection and shows **Online** within 30 seconds

The gateway uses **outbound HTTPS only** — the only firewall rule needed on the GPU cluster side:

```
Allow outbound HTTPS (port 443) → your-domain.com or YOUR_PUBLIC_IP
```

The worker auto-discovers all kubeconfig contexts on the node where it runs — no manual cluster registration needed.

**To add more clusters**, repeat from step 1 with a different gateway name (e.g. `gpu-cluster-2`).

**If the gateway does not go Online**, check the pod logs:
```
kubectl logs -n vibops-connect deployment/vibops-connect
```

**If a token is compromised**, delete the gateway in the console and register a new one — the old token is immediately invalidated.

---

## Verify

```
make check
```

---

## Stop and restart

```
make down
make up
```

---

## Getting help

- Run `make check` — diagnoses the most common issues automatically
- Full installation guide: [`docs/installation.md`](docs/installation.md)
- Incident runbook: [`docs/runbooks/incident-response.md`](docs/runbooks/incident-response.md)
- Support: david@vibops.ai

---

# `.env` variable reference

All variables live in the `.env` file at the root of the `vibops` folder.
Variables marked **auto-generated** are set by `make quickstart` and do not need to be edited manually.

## Required

| Variable | Auto-generated | Description |
|---|---|---|
| `SECRET_KEY` | ✓ | Flask/FastAPI session secret — 64-char hex |
| `JWT_SECRET_KEY` | ✓ | JWT signing key — 64-char hex |
| `POSTGRES_PASSWORD` | ✓ | PostgreSQL password |
| `DATABASE_URL` | ✓ | Full Postgres connection string (interpolated from `POSTGRES_PASSWORD`) |
| `LLM_PROVIDER` | | `claude` · `openai` · `ollama` |
| `LLM_API_KEY` | | API key for your LLM provider — not needed for `ollama` |

## Optional but common

| Variable | Default | Description |
|---|---|---|
| `VIBOPS_LICENCE_KEY` | _(empty)_ | RS256 JWT licence key — omit for 14-day trial (10 GPUs · 5 users · 2 clusters) |
| `LLM_BASE_URL` | _(empty)_ | Base URL for OpenAI-compatible endpoints (vLLM, Mistral, on-prem) |
| `OLLAMA_URL` | `http://ollama:11434` | Ollama endpoint — change to `http://localhost:11434` for local dev |
| `AUTH_USERNAME` | `admin` | Login username for the console |
| `AUTH_PASSWORD_HASH` | _(empty)_ | Bcrypt hash — generate with `make hash PASSWORD=yourpassword` |
| `JWT_EXPIRE_HOURS` | `24` | Token validity in hours |
| `VAULT_KEY` | _(empty)_ | Fernet key for secret encryption in DB — generate: `python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"` |
| `GRAFANA_PASSWORD` | ✓ | Grafana admin password (observability profile only) |

## Integrations

| Variable | Description |
|---|---|
| `GIT_PROVIDER` | `github` or `gitlab` |
| `GIT_TOKEN` | Personal Access Token — `repo:read` (GitHub) or `read_api` (GitLab) |
| `GIT_URL` | GitLab base URL — leave empty for github, set to `https://gitlab.example.com` for self-hosted |
| `GITHUB_WEBHOOK_SECRET` | Shared secret for incoming webhooks |
| `DATADOG_API_KEY` | Datadog API key — leave empty to disable |
| `DATADOG_APP_KEY` | Datadog application key |
| `SMTP_HOST` | SMTP server for alerts and password reset — leave empty to disable |
| `SMTP_PORT` | SMTP port (default: `587`) |
| `SMTP_USER` / `SMTP_PASSWORD` | SMTP credentials |
| `SMTP_FROM` | Sender address (e.g. `noreply@yourcompany.com`) |

## VibOps Connect (gateway)

| Variable | Description |
|---|---|
| `CONNECT_GATEWAY_ID` | Gateway ID — generated in the console under Connect → Register gateway |
| `CONNECT_TOKEN` | Gateway auth token — generated alongside `CONNECT_GATEWAY_ID` |

> For the full variable reference including Helm values, see [`docs/installation.md`](docs/installation.md).
