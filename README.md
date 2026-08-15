# VibOps

**Manage GPU clusters and LLM deployments in plain language.**

```
"Deploy llama3 on the prod cluster with 3 GPU replicas"
"Scale the gpu-ng node group to 5 nodes"
"Why is the inference service slow? Fix it."
```

VibOps is an AI-native GPU infrastructure operations platform. A single conversation replaces kubectl, Helm, and CI/CD pipelines for managing GPU clusters.

---

## Install VibOps

Three paths — pick yours:

| Option | Best for |
|--------|----------|
| **[A — Your PC](#option-a--your-pc)** | Local testing, demo |
| **[B — CSP internal server](#option-b--csp-internal-server)** | Production — intranet, sovereign, air-gapped |
| **[C — Cloud server](#option-c--cloud-server)** | Production — internet-accessible, remote teams |

Full step-by-step instructions with screenshots: **[QUICKSTART.md](QUICKSTART.md)**

---

## Option A — Your PC

**What you need:** Docker Desktop · An LLM API key (or Ollama for local AI)

```bash
git clone https://github.com/vibops/vibops-install.git
cd vibops-install
make quickstart
```

Open **http://localhost:8003** — your VibOps console is ready.

> Full guide: [QUICKSTART.md → Option A](QUICKSTART.md#option-a--install-on-your-pc)

---

## Option B — CSP internal server

**What you need:** Linux server on internal network (4 vCPU / 8 GB RAM / Ubuntu 22.04) · Internal LLM endpoint or API key

```bash
# On your server
git clone https://github.com/vibops/vibops-install.git
cd vibops-install
make quickstart
```

Access the console at **http://INTERNAL_SERVER_IP:8003** — accessible to anyone on the internal network. No internet exposure required.

GPU clusters connect via outbound polling — no inbound ports needed on the cluster side.

> Full guide: [QUICKSTART.md → Option B](QUICKSTART.md#option-b--install-on-a-csp-internal-server)

---

## Option C — Cloud server

**What you need:** Linux cloud VM with public IP (4 vCPU / 8 GB RAM / Ubuntu 22.04) · LLM API key

```bash
# On your server
git clone https://github.com/vibops/vibops-install.git
cd vibops-install
make quickstart
```

Share **http://YOUR_PUBLIC_IP:8003** with your team — accessible from anywhere.

> Full guide: [QUICKSTART.md → Option C](QUICKSTART.md#option-c--install-on-a-cloud-server)

---

## Connect a GPU cluster

Once VibOps is running, connect your GPU clusters via the **VibOps Connect** gateway:

1. Console → **Settings → Gateways → New Gateway**
2. Copy the token (shown once only)
3. On your GPU cluster:

```bash
helm upgrade --install vibops-connect charts/vibops-connect \
  --namespace vibops-connect --create-namespace \
  --set gateway.name="my-gpu-cluster" \
  --set vibops.coreUrl="http://YOUR_VIBOPS_IP:8000" \
  --set vibops.token="PASTE_YOUR_TOKEN_HERE"
```

Gateway shows **Online** within 30 seconds.

---

## Useful commands

```bash
make quickstart   # First-time setup — creates .env, generates secrets, starts stack
make check        # Health check — validates all components
make up           # Start the stack
make down         # Stop the stack
make hash PASSWORD=yourpassword  # Generate bcrypt hash for password setup
make pilot-create-client ORG="Acme" EMAIL=admin@acme.com PASSWORD=secret  # Provision a client org
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [QUICKSTART.md](QUICKSTART.md) | Step-by-step installation (PC / internal server / cloud) |
| [Installation Guide](docs/installation.md) | Full technical setup, server requirements, Helm production deployment |
| [User Guide](docs/user-guide.md) | Console walkthrough, agent commands, team management |
| [API Reference](docs/api-reference.md) | REST API endpoints with curl examples |
| [Runbooks](docs/runbooks/) | Incident response, upgrade procedure, pilot go-live checklist |
| [Roadmap](docs/roadmap.md) | What's shipped and what's coming |

---

## Production deployment (Helm)

For production Kubernetes deployments:

```bash
helm install vibops ./helm/vibops \
  -n vibops --create-namespace \
  -f my-values.yaml \
  --set postgresql.auth.password=<strong-password> \
  --set core.secret.jwtSecretKey=<secret> \
  --set agent.secret.llmApiKey=<api-key>
```

See [docs/installation.md](docs/installation.md) for the full Helm configuration reference.

---

## Support

- Documentation: [docs/installation.md](docs/installation.md)
- Health check: `make check`
- Support: david@vibops.ai

---

*© VibOps 2026 — Proprietary licence. This repository contains installation files only. Source code is not included.*
