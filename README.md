# VibOps — Installation

Deploy VibOps on your infrastructure in minutes. This repository contains everything needed to run VibOps — no source code, just configuration and pre-built Docker images.

## Prerequisites

- Linux server: 4 vCPU, 8 GB RAM, 50 GB SSD minimum
- Docker 24+ and Docker Compose v2
- An LLM API key (Claude recommended) or on-prem LLM (Ollama, vLLM)

**No GPU required** on the VibOps server — GPUs stay on your clusters.

## Quick Start

```bash
# 1. Clone this repository
git clone https://github.com/VibOpsai/vibops-install-.git
cd vibops-install

# 2. Authenticate to the VibOps container registry (token provided by VibOps)
make login VIBOPS_REGISTRY_TOKEN=<your-token>

# 3. Start the full stack (generates secrets, starts all services)
make quickstart

# 4. Set your LLM provider in .env
#    Edit LLM_PROVIDER and LLM_API_KEY, then:
docker compose restart agent

# 5. Create your organisation
make pilot-create-client ORG="My Company" EMAIL=admin@company.com PASSWORD=yourpassword

# 6. Open the console
#    http://SERVER_IP:8003
```

## What's included

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Full stack: core, agent, console, worker, PostgreSQL, Redis, Prometheus, Grafana |
| `.env.example` | Environment template — all variables documented |
| `Makefile` | Quickstart, health checks, client provisioning, backups |
| `prometheus.yml` | Prometheus scrape configuration |
| `alerting_rules.yml` | GPU and service alerting rules |
| `grafana/` | Grafana datasources and pre-built dashboards |
| `scripts/` | Health check, gateway setup, onboarding automation |
| `docs/installation.md` | Complete installation guide (13 sections) |

## Services

| Service | Port | Description |
|---------|------|-------------|
| Console | **8003** | Web UI — open in browser |
| Core API | 8000 | REST API + job engine |
| Agent | 8001 | LLM agent |
| Grafana | 3000 | Dashboards (admin / auto-generated password) |
| Prometheus | 9090 | Metrics |

## Connect a GPU cluster

GPU clusters connect to VibOps via an outbound-only gateway (no inbound ports required on the cluster side):

```bash
# From the VibOps console: Fleet → Add Gateway → copy the token
# On the GPU cluster:
helm upgrade --install vibops-connect vibops/vibops-connect \
  --set vibops.coreUrl="https://your-vibops-server" \
  --set vibops.token="<token-from-console>"
```

## Licence

VibOps starts a **14-day trial** automatically (10 GPUs / 5 users / 2 clusters).
Contact david@vibops.ai for a production licence key.

## Full documentation

See [docs/installation.md](docs/installation.md) for the complete guide including:
- Helm production deployment
- On-prem LLM (air-gapped / sovereign)
- Team management and RBAC
- Configuration reference
- Upgrade and backup procedures

## Support

- Email: david@vibops.ai
- Documentation: https://vibops.ai/docs
