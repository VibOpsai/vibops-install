# VibOps Connect — Quick Start Guide

Deploy a VibOps Connect gateway on a provider site in under 5 minutes. The gateway runs as a lightweight container inside the provider's network and communicates with VibOps Core via **outbound HTTPS only** — no inbound ports, no VPN, no firewall changes.

## Prerequisites

- **VibOps Core** running (SaaS or self-hosted)
- **Kubernetes cluster** on the provider site (for Helm install), OR **Docker** for standalone
- **Outbound HTTPS** (port 443) to the VibOps Core URL
- Admin access to the VibOps Console

## Step 1: Get an API Token

From the VibOps Console, go to **Settings > API Tokens** and generate a token. This token is used by the gateway to auto-register itself — no need to pre-create the gateway.

## Step 2: Install (the gateway self-registers automatically)

### Option A: Helm (Kubernetes)

```bash
helm repo add vibops https://install.vibops.ai/charts
helm repo update

helm upgrade --install vibops-connect vibops/vibops-connect \
  --namespace vibops-connect --create-namespace \
  --set gateway.name="provider-riyadh" \
  --set gateway.cluster="riyadh-prod" \
  --set vibops.coreUrl="https://vibops.example.com" \
  --set vibops.token="gw_xxxxxxxxxxxxxxxxxxxx"
```

### Option B: Docker (standalone)

```bash
docker run -d --name vibops-connect \
  -e GATEWAY_NAME="provider-riyadh" \
  -e CLUSTER_NAME="riyadh-prod" \
  -e CORE_URL="https://vibops.example.com" \
  -e GATEWAY_TOKEN="gw_xxxxxxxxxxxxxxxxxxxx" \
  ghcr.io/davidmacamara-boop/vibops-connect:latest
```

### Option C: Setup Script

```bash
curl -fsSL https://install.vibops.ai/connect.sh | bash -s -- \
  --name "provider-riyadh" \
  --cluster "riyadh-prod" \
  --core-url "https://vibops.example.com" \
  --token "gw_xxxxxxxxxxxxxxxxxxxx"
```

## Step 3: Verify

Within 30 seconds, the gateway appears as **online** in the VibOps Console under Fleet > Gateways.

```bash
# Check gateway status via API
curl -s https://vibops.example.com/api/v1/gateways \
  -H "Authorization: Bearer $TOKEN" | jq '.[] | {name, is_online}'
```

## Platform Configuration

### Kubernetes (default)

No extra config needed — the gateway uses the in-cluster ServiceAccount to discover pods, deployments, GPU metrics.

### Proxmox VE

```bash
helm upgrade vibops-connect vibops/vibops-connect \
  --set platformType="hypervisor" \
  --set proxmox.url="https://proxmox.local:8006" \
  --set proxmox.tokenId="vibops@pve!monitor" \
  --set proxmox.token="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### VMware vSphere

```bash
helm upgrade vibops-connect vibops/vibops-connect \
  --set platformType="hypervisor" \
  --set vsphere.url="https://vcenter.local" \
  --set vsphere.user="vibops@vsphere.local" \
  --set vsphere.password="xxxxx"
```

### Xen Orchestra (XCP-ng)

```bash
helm upgrade vibops-connect vibops/vibops-connect \
  --set platformType="hypervisor" \
  --set xenOrchestra.url="https://xo.local" \
  --set xenOrchestra.token="xxxxxxxx"
```

### Slurm HPC

```bash
helm upgrade vibops-connect vibops/vibops-connect \
  --set platformType="slurm" \
  --set slurm.host="login-node.hpc.local" \
  --set slurm.sshUser="vibops" \
  --set slurm.sshKeySecret="vibops-ssh-key"
```

### Hybrid (K8s + Hypervisor)

```bash
helm upgrade vibops-connect vibops/vibops-connect \
  --set platformType="hybrid" \
  --set proxmox.url="https://proxmox.local:8006" \
  --set proxmox.tokenId="vibops@pve!monitor" \
  --set proxmox.token="xxxxxxxx"
```

## Network Requirements

| Direction | Port | Protocol | Purpose |
|-----------|------|----------|---------|
| **Outbound** | 443 | HTTPS | Gateway → VibOps Core API |
| Internal | 8006 | HTTPS | Gateway → Proxmox API (if hypervisor) |
| Internal | 443 | HTTPS | Gateway → vSphere API (if vSphere) |
| Internal | 9090 | HTTP | Gateway → Prometheus (metrics) |
| Internal | 6443 | HTTPS | Gateway → K8s API (if in-cluster) |

**No inbound ports required.** The gateway initiates all connections.

## What Data Transits

| Data | Example | Transits? |
|------|---------|-----------|
| VM/pod inventory | "20 VMs, 320 vCPUs" | Yes (metadata only) |
| GPU utilization | "6/8 GPUs, 75%" | Yes |
| Workload status | "vllm-mistral: running" | Yes |
| Cost metrics | "$3.50/GPU/hour" | Yes |
| Client application data | Database contents, files | **Never** |
| Network topology / IPs | Internal subnets | **Never** |
| Credentials / secrets | Passwords, tokens | **Never** |

## Resource Footprint

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 100m | 500m |
| Memory | 256 Mi | 512 Mi |
| Disk | None | None |
| Network | ~1 KB/min (heartbeat) | ~10 KB/min (with metrics) |

## Troubleshooting

**Gateway shows "offline":**
```bash
# Check pod status
kubectl -n vibops-connect get pods
# Check logs
kubectl -n vibops-connect logs deploy/vibops-connect --tail=50
# Test connectivity to core
kubectl -n vibops-connect exec deploy/vibops-connect -- \
  curl -sf https://vibops.example.com/api/v1/health
```

**Token expired or invalid:**
```bash
# Generate a new token from the console or API
curl -X POST https://vibops.example.com/api/v1/gateways/{id}/rotate-token \
  -H "Authorization: Bearer $ADMIN_TOKEN"
# Update the Helm release with the new token
helm upgrade vibops-connect vibops/vibops-connect \
  --set vibops.token="gw_new_token_here"
```

**No GPU metrics:**
- Ensure NVIDIA GPU Operator or DCGM exporter is running on the cluster
- Verify Prometheus is scraping GPU metrics: `curl http://prometheus:9090/api/v1/targets`

## Uninstall

```bash
helm uninstall vibops-connect -n vibops-connect
kubectl delete namespace vibops-connect
```
