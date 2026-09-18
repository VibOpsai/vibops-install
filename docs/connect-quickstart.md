# VibOps Connect — Onboarding Guide

How a customer's Kubernetes clusters, virtual machines and bare-metal servers
become visible and manageable in VibOps.

Read section 2 first. It says which of the three is found automatically and
which must be declared, and almost every onboarding surprise comes from
assuming the wrong one.

---

## 1. What Connect is

VibOps Connect is a single lightweight container installed inside each
infrastructure site. It polls VibOps Core over outbound HTTPS, reports what it
can see every 30 seconds, and runs the jobs Core assigns to it.

```
Customer network (sovereign)
│
│  VibOps Connect (one container)
│    ├── Kubernetes  → pods, deployments, nodes, GPU count     (credentials)
│    ├── Hypervisors → VMs, vCPU, RAM, disk, GPU passthrough   (declared)
│    ├── Subnet scan → BMCs, Proxmox, Prometheus, Slurm…       (discovered)
│    │
│    └── HTTPS OUT (443) ──→ VibOps Core ──→ Console
│
│  Nothing comes IN. No inbound port, no VPN, no firewall change.
```

**Images are built for `linux/amd64` only.** An arm64 node — Graviton,
Ampere, Apple Silicon — cannot pull them. Check your node architecture before
planning a deployment.

**Connect does not register itself.** The gateway is created in the console
first; Connect authenticates as an existing gateway and needs its id. A
container started without `VIBOPS_GATEWAY_ID` logs one line and exits.

This is the one place where the flow is heavier than `cloudflared`, which the
architecture otherwise follows: **two values to copy instead of one**, an id
and a token. The token is returned once, at creation, and never shown again.

---

## 2. What is discovered, what is declared

The single most important table in this document.

| Asset | How Connect sees it | Automatic? |
|-------|---------------------|-----------|
| **Kubernetes** | The kubeconfig it is given, or the in-cluster ServiceAccount | **Automatic for clusters it has credentials for.** Every context in the kubeconfig is enumerated. A cluster absent from it is invisible. |
| **Virtual machines** | The hypervisor API endpoints declared in its configuration | **Declared.** Nothing scans a network, finds a Proxmox and logs into it — that would require credentials nobody supplied. |
| **Bare metal** | A sweep of a named subnet, identifying what answers (Redfish, Proxmox, Prometheus, Slurm, Grafana, k8s API) | **Discovered.** This is the only one that is genuinely automatic. |

The sentence worth keeping: **the scan discovers, it does not connect.** It
finds a BMC at `10.20.0.14` and reports what it is. Reading that BMC needs an
account, and the account is declared — see section 5.

And what the scan proposes, it never manages. Every BMC it finds lands in the
bare-metal inventory as **unmanaged**, and stays that way until an operator
confirms it (ADR 0040, decision 9).

---

## 3. The onboarding sequence

Four steps, the same for every site.

### Step 1 — Create the gateway in the console

**Fleet → Gateways → Add gateway.** Give it a name that says where it is
(`paris-dc1`, `riyadh-edge`), not what it does.

The API equivalent:

```bash
curl -X POST https://vibops.example.com/api/v1/gateways \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "paris-dc1", "description": "DC1, salle 3"}'
```

The response carries two values you need and one of them you will never see
again:

```json
{
  "id": "3f2a…-…-…",
  "name": "paris-dc1",
  "token": "kR7…",        ← shown once, at creation only
  "clusters": []
}
```

There is **no token rotation endpoint**. A lost or compromised token means
deleting the gateway and creating a new one — `DELETE /api/v1/gateways/{id}`,
which returns a dry-run summary until you pass `?confirmed=true`.

### Step 2 — Install Connect at the site

Copy the command the console shows you. It already carries the id and the
token.

**Helm** (inside a Kubernetes cluster). The chart is published as a GitHub
release asset — there is no public Helm repository yet, so fetch the chart
rather than adding a repo:

```bash
gh release download vibops-connect-0.27.0 \
  --repo davidmacamara-boop/vibops --pattern '*.tgz'

helm upgrade --install vibops-connect ./vibops-connect-0.27.0.tgz \
  --namespace vibops-connect --create-namespace \
  --set gateway.id="3f2a…-…-…" \
  --set vibops.coreUrl="https://vibops.example.com" \
  --set vibops.token="kR7…"
```

**Docker** (anywhere else — a hypervisor host, a jump box, a VM on the
management VLAN):

```bash
docker run -d --name vibops-connect --restart unless-stopped \
  -e VIBOPS_CORE_URL="https://vibops.example.com" \
  -e VIBOPS_GATEWAY_ID="3f2a…-…-…" \
  -e VIBOPS_TOKEN="kR7…" \
  ghcr.io/davidmacamara-boop/vibops-connect:latest
```

Those three variables gate start-up. Connect exits immediately without any one
of them.

### Step 3 — Give it what it needs to see

Nothing else is required for the gateway to come online, but an online gateway
with no credentials reports an empty site. Sections 4, 5 and 6 cover each asset
type.

### Step 4 — Verify

Within a few seconds the gateway is **online** in the console with its
clusters and hypervisors. The subnet scan runs afterwards, in the background,
and its findings appear on the following heartbeat — 15 seconds later on a
small subnet, minutes on a large one.

Measured on a kind cluster on 18/09: gateway online in the same second as
start-up, scan complete 32 seconds later on a /24.

```bash
curl -s https://vibops.example.com/api/v1/gateways \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  | jq '.[] | {name, online, clusters, discovered_services}'
```

---

## 4. Onboarding Kubernetes

### The cluster Connect runs in

Deployed by Helm with the chart's ServiceAccount, Connect reads the cluster it
is running in with no further configuration. This is the default and needs
nothing.

### Other clusters

Give it a kubeconfig. **Every context in the file is enumerated**, so one
kubeconfig with five contexts is five clusters reported and managed by one
gateway.

```bash
kubectl create secret generic vibops-kubeconfig \
  --from-file=config=$HOME/.kube/config -n vibops-connect

helm upgrade vibops-connect vibops/vibops-connect \
  --set kubeconfig.secretName=vibops-kubeconfig
```

⚠️ **The two modes are exclusive.** With a kubeconfig mounted, Connect reads
the contexts in it and *only* those. If the local cluster is not among them,
add it. Without a kubeconfig, Connect reads the local cluster and only that
one — multi-cluster requires the mounted secret.

Reaching those clusters is a separate matter: the pod needs a route to each API
server and the kubeconfig needs credentials that are still valid. A context
Connect cannot reach is reported as unavailable, not silently skipped.

### Cluster names are routing addresses

Core decides which gateway runs a job by looking for the gateway that declares
the target cluster. **A cluster name must therefore be unique within an
organisation.**

Two sites each calling their cluster `prod` is the natural thing to do and the
one thing that breaks: the job goes to one of the two, and which one is not
something you control.

VibOps refuses this at registration — `409 Conflict`, naming the gateway that
already holds the name — and a gateway reporting a name another one owns does
not claim it. The convention that avoids the whole question:

```
paris-prod      riyadh-prod      lyon-staging
```

Prefix by site. Never reuse a bare `prod`.

---

## 5. Onboarding virtual machines

VMs come from a hypervisor's API. The endpoint and its credentials are
declared — there is no discovery step that produces a working hypervisor
connection.

### One hypervisor

```bash
# Proxmox VE
helm upgrade vibops-connect vibops/vibops-connect \
  --set proxmox.url="https://pve.paris.local:8006" \
  --set proxmox.user="root@pam" \
  --set proxmox.tokenId="vibops" \
  --set proxmox.token="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
  --set gateway.hypervisorName="pve-paris"

# VMware vCenter
helm upgrade vibops-connect vibops/vibops-connect \
  --set vsphere.host="vcenter.lyon.local" \
  --set vsphere.username="svc-vibops@vsphere.local" \
  --set vsphere.password="xxxxx" \
  --set gateway.hypervisorName="vc-lyon"

# Xen Orchestra (XCP-ng / Vates)
helm upgrade vibops-connect vibops/vibops-connect \
  --set xenOrchestra.url="https://xo.paris.local" \
  --set xenOrchestra.token="xxxxxxxx" \
  --set gateway.hypervisorName="xo-paris"
```

There is **no `platformType` to set**. A hypervisor is detected by the presence
of its URL.

### Several hypervisors on one gateway

Use the `hypervisors` list. Each entry carries its own name.

```yaml
# values-paris.yaml
hypervisors:
  - type: proxmox
    name: pve-paris-a
    url: https://pve-a.paris.local:8006
    user: root@pam
    token_id: vibops
    token: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  - type: proxmox
    name: pve-paris-b
    url: https://pve-b.paris.local:8006
    user: root@pam
    token_id: vibops
    token: "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
  - type: vsphere
    name: vc-lyon
    url: vcenter.lyon.local
    user: svc-vibops@vsphere.local
    token: "zzzzz"
```

```bash
helm upgrade vibops-connect vibops/vibops-connect -f values-paris.yaml
```

**The name is the key.** Alert rules and pricing target a hypervisor by name,
so two Proxmox instances without distinct names are merged into one and their
VMs are attributed to whichever answered last. Choose the names deliberately
and keep them stable.

The single-variable form and the list are mutually exclusive: when
`hypervisors` is set, the `proxmox` / `vsphere` / `xenOrchestra` blocks are
ignored.

---

## 6. Onboarding bare metal

This is the one that is scanned, and the one where deployment placement
matters.

### Point the scan at the right subnet

By default Connect derives the subnet from its own address. **Inside a
Kubernetes pod that is the cluster network, where there is no BMC.** The scan
runs, finds nothing, and reports zero servers — which reads as "this customer
has no bare metal" and means "I could not look".

```bash
helm upgrade vibops-connect vibops/vibops-connect \
  --set networkScan.subnet="10.20.0.0/24" \
  --set networkScan.timeoutMs=500
```

### Naming a subnet does not create a route to it

The second half is the one that gets forgotten. Either:

- Connect runs on the **host network of a machine that already reaches the
  management VLAN** — the Docker install of section 3 with `--network host`,
  typically on a jump box; or
- that VLAN is **routed to the pod network**.

Without one of the two, the address is correct and the packets go nowhere.

### What it finds

The sweep probes ports 8006, 6443, 443, 9090, 9400, 6817, 3000 and 8080 and
identifies what answers: Redfish BMCs (iDRAC, iLO — including model and
firmware), Proxmox, Kubernetes API, Prometheus, DCGM exporter, Slurm, Grafana.

Every BMC found is **proposed, not adopted**: it lands unmanaged in the
bare-metal inventory and an operator confirms it. Reading it then requires
credentials, stored as a vault secret name against the node and resolved at
execution — VibOps never stores the credential itself.

### Turning it off

Scanning a customer's network is opt-out, and opting out costs one flag:

```bash
helm upgrade vibops-connect vibops/vibops-connect --set networkScan.enabled=false
```

Nodes are then declared by hand. Nothing else changes.

---

## 7. Remote clusters, remote VMs, other sites

The question that decides the topology is not *"is this the same customer?"*
but **"can this container open a TCP connection to that API?"**

### It can reach them → one gateway

Add the contexts to the kubeconfig (section 4), add the entries to the
`hypervisors` list (section 5). One Connect serves as many clusters and
hypervisors as it has routes and credentials for.

### It cannot → one gateway per network island

A different datacentre, a different customer, a segment with no route: install
a second Connect with **its own gateway id and its own token**.

Routing follows on its own. Core sends each job to the gateway that declares
the target cluster, so two gateways declaring different clusters each receive
their own work with no routing configuration. This is exactly the
`cloudflared` model: one lightweight client per network island, all
connections outbound.

Which is the practical reason for the naming rule in section 4: with one
gateway, duplicate cluster names are impossible; with two, they are the default
outcome unless someone decides otherwise.

---

## 8. What is *not* configured in the chart

**Slurm head node, Prometheus URL, mTLS.** These are properties of the gateway,
entered in the console, not of the deployment — which is also what lets you
change them without redeploying.

They were once declared in `values.yaml`, rendered by no template and read by
no code: an operator could set `slurm.host`, helm would accept it, and nothing
would happen. They have been removed rather than left as decoration.

---

## 9. Network requirements

| Direction | Port | Protocol | Purpose |
|-----------|------|----------|---------|
| **Outbound** | 443 | HTTPS | Connect → VibOps Core |
| Internal | 6443 | HTTPS | Connect → Kubernetes API |
| Internal | 8006 | HTTPS | Connect → Proxmox API |
| Internal | 443 | HTTPS | Connect → vCenter / Xen Orchestra API |
| Internal | 443 | HTTPS | Connect → BMC Redfish (management VLAN) |
| Internal | 9090 / 9400 | HTTP | Connect → Prometheus / DCGM exporter |

**No inbound port.** Connect initiates every connection.

## 10. What data transits

| Data | Example | Transits? |
|------|---------|-----------|
| VM / pod inventory | "20 VMs, 320 vCPU" | Yes — metadata only |
| GPU utilisation | "6/8 GPUs, 75 %" | Yes |
| Workload status | "vllm-mistral: running" | Yes |
| Cost metrics | "$3.50/GPU/hour" | Yes |
| Discovered services | "10.20.0.14: iDRAC 9, R760xa" | Yes — address, type, model |
| Customer application data | Database contents, files | **Never** |
| Credentials, secrets | Passwords, API tokens | **Never** — secret *names* only |

## 11. Resource footprint

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 100m | 500m |
| Memory | 256 Mi | 512 Mi |
| Disk | none | none |
| Network | ~1 KB/min (heartbeat) | ~10 KB/min (with metrics) |

---

## 12. Troubleshooting

**The gateway stays offline.**

```bash
kubectl -n vibops-connect logs deploy/vibops-connect --tail=50
```

The first line usually says it. A missing `VIBOPS_GATEWAY_ID`,
`VIBOPS_CORE_URL` or `VIBOPS_TOKEN` makes the container exit immediately —
in Kubernetes that reads as `CrashLoopBackOff`, in Docker as a container that
will not stay up.

```bash
kubectl -n vibops-connect exec deploy/vibops-connect -- \
  curl -sf https://vibops.example.com/api/v1/health
```

**The gateway is online but the site is empty.** Expected, if nothing has been
given to it — see sections 4, 5 and 6. Check in order: is a kubeconfig mounted
or is Connect in-cluster; is a hypervisor declared; is the scan aimed at a
subnet it can reach.

**A cluster is missing from the console.** If another gateway already declares
that name, this one does not claim it — by design, and the gateway's log says
so:

```
gateway paris-dc1 reports cluster 'prod', already declared by gateway
'riyadh-edge' — not claimed; rename one of them, cluster names route jobs
```

Rename one of the two (section 4).

**The scan finds nothing.** Almost always the subnet or the route, in that
order. Confirm the BMCs are on the subnet you named, then confirm the container
can reach it:

```bash
kubectl -n vibops-connect exec deploy/vibops-connect -- \
  python -c "import socket; socket.create_connection(('10.20.0.14', 443), 2)"
```

**No GPU metrics.** Check that the NVIDIA GPU Operator or a DCGM exporter is
running, and that Prometheus is scraping it.

## 13. Uninstall

```bash
helm uninstall vibops-connect -n vibops-connect
kubectl delete namespace vibops-connect
```

Then delete the gateway in the console, or:

```bash
curl -X DELETE "https://vibops.example.com/api/v1/gateways/{id}?confirmed=true" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

Without `confirmed=true` the call returns a dry-run summary of what would be
removed.
