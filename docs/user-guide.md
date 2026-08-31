# VibOps — User Guide

## Table of contents

1. [Introduction](#1-introduction)
2. [Quick start — from zero to operational](#2-quick-start--from-zero-to-operational)
   - [Step 1 — Log in and change your password](#step-1--log-in-and-change-your-password)
   - [Step 2 — Connect your first cluster](#step-2--connect-your-first-cluster)
   - [Step 3 — Configure your secrets](#step-3--configure-your-secrets)
   - [Step 4 — Connect your Git provider](#step-4--connect-your-git-provider-for-gitops)
   - [Step 5 — Configure your organization (admin)](#step-5--configure-your-organization-if-you-are-an-admin)
   - [Step 6 — Set up a notification](#step-6--set-up-a-notification-optional-but-recommended)
   - [Step 7 — First test with the agent](#step-7--first-test-with-the-agent)
3. [Login and first session](#3-login-and-first-session)
4. [Console overview](#4-console-overview)
5. [The Morning Brief](#5-the-morning-brief)
6. [Talking to the agent](#6-talking-to-the-agent)
   - [How to phrase a request](#how-to-phrase-a-request)
   - [What the agent can do](#what-the-agent-can-do)
   - [Agent Catalog — explore and configure tools](#agent-catalog--explore-and-configure-tools)
   - [Session Replay](#session-replay)
   - [Production safety guardrails](#production-safety-guardrails)
   - [Cross-session memory](#cross-session-memory)
7. [Kubernetes cluster management](#7-kubernetes-cluster-management)
8. [Inference workloads and GPU](#8-inference-workloads-and-gpu)
9. [MLOps workflows](#9-mlops-workflows)
   - [Slurm HPC training (bare-metal clusters)](#slurm-hpc-training-bare-metal-clusters)
10. [Incident diagnosis and remediation](#10-incident-diagnosis-and-remediation)
11. [Capacity planning and benchmarking](#11-capacity-planning-and-benchmarking)
12. [SLOs and alerts](#12-slos-and-alerts)
13. [GitOps](#13-gitops)
14. [Dashboard tab](#14-dashboard-tab)
15. [Cluster tab](#15-cluster-tab)
16. [Fleet tab](#16-fleet-tab)
17. [Admin tab](#17-admin-tab)
    - [Organization](#organization)
    - [Teams](#teams)
    - [Members](#members)
    - [Per-cluster roles (overrides)](#per-cluster-roles-overrides)
    - [Secrets](#secrets)
    - [Tool policy](#tool-policy)
    - [Approvals](#approvals)
    - [Org Policy (declarative YAML)](#org-policy-declarative-yaml)
    - [LLM Evaluation Rubrics](#llm-evaluation-rubrics-admin-only)
    - [Proactive Anomaly Detection](#proactive-anomaly-detection)
    - [Live Workload Cost Attribution](#live-workload-cost-attribution)
    - [Notifications](#notifications)
    - [Integrations](#integrations)
    - [Audit](#audit)
    - [Memories](#memories)
    - [License](#license)
    - [Customers (reseller orgs only)](#customers-reseller-orgs-only)
    - [Security tab](#security-tab)
    - [LLM Provider (Settings → Operations)](#llm-provider-settings--operations)
    - [VMs admin (Settings → Infrastructure)](#vms-admin-settings--infrastructure)
18. [Connect Gateway](#18-connect-gateway)
19. [VM Management (Proxmox, vSphere, XCP-ng)](#19-vm-management-proxmox-vsphere-xcp-ng)
    - [Supported hypervisors](#supported-hypervisors)
    - [Connecting a hypervisor](#connecting-a-hypervisor)
    - [VM lifecycle operations](#vm-lifecycle-operations)
    - [VM metrics](#vm-metrics)
    - [VM waste detection](#vm-waste-detection)
    - [VM backup compliance](#vm-backup-compliance)
    - [GPU passthrough VMs](#gpu-passthrough-vms)
20. [FinOps tab](#20-finops-tab)
    - [Waste — GPU waste detection](#waste-sub-tab--gpu-waste-detection)
    - [Budget](#budget-sub-tab)
    - [Chargeback](#chargeback-sub-tab)
    - [VM Chargeback](#vm-chargeback)
    - [VM Waste Detection](#vm-waste-detection-finops)
    - [Alerts](#alerts-sub-tab)
    - [Workloads — per-workload GPU metrics](#workloads-sub-tab--per-workload-gpu-metrics)
    - [Scheduled Triggers](#scheduled-triggers)
21. [LLM Inference Proxy — Agent Infrastructure Control Plane](#21-llm-inference-proxy--agent-infrastructure-control-plane)
22. [Dataset & RLHF](#22-dataset--rlhf)
23. [MCP Server](#23-mcp-server)
24. [Python SDK](#24-python-sdk)
25. [Cloud Provider Connectors](#25-cloud-provider-connectors)
26. [Terraform Integration](#26-terraform-integration)
27. [Docker Build & CI Integration](#27-docker-build--ci-integration)
28. [Quick reference](#28-quick-reference)
- [Compliance Verification](#compliance-verification)
- [Security Scans](#security-scans)

---

## 1. Introduction

VibOps is the **AI agent for GPU/AI infrastructure operations**. It interfaces directly with your Kubernetes clusters, your NVIDIA stack, your Git repositories, and your monitoring tooling — responding to natural language instructions.

**What VibOps is not:**
- Not a general-purpose LLM — it knows GPU infrastructure and Kubernetes, not cooking or law
- Not a visualization tool — it is an agent that acts, not just displays
- Not an agent framework — it is a vertical solution, not a development kit

**What VibOps is:**
- A single interface for operating multi-environment Kubernetes clusters
- An on-call SRE capable of diagnosing, correlating, and remediating incidents in seconds
- A production guardrail: no destructive action without explicit confirmation
- An operational memory: the context of each cluster persists between sessions

---

## 2. Quick start — from zero to operational

This section is for you if you have just accessed VibOps for the first time and do not know where to begin. Follow these steps in order — allow **15 to 30 minutes** to be fully operational.

---

### Step 1 — Log in and change your password

1. Open the console URL provided by your administrator
2. Enter the username and temporary password communicated by your admin
3. Once logged in, click your **name in the top right** → **Change password**
4. Enter the temporary password in "Current password", then your new password (minimum 8 characters) twice
5. Click **Save**

> **Forgot or lost your password?** On the login page, click **Forgot password?**, enter your email or username, and follow the link received by email. In dev mode (without SMTP configured), the code appears directly on screen.

---

### Step 2 — Connect your first cluster

Without a connected cluster, the agent cannot do anything. This is the prerequisite for everything else.

**Option A — You have an existing Kubernetes cluster (most common)**

VibOps connects via a lightweight gateway deployed in your cluster:

1. Admin → **Integrations** sub-tab → **Connect Gateway** section
   — or directly: navigation bar → **Connect**
2. Click **Register gateway**
3. Give the gateway a name (e.g. `prod-gpu`, `eks-staging`) and an optional description
4. Click **Register** → a token is displayed. **Copy it now** — it will not be shown again.
5. On your cluster, deploy the VibOps worker with this token:
   ```bash
   # Copy the command shown in the interface, it looks like:
   docker run -d \
     -e VIBOPS_TOKEN=<your_token> \
     -e VIBOPS_CORE_URL=https://your-instance.vibops.ai \
     vibopsai/vibops-worker:latest
   ```
   — or via Helm if you are in production (see §17 Connect Gateway for details)
6. Wait a few seconds → the gateway switches to **online** status ✅ in the interface

> **The gateway does not require opening any inbound port** on your infrastructure. It establishes an outbound connection to VibOps.

**Option B — You want to test without a real cluster**

Use the built-in demo cluster (`vibops-dev` or `kind-vibops-dev`) if it is already shown in the Connect tab. These clusters are pre-configured for demonstration.

---

### Step 3 — Configure your secrets

Secrets allow the agent to act on your behalf on third-party services — without credentials ever appearing in the chat.

**Essential secrets to configure based on your use case:**

| You want to… | Secret to create | Value |
|--------------------|---------------|--------|
| Clone/push Git repos (GitHub) | `git_token` | GitHub Personal Access Token (scopes: `repo`, `workflow`) |
| Clone/push Git repos (GitLab) | `git_token` | GitLab Personal Access Token (scope: `read_api`) |
| Deploy NVIDIA NIMs | `ngc_api_key` | NGC API key (`ngc.nvidia.com` → Setup → API Key) |
| Push images to GHCR | `ghcr_token` | GitHub PAT with `write:packages` scope |
| Push images to Docker Hub | `dockerhub_token` | Docker Hub access token |
| Push images to GitLab Registry | `gitlab_registry_token` | GitLab PAT with `write_registry` scope |
| Access a private Docker registry | `registry_password` | Registry password or token |

**How to create a secret:**
1. Admin → **Secrets** sub-tab → **+ New secret**
2. **Name**: short identifier without spaces (e.g. `git_token`)
3. **Value**: paste the token/credential in plain text — it will be encrypted immediately
4. Click **Create**

Once created, use it in the chat with `@secret:name`:
```
Clone the repo github.com/myorg/infra with token=@secret:git_token
```

---

### Step 4 — Connect your Git provider (for GitOps)

Git access in VibOps operates at two levels:

- **Admin → Git** (org-level) — one token for the entire organization. Used by the agent to clone repos, push commits, open PRs, and build/push Docker images. Configured once by an admin.
- **Git tab** (per-app) — links each application in your sidebar to its source repository. Enables commit history and rollback.

**Step 4a — Configure the org-level Git token:**

1. Admin → **Git** sub-tab
2. Select your provider: **GitHub** or **GitLab**
3. Paste your Personal Access Token:
   - GitHub: `ghp_...` — requires scopes `repo` + `workflow` + `write:packages` (if you push images to GHCR)
   - GitLab: `glpat-...` — requires scopes `read_api` + `write_repository`
   - Self-hosted GitLab: also fill in **GitLab URL** (e.g. `https://gitlab.mycompany.com`)
4. Click **Save** — the status badge turns **Connected ✓**

**Step 4b — Link your apps to their repos:**

In the same Admin → Git panel, the **Apps & repositories** table lists all applications discovered on your cluster. For each app:
- If already linked: the repo URL is shown with branch and last commit SHA.
- If not linked: click **Link repo** → type `owner/repo` (e.g. `acme/api-server`) → press Enter or click Save.

You can also link an app directly from the **Git** main tab: select the app in the sidebar and use the inline form that appears when no repo is linked.

**Test:**
```
Clone the repo github.com/myorg/my-repo
```
If the agent clones successfully → Git provider is configured ✅

---

### Step 5 — Configure your organization (if you are an admin)

This step is for `org_admin` users who want to invite their team and define access. If you are the only user on the instance, skip to step 6.

**Create a team:**

A team defines what its members are allowed to do (on which clusters, which namespaces, which environments).

1. Admin → **Teams** sub-tab → **New team**
2. Give it a name (e.g. `Platform`, `Dev`, `ReadOnly`)
3. Define the scope:
   - **Allowed namespaces** — e.g. `default, gpu-prod` (empty = all)
   - **Allowed environments** — e.g. `dev, staging` (empty = all)
   - **Allowed clusters** — e.g. `eks-prod` (empty = all)
4. Click **Create**

> **Getting started tip:** create at least two teams — one `Ops` with no restrictions and one `Dev` limited to `dev, staging`. Adjust from there.

**Invite a user:**

1. Admin → **Users** sub-tab → **+ New user**
2. Fill in:
   - **Username** — login identifier
   - **Email** — for password recovery
   - **Initial password** — communicate via a separate channel
   - **Role** — `readonly` / `developer` / `org_admin`
3. Click **Create**
4. Expand the user panel → assign them to a team

**Role summary:**

| Role | Can do |
|------|-----------|
| `readonly` | View clusters, logs, dashboard — no actions |
| `developer` | Deploy, scale, rollback — within their team's scope |
| `org_admin` | Everything — full organization management |

---

### Step 6 — Set up a notification (optional but recommended)

To receive VibOps alerts (detected incidents, budget exceeded, triggers fired) on Slack or by email:

**Slack (fastest):**
1. In Slack: target channel → **Integrations** → **Add an app** → **Incoming Webhooks**
2. Copy the generated URL (`https://hooks.slack.com/services/...`)
3. In VibOps: Admin → **Notifications** → **+ New channel** → type **Slack Incoming Webhook**
4. Paste the URL → click **Create**

**Email:**
1. Admin → **Notifications** → **+ New channel** → type **Email (SMTP)**
2. Fill in the SMTP fields (see §16 Notifications for Gmail/SMTP details)

---

### Step 7 — First test with the agent

Your cluster is connected and your secrets are in place. Verify everything works:

```
List the deployments on cluster <your-cluster-name>
```

The agent should respond with the list of active pods/deployments. If so: **you are operational** ✅

**Other useful verification commands:**
```
What is the health status of my infrastructure?
List the connected clusters and their gateways
Are there any GPUs available on my clusters?
```

---

### Summary — Getting started checklist

```
☐ Login OK + password changed
☐ At least one cluster connected (gateway online)
☐ Git token configured in Admin → Git (if GitOps or image builds)
☐ Apps linked to their repos in Admin → Git → Apps & repositories (if GitOps)
☐ ngc_api_key secret created (if NVIDIA NIM)
☐ Teams created and users invited (if admin)
☐ Notification channel created (Slack or email)
☐ First agent test successful (deployment list)
```

Once this checklist is complete, you can explore the rest of the guide according to your needs.

---

## 3. Login and first session

### Logging in

Open the console URL provided by your administrator. Enter your username and password. The session token is stored locally in the browser — you remain logged in until you click **Logout** or the token expires (24 hours by default).

### Changing your password

In the user menu (top right corner) → **Change password**. A temporary password is assigned to you when your account is created by your administrator — change it at first login.

### The Morning Brief

When opening the first session of the day, the agent automatically generates a **morning brief**: cluster health status, open incidents, anomalies detected since the previous day. It appears in the chat window without any action on your part.

See section [4 — The Morning Brief](#4-the-morning-brief) for details.

---

## 4. Console overview

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│  VibOps / AI Infrastructure Console  | ● prod-gpu  ● eu-h100   [FR/EN]  [⚙]    │
├──────────────────────────────────────────────────────────────────────────────────┤
│  [Dashboard] [Fleet ●] | [Git] [Cluster] [LLM] [NIM] | [Automations] | [FinOps] │
├──────────────────────┬───────────────────────────────────────────────────────────┤
│                      │                                                            │
│   Sidebar            │   Main area                                                │
│   (applications)     │   (active tab)                                             │
│                      │                                                            │
│                      ├───────────────────────────────────────────────────────────┤
│                      │   Chat panel  [Auto] [prod-gpu ⬡3/8] [eu-h100 ⬡0/4]     │
└──────────────────────┴───────────────────────────────────────────────────────────┘
```

### Navigation bar

- **Dashboard** — real-time view of the infrastructure (jobs, deployments, recent activity)
- **Fleet** — multi-cluster overview: all connected sites, GPU metrics per cluster, cross-cluster actions, and gateway health. This is the primary entry point for multi-cluster / multi-site management.
- **Git** — GitOps status of the selected application: commit history, branch, rollback, inline repo linking
- **Cluster** — CPU / RAM / GPU resources of the active cluster
- **LLM / NIM** — inference workload management
- **Automations** — trigger rules and pipelines
- **FinOps** — waste, budget, chargeback
- **⚙ Admin** — administration panel (visible to `org_admin` only)
- **Language selector** — FR / EN / ES / DE / IT / PT / JA / ZH

A **red badge** on the ⚙ icon indicates the license expires in 7 days or less, or has expired.

### Cluster switcher (header)

The header shows a **pill for each connected cluster** (e.g. `● prod-gpu ⬡3/8 GPU`). Clicking a pill targets that cluster in the chat. If no cluster is connected yet, a `+ connect cluster` button opens the Admin panel directly.

### Sidebar

Lists all applications discovered on the cluster. Clicking an application selects it as the active context for chat and tabs.

### Chat panel cluster selector

At the bottom of the chat panel: pill buttons to target a specific cluster (`prod-gpu`, `eu-h100`…) or leave it on **Auto** (the agent picks the right cluster from context). The selected cluster is shown in the chat input placeholder.

### Chat panel

Always visible at the bottom of the screen. Drag the top edge to expand or collapse it. It retains the history of the current conversation.

---

## 5. The Morning Brief

At the first session of the day, the agent automatically generates a morning summary without you needing to ask a question. This brief includes:

- **Cluster health status** — pods in error, OOMKills, active CrashLoops
- **Recent jobs** — operations from the last 24 hours (success / failure / in progress)
- **Detected anomalies** — configuration drift, overloaded resources, received Prometheus alerts
- **Reminders** — in-progress tasks memorized from previous sessions (e.g. "staging to prod migration planned")
- **GPU metrics** — if a GPU cluster is connected: utilization, temperature, ECC errors

The brief is displayed directly in the chat window. You can ask follow-up questions immediately:

```
> Give me more details about last night's OOMKills
> Which pod has the most restarts?
> What is the status of the migration I started yesterday?
```

---

## 6. Talking to the agent

### How to phrase a request

The agent understands natural language instructions — no need to know kubectl syntax, exact resource names, or namespaces.

**Examples of valid phrasings:**

```
Give me the status of all our LLM inference services on vibops-dev
The open-webui pod is crashing. Diagnose what is happening.
Deploy nginx:latest on the apalacha cluster, namespace demo, 2 replicas
Scale llama3 in prod to 5 replicas and confirm they are all Running
Is there enough GPU capacity for a llama3-70b deploy with 4 GPUs?
What has changed on our clusters in the last 2 hours?
```

**Best practices:**

| Practice | Example |
|----------|---------|
| Specify the cluster if you have several | `"on vibops-dev"`, `"on the prod cluster"` |
| Specify the namespace for actions | `"in the ai namespace"`, `"in prod"` |
| Provide context for diagnostics | `"since this morning"`, `"since the last deployment"` |
| Confirm interactive actions | The agent asks for confirmation for destructive actions — reply "yes" or "cancel" |

**The agent always calls tools before responding** — it never guesses from its model memory. Every response reflects the actual state of the cluster at the time of the question.

### What the agent can do

| Category | Example actions |
|-----------|-------------------|
| **Discovery & audit** | List all clusters, map workloads, audit configurations |
| **Kubernetes** | Deploy, scale, restart, rollback, patch deployments |
| **GPU** | Check GPU availability, configure MIG, manage time-slicing |
| **Inference** | Deploy Ollama models, NVIDIA NIMs, manage endpoints |
| **Helm** | Install, update, rollback, diff charts |
| **ArgoCD** | Sync apps, view history, rollback |
| **Incident** | Diagnose, correlate logs + events + metrics, remediate |
| **Capacity** | Benchmark, plan capacity, detect underutilized GPUs |
| **GitOps** | Clone, patch YAML, commit, open PRs |
| **Image build** | Build Docker images, push to GHCR / Docker Hub / GitLab Registry, full git→build→deploy pipeline |
| **CI/CD** | Trigger GitHub Actions / GitLab CI pipelines, wait for result, list registry tags |
| **Slurm HPC** | Submit multi-node GPU training jobs on bare-metal Slurm clusters, monitor progress, tail logs, cancel jobs |
| **SLO & alerts** | Define SLOs, create triggers, configure Slack alerts |
| **Audit** | View the full history of all operations with who/what/when |

### Agent Catalog — explore and configure tools

The **Agents tab** exposes the full list of actions the agent can execute. Click any action to open a details drawer.

#### Browsing the catalog

Use the **"Search for an action"** field at the top to filter by name or keyword. A **tag dropdown** lets you filter by technology category (e.g. `kubernetes`, `gpu`, `inference`, `gitops`). The catalog displays:

| Column | Description |
|--------|-------------|
| **Action** | Technical name (e.g. `accelerator_get_metrics`) |
| **Connector** | Source connector (e.g. `Nvidia`, `Kubectl`, `Helm`) |
| **Role** | Minimum role required to execute this action |
| **Tags** | Technology category chips — click any chip to filter the catalog to that tag |
| **Destructive** | ⚠ badge if the action modifies or deletes resources |
| **Confirmation** | Whether the agent asks for confirmation before executing |
| **Approval** | Whether an external approval workflow is triggered |

**Filtering by tag:**

1. Click the **tag dropdown** next to the search field
2. Select a tag (e.g. `gpu`, `kubernetes`, `inference`)
3. The catalog narrows to actions in that category
4. Click **Clear** or select **All tags** to reset

Tags are derived from the connector name when not explicitly set (e.g. `Kubectl` → `kubernetes`, `compute`; `Nvidia` → `gpu`, `nvidia`, `compute`).

#### Schema drawer

Click any row to open the **schema drawer** on the right. It shows:

- **Description** — what the action does
- **Input parameters** — name, type (string / integer / boolean / array / object), required vs optional, accepted enum values
- **Override status** — a badge indicates if your org has an active policy override on this action

This allows you to understand exactly what parameters the agent will use when executing an action, and anticipate what information to provide in your prompt.

#### Execution history

The bottom of the schema drawer shows the execution history for this action in your organization:

| Metric | Description |
|--------|-------------|
| **Total runs** | Number of times this action was executed by your org |
| **Success rate** | Percentage of runs that completed without error |
| **Avg duration** | Average execution time across all runs |
| **Recent runs** | Up to 20 most recent executions — status, timestamp, who ran it |

Click any run row to open the [Session Replay](#session-replay) modal and inspect every step in detail.

---

#### Configure tool policy (org admins only)

Org admins see two additional toggles at the bottom of the drawer:

| Toggle | Effect when enabled |
|--------|---------------------|
| **Requires confirmation** | VibOps blocks execution at the platform level and returns a 409 gate — the agent must obtain explicit confirmation before retrying. Enforced regardless of which LLM is configured. |
| **Requires external approval** | Execution is blocked until a human approves the request in an external system (e.g. Slack, PagerDuty, ITSM) |

These overrides are **per-org** and **per-action** — they do not affect other organizations. Changes take effect immediately and are recorded in the audit log.

**Example use case:** your org wants confirmation before any `helm_upgrade` in production, even though VibOps does not classify it as destructive by default. Enable "Requires confirmation" on `helm_upgrade` — from that point on, VibOps will always block and ask before running it, even if the LLM would have executed silently.

> **Note:** overrides supplement the connector defaults. Removing an override reverts the action to its built-in behavior.
> **LLM-agnostic guarantee:** the Confirmation gate is enforced by the policy engine (HTTP 409), not by the LLM's own judgment. It works identically whether VibOps is connected to Claude, GPT-4o, Mistral, or any other model.

---

### Session Replay

The **Session Replay** modal reconstructs any past job execution step by step, so you can understand exactly what happened, why it succeeded or failed, and what the agent did at each stage.

#### How to open a replay

1. In the **Agent Catalog** schema drawer → click a row in the Recent Runs list
2. In the **Jobs** history panel (Dashboard or Chat) → click any job row
3. From the **Replay footer** → click **⊲ Replay** on any job result

#### Replay view

The modal shows:
- **Header**: action name, job ID, final status, start time, total duration
- **Step list** (left panel): numbered steps, each with a tool name, status badge, and relative timestamp
- **Step detail** (right panel): when you click a step —
  - **Input**: the parameters passed to the tool
  - **Output**: the full result returned
  - **Duration**: how long this step took
  - **Error**: if the step failed, the full error message

Long jobs (>20 steps) are paginated — use **‹ Prev** / **Next ›** to navigate.

#### LLM evaluation from replay

At the bottom of the replay modal, an **Evaluate** section lets you run an LLM-as-judge evaluation:
1. Select a rubric from the dropdown
2. Click **⚖ Evaluate** — the evaluation runs asynchronously
3. Results appear in the **LLM Evaluations** section: overall score (0–1), per-criterion scores, and a text justification

See [LLM Evaluation Rubrics](#llm-evaluation-rubrics-admin-only) for rubric configuration.

---

### Production safety guardrails

Certain actions are automatically blocked until explicit confirmation:

- Restarting a service in production
- Scaling a node group (cost and availability impact)
- Uninstalling a Helm chart
- Rolling back a deployment
- MIG reconfiguration (affects running pods)
- Any action in a `prod` namespace

When the agent proposes a blocked action, it displays:

```
⚠  This action will scale gpu-ng from 3 to 0 nodes.
   Impact: all GPU workloads will stop, cost suspended.
   Current state: 3 pods Running on gpu-ng.
   [Confirm]  [Cancel]
```

**These guardrails are enforced at the engine level** — not an interface convention, not a configuration flag. They cannot be disabled by the user.

### Cross-session memory

The agent memorizes operational context between sessions:
- Namespaces and clusters preferred by your team
- Models currently being experimented with
- Interrupted tasks (e.g. "migration planned tomorrow morning")
- Recurring anomalies you have already worked on

You can instruct the agent explicitly:
```
Remember that the ai namespace is reserved for research team experiments
Remember that llama3-70b is validated in staging until Friday
```

Memories can be viewed and deleted in **Admin → Memories**.

---

## 7. Kubernetes cluster management

### Multi-cluster discovery

```
Give me a complete view of our Kubernetes infrastructure — all clusters,
CPU/RAM/GPU resources per node, what is running in each namespace.
```

The agent automatically discovers all configured clusters, maps workloads in parallel, and surfaces operational risks (pods without limits, overloaded nodes, recent OOMKills).

### Creating a test cluster

```
Create a kind cluster "feature-test" with 2 nodes for the team, without touching vibops-dev.
```

The cluster is provisioned, kubeconfig configured automatically, and it appears in the console's cluster selector. To delete it:

```
Delete the feature-test cluster.
```

### Deploying a workload from scratch

```
Deploy nginx:latest on the apalacha cluster, namespace demo, 2 replicas, port 80.
```

The agent creates the namespace if needed, the Deployment, the Service, and confirms the pods are Running before responding.

### Port-forward to localhost

```
Port-forward nginx from the demo namespace on apalacha to localhost:8080.
```

### Patching resources

```
The open-webui pod is OOMKilling. Increase its memory limit to 2Gi on vibops-dev.
```

The agent checks the current state, applies the strategic merge patch, and confirms the rollout.

### Detecting configuration drift

```
Compare llama3 deployments in staging and prod on vibops-dev.
Are they running on the same image and the same config?
```

The agent queries both environments in parallel and produces a full diff: image, replicas, pull policy, resource limits — with an explanation of what each discrepancy means operationally.

### Auditing production workloads

```
Audit all our LLM workloads on vibops-dev.
Surface anything running without resource limits, with an untagged image,
or with fewer replicas than expected in prod.
```

### Operations history

```
Show me everything that happened on the clusters in the last 2 hours.
Any failures to flag?
```

---

## 8. Inference workloads and GPU

### Checking GPU availability

```
We need 4 A100s for a llama3-70b deployment.
Do we have the capacity on the prod cluster?
```

The agent inspects each GPU node in parallel, calculates free vs allocated GPUs, and delivers a verdict with the list of what is currently consuming GPUs.

### Deploying an Ollama model

```
Deploy an Ollama container for mistral in the ai namespace on vibops-dev,
1 replica for the research team.
```

### Deploying a NVIDIA NIM

```
Deploy the NVIDIA NIM for llama-3.1-8b-instruct on the prod GPU cluster with 2 GPUs.
```

The agent performs in order: GPU audit, operator audit, VRAM profile selection, Helm deployment with the NGC secret, waiting for pod availability, and a live inference test.

### Bootstrapping the GPU Operator

```
I just added a GPU node on vibops-dev.
Configure the NVIDIA GPU Operator so the node is ready for inference workloads.
```

The agent installs the GPU Operator via Helm, waits for driver + device-plugin + DCGM exporter to all be Running, and confirms the GPU capacity visible by the scheduler.

### Configuring MIG (multi-instance GPU)

```
Partition the A100s on gpu-node-1 into 3g.40gb slices so
three teams can share the GPU.
```

**Note:** MIG reconfiguration requires explicit confirmation — the agent explains the impact (node drain, affected pods) before acting.

### Configuring GPU time-slicing

```
Configure time-slicing on underutilized GPUs to multiply
workloads on the same hardware.
```

### GPU cost report

```
How much are our GPUs costing this week? Break it down by team
and surface anything that looks like waste.
```

### Detecting idle GPUs

```
Are any of our GPU workloads underutilizing their allocation?
I want to know what we can scale down or move to time-slicing.
```

---

## 9. MLOps workflows

### Inference fleet status (start of day)

```
Give me the complete status of all our LLM inference services on vibops-dev —
models, namespaces, replicas, health.
```

### Promoting a model from staging to prod

Step 1 — verify staging is ready:
```
Is llama3 in staging on vibops-dev healthy and running on the right image?
I want to promote it to prod.
```

The agent compares staging and prod in parallel and confirms whether the promotion is safe.

Step 2 — promote:
```
OK. Move prod llama3 to the same image as staging and confirm the rollout.
```

### Updating a model with validation

```
Update llama3 in prod on vibops-dev to ollama/ollama:0.6.5,
then check the logs to confirm the model loaded correctly.
```

The agent patches, waits for the rollout, reads the logs of the new pod, and confirms the model is operational — or reports a startup error.

### Emergency rollback

```
The last deployment broke the llama3 API in prod on vibops-dev.
Immediate rollback to the previous version.
```

The agent checks the deployment state, executes the rollback, and confirms the pod is Running again on the previous version.

### Scale-up for a traffic spike

```
We expect a traffic spike tonight on prod llama3 on vibops-dev.
Scale to 5 replicas and confirm they are all Running.
```

### Scale-down after the traffic spike

```
Traffic has dropped. Scale llama3 in prod to 2 replicas.
```

### Slurm HPC training (bare-metal clusters)

For organizations running multi-node GPU training on bare-metal Slurm clusters (not Kubernetes), VibOps connects via SSH or the slurmrestd REST API.

#### Cluster discovery and queue inspection

```
Check the GPU capacity on our Slurm cluster at gpu.hpc.acme.com —
how many A100 nodes are available and what is the current queue?
```

The agent calls `slurm_get_cluster_info` and `slurm_list_jobs` in parallel and returns partition availability, node states, running and pending jobs.

#### Submitting a multi-node training job

```
Submit a training job on the gpu partition: 4 nodes, 8 GPUs per node,
run train.py with batch_size=512, epochs=50.
Job name: llm-finetune-v3. Use ssh_key=@secret:slurm_ssh_key.
```

The agent:
1. Generates the sbatch script and shows it as a dry-run preview
2. Waits for explicit confirmation before submitting
3. Returns the Slurm job ID and saves it to memory (`slurm_job:llm-finetune-v3`)

The SSH key is resolved from the VibOps Vault — it is never stored in chat history or on disk permanently.

#### Monitoring a running job

```
What is the status of my llm-finetune-v3 job? Show me the last 50 lines of logs.
```

The agent calls `slurm_get_job_status` and `slurm_get_job_output` without requiring SSH access from the engineer's machine.

#### Cancelling a job

```
Cancel job 48291. Loss is diverging.
```

The agent shows a confirmation gate (job ID, node count, estimated GPU cost remaining) before sending `scancel`.

#### SSH key configuration

Store the Slurm SSH private key in the VibOps Vault:

1. **Admin → Secrets → New secret**
   - Name: `slurm_ssh_key`
   - Value: PEM content of the private key (the full `-----BEGIN ... -----END ...` block)

2. Reference it in any Slurm prompt: `ssh_key=@secret:slurm_ssh_key`

The key is written to a temporary file with `chmod 600` for the duration of the SSH call, then deleted.

#### Connecting a Slurm cluster via the console form (v0.17.4+)

Since v0.17.4, Slurm cluster configuration is managed directly from the gateway registration form — no environment variables required.

In **Admin → Gateways → New Gateway** (or edit an existing gateway):

1. Set **Gateway type** to `slurm` (or `hybrid` for clusters running both Kubernetes and Slurm)
2. Fill in the **Slurm config** fields that appear conditionally:
   - **Host** — Slurm head node hostname (e.g. `gpu.hpc.acme.com`)
   - **SSH user** — SSH username (default: `slurm`)
   - **SSH port** — optional, default 22
   - **REST URL** — slurmrestd base URL (e.g. `http://gpu.hpc.acme.com:6820`); if set, REST is preferred over SSH
   - **SSH key secret** — name of the VibOps Vault secret holding the private key (e.g. `slurm_ssh_key`)
3. For Kubernetes metrics, the **Prometheus URL** field remains available when `gateway_type` is `kubernetes` or `hybrid`

The `gateway_type` and `slurm_config` fields are exposed in the API (`GatewayCreate` / `GatewayOut`). Secret names are masked (`***`) in API responses.

> **Slurm version requirement:** Slurm ≥ 21.08 is required. VibOps uses structured JSON output (`squeue --json`, `sacct --json`) — text parsing is not supported.

#### GPU job tracking (workloads table)

Since v0.17.3, Slurm jobs are tracked persistently in the `workloads` table:

- **Every 60 seconds**, `SlurmWorkloadCollector` polls `squeue` (via REST or SSH) and upserts running jobs into the `workloads` table — accumulating GPU-seconds for FinOps chargeback
- **After each poll**, `sacct` is called to finalize recently completed jobs (`collect_completed`), setting exact `ended_at` timestamps from Slurm accounting records
- GPU allocation is parsed from GRES strings: `gpu:2`, `gpu:tesla:2`, `gpu:a100:2,gpu:v100:1` (multi-type supported)
- For `hybrid` gateways, both `KubernetesWorkloadCollector` and `SlurmWorkloadCollector` run in parallel

---

## 10. Incident diagnosis and remediation

### Initial diagnosis

```
We have latency spikes in the ai namespace since this morning.
Diagnose what is happening, check the cluster resources,
and tell me if open-webui is healthy.
```

The agent automatically correlates: recent logs, Kubernetes events, pod status, resource utilization, restart history. It surfaces the root cause and a concrete recommendation.

### Full remediation in two steps

Step 1:
```
The open-webui pod in the ai namespace on vibops-dev is crash-looping.
Diagnose what is wrong and tell me what to do.
```

The agent uses `analyze_pod_failure` to correlate events + describe + logs and returns a structured diagnosis (cause, current limit, last log lines, recommendation).

Step 2:
```
Fix it. Increase the memory limit to 2Gi.
```

The agent applies the patch and confirms the pod is Running with the restart count reset to zero.

### Multi-source correlation

For complex incidents involving multiple services:

```
Correlate the incident on the inference namespace: logs + Kubernetes events +
Prometheus metrics + deployment status. I want the full timeline.
```

The agent queries all four sources in parallel (`asyncio.gather`) and produces a correlated timeline with identified causal relationships.

### Prometheus alerts

When a Prometheus alert arrives via webhook, the agent receives it automatically, launches the diagnosis pipeline, and posts an analysis in the active chat (or opens a new conversation) without any action on your part.

### Auto-healing: creating a trigger

```
Set up a rule: if a pod has more than 3 restarts in 10 minutes,
automatically restart the deployment and notify on Slack.
```

For destructive actions (rollback, scale-down), the trigger will pause and ask for confirmation — the same guardrail as for manual actions.

---

## 11. Capacity planning and benchmarking

### Benchmarking an inference service

```
Benchmark the ollama service in the ai namespace on vibops-dev.
Run 5 requests against llama3 and give me p50/p95/p99 latencies.
```

The benchmark runs inside the pod (not from your workstation), giving real latencies as your users experience them.

### Planning capacity

```
Based on this benchmark (p99: 3200ms, avg: 2500ms), plan capacity for llama3
to handle 50 RPS at under 2000ms p99. Each replica needs 4 CPU and 8GB RAM.
```

The agent calculates the recommended number of replicas (with 20% headroom), total resources needed, and an HPA min/max range.

Then directly:
```
Scale llama3 in the ai namespace to the recommended number of replicas.
```

### Finding the right cluster for a new deployment

```
I need to deploy a new inference service: 4 CPU, 8GB RAM, 2 replicas.
Which of my clusters has the capacity?
```

The agent scans all clusters in parallel and returns a ranked list with fit score (available headroom).

### Detecting GPU waste

```
Are any of our GPU workloads underutilizing their allocation?
I want to know what we can optimize.
```

---

## 12. SLOs and alerts

### Defining an SLO

```
Define an SLO for llama3 in the prod namespace:
p99 latency below 2000ms, 99.9% of the time.
Alert on Slack if we exit the error budget.
```

The agent creates the SLO, configures a Prometheus trigger, and wires up the Slack notification.

### Checking SLO compliance

```
Are we currently meeting the llama3 SLO?
```

The agent queries Prometheus and returns real-time compliance: current p99 vs threshold, remaining error budget.

### Configuring Prometheus alerts

```
Configure a Slack alert if a node's CPU exceeds 90% for more than 5 minutes.
```

### Checking available notification channels

```
What notification channels are configured?
```

---

## 13. GitOps

### Admin → Git — org-level configuration

Access via the **⚙ Admin** panel → **Git** sub-tab. This panel has two sections:

**Git provider card** — configure the token the agent uses for all Git and registry operations:

| Field | Description |
|-------|-------------|
| Provider | `GitHub` or `GitLab` |
| Personal Access Token | `ghp_...` or `glpat-...` — stored encrypted, never displayed again |
| GitLab URL | Only for self-hosted GitLab (e.g. `https://gitlab.mycompany.com`) |

The status badge shows **Connected ✓** (green) once a token has been saved, or **Not configured** (gray) if no token is stored.

**Apps & repositories table** — links each app to its source repo:

| Column | Description |
|--------|-------------|
| App / Namespace | Application name and Kubernetes namespace |
| Env | Environment badge: `prod` (red) · `staging` (yellow) · other (gray) |
| Status | ● running / ○ stopped |
| Repository | `owner/repo` link with branch and last commit SHA. Click **Edit** to change inline. |
| ✕ | Unlink the repo from this app |

To link an unlinked app: click **Link repo** in the Repository column → type `owner/repo` → Enter.

---

### Git tab — per-app view

Select an application in the sidebar and click the **Git** tab.

**When no repo is linked:**
An inline form appears — type `owner/repo` and press Enter to link the app immediately. The Git tab then loads the commit history.

**When a repo is linked:**

| Section | What it shows |
|---------|--------------|
| Commit history | List of recent commits: SHA · message · author · date |
| Current commit badge | Green **current** badge on the commit deployed on the cluster |
| Rollback | Click any older commit to roll back the deployment to that version |

### Modifying a configuration in a repository

```
Increase the replicas of inference-server to 3 in the infra repo
and open a PR for review.
```

The agent clones the repository (using the token from Admin → Git), patches the YAML, generates the diff, commits, and opens the PR — all in a single operation.

### Building and pushing a Docker image

```
Build and push the latest commit of acme/api-server to ghcr.io/acme/api-server:latest
using token=@secret:ghcr_token
```

The agent runs `docker build`, logs every build layer in the job output, pushes the image to the registry, and returns the image digest. Use the digest to pin the image in Helm:

```
helm upgrade api-server ./charts/api-server \
  --set image.digest=sha256:cafebabe...
```

**Supported registries:**

| Registry | Image prefix | Auth |
|----------|-------------|------|
| GitHub Container Registry | `ghcr.io/org/app:tag` | GitHub PAT with `write:packages` |
| Docker Hub | `org/app:tag` | Docker Hub access token |
| GitLab Registry | `registry.gitlab.com/group/app:tag` | GitLab PAT with `write_registry` |
| Self-hosted | `registry.mycompany.com/app:tag` | Username + password |

The registry token is passed via `--password-stdin` — never via CLI argument — and is masked in all job logs.

### Full GitOps pipeline in one conversation

```
Deploy the latest commit of acme/api-server to prod:
1. Clone the repo
2. Build and push the image to ghcr.io/acme/api-server with token=@secret:ghcr_token
3. Upgrade the Helm release with the new image digest
```

The agent chains `git_clone` → `docker_build_push` → `helm_upgrade` automatically, confirming before the Helm upgrade (destructive action).

### CI pipeline triggering

VibOps can trigger and monitor CI/CD pipelines on GitHub Actions or GitLab CI using the same token configured in **Admin → Git**.

**Trigger a pipeline and wait for the result:**
```
Trigger the build.yml workflow on acme/api-server on the main branch
```
```
Wait for CI pipeline 12345 on acme/api-server to finish
```

**Full build → CI → deploy pipeline:**
```
Clone acme/api-server, build and push the Docker image to ghcr.io/acme/api-server:latest,
trigger the integration-tests.yml workflow, wait for it to succeed, then deploy to staging.
```

The agent chains `ci_trigger` → `ci_wait` → `helm_upgrade`, aborting the deploy if the CI pipeline fails.

**List registry tags:**
```
List available tags for ghcr.io/acme/api-server
```

#### Admin → CI panel

The **Admin → CI** sub-tab shows all pipeline runs triggered by VibOps:

| Column | Description |
|--------|-------------|
| App | Short repository name |
| Workflow / Pipeline | Workflow file (GitHub) or pipeline name (GitLab) |
| Branch | Git ref used for the trigger |
| Status | `success` / `running` / `failure` / `cancelled` |
| Duration | Elapsed seconds for completed runs |
| Triggered | Timestamp of the VibOps job |
| Link ↗ | Direct link to the GitHub Actions run or GitLab pipeline |

**Provider scope requirements:**

| Provider | Required PAT scope |
|----------|--------------------|
| GitHub | `workflow` (plus `repo` if private) |
| GitLab | `api` (upgrade from `read_api` used by the Git connector) |

> The CI connector reuses the `GIT_TOKEN` set in Admin → Git. No additional credential is required.

### Using a Git token from Secrets

```
Clone the infra repo using token=@secret:git_token
```

Secrets are injected at runtime — the raw value is never exposed in the chat. See [Secrets](#18-secrets) for how to create them.

---

## 14. Dashboard tab

Real-time view of operational activity:

- **Recent jobs** — all operations with status (in progress / success / failure), environment badge (dev/staging/prod), and timestamp. Click a job to see its full logs.
- **Counters** — number of jobs in progress / succeeded / failed for the period.
- **Deployments** — list of all discovered applications with replica count and health status.
- **⟳ Discover button** — triggers a full cluster scan.
- **Last discovered** — timestamp of the last automatic scan.

The Dashboard refreshes automatically every 30 seconds.

---

## 15. Cluster tab

Live resource view of the selected cluster:

- **GPU** — total / used / free with utilization rate bar
- **CPU** — requested vs allocatable across all nodes
- **Memory** — same
- **Nodes** — status per node, CPU/RAM/GPU capacity and requests
- **Pods** — top consumers by resource request

Use the **context selector** (top left) to switch between clusters. **Refresh** button to relaunch the scan manually.

---

## 16. Fleet tab

The Fleet tab is the **multi-cluster control centre**. It is the second tab in the navigation bar (right after Dashboard) and always shows an online/offline indicator.

### Fleet sub-tab

Aggregated KPIs across all connected sites:

- **Clusters online** — number of live clusters and active gateways
- **GPU total** — sum of all GPUs across the fleet
- **GPU used / %** — real-time utilisation bar
- **Nodes** — total worker nodes
- **Unreachable** — gateways that have stopped reporting

Below the KPIs: a **cluster table** listing every cluster with its gateway, GPU used/total, a utilisation bar, and a **Chat** button to target that cluster directly.

**Cross-cluster quick actions** (bottom of the tab):
- Health check on all clusters
- Active alerts across all clusters
- Best cluster for a new deployment
- GPU usage comparison

If no gateway is registered yet, the tab shows a **"Add a gateway"** button that opens the gateway wizard directly.

Removing a cluster from the Fleet table (×) permanently removes it from the gateway's cluster list. The cluster is added to a blocklist and will not reappear even after the gateway sends its next heartbeat.

### Gateways sub-tab

Lists all registered gateways with their status (online / offline / never connected), last ping, and declared clusters. Use this to diagnose connectivity issues.

### Grafana sub-tab

Embedded Grafana dashboards (GPU metrics, API SLOs) — requires Prometheus + Grafana configured in Admin → Integrations.

**Real-time GPU metrics collected by DCGM Exporter:**
- Temperature per GPU (°C), GPU utilization (%), VRAM used/free (MiB), Power (W), ECC errors

**Prerequisites:** DCGM Exporter deployed on the cluster and Prometheus configured. If not, the tab shows installation instructions.

To detect and install automatically:
```
Is Prometheus installed on my cluster? If not, install it.
```

---

## 17. Admin tab

**Who can access it?** Only users with the `org_admin` role. If you do not see the ⚙ icon in the sidebar, your account does not have this role — ask an admin to assign it to you.

**How to access it?** Click the ⚙ icon at the bottom of the left sidebar. A panel opens over the console. Click **Close Admin** or press **Escape** to close it.

> **Red badge on the ⚙ icon** — Indicates a license issue to resolve: quota exceeded, license expired, or trial expired. Click ⚙ then the **License** tab to see the details.

The Admin is organized into sub-tabs. Here is each one in turn.

---

### Organization

This is your organization's identity profile in VibOps.

**What you can view and modify:**
- **Name** of the organization (displayed in the header and reports)
- **Slug** (short identifier, used in URLs — for example `acme-corp`)
- **Logo URL** — if you have a hosted logo, enter its URL here. The URL is auto-detected from your org email domain name, but you can replace it.
- **Dataset consent** — controls whether your org's operational data contributes to VibOps improvement (see §19 Dataset & RLHF)

**How to modify:**
1. Click in the field to modify
2. Type the new value
3. Click **Save**

> **The slug matters**: if you change it after creating rules or pipelines that use it, you will need to update them manually.

---

### Teams

A **team** is a group of users with a shared action scope. It defines: on which clusters, which namespaces, and which environments members can act.

**Why teams exist:** Imagine you have a junior developer. You want them to be able to deploy in `dev` but absolutely not touch `prod`. You create a `Dev team`, give it access to the `dev, staging` namespaces and `dev` environment only. The junior developer is a member. They will never be able to send an action to `prod`, even if they try.

**Team parameters:**

| Parameter | Description | Example |
|-----------|-------------|---------|
| **Name** | Internal team name | `Platform Team` |
| **Allowed namespaces** | List of accessible K8s namespaces (comma-separated). Empty = all. | `default, prod, gpu-workloads` |
| **Allowed environments** | `dev`, `staging`, `prod` — comma-separated. Empty = all. | `dev, staging` |
| **Allowed clusters** | Accessible cluster names. Empty = all. | `kind-dev, eks-staging` |
| **GPU quota** | Max number of GPUs the team can request per job. `0` = unlimited. | `8` |

**Create a team:**
1. Admin → **Teams** sub-tab
2. Click **New team**
3. Fill in the fields. **Important**: if you leave a field empty, there is no restriction for that dimension (e.g. empty namespaces = access to all namespaces).
4. Click **Create**

**Modify a team:**
1. Click the team name in the list
2. Modify the fields
3. Click **Update**

**Delete a team:**
- Click the trash icon next to the team
- Members of this team lose the permissions it gave them — verify they have other teams or roles before deleting

> **Tip:** Start by creating 2-3 teams (e.g. `Ops`, `Dev`, `ReadOnly`) and adjust as you go rather than creating one team per person.

---

### Members (Users)

This is where you manage user accounts: creation, teams, role, password, activation/deactivation.

**Understanding roles:**

| Role | Can do | Cannot do |
|------|-----------|------------------|
| `readonly` | View clusters, logs, dashboard, read-only chat | Launch jobs, modify resources, access Admin |
| `developer` | Everything `readonly` + deploy, scale, rollback, launch jobs | Manage users, secrets, licenses. Prod actions subject to team restrictions. |
| `org_admin` | Everything — manage teams, members, secrets, notifications, license | Nothing — full access |

> **Important:** The role is global to the organization. Fine-grained scope (which clusters, which namespaces) is controlled by teams. A `developer` without an assigned team can act on everything.

**Create a user:**
1. Admin → **Users** sub-tab
2. Click **+ New user**
3. Fill in:
   - **Username** — login identifier (no spaces, no uppercase)
   - **Email** — for password recovery (optional if no SMTP)
   - **Initial password** — communicate to the user via a separate channel
   - **Role** — choose `readonly`, `developer`, or `org_admin`
   - **Admin?** — check if `org_admin`
4. Click **Create**

> **After creation**, the user will need to change their password. You can generate a reset link from the login page ("Forgot password" section).

**Modify a user:**
- Click on the user's row to expand their detail panel
- Modify the role, teams, email
- Changes take effect immediately

**Deactivate an account:**
- Expand the user panel → **Deactivate** button
- The user can no longer log in but their history is preserved
- You can reactivate them later

**Assign a team:**
- In the user's detail panel, select teams from the list
- A user can belong to multiple teams — the broadest permissions apply

---

### Per-cluster roles (overrides)

**Why this feature exists:** Sometimes a user needs a different access level depending on the cluster, without you wanting to create an entire team just for that. Example: Alice is a `developer` in the general team, but on the `prod-gpu` cluster, you want her to be `readonly` — she can view but not modify.

**How it works — priority rule:**

```
Effective access on a cluster =
  cluster override defined for this user → that role applies
  otherwise → user's team role
  otherwise → user's global role
```

In other words: the cluster override ALWAYS takes precedence over the team role, for that specific cluster only.

**How to add an override:**
1. Admin → **Users** sub-tab
2. Find the user in the list
3. Click the **⛭ Cluster roles** button on their row (the numeric badge shows the number of active overrides)
4. The panel opens below the user card
5. In the **Cluster name** field: type the exact name of the cluster, as it appears in the Connect tab (e.g. `kind-vibops-dev`, `eks-prod-us-east-1`)
6. In the **Role** menu: choose `readonly`, `developer`, or `admin`
7. Click **+ Add override**

> **The cluster name must be exact.** If you type `prod` but the cluster is named `eks-prod`, the override will not apply. Check the exact name in the **Connect → Gateways** tab.

**How to remove an override:**
- In the user's Cluster roles panel, click the trash icon next to the override
- You will be asked to confirm
- The override is removed immediately — the user reverts to their team role on that cluster

**Concrete examples:**

| Situation | Solution |
|-----------|---------|
| Alice is dev everywhere, but readonly on prod | Override `prod` → `readonly` for Alice |
| Bob is readonly everywhere, but needs to act on the test cluster | Override `kind-test` → `developer` for Bob |
| Carol manages only the H100 cluster, not the others | Global role `readonly` + override `gpu-h100` → `admin` |
| The Platform team should be admin on all clusters except the client cluster | `developer` role in the team + override `client-cluster` → `readonly` |

> **Technical note:** Overrides are read on every API request. Deletion is effective immediately for API tokens. For users connected via JWT (browser session), the new role applies at the next token issuance (within 2 hours at most). If you need the effect to be immediate: ask the user to log out and log back in.

---

### Secrets

The VibOps secrets vault stores your sensitive credentials (API tokens, passwords, private keys) in encrypted form, and injects them into jobs on demand — without ever exposing them in plain text in the chat or logs.

**Why not just type the token in the chat?** If you type `ngc_api_key=abc123` in the chat, that value appears in the history, logs, and potentially exports. Vault secrets are never logged.

**Create a secret:**
1. Admin → **Secrets** sub-tab
2. Click **+ New secret**
3. Fill in:
   - **Name** — short identifier without spaces (e.g. `git_token`, `ngc_api_key`)
   - **Value** — the secret in plain text. Displayed masked after entry.
   - **Description** — optional, to remind you what this secret is for
4. Click **Create**

> Once created, **the value is no longer displayed** in the interface. If you have lost it, delete and recreate the secret.

**Use a secret in the chat:**
```
Clone the infra repo with token=@secret:git_token
Deploy the llama3 NIM with NGC key=@secret:ngc_api_key
Push the config with credentials=@secret:registry_password
```
The agent automatically resolves `@secret:<name>` before sending the request to the cluster. The token is never visible in the response or in the logs.

**Modify / delete a secret:**
- Click the pencil ✏ to modify the value
- Click the trash 🗑 to delete (irreversible — jobs that reference this secret will fail afterwards)

> **System secrets**: some secrets are marked `system` — they are shared between organizations by the VibOps team for reselling scenarios. Do not modify them unless explicitly instructed.

---

### Tool policy

_(Org admins only)_

The **Tool policy** sub-tab lets you override the default confirmation and approval rules for any action in the agent catalog — at the organization level.

**Understanding the two safety flags:**

| Flag | What it does | Enforced by | Scope |
|------|-------------|-------------|-------|
| **Confirmation** | VibOps blocks the job at the platform level (HTTP 409) and returns a dry-run preview. The agent must send `confirmed: true` to proceed. Works with any LLM — the gate is at the infrastructure layer, not the model layer. | Policy engine | In-conversation |
| **Approval** | VibOps sends a notification (Slack, email, webhook) to a person or external system. The job stays in `pending_approval` state until they click Approve or Reject. The operator in chat does not have a say. | Policy engine | Out-of-band |

Both flags can be active simultaneously: the agent presents the dry-run and waits for in-chat confirmation, **and** sends an external approval request — the job only runs when both are satisfied.

> **Why platform-level enforcement matters:** some LLMs may execute actions without asking for confirmation. The Confirmation gate is a hard stop at the infrastructure layer — even if the LLM skips the question, the platform returns 409 and nothing runs until the user explicitly confirms.

**The table**

The Tool policy table lists all 258 actions across every registered connector. Each row shows:

| Column | Description |
|--------|-------------|
| **Action** | The action name (monospace). A yellow `override` badge appears if your org has an active policy override. |
| **Risk** | A red `⚠ destruct.` badge for actions that modify or delete infrastructure. |
| **Confirmation** | Blue toggle — ON means the agent will pause and ask before executing. |
| **Approval** | Amber toggle — ON means an external approval notification is sent before execution. |

**To configure an action:**

1. Admin → **Tool policy** sub-tab
2. Use the search field or the **All / Active overrides / Destructive** filters to find the action
3. Click the **Confirmation** or **Approval** toggle to enable/disable
4. Changes apply immediately — no restart needed

**Behavior of overrides:**

- Overrides are **per-org** — your configuration does not affect other tenants
- Overrides are **additive** — you can only raise the safety level, not remove a confirmation that is built into the connector
- All changes are recorded in the **Audit** log with the admin's identity and timestamp

**Example policies:**

| Goal | Action to configure | Toggle |
|------|---------------------|--------|
| Always confirm before Helm upgrades | `helm_upgrade` | Confirmation ON |
| Route all scaling decisions through ITSM | `scale_deployment` | Approval ON |
| Require both in-chat + manager sign-off on MIG partitioning | `accelerator_partition_device` | Both ON |
| Enforce approval before any cluster deletion | `delete_cluster` | Approval ON |

> **Non-admin users** see confirmation/approval state as read-only information in the Agent Catalog drawer — they cannot change it.

---

### Approvals

_(Org admins only)_

When an action has **Approval** enabled (either via the Tool Policy toggles or the Org Policy YAML), VibOps creates an **approval gate** before the job executes. The gate blocks execution until an admin approves or rejects it.

#### What the user sees in the chat

When a job enters `AWAITING_APPROVAL`, the agent immediately informs the user — regardless of which LLM is configured (Claude, GPT-4o, Mistral, Ollama, etc.):

> *"This action requires admin approval before it can be executed. Your request has been submitted and is pending review. You will be notified once a decision has been made."*

The agent does not poll or retry — the conversation closes cleanly. This message is returned as a structured tool result, so any LLM interprets and relays it to the user in natural language.

#### Approval notifications

VibOps automatically notifies all active notification channels when an approval gate is created:

- **Slack**: an interactive message with **Approve** and **Reject** URL buttons (Block Kit format). Clicking the button opens a confirmation page — no Slack app installation required.
- **HTTP webhook / email / PagerDuty**: a structured message with the approval and rejection URLs.

The notification includes: the action name, the user who triggered it, a dry-run preview (if available), and the expiry time of the gate.

#### Managing approvals in the console

Admins can approve or reject pending gates directly in the console:

1. Admin → **Approvals** sub-tab
2. The table shows all pending gates: action, triggered by, created at, expiry
3. Click **Approve** to allow execution — the job immediately transitions to `queued`
4. Click **Reject** to block execution — optionally enter a reason

> Gates expire automatically after 24 hours. Expired gates cannot be approved.

#### Approval flow summary

```
User submits action
       ↓
PolicyEngine → approval required
       ↓
Job created (state: AWAITING_APPROVAL)
       ↓
Agent informs user in chat: "pending admin approval" ← any LLM
       ↓
Notifications sent to all active channels (Slack, email, webhook)
       ↓
Admin approves (console or Slack/webhook URL)      ← async, out-of-band
       ↓
Job transitions to QUEUED → executes
```

---

### Org Policy (declarative YAML)

_(Org admins only)_

The **Policy** sub-tab lets you define conditional access rules for your organization in YAML. These rules are evaluated **after** the connector role check and **before** the catalog approval gate — they can tighten or override catalog defaults without editing connector code.

#### When to use Policy vs Tool Policy toggles

| Use case | Recommended approach |
|----------|---------------------|
| Toggle confirmation/approval on a specific action | Tool Policy toggles (simpler) |
| Conditional rule: block an action only in a specific namespace | Org Policy YAML |
| Block all actions in `prod` except for admins | Org Policy YAML |
| Require approval for scale operations above a threshold | Org Policy YAML |
| OPA/Rego integration for enterprise policy-as-code | Org Policy YAML (mode: rego) |

#### YAML schema

```yaml
version: "1"
rules:
  - name: "protect-prod-delete"       # unique name (required)
    match:
      action: "kubectl_delete"        # exact or glob (* = any action)
      namespace: "prod"               # payload.namespace equality or glob
      env: "production"               # payload.env equality
      cluster: "gpu-prod-*"           # payload.cluster glob
      replicas_gt: 8                  # payload.replicas > 8
    effect: "deny"                    # see effects table below
    reason: "Production deletions blocked — open a change ticket"
    value: "admin"                    # role name for require_role effect
```

**Match conditions** (all optional, ANDed):

| Field | Type | Matches |
|-------|------|---------|
| `action` | string/glob | Action name (`kubectl_delete`, `helm_*`, `*`) |
| `namespace` | string/glob | `payload.namespace` |
| `env` | string | `payload.env` |
| `cluster` | string/glob | `payload.cluster` or `payload.context` |
| `replicas_gt/gte/lt/lte` | integer | Numeric comparison on `payload.replicas` |

**Effects:**

| Effect | What happens |
|--------|-------------|
| `deny` | Hard block — HTTP 403, reason shown to the user |
| `require_confirmation` | Dry-run preview shown, `confirmed: true` required |
| `require_approval` | Approval gate created, external notification sent |
| `require_role` | Denied unless the user has the role specified in `value` (`viewer`/`operator`/`admin`) |
| `allow` | Explicit allow — skips the catalog approval gate |

Rules are evaluated **in order** — first match wins.

#### OPA/Rego mode

For organizations with an existing OPA deployment:

```yaml
version: "1"
mode: "rego"
body: |
  package vibops.policy
  default allow = true
  deny[msg] {
    input.payload.namespace == "prod"
    input.action == "kubectl_delete"
    msg := "Production deletions are blocked"
  }
```

Set `OPA_URL` in the server environment to point to your OPA sidecar. If `OPA_URL` is not set, the Rego policy falls through to catalog defaults (with a warning logged).

#### Editing the policy

1. Admin → **Policy** sub-tab
2. Edit the YAML in the editor
3. Click **Save policy** — the YAML is validated before saving (errors shown inline)
4. To start from scratch, click **Remove policy** — all decisions revert to catalog defaults

A **starter example** is displayed when no policy is set.

---

### LLM Evaluation Rubrics (admin only)

The **Eval Rubrics** sub-tab lets you define how job executions should be scored by an LLM judge. This enables systematic, reproducible quality measurement across your infrastructure operations — useful for compliance, team coaching, or continuous improvement.

#### Creating a rubric

1. Admin → **Eval** sub-tab → **+ New rubric**
2. Fill in:
   - **Name**: a short identifier (e.g. `production-safety`, `correctness-check`)
   - **Description**: what this rubric measures
   - **Provider**: which LLM runs the evaluation (see table below)
   - **Model**: model name — leave empty to use `LLM_MODEL` from the environment
3. Add **criteria**: each criterion has a name, description, and weight (relative importance)
4. Click **Create rubric**

#### LLM providers for evaluation

| Provider | Description |
|----------|-------------|
| **VibOps** (default) | Inherits `LLM_PROVIDER`/`LLM_API_KEY`/`LLM_BASE_URL`/`LLM_MODEL` from the environment — uses the same LLM as the agent automatically |
| **Claude** | Anthropic API (`LLM_API_KEY` or `ANTHROPIC_API_KEY`) |
| **OpenAI / vLLM / Groq** | Any OpenAI-compatible endpoint — reads `LLM_BASE_URL` + `LLM_API_KEY` |
| **Ollama** | Local Ollama instance (`OLLAMA_URL`) |

> **Recommendation:** keep the default `VibOps` provider. If you change the agent's LLM, evaluations automatically follow without editing rubrics.

#### Criteria

Each criterion is scored 0.0 to 1.0. A weighted aggregate is computed. Typical criteria:

| Name | Description | Example weight |
|------|-------------|----------------|
| `correctness` | Did the action achieve its stated goal? | 0.5 |
| `safety` | Were destructive flags and dry-run previews respected? | 0.3 |
| `efficiency` | Was the execution concise with no unnecessary steps? | 0.2 |

#### Running an evaluation

Evaluations are triggered from the [Session Replay](#session-replay) modal:
1. Open any job replay
2. Select a rubric in the **Evaluate** footer
3. Click **⚖ Evaluate** — the task runs asynchronously in a Celery worker
4. Status cycles: `pending → running → completed` (or `failed`)
5. Results appear inline: overall score, per-criterion scores, LLM justification

Evaluation results are stored in the database and accessible via `GET /api/v1/eval/evaluations?job_id={id}`.

#### L2 Auto-Scanner

When you enable **Scanner L2** on a rubric, VibOps automatically evaluates every completed job in your organisation — successes and failures alike — without any manual action.

**How to enable:**
1. In the rubric create form, check **"Scanner L2 — apply to every completed job"**
2. Only one rubric per org should have this enabled at a time (the most recent wins)

**Use cases:**
- Continuous quality gate: flag jobs whose outputs don't meet your correctness criteria
- Failure analysis: automatically score every failure with a "root cause" rubric
- Compliance audit: ensure every production action meets safety criteria

Auto-scan evaluations appear in the [Session Replay](#session-replay) modal just like manually triggered evaluations.

---

### Proactive Anomaly Detection

VibOps continuously monitors GPU metrics for all connected clusters and automatically raises **anomaly events** when abnormal conditions are detected — without waiting for a user to ask.

The anomaly scanner runs every 5 minutes via a Celery Beat task.

#### Anomaly types

| Type | Trigger condition | Default severity |
|------|-------------------|-----------------|
| `gpu_idle` | Average GPU utilization < 10% over 15 minutes | Warning |
| `gpu_spike` | Average GPU utilization > 90% over 15 minutes | Warning (Critical if > 98%) |
| `node_loss` | Node count dropped vs. the 15-minute maximum | Critical |
| `utilization_drop` | Single-interval drop > 30 points and current util < 50% | Warning |

#### Dashboard widget

Open anomalies appear in a collapsible **Anomalies GPU** panel at the top of the Dashboard tab:

- Severity badge (WARNING / CRITICAL) and anomaly type
- Cluster name and human-readable description
- Detection timestamp
- **Resolve** button — closes the event manually once you have investigated

The badge shows the count of open (unresolved) events. It reloads automatically when you open the dashboard.

#### Notifications

When an anomaly is created, VibOps dispatches a notification to all configured channels (Slack, webhook, email, PagerDuty) using the same channel infrastructure as alert rules.

#### API

```
GET  /api/v1/anomalies               — list recent events (filters: cluster, type, severity, open_only)
GET  /api/v1/anomalies/open          — open events only
POST /api/v1/anomalies/{id}/resolve  — manually resolve (org_admin)
```

#### Deduplication and auto-resolution

- If an open event of the same type already exists for a cluster, no duplicate is created.
- Once the condition clears (e.g. utilization rises back above 10%), the open event is automatically marked as resolved at the next scan.

---

### Proaction Required

The **Proaction Required** panel appears at the top of the Dashboard tab when VibOps detects infrastructure issues that need attention. Unlike anomaly detection (which monitors GPU metrics), the proactive engine runs 7 event-driven checks every 5 minutes across anomalies, budgets, jobs, deployments, GPU health, and cost optimization.

#### Insight types

| Type | What it detects |
|------|----------------|
| `stale_anomaly` | Open anomalies unresolved for more than 1 hour |
| `gpu_health_warning` | GPU temperature or utilization health warnings |
| `budget_warning` | Budget > 90% consumed, with exhaustion date forecast |
| `job_failure_pattern` | 3+ failures on the same action within 30 minutes |
| `deployment_health` | Pods restarting 3+ times in 1 hour |
| `capacity_forecast` | GPU utilization projected to hit 90% within 14 days |
| `cost_optimization` | Clusters averaging < 30% utilization over 24 hours, with waste estimate |

#### Click-to-chat recommendations

Each insight includes a contextual recommendation with real data (daily burn rate, cluster names, error messages, waste estimates). Click the recommendation text to inject it directly into the agent chat — the agent will act on it immediately.

#### Toast notifications

Critical insights trigger a toast notification in the bottom-right corner. Notifications poll every 60 seconds.

#### Auto-acknowledge

When the agent resolves the underlying issue (e.g. resolves a stale anomaly, scales a deployment, adjusts a budget), the corresponding insight is automatically marked as acknowledged. No manual dismissal is required.

#### Deduplication

Insights are deduplicated within a 1-hour window — the same check will not produce a duplicate insight if one already exists for the same resource.

---

### Live Workload Cost Attribution

The **Live Cost** panel in the FinOps → Workloads tab shows real-time cost attribution for every currently running workload.

**Formula:**

```
estimated_cost_usd = elapsed_hours × gpu_count × rate_per_gpu_hour
```

The rate is resolved from the cluster's [ClusterRate](#pricing-and-cluster-rates) configuration (cloud formula or on-prem formula). If no rate is configured, a default of $2.00/GPU/hr is used.

#### Reading the panel

Select a cluster in the Workloads section filter — the Live Cost panel appears above the historical table:

| Column | Description |
|--------|-------------|
| **Workload** | Pod name or Slurm job ID (last 16 characters) |
| **Namespace** | Kubernetes namespace or Slurm partition |
| **GPU** | Number of GPUs allocated |
| **Duration** | Elapsed time since workload started |
| **Estimated cost** | elapsed × GPUs × rate |

Workloads are sorted by cost descending — the most expensive workloads appear first.

The panel also shows:
- **Total estimated cost** across all running workloads on the cluster
- **Running workloads count**

Click **↺** to refresh at any time. Data is computed live — no caching.

#### API

```
GET /api/v1/finops/workloads/live-cost?cluster=<name>
```

Returns `running_workloads`, `total_estimated_cost_usd`, `computed_at`, and a `workloads` array.

---

### Notifications

Configure where VibOps sends its alerts: detected incidents, fired triggers, completed deployments, license expiration.

**Available channels:**

| Channel | What to configure | When to use |
|-------|------------------------|-----------------|
| **Slack Incoming Webhook** | Slack webhook URL (e.g. `https://hooks.slack.com/...`) | Alerts in a Slack channel |
| **HTTP Webhook** | URL + optionally a secret for signing requests | Custom integration (Opsgenie, etc.) |
| **Email (SMTP)** | SMTP server, port, user, password, recipients | Email alerts |
| **PagerDuty** | PagerDuty Integration Key | Incident escalation |
| **Datadog** | Datadog API Key + site (default: `datadoghq.com`) | Events in Datadog Event Stream |

**Create a notification channel:**
1. Admin → **Notifications** sub-tab
2. Click **+ New channel**
3. Choose the type from the dropdown
4. Fill in the fields according to the type (see table below)
5. Click **Create**

**Slack configuration (simplest):**
1. In Slack: go to your workspace → Apps → Incoming Webhooks → Add to Slack
2. Choose the destination channel → click "Add Incoming Webhooks integration"
3. Copy the generated URL (e.g. `https://hooks.slack.com/services/T.../B.../xxx`)
4. In VibOps: paste this URL in the **Webhook URL** field
5. Give the channel a name (e.g. `Slack #alerts-gpu`)

**Email SMTP configuration:**

| Field | Description | Example |
|-------|-------------|---------|
| SMTP server | Mail server hostname | `smtp.gmail.com` |
| SMTP port | Port (587 = TLS, 465 = SSL, 25 = unencrypted) | `587` |
| Username | Email or SMTP login | `alerts@mycompany.com` |
| Password | SMTP password or App Password | `xxxx xxxx xxxx xxxx` |
| Recipients | Addresses separated by comma | `ops@mycompany.com, cto@...` |

> **Gmail**: use an "App Password" (Google account → Security → App passwords), not your regular Google password.

**Datadog configuration:**
1. In Datadog: go to Organization Settings → API Keys → New Key
2. Copy the API key
3. In VibOps: create a channel of type **Datadog**, paste the API key
4. Optionally set the site (`datadoghq.eu` for EU, `us3.datadoghq.com` for US3, etc.)

VibOps events appear in your Datadog Event Stream with `source:vibops` tag.

**Delivery queue & retries:**
All webhook notifications (Slack, HTTP, PagerDuty, Datadog) are queued with automatic retries on failure. If a destination returns a 5xx error or is unreachable, VibOps retries with exponential backoff (30s, 2min, 8min, 30min, 2h — up to 5 attempts). View delivery status in Settings → Notifications → Delivery Log.

**Test a channel:**
After creation, manually trigger a trigger or a Morning Brief to verify the notification arrives.

**Delete a channel:**
Click the trash icon next to the channel. Triggers that use it will no longer be notified.

---

### Integrations

Connect VibOps to your external tools so the agent can use them automatically.

**Available integrations:**

| Integration | What it does | What to provide |
|-------------|---------------|------------------------|
| **Git Provider** (GitHub or GitLab) | Clone repos, push configs, create PRs/MRs, build and push Docker images | Configured in **Admin → Git** sub-tab (dedicated panel — not this Integrations tile) |
| **Prometheus** | Real-time metrics, SLOs, incident correlation | URL (e.g. `http://prometheus:9090`) + credentials if auth is enabled |
| **Grafana** | Receive Grafana/AlertManager alerts in VibOps | The webhook URL to configure in Grafana — VibOps side is automatic |
| **NGC (NVIDIA)** | Deploy NIMs from the NVIDIA catalog | NGC API key (obtained at `ngc.nvidia.com`) |
| **ArgoCD** | GitOps synchronization, application status | ArgoCD URL + admin token |
| **Datadog** | Query metrics, submit custom metrics, push events, receive alerts | `DATADOG_API_KEY` + `DATADOG_APP_KEY` env vars |

**How to configure an integration:**
1. Admin → **Integrations** sub-tab
2. Click on the tile of the desired integration
3. Fill in the fields (they vary by integration)
4. Click **Save**

> **Integrations are stored in the secrets vault**. You will never see the token in plain text after the first entry.

**Verify an integration is working:**
- **Git Provider**: ask the agent to clone a repo: `"Clone the repo github.com/myorg/infra"` (or your GitLab URL). If it works, the token is valid.
- **Prometheus**: the Fleet tab → Grafana sub-tab should display metrics. If you see "Prometheus not detected", the URL is incorrect or unreachable.
- **NGC**: ask the agent: `"List the available models in the NGC catalog"`.

---

### Audit

The audit log is the **complete and immutable** history of everything that happened in VibOps: every job launched, every action denied, every configuration change.

**What it is for:**
- Find out who did what and when (essential after an incident)
- Verify that an action was successfully executed (or understand why it failed)
- SOC2 compliance / security audit

**Log columns:**

| Column | Description |
|---------|-------------|
| **Date** | Precise timestamp of the action |
| **User** | Who triggered the action (`claude-agent` = the AI, `github-webhook` = a GitHub trigger, or your username) |
| **Action** | Technical name of the action (e.g. `scale_cluster`, `deploy_model`) |
| **Parameters** | What was passed to the action (cluster, namespace, number of replicas…) |
| **Status** | `success` (green), `failed` (red), `pending` (grey) |
| **Duration** | Execution time |

**Filter logs:**
- **By action**: type `scale_cluster` to see only scaling actions
- **By status**: filter on `failed` to see only errors
- **By user**: type `claude-agent` to see AI actions, or your username for your own actions

**Typical use cases:**

_"A deployment crashed last night, I want to know what happened"_
→ Filter by status `failed`, look at the **Error detail** column on the corresponding row

_"Someone scaled the prod cluster to 0 replicas, who was it?"_
→ Filter by action `scale_cluster`, look at the **User** column

_"The agent took an action I didn't request"_
→ Filter by user `claude-agent`, check the **Parameters** column to see exactly what it did

> **Pagination**: the `←` and `→` buttons load in batches of 100 entries. The most recent appear first.

---

### Memories

The VibOps agent has **persistent memory** between sessions. Without it, it would start from scratch with each conversation — it would not know that it already diagnosed an incident on prod last week, or that you always want confirmation before scaling.

**Why is the panel empty at first?**
Memories are created over the course of real conversations. On a fresh instance, without chat history, the panel is empty — this is normal. They accumulate naturally as you use the agent.

**How it works in practice:**
1. You ask the agent a question or request an action
2. The agent acts, then at the end of the turn it decides whether something deserves to be memorized
3. If so, it calls `save_memory` — an entry appears in this panel
4. **At the next session**, before even reading your first message, the agent re-reads all saved memories and integrates them into its context — it already "knows" what it learned before

**The 6 memory types and when they are created:**

| Type | Created automatically when… | Example |
|------|-----------------------------|---------|
| `incident` | The agent diagnoses a failure with an identified cause | OOMKill on llama3, fixed on 2026-05-03 |
| `slo` | An SLO is created or modified via the agent | llama3: p99 < 500ms at 99.5% |
| `pipeline` | A multi-step pipeline is interrupted mid-way | deploy-to-prod blocked at step 3 |
| `preference` | You express an explicit preference | "Always ask for confirmation before scaling prod" |
| `fact` | The agent learns a structural fact about your infra | "vibops-dev is a kind cluster without real GPUs" |
| `action` | A recurring operation is defined | "Every Monday, scale down the dev cluster" |

The `incident`, `slo`, and `pipeline` types are saved **automatically**. The `preference`, `fact`, and `action` types generally require you to ask explicitly.

**Force a save manually:**
```
Remember that the prod namespace is frozen until the 25th of the month.
Remember that vibops-dev is our test cluster without GPUs.
Remember that I always want a dry-run before any destructive action.
```

**Agent behavior rules:**
- Maximum 2 memories saved per conversation turn
- Never a duplicate on an existing key (it updates instead)
- Never during an action sequence — only after the final result

**What the agent CANNOT do:**
The agent only has access to memories. It cannot modify users, teams, secrets, notifications, budget, license, or anything else in the Admin. All of that is reserved for `org_admin` users via the interface or API.

**Managing memories from the panel:**
1. Admin → **Memories** sub-tab
2. Filter by type (`fact`, `incident`, `preference`…) via the dropdown
3. **Delete**: click the trash icon — the agent will no longer remember it from the next session
4. **Refresh**: click ↺ to reload the list

**When to delete a memory:**
- The information has become false or outdated (e.g. the namespace freeze is over)
- The agent is drawing incorrect conclusions because of a stale memory
- You want to start fresh on a specific topic

> **Memories are per organization.** All `org_admin` users can view and delete them. Non-admin users do not see this panel.

---

### License

The License tab displays the status of your VibOps subscription and the associated quotas.

**What you see:**

| Information | Description |
|-------------|-------------|
| **Plan** | Trial (14 days) / Starter / Growth / Scale |
| **GPUs under management** | Number of GPUs currently declared vs maximum allowed by your plan |
| **Users** | Active accounts vs maximum |
| **Clusters** | Connected clusters vs maximum |
| **Expiration** | Expiration date or number of days remaining |

**Visual indicators:**

The **trial banner** at the top of the console (visible to admins only) changes color based on urgency:
- ⬜ **Grey**: more than 7 days remaining — nothing to do
- 🟡 **Amber**: 7 days or less — consider renewing
- 🔴 **Red**: expired or quota exceeded — some functions are blocked

**What happens when the license expires?**
- In-progress jobs complete normally
- New jobs are blocked
- The console switches to read-only mode
- The agent can answer questions but can no longer act

**What happens when a quota is exceeded?**
- GPU quota exceeded → new GPU jobs are rejected (existing ones continue)
- User quota exceeded → you can no longer create new accounts
- Cluster quota exceeded → you can no longer connect new clusters

To renew or upgrade to a higher plan: contact **`david@vibops.ai`** or your VibOps sales representative.

---

### Customers (reseller orgs only)

The **Customers** sub-tab is visible only to organizations with a reseller license (Tier 2 or Tier 3). It lets you create and manage sub-organizations (your end customers) and configure per-customer pricing.

**Customer list:** displays all sub-organizations with their usage (GPU-hours, active clusters, spend this month).

**Create a customer:**
1. Admin → **Customers** → **+ New customer**
2. Fill in: organization name, admin email, initial password, GPU quota
3. Click **Create** — a new isolated sub-org is provisioned instantly

**Pricing rules:** configure the rates that drive VM and GPU chargeback for each customer:

| Rule | Description |
|------|-------------|
| **Vendor** | GPU vendor (NVIDIA, AMD) to which this rule applies |
| **Accelerator** | Specific GPU model (e.g. H100, A100) — leave empty for all |
| **Markup %** | Margin added on top of your infrastructure cost |
| **Tier** | `on_demand` / `reserved_1y` / `reserved_3y` |

**Customer pricing overrides:** apply per-customer discounts or custom prices:

- **GPU override**: discount percentage or custom USD/GPU/hour price
- **VM override**: custom rates for vCPU ($/vCPU/hr), RAM ($/GB/hr), disk ($/GB/hr)

Configure in **Admin → Customers → [customer name] → Pricing**.

**White-label config:** set a custom domain and brand name for each customer's console access. See the [White-label console](#white-label-console-for-csp-resellers) section.

---

### Security tab

The **Security** sub-tab (Admin → Security) consolidates enterprise authentication and audit export settings.

#### SSO / OIDC

Configure your organization to authenticate via a corporate identity provider:

| Provider | Notes |
|----------|-------|
| Azure Active Directory | Set tenant ID in the issuer URL |
| Okta | Use your Okta org URL as the issuer |
| Google Workspace | Standard Google OIDC endpoint |
| Custom OIDC | Any compliant provider — supply issuer URL manually |

1. Admin → **Security → SSO**
2. Select provider, paste Client ID and Client Secret
3. Enable **JIT provisioning** to create accounts automatically on first login
4. Toggle **SSO enabled**

Full OIDC flow and API reference: see [SSO / OIDC Integration](#sso--oidc-integration-issue-9).

#### LDAP / Active Directory

Authenticate users against your corporate directory without an external IdP:

1. Admin → **Security → LDAP**
2. Fill in: server URL (`ldaps://`), bind DN, bind password, search base, search filter
3. Toggle **LDAP enabled**

Full LDAP configuration guide: see [LDAP / Active Directory authentication](#ldap--active-directory-authentication).

#### SIEM export

Push audit logs to your SIEM on demand or on a schedule:

| Provider | Config needed |
|----------|---------------|
| Splunk | HEC endpoint URL + HEC token |
| Datadog | Datadog API key + site |

1. Admin → **Security → SIEM**
2. Select provider, fill in endpoint and token
3. Click **Push now** to test, or set a scheduled push interval

Full SIEM setup: see [SIEM push export](#siem-push-export).

---

### LLM Provider (Settings → Operations)

Configure which LLM the VibOps agent uses for all conversations and automated tasks.

**Access:** Settings → **Operations → LLM Provider**

**Supported providers:**

| Provider | Notes |
|----------|-------|
| Claude (Anthropic) | Default — `ANTHROPIC_API_KEY` or custom key |
| OpenAI-compatible | Any vLLM, Groq, Together AI, or custom endpoint |
| Ollama | Local Ollama instance — no API key required |

**Configuration fields:**

| Field | Description |
|-------|-------------|
| **Provider** | Select from dropdown |
| **Model** | Model name (e.g. `claude-opus-4-6`, `llama-3.1-70b-instruct`) |
| **API key** | Stored encrypted in the VibOps Vault |
| **Base URL** | Required for OpenAI-compatible and Ollama providers |

**Workflow:**
1. Fill in the fields
2. Click **Test connection** — sends a short probe request to verify the credentials and model are reachable
3. Click **Save** — the new LLM is active immediately for all new conversations

Changes are recorded in the audit log. The previous LLM is not stored — if the new connection fails, restore the previous values manually.

---

### VMs admin (Settings → Infrastructure)

The **VMs** panel in Settings → Infrastructure shows all hypervisors connected to your VibOps instance.

**Access:** Settings → **Infrastructure → VMs**

**What you see:**

| Column | Description |
|--------|-------------|
| **Hypervisor** | Name and type (Proxmox, vSphere, XCP-ng) |
| **Gateway** | Which VibOps gateway handles this hypervisor connection |
| **Clusters managed** | Number of hypervisor clusters or data centers |
| **Discovered services** | VMs, hosts, and resource pools found at last sync |
| **Status** | Connected / Unreachable / Degraded |

**Connect Hypervisor button:** opens the connection wizard. Select the hypervisor type and fill in the connection details (URL, credentials). Credentials are stored in the VibOps Vault.

**Resync:** click the refresh icon on any hypervisor row to trigger a full rediscovery of VMs and hosts.

---

## 18. Connect Gateway

The Connect Gateway allows connecting remote clusters (on-premise, multi-cloud, isolated environments) to your central VibOps instance, via a secure outbound connection — without opening any inbound port on your infrastructure.

### Architecture

```
VibOps Core (your datacenter)
        ↑  Encrypted WebSocket (TLS)
        │
vibops-worker (in the target cluster)
        │
        ↓  kubectl / Helm / GPU Operator
Remote GPU cluster
```

The worker receives only the necessary instructions, sends back results, and pushes metrics (heartbeat every 60 seconds).

### Connecting a cluster via the console

Two entry points open the gateway wizard:
- **Fleet tab** → **"Add a gateway"** button (opens the wizard directly)
- **⚙ Admin → Gateways** sub-tab → **New Gateway**

Wizard steps:
1. Enter a name for the gateway (e.g. `prod-gpu`, `eu-h100-pool`) and click **Register**
2. Copy the generated token — **shown only once** — and the pre-filled Helm deploy command
3. Run the Helm command on your target cluster (or start the Docker worker with the token)
4. The wizard shows "Waiting for worker to connect…" and advances automatically when the first heartbeat arrives
5. The Fleet tab shows the gateway as **online** and lists its clusters within 30 seconds

The worker auto-discovers all kubeconfig contexts available on the node where it runs and reports them as clusters in every heartbeat. No manual cluster registration is required.

### Connecting a cluster via the script

```bash
./connect-setup.sh --name prod-gpu-1 --cluster kind-vibops-dev --start
```

Options:
- `--name` — gateway name in the console
- `--cluster` — target Kubernetes context name
- `--start` — starts the worker immediately after installation

### Connecting a cluster via Helm (production)

```bash
helm install vibops-worker charts/vibops-connect \
  --namespace vibops-connect \
  --create-namespace \
  --set worker.core.url=https://vibops.yourcompany.com \
  --set worker.core.token=<gateway-token>
```

### Gateway type and Slurm configuration (v0.17.4+)

Each gateway has a **gateway_type** that controls which workload collectors run:

| Gateway type | Collectors active |
|-------------|------------------|
| `kubernetes` | `KubernetesWorkloadCollector` (DCGM/ROCm-SMI via Prometheus) |
| `slurm` | `SlurmWorkloadCollector` (squeue + sacct) |
| `hybrid` | Both collectors run in parallel |

For `slurm` and `hybrid` gateways, the **slurm_config** JSONB block stores the connection parameters (host, ssh_user, ssh_port, rest_url, ssh_key_secret). These fields are exposed in the gateway form (shown conditionally based on the selected gateway_type) and in the API. SSH key secret names are masked in all API responses.

### Gateway status

In Admin → Gateways, each gateway displays:
- **Status** — connected / disconnected / degraded
- **Last heartbeat** — X seconds ago
- **Clusters** — number of clusters exposed
- **GPUs** — total GPUs declared by the worker

A gateway disconnected for more than 5 minutes switches to `degraded` state and generates an alert.

---

## 19. VM Management (Proxmox, vSphere, XCP-ng)

VibOps manages virtual machine infrastructure across the three major hypervisor platforms — alongside Kubernetes and Slurm — giving you a single conversation interface for your entire AI infrastructure.

### Supported hypervisors

| Hypervisor | Lifecycle | Snapshots | Migration | Metrics | Waste detection | Backup compliance |
|------------|-----------|-----------|-----------|---------|-----------------|-------------------|
| Proxmox VE | start, stop, migrate, snapshot, list | ✓ | ✓ | CPU/RAM per VM | ✓ | ✓ |
| VMware vSphere | start, stop, restart, migrate, snapshot, list | ✓ | ✓ | CPU/RAM per VM | ✓ | ✓ |
| XCP-ng (Xen Orchestra) | start, stop, migrate, snapshot, list | ✓ | ✓ | — | ✓ | ✓ |

### Connecting a hypervisor

Hypervisor connections are managed from **Settings → Infrastructure → Connect Hypervisor**. See the [QUICKSTART](../QUICKSTART.md) for the full setup guide. At a minimum you need:

- **Proxmox**: API URL + API token (`user@realm!tokenid=secret`)
- **vSphere**: vCenter URL + username + password
- **XCP-ng**: Xen Orchestra URL + credentials

Credentials are stored in the VibOps Vault and never exposed in chat or logs.

### VM lifecycle operations

```
List all VMs on the Proxmox cluster
Start VM gpu-worker-01 on vsphere-prod
Stop VM test-node-3 on proxmox-lab
Migrate VM llm-runner-02 from host esxi-01 to esxi-02
Take a snapshot of VM api-gateway before the upgrade
```

The agent shows a dry-run preview before any destructive operation (stop, migrate). Confirmation is required.

### VM metrics

Per-VM CPU and RAM metrics are available for Proxmox and vSphere:

```
Show me CPU and memory usage for all VMs on vsphere-prod
Which VM is consuming the most RAM on the Proxmox cluster?
```

### VM waste detection

VibOps identifies three types of VM waste:

| Type | Description |
|------|-------------|
| **Stopped** | VM is powered off but still consuming disk/reservation cost |
| **Low CPU** | VM running but CPU utilization below 5% over 24 hours |
| **Over-provisioned** | VM allocated 4+ vCPUs but averaging under 10% utilization |

```
Scan for wasted VMs on proxmox-lab
Find over-provisioned VMs across all hypervisors
Which stopped VMs have been idle for more than 7 days?
```

### VM backup compliance

VibOps checks snapshot freshness against your backup policy:

| Finding | Condition |
|---------|-----------|
| **No snapshot** | VM has never been snapshotted |
| **Stale snapshot** | Most recent snapshot older than 7 days (configurable) |

```
Check backup compliance for all production VMs on vsphere-prod
```

The agent lists non-compliant VMs and optionally creates snapshots for them immediately.

### GPU passthrough VMs

For VMs with GPU passthrough (common in Proxmox and vSphere deployments), VibOps combines VM cost (vCPU + RAM + disk) with the GPU cost from the underlying host to produce a unified cost view:

```
Show me the total cost of our GPU passthrough VMs including the GPU allocation
```

This is especially useful for teams billing GPU compute to internal teams via VMs rather than Kubernetes pods.

---

## Pipeline templates — deploy from the console

VibOps can manage its own infrastructure. Once a VibOps instance is running, all subsequent deployments and cluster connections can be triggered directly from the operator chat — no local `kubectl` or `helm` required.

### Available templates

```
GET /api/v1/pipelines/templates
```

Returns the full catalogue with parameters, step descriptions, and step count.

| Template | Steps | Purpose |
|----------|-------|---------|
| `deploy_vibops` | 3 | Deploy or upgrade a VibOps instance via Helm |
| `connect_gpu_cluster` | 2 | Deploy the VibOps Connect gateway on a remote GPU cluster |

---

### Template: deploy_vibops

Clones the VibOps repo, runs `helm upgrade --atomic`, then waits for rollout.

**Chat prompt:**
```
Deploy VibOps v0.21.0 on context prod-k8s
```

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `image_tag` | `v0.20.0` | Image tag to deploy |
| `context` | `""` | kubectl context (empty = current context) |
| `release` | `vibops` | Helm release name |
| `namespace` | `vibops` | Target namespace |
| `chart_ref` | `./helm/vibops` | Helm chart path or OCI ref |
| `jwt_secret_key` | `""` | JWT secret (set for initial deploy) |
| `llm_api_key` | `""` | Anthropic API key (set for initial deploy) |
| `values_file` | `""` | Path to extra values file |

**API:**
```bash
curl -X POST https://vibops.yourcompany.com/api/v1/pipelines/from-template/deploy_vibops \
  -H "Authorization: Bearer <jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "image_tag": "v0.21.0",
    "context": "prod-k8s",
    "namespace": "vibops"
  }'
```

**Steps executed:**
1. `git_clone` — clones `https://github.com/davidmacamara-boop/vibops.git` to `/tmp/vibops-deploy`
2. `helm_upgrade` — deploys with `--atomic --wait --timeout 10m`
3. `run_kubectl` — `rollout status deployment -n vibops --timeout=5m` (non-blocking: `on_failure: continue`)

---

### Template: connect_gpu_cluster

Deploys the `vibops-connect` gateway chart on a remote GPU cluster, then verifies the pod is running.

**Chat prompt:**
```
Connect the GPU cluster gpu-prod to this VibOps instance using API key vbops_xyz
```

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `gateway_name` | `gpu-prod` | Gateway display name in Admin → Gateways |
| `vibops_url` | `https://vibops.yourcompany.com` | VibOps public URL |
| `api_key` | `""` | VibOps API key (generate in Admin → API Tokens) |
| `namespace` | `vibops-connect` | Namespace on the GPU cluster |
| `context` | `""` | kubectl context of the GPU cluster |

**API:**
```bash
curl -X POST https://vibops.yourcompany.com/api/v1/pipelines/from-template/connect_gpu_cluster \
  -H "Authorization: Bearer <jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "gateway_name": "gpu-prod",
    "vibops_url": "https://vibops.yourcompany.com",
    "api_key": "vbops_xyz",
    "context": "gpu-cluster-ctx"
  }'
```

**Steps executed:**
1. `helm_upgrade` — deploys `oci://ghcr.io/vibops/charts/vibops-connect` with `--wait --timeout 5m`
2. `run_kubectl` — `get pods -n vibops-connect -l app=vibops-connect` to verify the pod is running

---

### Monitoring pipeline execution

```bash
# Get pipeline status
GET /api/v1/pipelines/{pipeline_id}

# List recent pipelines
GET /api/v1/pipelines?limit=20
```

Each pipeline response includes per-step status (`pending` / `running` / `success` / `failed`), the `job_id` of the spawned job, and any error message.

### Policy and permissions

- Template instantiation requires a `write` role.
- All step actions are validated against the PolicyEngine at creation time — unknown or forbidden actions return `403` with the offending steps listed.
- All executions are recorded in the audit log (`triggered_by: template:deploy_vibops:admin`).

---

## 20. FinOps tab

**What is it for?** The FinOps tab gives you a centralized view of what your GPUs cost, where the money goes, and how to control it. Five sub-tabs: **Waste**, **Budget**, **Chargeback**, **Alerts** (history of overruns), **Workloads** (live per-workload GPU utilisation).

**Who should use it:** admins, infrastructure leads, and anyone who needs to justify GPU costs to a finance director.

---

### Waste sub-tab — GPU waste detection

**What is GPU waste?** A GPU that is running but doing nothing (model loaded in memory but zero requests, pod waiting, job finished but worker not released) consumes energy and money. The Waste sub-tab shows you exactly that.

**How to read the Waste table:**

| Column | Description |
|---------|-------------|
| **Cluster** | Cluster where the idle GPU is detected |
| **GPU / Device** | GPU identifier (e.g. `nvidia.com/gpu` on node `gpu-node-1`) |
| **Utilization %** | Average utilization percentage measured at the last scan |
| **Memory used** | GPU memory occupied (if 0 MB → pod exists but uses nothing) |
| **Score** | Waste score from 0 to 100 — the higher, the more urgent |
| **Est. waste/month** | Estimated waste cost in USD for the full month |
| **Scanned** | How long ago the last measurement was taken |

**Item severity:**
- 🔴 **High** — utilization < 5% or memory occupied but no measured activity
- 🟡 **Medium** — utilization between 5% and 20%
- 🟢 **Low** — utilization between 20% and the configured threshold

**Available actions on each row:**

- **Click the row** → expands the detail by device (GPU ID, node, precise metrics)
- **Diagnose button** → automatically pre-fills the chat with scan data and starts an analysis: the agent tells you why this GPU is idle and what to do. No copy-pasting required.
- **Scale down button** → opens the scaling form directly in the chat to reduce replicas of the offending workload

**Triggering a new scan:**

The Waste scan is not continuous (it requires cluster resources). To launch a fresh analysis:
```
Detect idle GPUs on the prod cluster
```
or via the agent:
```
Analyze GPU waste across all clusters
```

> **The scan takes a few seconds.** After the agent responds, go back to the Waste tab and click ↺ to reload. Fresh data appears with a timestamp of "Scanned < 1 minute ago".

**Typical case: idle GPU overnight**
```
It is 8am, the scan shows 4 GPUs idle since the night:
→ Click Diagnose on the row → the agent confirms they are last night's test pods
→ Click Scale down → scale to 0
→ Budget saved: ~$200/night depending on GPU type
```

---

### Budget sub-tab

**What is a VibOps budget?** It is a monthly GPU spending cap for your organization. VibOps monitors accumulated consumption in real time (calculated from jobs executed this month) and alerts or blocks you when you approach or exceed the limit.

**Understanding the two types of cap:**

| Type | Behavior | When to use |
|------|-------------|-----------------|
| **Alert threshold (soft cap)** | Sends an alert (Slack, email…) but blocks nothing | Notify the team at 80% consumption |
| **Blocking cap (hard cap)** | Blocks creation of new GPU jobs when reached | Never exceed an absolute contractual or budget limit |

> **Tip:** Set the soft cap at 80% and the hard cap at 100% (or 110% if you want a margin). Only activate the hard cap if you have a real financial constraint — it can block production workloads.

**What you see on the Budget tab:**

- **Cap ($)** — configured monthly budget
- **Spent ($)** — current month consumption (calculated from jobs)
- **Burn rate / day** — current spending speed (last 7 days spend / 7)
- **End-of-month forecast** — at this rate, how much you will spend by the 31st. In red if it exceeds the cap.
- **Progress bar** — visual fill with soft cap and hard cap markers

**Create or modify a budget:**
1. FinOps → **Budget** sub-tab
2. If no budget is configured: click **Set budget**
3. If a budget already exists: click **Edit**
4. Fill in:
   - **Limit (USD)** — monthly cap in dollars (e.g. `5000`)
   - **Alert threshold (%)** — percentage at which to send an alert (e.g. `80`)
   - **Hard cap (%)** — percentage at which to block new jobs (e.g. `100`). Leave at 100 by default.
5. Click **Save**

> The budget is calculated on the calendar month (1st to last day of the month). It resets to zero on the 1st of each month.

**Or via the chat:**
```
Set the monthly GPU budget to 5000 dollars with an alert at 80% and a hard cap at 100%
```

**Delete the budget:**
- **Delete** button in the Budget form
- Without a configured budget, no blocking is applied (unlimited spending)

**Budget alerts:** when the soft cap is reached, a notification is sent to the channels configured in Admin → Notifications. Verify you have at least one channel configured to avoid missing the alert.

---

### Chargeback sub-tab

**What is chargeback?** It is the monthly report that details: how much did the GPU infrastructure cost this month, broken down by team, by cluster, and by workload type. Useful for charging GPU costs back to business units or for justifying spending internally.

**How to generate a report:**
1. FinOps → **Chargeback** sub-tab
2. Select the **year** and **month** from the selectors at the top
3. Click **Load** — if a report exists for this period, it is displayed
4. If no report exists → click **Generate** (or **Generate from jobs** to build the report directly from VibOps jobs)
5. The report appears within a few seconds

**Reading the report:**

| Section | Description |
|---------|-------------|
| **Total cost** | Total billed cost (customer price with markup if applicable) |
| **Internal cost** | Actual infrastructure cost (without markup) |
| **GPU hours** | Total GPU hours consumed |
| **Total jobs** | Number of jobs that contributed to the cost |
| **Markup applied** | If you are a reseller, the configured markup |
| **Breakdown by team** | Cost breakdown by team (K8s namespace) |
| **Vendor breakdown** | Distribution by GPU vendor (NVIDIA / AMD / Google TPU / etc.) |

**Export to CSV:**
- **Export CSV** button at the top of the report
- The downloaded file contains all detailed rows: date, action, cluster, namespace, unit cost, total cost

**12-month history:**
- The chart at the bottom of the tab displays your GPU spending evolution over the last 12 months
- Useful for spotting abnormal months and anticipating future budgets

**When "Generate" vs "Generate from jobs"?**
- **Generate** — creates the standard report from recorded cost data. Use this normally.
- **Generate from jobs** — rebuilds the report by re-reading VibOps jobs directly. Use this if the standard report is empty while jobs ran this month.

> A generated report is frozen at the time of generation. If new jobs arrive afterwards, you can regenerate — the report will be overwritten with up-to-date data.

---

### Cloud Pricing sub-tab

**What is it for?** Automatically fetches the real-time GPU instance price from your cloud provider (AWS, Azure, GCP) and stores it as the cluster rate. Eliminates manual rate entry and keeps cost estimates accurate as cloud prices change.

**Supported providers and tiers:**

| Provider | On-demand | Spot | Reserved 1Y | Reserved 3Y |
|----------|-----------|------|-------------|-------------|
| AWS | ✓ (Pricing API) | ✓ (Spot API) | ✓ | ✓ |
| Azure | ✓ (Retail Prices API) | ✓ | ✓ | ✓ |
| GCP | ✓ (static table) | ✓ | ✓ | ✓ |

**Syncing a cluster rate from the agent:**

```
Sync the GPU rate for cluster h100-prod from AWS — p5.48xlarge, us-east-1, on-demand
```

```
What is the current Azure spot price for Standard_ND96isr_H100_v5 in eastus?
```

**Syncing via API:**

```bash
# Preview without saving
GET /api/v1/cloud-pricing/lookup?provider=gcp&instance_type=a3-highgpu-8g&region=us-central1
→ {"rate_per_gpu_hour_usd": 12.29, "source": "static", ...}

# Fetch + save as cluster rate
POST /api/v1/clusters/h100-prod/rate/sync
{"provider": "aws", "instance_type": "p5.48xlarge", "region": "us-east-1", "markup_pct": 20}
```

**Daily auto-refresh:** once a cluster is synced, VibOps re-fetches the price every night at 03:00 UTC automatically. The `rate_per_gpu_hour` in cost estimates and chargeback reports always reflects the current cloud price.

**Pricing tier selection:**

| Tier | When to use |
|------|-------------|
| `on_demand` | Default — pay-as-you-go fleet |
| `spot` | Cost tracking for interruptible GPU nodes |
| `reserved_1y` | Cost model for committed instance purchases |
| `reserved_3y` | Long-term commitment cost model |

**AWS credentials:** the sync endpoint calls the AWS Pricing API via `boto3`. The gateway must have AWS credentials configured (IAM role, instance profile, or `AWS_ACCESS_KEY_ID` env var).

**GCP note:** prices come from a curated static table (updated with each VibOps release). Azure prices are live from the public Microsoft Retail Prices API — no credentials required.

---

### Alerts sub-tab

The history of all budget overruns: when the soft cap or hard cap was reached, what the spend was at that moment, and what the cap was.

**Columns:**

| Column | Description |
|---------|-------------|
| **Type** | `Soft alert` (alert threshold) or `Hard cap` (blocking cap) |
| **Threshold** | The percentage that triggered the alert (e.g. 80%) |
| **Spend at trigger** | Amount spent at the time of triggering |
| **Limit** | Cap configured at the time of triggering |
| **Date** | Date and time of triggering |

> Alerts are listed in reverse chronological order (most recent first). If the list is empty: either no budget is configured, or you have never exceeded the threshold — that is a good thing!

---

### Workloads sub-tab — per-workload GPU metrics

**What is it for?** Shows live GPU utilisation, memory usage, and power draw at the individual workload level — covering both Kubernetes pods (sourced from DCGM Exporter / ROCm-SMI Exporter via Prometheus) and Slurm jobs (tracked via `squeue` + `sacct`). Data is persisted in the `workloads` table and updated every 60 seconds.

**Prerequisites:**
- DCGM Exporter ≥ 3.1.x (NVIDIA) or ROCm-SMI Exporter (AMD) installed in the cluster with Kubernetes pod labels enabled
- Gateway configured with a `prometheus_url` (Admin → Gateways → edit) for Kubernetes workloads
- For Slurm workloads: `gateway_type=slurm` or `hybrid` with `slurm_config` filled in

**How to use:**
1. FinOps → **Workloads** sub-tab
2. Select a cluster from the dropdown — metrics load automatically
3. Workloads are ranked by GPU utilisation (highest first)
4. Workloads with util% < 20 are highlighted in amber — potential waste candidates

**Columns:**

| Column | Description |
|---------|-------------|
| **Workload** | Kubernetes pod name or Slurm job name |
| **Type** | `k8s_pod` (Kubernetes) or `slurm_job` (Slurm HPC) |
| **Namespace** | Kubernetes namespace or Slurm partition |
| **GPU Util %** | Average utilisation across all GPUs assigned to this workload |
| **Memory (MB)** | Total framebuffer memory used across all GPUs |
| **Power (W)** | Total power draw (NVIDIA only — AMD exporters do not expose pod-level power) |

**If Prometheus is not configured:** the tab shows a "Prometheus not configured" message. No error — the gateway and cluster still function normally; metrics are simply unavailable.

**From the agent:**
```
"Which pods are using the most GPU on vibops-dev?"
→ get_top_consuming_pods(cluster="vibops-dev", limit=10)

"Show me GPU metrics for pod llm-inference-7b in the prod namespace"
→ get_pod_gpu_metrics(cluster="vibops-dev", namespace="prod", pod_name="llm-inference-7b")

"Summarize GPU utilisation across the ml-team namespace"
→ get_namespace_gpu_aggregated(cluster="vibops-dev", namespace="ml-team")
```

---

### VM Chargeback

VM chargeback extends GPU chargeback to cover the full VM infrastructure cost.

**Cost formula:**

```
VM cost = (vCPU × vcpu_rate + RAM_GB × ram_rate + disk_GB × disk_rate) × hours
```

**Default rates** (configurable per cluster or per customer):

| Resource | Default rate |
|----------|-------------|
| vCPU | $0.04 / vCPU / hour |
| RAM | $0.005 / GB / hour |
| Disk | $0.0001 / GB / hour |

For GPU passthrough VMs, the GPU cost (from the cluster GPU rate) is added on top of the VM resource cost.

**Generate a VM chargeback report:**
```
Generate the VM chargeback report for October 2026
Show me VM costs broken down by team on vsphere-prod
```

Via API: `POST /api/v1/finops/chargeback/{year}/{month}/generate?include_vms=true`

**VM pricing overrides** — resellers can set per-customer rates that override the defaults. Configure in **Admin → Customers → Pricing rules**.

---

### VM Waste Detection (FinOps)

The FinOps waste view includes VM waste alongside GPU waste. Three types are detected (same as in §19):

| Type | Agent prompt |
|------|-------------|
| Stopped VMs | `Find all stopped VMs that are still incurring cost` |
| Low CPU VMs | `List VMs with CPU utilization under 5% on proxmox-lab` |
| Over-provisioned | `Which VMs are over-provisioned across all hypervisors?` |

The waste estimate includes disk reservation cost for stopped VMs and wasted vCPU allocation for low-utilization VMs.

---

### Scheduled Triggers

Triggers in VibOps support **cron expressions** — allowing waste scans, compliance checks, and any agent action to run automatically on a schedule.

**Cron format:** standard 5-field cron (`minute hour day month weekday`).

| Expression | Meaning |
|------------|---------|
| `0 8 * * 1` | Every Monday at 8:00 AM |
| `0 0 1 * *` | First day of each month at midnight |
| `0 */6 * * *` | Every 6 hours |

**Example — weekly VM waste report every Monday at 8am:**
```
Set up a trigger: every Monday at 8am, scan for wasted VMs on all hypervisors
and send the report to Slack
```

This creates a trigger with cron `0 8 * * 1`, action `vm_waste_scan`, and your configured Slack channel as the notification target.

**Example — nightly backup compliance check:**
```
Run a backup compliance check every night at midnight and alert on Slack
if any VMs have stale snapshots
```

Scheduled triggers are visible and editable in **Automations → Triggers**.

---

## 21. LLM Inference Proxy — Agent Infrastructure Control Plane

VibOps includes a transparent OpenAI-compatible proxy (port 8004) that sits between AI agents and LLM inference servers. It captures every inference with per-agent attribution for FinOps, budget enforcement, model policy, and anomaly detection.

### How it works

```
AI Agents (n8n, LangChain, CrewAI, Dify, or any OpenAI-compatible client)
        ↓ POST /v1/chat/completions
        ↓ Headers: X-VibOps-Agent-Id + X-VibOps-Team
VibOps LLM Proxy (:8004)
    1. Identify agent (cached 60s)
    2. Check budget (cached 10s) → 429 if exceeded
    3. Check model policy (cached 60s) → 403 if denied
    4. Route to backend by model prefix
    5. Forward request (streaming supported)
    6. Measure tokens + latency
    7. Calculate cost (token rate or GPU time)
    8. Log async (batch every 5s)
        ↓
LLM Backends (vLLM, Ollama, TGI)
```

### Configuration

Set backend routing in `.env`:

```bash
BACKENDS='{"mistral": "http://vllm-mistral:8000", "llama": "http://vllm-llama:8001"}'
DEFAULT_BACKEND_URL=http://ollama:11434
```

### Agent attribution

Your agents add two headers:

| Header | Purpose | Example |
|--------|---------|---------|
| `X-VibOps-Agent-Id` | Unique agent identifier | `pricing-agent-v2` |
| `X-VibOps-Team` | Team or cost centre | `supply-chain` |

### FinOps per agent

Visible in the console under **FinOps → Agent LLM Usage**:

| Agent | Model | Requests | Tokens | GPU-hrs | Cost |
|-------|-------|----------|--------|---------|------|
| pricing-v2 | llama-70b | 5,000 | 18.2M | 210h | $6,300 |
| supply-chain | mistral-7b | 8,100 | 11.4M | 89h | $2,670 |

Or via the agent chat:

```
"Which agent costs the most this month?"
"Show me the cost breakdown for pricing-agent-v2"
```

### Budget per agent

Set monthly spend limits. When the hard cap is reached, the proxy returns 429.

```
"Set a $500/month budget on pricing-agent-v2"
```

API: `POST /api/v1/finops/agent-budgets`
MCP: `set_agent_budget("pricing-agent-v2", 500)`

### Model policy per agent

Control which models each agent can use. Glob patterns supported.

```
"Allow pricing agents only on Mistral models"
```

API: `POST /api/v1/policy/agent-model-rules`
MCP: `update_agent_model_rule("pricing-*", allowed_models=["mistral-*"])`

If an agent tries to use a denied model, the proxy returns 403.

### Anomaly detection per agent

Celery Beat scans `inference_logs` every 10 minutes for three anomaly classes:

| Anomaly | Trigger | Severity |
|---------|---------|----------|
| `agent_cost_spike` | Cost in last hour > 3x 7-day average | Warning |
| `agent_request_surge` | Requests in last hour > 5x 7-day average | Warning |
| `agent_error_spike` | Error rate > 20% in last hour | Warning / Critical |

Anomalies appear in the console under **Fleet → Anomalies** (filter: `llm-proxy`).

### Verify

```bash
# Health check
curl http://SERVER_IP:8004/health

# List available models across all backends
curl http://SERVER_IP:8004/v1/models
```

### MCP tools

| Tool | Description |
|------|-------------|
| `get_agent_usage` | Per-agent inference cost, tokens, requests |
| `get_agent_usage_detail` | Daily breakdown for one agent |
| `get_agent_budget` | Current budget + spend for an agent |
| `set_agent_budget` | Set monthly spend limit |
| `get_agent_model_rules` | List model access rules |
| `update_agent_model_rule` | Create model access rule |

---

## 22. Dataset & RLHF

VibOps builds an operational dataset from real production actions — the foundation for fine-tuning specialized GPU models.

### Collected signals

| Signal | Source |
|--------|--------|
| WorkloadSignature (vendor, accelerator, framework) | Job submission |
| Job results (success/oom/timeout/failure) | Worker end-of-execution |
| Recommendation events (followed/ignored/overridden) | Operator response |
| Automatic framework detection from image | WorkloadDetector |
| Agent feedback (👍 / 👎 per response) | Chat interface |

### Consent model

Configurable per organization (Admin → Organization → Dataset consent):

| Mode | Behavior |
|------|--------------|
| `pseudonymized` | Stable hashed identifiers — cross-job correlation preserved |
| `anonymized` | Identifiers removed — full anonymity |
| `opted_out` | Excluded from all exports |

### Export the dataset

```bash
# Jobs (JSONL)
GET /api/v1/dataset/export

# Agent exchanges + feedback (alpaca / sharegpt / chatml formats)
GET /api/v1/training/export?format=alpaca
```

---

## 23. MCP Server

VibOps exposes its tools via the **Model Context Protocol** (MCP) — allowing any MCP client (Claude Desktop, Cursor, IDE) to operate GPU infrastructure directly from its own context.

### Connection

```json
{
  "mcpServers": {
    "vibops": {
      "command": "npx",
      "args": ["-y", "vibops-mcp"],
      "env": {
        "VIBOPS_API_URL": "https://vibops.yourcompany.com",
        "VIBOPS_API_TOKEN": "vbops_xxxxxxxx"
      }
    }
  }
}
```

### What you can do via MCP

The same tools as the VibOps agent are available: model deployment, scaling, incident diagnosis, GitOps, FinOps. The difference: you use them from your own LLM or IDE, without going through the VibOps console.

```
"Scale llama3 to 3 replicas in prod"     → patch_deployment
"Show idle GPUs on the GPU cluster"      → accelerator_detect_waste
"Deploy NIM for mistral-7b"              → nim_deploy (with guardrails)
```

The same guardrails apply: PolicyEngine, dry-run preview, confirmation required for destructive actions.

See the [`vibops-mcp`](https://github.com/VibOpsai/vibops-mcp) repository for the full installation guide.

---

## 24. Python SDK

The VibOps Python SDK provides typed sync and async access to all VibOps APIs — suitable for scripts, CI pipelines, and data pipelines.

### Installation

```bash
pip install vibops
```

### Quick start — synchronous

```python
from vibops import VibOpsClient

client = VibOpsClient(
    base_url="https://vibops.yourcompany.com",
    api_key="vbops_xxxxxxxx"
)

clusters = client.clusters.list()
for c in clusters:
    print(c.name, c.gpu_total)
```

### Quick start — async

```python
import asyncio
from vibops import AsyncVibOpsClient

async def main():
    async with AsyncVibOpsClient(
        base_url="https://vibops.yourcompany.com",
        api_key="vbops_xxxxxxxx"
    ) as client:
        waste = await client.finops.get_waste_analysis(cluster="gpu-prod")
        print(waste)

asyncio.run(main())
```

### Resource namespaces (27 total)

The client exposes 27 resource namespaces covering clusters, deployments, GPU metrics, jobs, pipelines, finops, compliance, audit, agents, secrets, policies, VMs, and more. See the full list at [github.com/VibOpsai/vibops-sdk](https://github.com/VibOpsai/vibops-sdk).

---

## 25. Cloud Provider Connectors

VibOps includes connectors for sovereign and hyperscale cloud providers, enabling full lifecycle management from the agent.

### Supported providers

| Provider | Tools | Notes |
|----------|-------|-------|
| Scaleway | 15 | Instances, GPU instances, Kubernetes Kapsule, Object Storage |
| Outscale | 15 | VMs, snapshots, security groups, load balancers |
| DGX Cloud | 16 | NVIDIA DGX SuperPOD clusters, GPU reservations, job submission |
| HPE PCAI | 17 | HPE Private Cloud AI — clusters, workloads, model catalog |
| AWS EKS | 6 | Cluster discovery, node groups, scaling, kubeconfig generation |
| GKE | 3 | Cluster discovery, node pool scaling, workload identity |
| AKS | 3 | Cluster discovery, node pool scaling, managed identity |

### Example prompts

```
List all GPU instances on our Scaleway account
Scale the DGX Cloud reservation from 4 to 8 H100s
What is the current node count on our EKS cluster in us-east-1?
Show me the workloads running on HPE PCAI
Deploy a GKE node pool with 4 L4 GPUs in europe-west4
```

Credentials for each provider are stored in the VibOps Vault. Configure them in **Admin → Integrations** or via `POST /api/v1/secrets`.

---

## 26. Terraform Integration

VibOps can run Terraform operations directly from the agent — enabling infrastructure-as-code management without leaving the conversation.

### Supported actions

| Action | Description |
|--------|-------------|
| `terraform_init` | Initialize a Terraform working directory |
| `terraform_plan` | Generate and display an execution plan |
| `terraform_apply` | Apply the plan (requires confirmation) |
| `terraform_destroy` | Destroy managed infrastructure (requires confirmation) |
| `terraform_output` | Read output values from state |
| `terraform_state` | Inspect or manipulate the Terraform state |

### Example

```
Clone the infra repo, run terraform plan on the gpu-cluster module,
show me what would change, then apply if it looks correct.
```

The agent chains `git_clone` → `terraform_init` → `terraform_plan`, shows the diff, and waits for confirmation before `terraform_apply`. Destructive operations always require explicit confirmation.

Store Terraform backend credentials (AWS keys, GCP SA JSON, etc.) in the VibOps Vault and reference them via `@secret:` in your prompt.

---

## 27. Docker Build & CI Integration

VibOps provides a full set of container build and CI pipeline actions, enabling end-to-end automation from code to deployment.

### Build actions

| Action | Description |
|--------|-------------|
| `docker_build` | Build a Docker image from a local or cloned repo |
| `docker_tag` | Tag an image with a new name or version |
| `docker_push` | Push an image to a container registry |
| `docker_build_push` | Build and push in a single step (most common) |

### CI actions

| Action | Description |
|--------|-------------|
| `ci_trigger` | Trigger a GitHub Actions workflow or GitLab CI pipeline |
| `ci_status` | Check the current status of a pipeline run |
| `ci_wait` | Block until a pipeline completes (success or failure) |

### Full pipeline example

```
Deploy the latest commit of acme/api-server to staging:
1. Clone the repo
2. Build and push the image to ghcr.io/acme/api-server:latest using token=@secret:ghcr_token
3. Trigger the integration-tests workflow on main
4. Wait for the tests to pass
5. Helm upgrade the staging release with the new image
```

The agent chains `git_clone` → `docker_build_push` → `ci_trigger` → `ci_wait` → `helm_upgrade`, aborting at any step on failure and reporting the exact error. The Helm upgrade requires confirmation before executing.

---

## 28. Quick reference

### Keyboard shortcuts

| Shortcut | Action |
|-----------|--------|
| `⌘K` / `Ctrl+K` | Focus the chat input field |
| `Enter` | Send message |
| `Shift+Enter` | New line in message |
| `Escape` | Close the open modal |

### Language selector

Click the language selector (top right of the navigation bar) to change the interface language and agent response language.

Available languages: Français, English, Español, Deutsch, Italiano, Português, 日本語, 中文

The preference is saved locally and applied to both interface labels and agent responses.

### Personas and typical use cases

| Persona | Typical questions |
|---------|-------------------|
| **SRE / On-call** | Incident diagnosis, emergency rollback, last-hours audit, auto-healing |
| **MLOps engineer** | Inference fleet status, staging→prod promotion, benchmarking, capacity planning |
| **DevOps / Platform** | Deploying new services, creating environments, configuring clusters |
| **Engineering manager** | Audit trail, SLO compliance, GPU cost report, overall health status |
| **FinOps** | GPU cost report, idle GPU detection, rightsizing |

### Common error messages

| Message | Cause | Action |
|---------|-------|--------|
| `Cluster unreachable` | The kubeconfig context is no longer valid | Reconnect the gateway or update the kubeconfig |
| `Confirmation required` | Action blocked by production guardrails | Reply "yes" to confirm or "cancel" |
| `GPU limit exceeded` | License GPU quota reached | Contact david@vibops.ai to upgrade |
| `User limit reached` | Maximum number of users reached for your plan | Upgrade the plan or delete inactive accounts |
| `Licence expired` | License expired | Contact david@vibops.ai |
| `No Prometheus configured` | Metrics not available | See Admin → Integrations → Prometheus |

---

## Sprint 5 — Compliance, SSO, Agent Identity, Dependency Graph

### Agent Identity Lifecycle

Machine identities for automated agents, CI/CD pipelines, and service accounts — no shared passwords, no personal API tokens in CI.

#### Creating an identity

Navigate to **Admin → Agent Identities** and click **Create identity**. Enter a name (e.g. `GitHub Actions — prod`). The raw API key is shown **once** — copy it immediately.

```
POST /api/v1/agent-identities
{
  "name": "GitHub Actions — prod",
  "description": "Deploys inference services from CI"
}
```

Response includes `key` (raw value, shown once), `key_prefix` (e.g. `vib_k3f9a2…`), and `id`.

#### Rotating a key

Key rotation generates a new raw key and invalidates the old one. The previous key stops working immediately.

```
POST /api/v1/agent-identities/{id}/rotate
```

The response includes the new `key`. Update your CI secrets before confirming the rotation.

#### Revoking an identity

Revocation permanently invalidates the key. The identity record is preserved for audit purposes.

```
POST /api/v1/agent-identities/{id}/revoke
```

A revoked identity cannot be rotated — create a new one if needed.

#### Listing identities

```
GET /api/v1/agent-identities
```

Returns `items` (list) and `total`. Each item shows `key_prefix`, `is_revoked`, `created_at`, `rotated_at`, `last_used_at`.

---

### Compliance Reports (SOC 2 · GDPR · HIPAA)

VibOps generates evidence packages by analyzing your audit log for the requested reporting period. Reports are generated asynchronously — status goes from `pending` to `ready` (or `failed`) in the background.

#### Generating a report

Navigate to **Admin → Compliance → Reports** and click **Generate report**, or via API:

```
POST /api/v1/compliance/reports
{
  "report_type": "soc2",
  "period": "2026-Q1"
}
```

Supported `report_type` values: `soc2`, `gdpr`, `hipaa`.

Supported `period` formats:
- `2026-Q1` — quarter
- `2026-05` — month
- `2026` — full year

#### Reading a report

```
GET /api/v1/compliance/reports/{id}
```

The `summary` field contains findings organized by standard:

**SOC 2** — CC6 (audit trail completeness), CC7 (monitoring), CC8 (change management). Each control is `compliant`, `partial`, or lists specific findings with severity.

**GDPR** — Art17 (right to erasure), data minimization, access control. Partial findings flag areas requiring additional controls outside VibOps.

**HIPAA** — Audit controls, access control, transmission security safeguards.

#### Listing reports

```
GET /api/v1/compliance/reports?report_type=soc2
```

---

### EU AI Act Controls (Issue #7)

VibOps maps its operational controls to the EU AI Act articles most relevant to GPU infrastructure operators. This is relevant for organizations whose VibOps-orchestrated workloads power high-risk AI systems.

#### Seeding controls

Initialize the 6 default articles for your organization (idempotent — safe to call multiple times):

```
POST /api/v1/compliance/ai-act/seed
```

Creates controls for: **Art9** (risk management), **Art12** (record-keeping), **Art13** (transparency), **Art14** (human oversight), **Art15** (accuracy & cybersecurity), **Art17** (quality management).

#### Compliance score

```
GET /api/v1/compliance/ai-act/score
```

Returns:
- `score` — weighted percentage (compliant=1.0, partial=0.5, non_compliant=0.0, not_applicable excluded)
- `breakdown` — count per status
- `applicable` — controls counted in the score

#### Updating a control

```
PATCH /api/v1/compliance/ai-act/{id}
{
  "status": "compliant",
  "notes": "VibOps audit log chain satisfies Art12 requirements.",
  "evidence_url": "https://docs.vibops.ai/compliance/art12"
}
```

Valid `status` values: `compliant`, `partial`, `non_compliant`, `not_applicable`.

The console **Compliance → AI Act** tab shows all controls as cards with inline status dropdowns and notes fields.

**VibOps built-in controls:**

| Article | What VibOps covers |
|---------|-------------------|
| Art9 | Risk management — PolicyEngine default-deny, approval gates |
| Art12 | Record-keeping — tamper-evident HMAC audit log chain |
| Art13 | Transparency — every agent action is explainable and auditable |
| Art14 | Human oversight — confirmation required for destructive actions |
| Art15 | Robustness — dry-run preview, rollback on failure in pipelines |
| Art17 | Quality management — CI test suite, migrations, semantic versioning |

---

### SSO / OIDC Integration (Issue #9)

Org admins can configure an OIDC identity provider so users log in via their corporate SSO instead of (or in addition to) local passwords. Supports Azure AD, Okta, Google Workspace, and any compliant custom OIDC provider.

#### Configuring SSO

Navigate to **Admin → Security → SSO** and fill in the provider details, or via API:

```
PUT /api/v1/sso/config
{
  "oidc_provider": "okta",
  "oidc_issuer_url": "https://acme.okta.com",
  "oidc_client_id": "0oa1b2c3d4e5f6g7h8i9",
  "oidc_client_secret": "<secret>",
  "oidc_jit_provisioning": true,
  "oidc_default_role": "member"
}
```

The client secret is stored encrypted (Fernet / `VAULT_KEY`). The API only exposes whether a secret is set (`oidc_client_secret_set: true`) — it never returns the raw value.

#### Enabling SSO

Set all three required fields (`oidc_issuer_url`, `oidc_client_id`, `oidc_client_secret`) before enabling:

```
PUT /api/v1/sso/config
{ "oidc_enabled": true }
```

Enabling SSO without the required fields returns HTTP 422.

#### Supported providers

| Provider | `oidc_provider` | Notes |
|----------|----------------|-------|
| Azure Active Directory | `azure_ad` | Tenant-aware — include tenant ID in `oidc_issuer_url` |
| Okta | `okta` | Org URL as issuer |
| Google Workspace | `google` | Standard Google OIDC |
| Any OIDC-compliant IdP | `custom` | Provide full authorization and token endpoints in `oidc_issuer_url` |

#### JIT user provisioning

With `oidc_jit_provisioning: true` (default), users are created automatically on first SSO login with `oidc_default_role`. Set to `false` to require pre-created user accounts.

#### OIDC flow

1. User navigates to the console login page and clicks **Continue with SSO**
2. VibOps redirects to `GET /api/v1/sso/oidc/login?org_slug=<slug>`
3. Browser is redirected to the IdP authorization endpoint
4. IdP redirects back to `GET /api/v1/sso/oidc/callback?code=…&state=…`
5. VibOps exchanges the code for tokens, extracts email/name, JIT-provisions if needed, and returns a VibOps JWT

#### Disabling SSO

```
DELETE /api/v1/sso/config
```

Clears all OIDC configuration and disables SSO. Existing users are unaffected.

---

### Agent Dependency Graph (Issue #11)

VibOps tracks which agents call which LLM models, connectors, and sub-agents — forming a directed dependency graph per organization. This is useful for impact analysis (e.g. "if I change the model, which agents are affected?") and for understanding system architecture.

#### Recording a dependency

The agent loop records edges automatically. You can also record manually:

```
POST /api/v1/agents/dependencies
{
  "from_agent_id": "orchestrator-v2",
  "from_agent_name": "VibOps Orchestrator",
  "edge_type": "uses_model",
  "to_node_id": "claude-opus-4-6",
  "to_node_name": "Claude Opus 4.6",
  "to_node_type": "model"
}
```

`edge_type` values: `uses_model`, `uses_connector`, `calls_agent`

`to_node_type` values: `model`, `connector`, `agent`

Posting the same edge again increments `call_count` rather than creating a duplicate.

#### Full org graph

```
GET /api/v1/agents/graph
```

Returns `nodes` (deduplicated, with `id`, `name`, `type`) and `edges` (with `call_count`, `first_seen_at`, `last_seen_at`).

#### Agent-level view

```
GET /api/v1/agents/{agent_id}/dependencies
```

Returns all outbound edges from a specific agent, grouped by `edge_type`.

#### Removing a stale edge

```
DELETE /api/v1/agents/dependencies/{edge_id}
```

The console **Admin → Agent Graph** panel renders the graph as a table of edges, sortable by call count and last seen timestamp.

---

### Signed billing export — verifiable billing for BYOC enterprise (Issue #12)

Enterprise accounts running VibOps in a BYOC (Bring Your Own Cloud) context can export a cryptographically signed billing record for any closed month. The signature makes the document tamper-evident: any modification to any field — including rounding — invalidates it.

#### Exporting a signed bill

```
GET /api/v1/finops/billing/export?month=2026-05
```

**Prerequisites:** a chargeback report must exist for the period. Generate one first if needed:

```
POST /api/v1/finops/chargeback/2026/5/generate
```

#### Response structure

```json
{
  "report": {
    "org_id": "...",
    "period_year": 2026,
    "period_month": 5,
    "gpu_hours_total": 320.5,
    "customer_cost_usd": 801.25,
    "currency": "USD",
    "signed_at": "2026-06-01T00:00:00+00:00",
    ...
  },
  "export_meta": {
    "signed_at": "2026-06-01T00:00:00+00:00",
    "algorithm": "HMAC-SHA256",
    "signature": "a3f2b1..."
  }
}
```

The `signed_at` timestamp is embedded inside `report` so it is part of the signed data — you cannot change the timestamp without invalidating the signature.

#### Verifying the signature (no VibOps SDK required)

```python
import hmac, hashlib, json

def verify_billing_export(export: dict, secret_key: str) -> bool:
    payload = export["report"]
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    expected = hmac.new(
        secret_key.encode(),
        canonical.encode(),
        hashlib.sha256,
    ).hexdigest()
    return hmac.compare_digest(expected, export["export_meta"]["signature"])
```

The `secret_key` is your instance's `SECRET_KEY` environment variable. For multi-tenant setups, VibOps can provide a per-org sub-key on request.

---

### Huawei Ascend NPU support

VibOps supports Huawei Ascend NPU clusters (Ascend 910B, 910A, 310P) managed via the Ascend Device Plugin for Kubernetes. This enables sovereign European defense deployments and Asia-Pacific deployments seeking NVIDIA-independence.

#### Prerequisites

- Ascend Device Plugin installed in the cluster (`ascend-device-plugin` namespace)
- `npu-smi` available on NPU nodes (bundled with Ascend driver, CANN 7.x+)
- Kubernetes resource `huawei.com/Ascend910` visible in node allocatable

#### Ascend-specific tools

| Tool | Description |
|------|-------------|
| `ascend_list_devices` | List Ascend NPU nodes from Kubernetes labels (`huawei.com/Ascend910`, `310P`). Returns model, HBM capacity, CANN version, vNPU support. |
| `ascend_get_metrics` | Real-time metrics via npu-smi: Aicore utilization, HBM memory, temperature, power draw. Simulated fallback for demo clusters without npu-smi. |
| `ascend_partition_device` | Enable/disable vNPU partitioning. Modes: `full` (1 vNPU), `half` (2), `quarter` (4, 910B only). Requires confirmation. |

All generic `accelerator_*` tools also work on Ascend clusters (`accelerator_diagnose`, `accelerator_get_metrics`, `accelerator_workload_match`, etc.).

#### vNPU partitioning — important semantics

Ascend vNPU partitioning **is not equivalent to NVIDIA MIG or AMD CPX**. Isolation is enforced at the VNPU scheduler level, not hardware-enforced memory partitioning. Do not cross-map Ascend vNPU slice counts to NVIDIA MIG profile names — the isolation model and scheduling behaviour are distinct.

```
# Enable quarter mode (4 vNPU slices per 910B) on all Ascend nodes
ascend_partition_device  action=enable  profile=quarter

# Disable partitioning (reset to full physical NPU)
ascend_partition_device  action=disable
```

#### Example conversation

```
You: List the Ascend NPUs available in the cluster
VibOps: [calls ascend_list_devices]
         ascend-node-uk-01 : Ascend910B (64GB HBM) ×6 CANN=7.0.RC1
         ascend-node-uk-02 : Ascend910B (64GB HBM) ×6 CANN=7.0.RC1

You: What's the current HBM utilization?
VibOps: [calls ascend_get_metrics]
         NPU 0 [Ascend910B]  Aicore: 58%  HBM: 12GB/64GB (18%)  Temp: 52°C  Power: 310W
         NPU 1 [Ascend910B]  Aicore: 61%  HBM: 16GB/64GB (25%)  Temp: 54°C  Power: 325W
```

---

### White-label console for CSP resellers

VibOps supports custom domain deployments for CSP resellers. When clients access the console via a CSP-specific domain (e.g. `gpu.acme-cloud.com`), the console automatically displays the CSP brand name and contact information instead of "VibOps".

#### Setting up a white-label domain (reseller admin)

```
PUT /api/v1/resellers/me
{
  "white_label_domain": "gpu.acme-cloud.com",
  "white_label_name": "Acme GPU Console",
  "white_label_contact_email": "support@acme.com"
}
```

Then point your DNS `A` or `CNAME` record for `gpu.acme-cloud.com` to your VibOps instance IP. TLS is handled by your reverse proxy (Caddy, nginx, Cloudflare).

#### What changes for end users

- Browser tab shows `Acme GPU Console` instead of `VibOps Console`
- Console header logo shows `Acme GPU Console`
- Licence hint strings show `support@acme.com` instead of `david@vibops.ai`

#### How it works

The console calls `GET /api/v1/branding` (public, no JWT) on startup. VibOps reads the `Host` header, looks up the matching `white_label_domain`, and returns the brand configuration. If no match is found, VibOps defaults are returned — the same VibOps instance serves multiple CSP brands via a single public endpoint.

#### Multiple CSP tenants on one instance

Each reseller org can have its own `white_label_domain`. A single VibOps instance handles all of them:

| Host header | Brand returned |
|-------------|----------------|
| `gpu.acme-cloud.com` | Acme GPU Console |
| `ai.beta-cloud.io` | Beta AI Platform |
| `vibops.ai` | VibOps (default) |

---

---

---

## Sprint 6 — LDAP Auth, SIEM Push, Registry Connector

### LDAP / Active Directory authentication

Org admins can configure LDAP so enterprise users log in with their Active Directory or OpenLDAP credentials — no external IdP required.

#### Configuring LDAP (Admin → Security)

Navigate to **Admin → 🔐 Security** and fill in the LDAP form, or via API:

```
PUT /api/v1/ldap/config
{
  "ldap_server_url":    "ldaps://ldap.acme.com:636",
  "ldap_bind_dn":       "cn=vibops-svc,ou=svc,dc=acme,dc=com",
  "ldap_bind_password": "<service-account-password>",
  "ldap_search_base":   "ou=users,dc=acme,dc=com",
  "ldap_search_filter": "(uid={username})",
  "ldap_jit_provisioning": true,
  "ldap_default_role":  "member"
}
```

The bind password is stored encrypted (Fernet / `VAULT_KEY`). The API never returns the raw value — only `ldap_bind_password_set: true`.

#### Enabling LDAP

Set all four required fields (`ldap_server_url`, `ldap_bind_dn`, `ldap_bind_password`, `ldap_search_base`) before enabling:

```
PUT /api/v1/ldap/config
{ "ldap_enabled": true }
```

Enabling without the required fields returns HTTP 422.

#### Search filter

`{username}` is replaced with the login input at authentication time.

| Directory | Recommended filter |
|-----------|-------------------|
| OpenLDAP | `(uid={username})` |
| Active Directory | `(sAMAccountName={username})` |
| Azure AD on-premise | `(userPrincipalName={username}@acme.com)` |

#### Auth flow

1. User clicks **🏢 Login with LDAP / Active Directory** on the login page
2. Enters org slug, username, and password
3. VibOps binds to the LDAP server with the service account (connectivity check)
4. Searches for the user entry using the configured filter
5. Re-binds as the user's DN with the provided password (credential verification)
6. JIT-provisions the user if needed (same mechanism as OIDC)
7. Issues a VibOps JWT — user lands in the console

#### JIT provisioning

With `ldap_jit_provisioning: true` (default), users are created automatically on first LDAP login. Set to `false` to require pre-created user accounts.

JIT-provisioned LDAP users cannot log in via password — their account is LDAP-only (`password_hash = "sso:<random>"`).

#### TLS

- `ldaps://` — full TLS from connection start (port 636, recommended)
- `ldap://` — STARTTLS negotiated automatically before the bind (port 389)

#### Disabling LDAP

```
DELETE /api/v1/ldap/config
```

Clears all LDAP configuration. Existing JIT-provisioned users are unaffected.

---

### SIEM push export

VibOps supports both **pull** (existing) and **push** (new) delivery of audit logs to your SIEM.

#### Pull export (existing)

Available to org admins via `GET /api/v1/audit/export`:

```bash
# JSON with HMAC-signed manifest
GET /api/v1/audit/export?format=json&since=2026-01-01T00:00:00Z

# CEF for Splunk / ArcSight
GET /api/v1/audit/export?format=cef

# LEEF for IBM QRadar
GET /api/v1/audit/export?format=leef
```

#### Push export — Splunk HEC

Configure your Splunk HEC destination once:

```
PUT /api/v1/audit/siem/config
{
  "siem_provider": "splunk",
  "siem_endpoint": "https://splunk.acme.com:8088",
  "siem_token":    "<HEC-token>"
}
```

Then push on demand or on a schedule:

```
POST /api/v1/audit/siem/push?since=2026-06-01T00:00:00Z&until=2026-06-15T23:59:59Z
→ { "pushed": 4821, "provider": "splunk" }
```

Events land in Splunk with `sourcetype=vibops:audit`, `index=main`.

#### Push export — Datadog

```
PUT /api/v1/audit/siem/config
{
  "siem_provider": "datadog",
  "siem_endpoint": "datadoghq.com",
  "siem_token":    "<DD-API-KEY>"
}
```

```
POST /api/v1/audit/siem/push
→ { "pushed": 4821, "provider": "datadog" }
```

Events arrive with `ddsource=vibops`, `service=vibops-audit`, tagged `org_id:<id>,action:<action>`.

#### Config endpoint

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/audit/siem/config` | Read current SIEM destination |
| `PUT` | `/api/v1/audit/siem/config` | Set provider, endpoint, token |
| `POST` | `/api/v1/audit/siem/push` | Push a batch (query params: `since`, `until`, `action`, `limit`) |

The SIEM token is stored encrypted (Fernet). Org admin required.

---

### Container registry connector

The agent can now inspect and manage images in your container registry. Push and pull are handled by the existing `DockerBuildConnector` — this connector handles **management operations**: listing, checking, and deleting.

#### Supported registries

| Registry | `registry_type` | Auth |
|----------|----------------|------|
| Harbor v2 | `harbor` | `username` + `password` in payload |
| AWS ECR | `ecr` | `aws_access_key_id` / `aws_secret_access_key` in payload, or env vars |
| Google Artifact Registry | `gar` | `service_account_json` in payload, or ADC (`GOOGLE_APPLICATION_CREDENTIALS`) |

#### Actions

| Action | Description | Role |
|--------|-------------|------|
| `registry_list_repos` | List all repositories in a registry | viewer |
| `registry_list_tags` | List all tags for an image | viewer |
| `registry_check_image` | Check whether an image:tag exists | viewer |
| `registry_delete_tag` | Delete an image tag | operator |

#### Example — agent conversation

```
You: List all tags for ghcr.io/acme/api-service in our Harbor registry

Agent: I'll check Harbor for you.
  [registry_list_tags {
    "registry_type": "harbor",
    "registry_url": "https://registry.acme.com",
    "image": "acme/api-service",
    "username": "...", "password": "..."
  }]

  Found 12 tags for acme/api-service:
  v1.4.2, v1.4.1, v1.4.0, v1.3.9, v1.3.8, latest, …

You: Delete the untagged images older than v1.3.9

Agent: I'll delete v1.3.0 through v1.3.8 (8 tags). This is destructive.
  Confirm? [yes/no]
```

#### ECR example

```
You: Check if image api-service:v2.1.0 exists in ECR us-east-1

Agent:
  [registry_check_image {
    "registry_type": "ecr",
    "image": "api-service:v2.1.0",
    "region": "us-east-1"
  }]

  Image api-service:v2.1.0 exists in ECR. ✓
```

#### Security note

Registry credentials are passed per-job in the payload. Store them in the VibOps Secrets vault and reference them via `{{ secrets.HARBOR_PASSWORD }}` in your agent instructions to avoid exposing them in conversation history.

---

## Compliance Verification

VibOps includes a compliance agent that verifies SOC 2 controls are **active at runtime** — not just documented. It runs 8 checks daily via Celery Beat and can be triggered on-demand via API.

### Triggering a compliance check

**On-demand** (org admin only):

```bash
POST /api/v1/compliance/check
```

Returns the check results immediately. The 8 checks run in-process and complete within seconds.

**Automatic**: a daily Celery Beat task runs the full 8-check suite. No configuration required — it is enabled by default.

### The 8 SOC 2 runtime checks

| # | Control | What it verifies |
|---|---------|------------------|
| 1 | CC6.1 — Access controls | Auth middleware is active, PolicyEngine is loaded, at least one user exists |
| 2 | CC6.2 — Access provisioning | Agent identity tokens exist, rotation is configured, expired identities are flagged |
| 3 | CC7.1 — Vulnerability scanning | A recent DAST scan has run (security agent active) |
| 4 | CC7.2 — Incident detection | Anomaly detection is active, proactive insights are being generated |
| 5 | CC7.4 — Audit trail integrity | HMAC-SHA256 chain on audit logs is intact (no tampering) |
| 6 | CC8.1 — Change management | Alembic migrations are up to date (no pending migrations) |
| 7 | A1.2 — Backup freshness | Most recent backup exists and is within the configured retention window |
| 8 | C1.1 — Encryption active | Fernet encryption roundtrip succeeds, no default/placeholder keys in use |

### Viewing results

Non-compliant findings automatically create **ProactiveInsight** records. They appear in the **Proaction Required** panel on the Dashboard tab, alongside GPU health warnings, budget alerts, and security findings.

Each finding includes:
- The SOC 2 control reference (e.g., CC7.4)
- A description of what failed
- Remediation guidance

### When to use it

- **Before an audit**: trigger on-demand to verify all controls pass before presenting evidence to your auditor
- **After infrastructure changes**: confirm that a migration, key rotation, or backup configuration change did not break a control
- **Continuous monitoring**: the daily schedule provides SOC 2 CC7.1 evidence of ongoing verification

---

## Security Scans

VibOps includes an automated DAST (Dynamic Application Security Testing) agent that continuously validates your instance's security posture. It runs 8 penetration checks weekly via Celery Beat, or on-demand via API.

### Triggering a scan

**On-demand** (org admin only):

```bash
POST /api/v1/security/scan
```

Returns a scan ID. The scan runs asynchronously and completes within seconds.

**Automatic**: a weekly Celery Beat task runs the full 8-check suite. No configuration required — it is enabled by default.

### Viewing findings

**API**:

```bash
GET /api/v1/security/findings
```

Returns all scan results with severity, check name, description, and remediation guidance. Filter by severity with `?severity=critical` or `?severity=high`.

**Dashboard**: critical and high findings automatically create ProactiveInsight records. They appear in the **Proaction Required** panel on the Dashboard tab, alongside GPU health warnings and budget alerts.

### What the 8 checks test

| # | Check | What it tests |
|---|-------|---------------|
| 1 | Scope bypass | Cross-org JWT — attempts to access data from another organization using your token |
| 2 | Auth bypass | Unauthenticated access to protected endpoints |
| 3 | Tenant isolation | Cross-org resource access (jobs, secrets, clusters) |
| 4 | Input injection | Shell metacharacters in kubectl/helm payloads |
| 5 | Rate limiting | Brute-force login detection and enforcement |
| 6 | Privilege escalation | Non-admin user accessing admin-only endpoints |
| 7 | IDOR | Guessed UUIDs belonging to another organization |
| 8 | Header injection | X-Forwarded-For spoofing, Host header manipulation |

### Dev mode vs prod mode

The scanner is aware of the current environment mode (`APP_ENV`):

| Mode | Behavior |
|------|----------|
| **production** | All findings reported at full severity. Critical/high findings create ProactiveInsight records. |
| **development** | Expected findings (relaxed rate limiting, dev-only auth bypass) are downgraded from CRITICAL/HIGH to LOW/INFO. This prevents alert fatigue during development while keeping the same checks running. |

A typical first scan in development mode returns 0 CRITICAL, 0 HIGH, several PASS, and a handful of LOW findings — this is expected behavior.

---

## Security hardening — audit cycle

This section covers security improvements shipped after the internal Opus audit (June 2026). All changes are backward-compatible.

### Destructive operations — dry-run confirmation

Every `DELETE` in VibOps now follows a **two-step pattern**: the first call returns a preview, the second (with `?confirmed=true`) executes.

```bash
# Step 1 — preview (safe, no side effect)
DELETE /api/v1/webhooks/subscriptions/{id}
→ {"action":"delete_subscription","confirmed":false,"warning":"..."}

# Step 2 — execute
DELETE /api/v1/webhooks/subscriptions/{id}?confirmed=true
→ {"deleted":true,"id":"..."}
```

This applies to tokens, webhook subscriptions, notification channels, teams, invites, team members, alert rules, providers, eval rubrics, memories, and the org policy.

The agent handles this automatically — when Claude needs to delete a resource, it calls the preview first and includes the details in its response before executing.

### SIEM audit export

Compliance teams can export the audit trail to any SIEM. Navigate to **Admin → Audit** and click **Export**, or use the API directly:

```bash
# JSON (default)
GET /api/v1/audit/export?format=json&since=2026-01-01T00:00:00Z

# CEF for Splunk / ArcSight
GET /api/v1/audit/export?format=cef

# LEEF for IBM QRadar
GET /api/v1/audit/export?format=leef
```

Each export includes a signed manifest (`HMAC-SHA256`) for chain-of-custody verification. Maximum 50 000 events per call — paginate with `since`/`until` for larger ranges.

Available to **org admins** only.

### Budget hard cap — pre-flight enforcement

The budget hard cap now **blocks job creation** before the job starts, not after it completes. When the projected spend would exceed your org's monthly hard cap, VibOps returns `HTTP 429` with `"hard_cap": true`.

Configure your cap in **Admin → FinOps → Budgets**:

| Threshold | Effect |
|-----------|--------|
| `soft_cap_pct` | Alert sent to notification channels |
| `hard_cap_pct` | New job creation blocked until next billing cycle |

### OIDC / SSO — hardened flow

The OIDC callback is now fully secured:

- **State parameter**: HMAC-signed with 10-minute TTL — prevents CSRF attacks
- **id_token verification**: validated against the provider's JWKS endpoint (PyJWT) — tokens cannot be forged
- **JIT provisioning**: creates a real `User` row in the database — API tokens and audit records work from the first login

No configuration change required. Existing SSO configurations remain valid.

### Production secret validation

VibOps refuses to start in `production` mode with default secrets (`change-me-in-production`). Set `SECRET_KEY` and `JWT_SECRET_KEY` to strong random values:

```bash
python -c "import secrets; print(secrets.token_hex(32))"
```

---

### Support

- Documentation: this file and `docs/installation.md`
- API: `docs/openapi.json`
- Issues: open a ticket with your VibOps contact
- License and pricing: `david@vibops.ai`

---

## Console UI Structure (updated July 2026)

### Main Navigation — 5 tabs

| Tab | Purpose |
|-----|---------|
| **Dashboard** | Overview: cluster status, GPU utilization, alerts, morning brief |
| **Fleet** | GPU fleet management: clusters, deployments, GPU metrics, anomalies |
| **Agents** | AI agents discovered through the LLM Proxy: cost, requests, GPU-hours per agent |
| **FinOps** | GPU cost management: spend trends, budgets, chargeback, waste detection, agent LLM usage |
| **Settings (⚙)** | All configuration organized in 6 categories |

### Settings — 6 categories

| Category | Sub-tabs | Purpose |
|----------|----------|---------|
| **Organization** | Teams, Users, Licence | Org structure, roles, licence management |
| **Infrastructure** | Clusters, Gateways, Git, CI, Integrations | Connect clusters, configure Git/CI, external integrations (Datadog, SIEM) |
| **Governance** | Tool Policy, Org Policy, Approvals, Agent Tools | Access control, policy-as-code, approval gates, tool catalog (205 actions) |
| **Operations** | Notifications, Secrets, Memories | Alert channels, encrypted secrets, agent memory |
| **Compliance** | Audit, Eval, Data | Immutable audit log, LLM-as-judge evaluation, training dataset |
| **Security** | SSO/LDAP, API Tokens | Enterprise SSO (OIDC), LDAP/AD integration, API token management |

### Chat Panel

The chat panel (right sidebar) is available from any tab. It provides natural language access to all 205 tools via the VibOps agent. Click the chat icon in the header to open/close.
