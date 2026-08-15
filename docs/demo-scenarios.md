# VibOps — Demo Scenarios for CSP POC

38 scenarios covering the full GitOps, HPC, and VM/GPU lifecycle — from multi-cluster discovery to ArgoCD auto-sync, cloud registry deploys, OpenShift, Slurm HPC training workflows, and unified GPU workload accounting (K8s + Slurm). Core scenarios (1–21) tested live against the local kind cluster (no cloud account required).
Each prompt is a natural sentence — type it directly in the console chat tab.

**Automated validation:** run all scenarios end-to-end with:
```bash
pytest perf/test_scenarios.py -v -s --agent-url http://localhost:8001
```

## Personas

| Persona | Role | Pain today |
|---------|------|------------|
| **SRE / On-call** | Keeps the platform running 24/7 | Incidents at 3am, 10+ kubectl commands to diagnose, runbooks that are always out of date |
| **DevOps / Platform engineer** | Ships infrastructure, manages deployments | YAML fatigue, slow feedback loops, prod changes blocked on review queues |
| **MLOps engineer** | Runs LLM inference workloads | Model version drift, no visibility on what's running where, rollout risk without staging validation, resource sizing guesswork |
| **Engineering manager** | Owns reliability and compliance | No audit trail, no visibility into what the team changed and when, risk of human error in prod |
| **HPC / MLOps engineer** | Runs large-scale training on bare-metal Slurm clusters | Manual SSH to head node for every job submission, no audit trail, no approval gate, GPU budget waste from misconfigurations |

## Cluster state (2026-04-12)

Two kind clusters running:
- `vibops-dev` — 3 nodes, 24 vCPU, 23.5 GiB, ai/ollama + open-webui + prod/llama3 (3 replicas) + staging/llama3
- `apalacha` — 2 nodes, 16 vCPU, minimal workloads (clean cluster for provisioning demos)

---

## Scenario 1 — Multi-cluster discovery (~20s) ✅ validated
**Persona: Engineering manager / SRE** — *"I just joined the on-call rotation and have no idea what's running."*

**Prompt:**
> *I need a full picture of our Kubernetes infrastructure. List all clusters and show me the resource breakdown of vibops-dev: nodes, CPU, RAM, what's running.*

**Tools triggered:** `list_clusters` → `setup_kubeconfig` → `get_cluster_resources` → `get_deployment_status`

**What the agent produces:**
- Discovers both clusters (vibops-dev, apalacha)
- Maps 7 user workloads across 5 namespaces with CPU/RAM per node
- Flags 4 operational risks: OOMKills on ai namespace, BestEffort pods with no limits, overloaded worker node, no GPU

**Talking points:**
- *"One sentence. The agent discovers 2 clusters, maps 7 workloads across 5 namespaces, computes CPU/RAM utilization per node, and flags 4 operational risks — all in under 20 seconds. A human would need 10 kubectl commands and manual correlation."*
- *"Notice it pulled everything in parallel — list_clusters, then setup_kubeconfig and get_cluster_resources simultaneously. It doesn't wait sequentially."*

**ROI:**
- **Time saved:** ~25 min (manual kubectl correlation) → 20s — **98% reduction**
- **At scale:** an SRE doing this check daily saves ~90 hours/year per engineer
- **Risk shift:** operational risks flagged proactively before an incident, not during one

---

## Scenario 2 — Incident diagnosis (~35s) ✅ validated
**Persona: SRE / On-call** — *"It's 3am, users are complaining, I need root cause now."*

**Prompt:**
> *We're seeing latency spikes in the ai namespace since this morning. Diagnose what's happening, check the cluster resource usage, and tell me if open-webui is healthy.*

**Tools triggered:** `setup_kubeconfig` → `get_cluster_resources` → `get_deployment_status` → `get_recent_logs` → `get_job` (×2) → `get_cluster_resources` → `get_gpu_status`

**What the agent produces:**
- Identifies 12 OOMKill restarts on open-webui (exit code 137) as the root cause of latency spikes
- Shows cluster has 88% RAM free — the bottleneck is the pod memory limit (1Gi), not node pressure
- Flags that vibops-dev-worker is overloaded (ollama + open-webui + 4 llama3 pods on 1 node)
- Recommends raising open-webui memory limit to 1.5Gi and spreading llama3 pods across workers

**Talking points:**
- *"Mean time to root cause: 35 seconds, without touching kubectl."*
- *"The agent correlated across layers — OOMKill history (exit code 137) → memory ceiling (1Gi limit) → node co-location with Ollama (8Gi limit on a 7.8Gi node) → latency spikes. A human would need 6+ kubectl commands and manual correlation."*
- *"This is real data from the running cluster — 12 actual restarts, real timestamps, real resource numbers. Not a mock."*

**ROI:**
- **MTTR:** ~35 min (manual diagnosis across logs, events, metrics) → 35s — **99% reduction**
- **SLA impact:** a 30-min faster diagnosis on a 99.9% SLA service (8.7 hr downtime budget/year) can be the difference between a clean quarter and a breach — plus the SRE call-out avoided at 3am
- **Cognitive load at 3am:** 6 kubectl commands with exact flag syntax → 1 natural language sentence

---

## Scenario 3 — Production safety guardrail + dry-run preview (~45s, interactive) ✅ validated
**Persona: DevOps engineer** — *"I need to scale llama3 in prod, fast."* / **Engineering manager** — *"How do I know the agent won't do something dangerous?"*

**Step 1 prompt:**
> *Scale llama3 in the prod namespace on vibops-dev down to 2 replicas.*

**What happens:** PolicyEngine intercepts the `scale_cluster` action (destructive), returns HTTP 409 with a semantic dry-run preview — before a single kubectl command runs.

**API response (409):**
```json
{
  "requires_confirmation": true,
  "matched_rule": "destructive_requires_confirmation",
  "preview": {
    "resolved_params": { "name": "llama3", "replicas": 2, "namespace": "prod", "cluster": "kind-vibops-dev" },
    "estimated_cost_hourly_usd": null,
    "reversibility": "manual"
  }
}
```

**Agent presents to user:** *"This will scale llama3 in prod from 3 → 2 replicas. Reversibility: manual. Confirm?"*

**Step 2 prompt:**
> *Yes, go ahead.*

**Tools triggered:** `create_job(scale_cluster, confirmed=true)` → `get_job(job_id)`

**Talking points:**
- *"The agent shows you exactly what will happen before it happens: resolved params, reversibility — not a vague 'are you sure?'"*
- *"This is enforced at the engine level — not a UI convention, not a config flag. Every destructive action goes through PolicyEngine."*
- *"reversibility: manual means scale-up is easy but not automatic. For deploy_model it would be automatic — rollback_service can undo it. The agent knows the difference."*
- *"Every step is in the audit trail: the 409 attempt, the confirmation, the execution, the job ID. Compliance gets this for free."*

**ROI:**
- **Risk reduction:** 22% of production outages are caused by human error during manual changes — guardrails with preview eliminate the most common vector
- **Decision quality:** operator sees resolved params (including defaults VibOps filled in) before confirming — no surprises
- **Compliance:** 409 attempt + confirmation + execution all logged with matched_rule, reason, and preview context

---

## Scenario 4 — Configuration drift detection (~20s)
**Persona: MLOps engineer** — *"Did someone push a model change to prod without going through staging?"*

**Prompt:**
> *Compare the llama3 deployments in staging and prod on vibops-dev. Are they running the same image and configuration, or have they drifted?*

**Tools triggered:** `setup_kubeconfig` → `get_deployment_status` (staging/llama3) + `get_deployment_status` (prod/llama3) in parallel → `get_job` (×2)

**What the agent produces:**
A diff table comparing both environments, with real findings:
- Same image (`ollama/ollama:latest`) and same ReplicaSet hash → clean promotion
- Replicas differ as expected (1 staging / 3 prod)
- **Risk flagged:** both run untagged `latest` image → silent drift possible on next pull
- **Risk flagged:** no resource limits/requests defined on either — both unconstrained

**Talking points:**
- *"Same image — but revision 1 in staging vs revision 4 in prod. Someone touched prod directly without going through staging. VibOps caught it in 20 seconds."*
- *"imagePullPolicy: Always + untagged latest = silent drift risk on every pod restart. The agent flags it automatically — it's not just a diff tool, it understands what the diff means."*
- *"And it offers to fix it in the same turn — pin the image tag, add resource limits — just say yes."*

**ROI:**
- **Audit frequency:** manual drift review monthly (~2 hr) → on-demand in 20s — can run daily or on every deploy
- **Risk caught early:** configuration drift is the #2 cause of production incidents after human error; finding it in 20s vs during a 3am outage is the difference between a 5-minute fix and a P1
- **Coverage:** checks both environments in parallel — a manual process typically misses subtle deltas (replica count, pull policy, untagged image)

---

## Scenario 5 — Deploy a new workload from scratch (2-step) ✅ validated
**Persona: DevOps / Platform engineer** — *"I need to spin up a service for a team quickly, no YAML, no back-and-forth."*

**Reset before running:**
```bash
docker exec vibops_worker kubectl --context apalacha delete namespace demo --ignore-not-found
```

**Prompt 1:**
> *Deploy nginx:latest on the apalacha cluster, namespace demo, 2 replicas, port 80, env dev.*

**Tools triggered:** `setup_kubeconfig` (apalacha) → `deploy_webapp` (2 replicas) → `save_memory`

**Agent response:** Confirms namespace `demo` created, Deployment + NodePort Service up, 2/2 pods Running.

**Prompt 2 (immediately after):**
> *Port-forward nginx from the demo namespace on apalacha to localhost:8080 so I can open it in my browser.*

**Tools triggered:** `setup_kubeconfig` → `port_forward`

**Agent response:** Port-forward active (PID shown). Service accessible at http://localhost:8080.

**Verify live:** Open http://localhost:8080 in browser — nginx welcome page loads.

**Talking points:**
- *"From empty cluster to browser-accessible service in two sentences. No YAML, no kubectl, no docs lookup."*
- *"The agent handled namespace creation, deployment, NodePort service, and port-forward — 4 kubectl operations — from a single natural language instruction."*

**ROI:**
- **Time to deploy:** 30–60 min (write YAML, PR, review, merge, apply) → 2 sentences + 60s — **98% reduction**
- **Platform team dependency:** eliminated for standard workload deployments — engineers self-serve without a ticket queue
- **At scale:** a platform engineer handling 5 deploy requests/week saves ~4 hours/week — frees ~200 hours/year for strategic work

---

## Scenario 5b — Deploy a chatbot end-to-end (~60s) ✅ validated
**Persona: DevOps / Platform engineer** — *"A team needs a chatbot running on the cluster. I want to deploy the full stack — backend + UI — in one conversation."*

**Reset before running:**
```bash
docker exec vibops_worker kubectl --context apalacha delete namespace chatbot --ignore-not-found
```

**Prompt:**
> *Deploy a full chatbot stack on the apalacha cluster in a new namespace called chatbot: Ollama as the AI backend with llama3, and Open WebUI as the interface. Expose the UI on port 80 so the team can access it from their browser.*

**Tools triggered:** `setup_kubeconfig` (apalacha) → `deploy_webapp` (ollama, namespace: chatbot) → `deploy_webapp` (open-webui, namespace: chatbot, env: OLLAMA_BASE_URL) → `get_deployment_status` (both) → `port_forward` (open-webui:80)

**What the agent produces:**
- Creates namespace `chatbot`
- Deploys Ollama backend (1 replica, port 11434)
- Deploys Open WebUI frontend wired to Ollama (1 replica, port 80)
- Confirms both pods Running
- Exposes Open WebUI via NodePort — accessible at http://localhost:80

**Verify live:** Open http://localhost:80 in browser — Open WebUI loads, select llama3, start chatting.

**Talking points:**
- *"Full chatbot stack — AI backend + web interface — deployed in one sentence. No YAML, no Helm values file, no kubectl."*
- *"The agent wired the two services together automatically: Open WebUI points to Ollama's internal service address. Zero config on your end."*
- *"From this conversation, you could immediately say: 'Scale the Ollama backend to 3 replicas' or 'Add resource limits to the UI pod' — same interface, no context switch."*
- *"This works on any Kubernetes cluster — cloud or on-prem. The only prerequisite is a connected gateway."*

**Reset after demo:**
```bash
docker exec vibops_worker kubectl --context apalacha delete namespace chatbot --ignore-not-found
```

**ROI:**
- **Time to running chatbot:** 2–4 hours (write Helm charts, configure service wiring, debug DNS, expose ingress) → 1 sentence + 60s — **99% reduction**
- **No prerequisites:** no GPU, no cloud account, no YAML expertise — works on any connected cluster
- **Full lifecycle in one session:** deploy → verify → scale → audit — without leaving the chat

---

## Scenario 6 — Operations audit trail (~10s)
**Persona: Engineering manager / Compliance** — *"I need to show auditors what changed on the platform and who triggered it."*

**Prompt:**
> *Show me everything that happened on the clusters in the last 2 hours. Any failures I should know about?*

**Tools triggered:** `list_jobs`

**What the agent produces:**
Full chronological log of all operations — who triggered them (`api` / `claude-agent`), what action ran, success/failure, duration, and error detail for failures.

**Talking points:**
- *"Every action VibOps takes is logged — who triggered it, what ran, success or failure, duration, error detail. Immutable audit trail out of the box."*
- *"No extra SIEM integration required. Your compliance team gets this for free."*

**ROI:**
- **Compliance readiness:** SOC2/ISO27001 audit log preparation typically takes 2–4 weeks of engineering time — VibOps provides a structured, complete audit trail from day one
- **Policy decisions audited:** every 409 (denied + preview shown) is logged with `matched_rule`, `reason`, and `preview` context — not just successful actions, but every attempt, including what the operator was about to do before confirming
- **Tooling cost avoided:** a dedicated ops audit layer (SIEM + custom log pipeline) = $50k–$200k/year in tooling + maintenance
- **Mean time to evidence:** "what changed, who changed it, and what preview they saw before confirming" → instant query vs hours of log mining

---

## Scenario 7 — Production rollback (~30s, 2-step) ✅ validated
**Persona: SRE / On-call** — *"A bad deploy just hit prod. I need to roll back before the incident escalates."*

**Setup (run before demo):**
```bash
# Ensure llama3 is pinned to a known-good image (creates revision 2)
TOKEN=$(docker exec vibops_core python -c "
from app.auth import create_token; from app.user_context import UserContext
ctx = UserContext(user_id='1', username='admin', org_id='1', org_name='Acme', is_org_admin=True, teams=())
print(create_token(ctx))")
curl -s -X POST http://localhost:8000/api/v1/jobs \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"action": "patch_deployment", "payload": {"name": "llama3", "namespace": "prod", "cluster": "vibops-dev", "image": "ollama/ollama:0.6.5"}}'
```

**Step 1 prompt — simulate a broken deploy:**
> *Update llama3 in prod on vibops-dev to image ollama/ollama:broken-build*

**What happens:** Agent patches the deployment to the bad image (revision 3). Pod enters `ImagePullBackOff`.

**Step 2 prompt — rollback:**
> *The last deploy broke the llama3 API in prod on vibops-dev. Roll it back to the previous version immediately.*

**Tools triggered:** `setup_kubeconfig` → `get_deployment_status` → `rollback_deployment` → `get_deployment_status`

**What the agent produces:**
- Checks current state (1/1 but ImagePullBackOff on fresh pod)
- Executes `kubectl rollout undo deployment/llama3 --namespace=prod` (revision 3 → revision 2)
- Confirms pod is back on `ollama/ollama:0.6.5`, 1/1 Running

**Talking points:**
- *"Mean time to rollback: under 30 seconds from natural language to confirmed healthy pod. No kubectl, no runbooks."*
- *"The agent didn't just run rollback blindly — it checked the deployment state first, identified the broken image, then executed the undo and confirmed the pod came back healthy."*
- *"This is a full audit trail: the bad deploy, the rollback, the confirmation — all logged with timestamps in the operations tab. Compliance gets this for free."*
- *"In a real incident at 3am, your on-call engineer types one sentence instead of hunting for the right kubectl command under pressure."*

**ROI:**
- **MTTR for rollback:** ~30 min (find revision, recall kubectl syntax, verify manually) → 30s — **99% reduction**
- **Revenue protected:** a SaaS at $1M ARR loses ~$115/min of downtime; saving 30 min per rollback = ~$3.4k per incident — scales linearly with revenue
- **On-call stress:** zero kubectl syntax to recall at 3am under pressure — one sentence, confirmed recovery
- **Never blocked by policy:** rollback is explicitly exempt from PolicyEngine by design (ADR 0002) — a guardrail that blocks a production rollback during an incident is worse than any policy violation it prevents. Scale-up has dry-run preview; rollback is instant.

---

## Scenario 8 — Scale up for traffic spike with dry-run preview (~30s, 2-step) ✅ validated
**Persona: MLOps / SRE** — *"We're expecting a surge tonight. I need more capacity before it hits."*

**Step 1 prompt:**
> *We're expecting a traffic spike tonight on prod llama3 on vibops-dev. Scale it up to 5 replicas.*

**What happens:** PolicyEngine intercepts (destructive), returns 409 with preview. Agent shows the operator exactly what will change before touching the cluster.

**Step 2 prompt:**
> *Confirmed. Do it.*

**Tools triggered:** `create_job(scale_cluster, confirmed=true)` → `get_job(job_id)` → `get_deployment_status`

**What the agent produces:**
- 409 preview: resolved params (name, replicas: 5, namespace: prod, cluster: kind-vibops-dev), reversibility: manual
- After confirmation: scales `llama3` from current replicas to 5
- Confirms all 5/5 pods Running before responding

**Talking points:**
- *"The preview shows 'replicas: 5, namespace: prod' with defaults filled in — before any kubectl runs. The operator confirms they're targeting the right cluster and namespace."*
- *"Capacity management in two sentences. No YAML diff, no kubectl scale, no manual verification loop."*
- *"The agent closes the loop — waits for the pods to be ready and reports back. Same pattern for scale-down: 'Traffic dropped, scale llama3 back to 2 replicas.' One sentence, done."*

**ROI:**
- **Time to scale:** 5–10 min (kubectl scale, watch pods, verify) → 30s with confirmation — **95% reduction**
- **SLA protection:** every minute of under-provisioning during a traffic spike = SLA breach risk; faster scale-up directly protects revenue
- **Self-service:** non-ops personas (MLOps, product) can trigger scaling without a platform team ticket — guardrail prevents targeting the wrong cluster

---

## Scenario 9 — Patch resource limits (~20s) ✅ validated
**Persona: SRE / MLOps engineer** — *"A pod keeps crashing. I need to fix the limits without writing YAML or filing a PR."*

**Prompt:**
> *The open-webui pod keeps OOMKilling. Raise its memory limit to 2Gi on vibops-dev right now.*

**Tools triggered:** `setup_kubeconfig` → `get_deployment_status` → `patch_deployment(memory_limit: 2Gi)` → `get_deployment_status`

**What the agent produces:**
- Checks current state and confirms OOMKill history (exit code 137)
- Patches the memory limit via strategic merge patch
- Confirms pod rolled out on new spec, Running

**Talking points:**
- *"This is the fix for the exact OOMKill pattern flagged in Scenario 2 — the same agent that diagnosed it can fix it in the next sentence."*
- *"No YAML editing, no `kubectl patch` syntax to remember under pressure. The agent handles the strategic merge patch internally."*
- *"The change is immediately visible in the audit trail — who requested it, what was patched, when, success/failure."*

**ROI:**
- **Time to fix:** 10–15 min (kubectl edit, YAML merge patch, rollout watch) → 20s — **97% reduction**
- **Full loop in one session:** diagnose (S2) → fix → verify without switching tools or context
- **Error elimination:** hand-editing YAML under incident pressure is a common source of secondary failures — the agent generates the correct strategic merge patch every time

---

## Scenario 10 — Create a test cluster from scratch (~60s) ✅ validated
**Persona: DevOps / Platform engineer** — *"The team needs an isolated environment for a feature branch, without touching the shared clusters."*

**Prompt:**
> *Create a fresh kind cluster called feature-test with 2 nodes so the team can test the new pipeline without touching vibops-dev.*

**Tools triggered:** `create_cluster(name: feature-test, workers: 2)` → `setup_kubeconfig` → `get_cluster_resources`

**What the agent produces:**
- Provisions a new kind cluster (`feature-test`) with 1 control-plane + 2 worker nodes
- Configures kubeconfig automatically
- Reports node status and available resources

**Reset after demo:**
```bash
docker exec vibops_worker kind delete cluster --name feature-test
```

**Talking points:**
- *"Isolated environment in one sentence — no cloud account, no Terraform, no waiting for a PR to merge."*
- *"Teams can spin up a throwaway cluster for a feature branch and tear it down when done. VibOps handles the lifecycle."*
- *"The new cluster immediately appears in the console cluster selector — kubeconfig is merged automatically."*

**ROI:**
- **Time to new environment:** 30–60 min (Terraform + PR + review + merge + apply + kubeconfig) → 60s — **98% reduction**
- **Platform team ticket queue:** eliminated for environment provisioning — every developer self-serves
- **Cost discipline:** throwaway clusters are deleted immediately after use — no forgotten test environments burning cloud budget

---

---

## MLOps scenarios — no GPU required

---

## Scenario 11 — Inference fleet health check (~20s)
**Persona: MLOps engineer** — *"I'm starting my day. I want to know if all our LLM services are up before the team starts hitting them."*

**Prompt:**
> *Give me a full status of all LLM inference services running on vibops-dev — models, namespaces, replicas, health.*

**Tools triggered:** `setup_kubeconfig` → `get_cluster_resources` → `get_deployment_status` (ollama, llama3/prod, llama3/staging, open-webui) in parallel

**What the agent produces:**
- Lists all inference workloads with namespace, replica count, image, and health status
- Flags any pod not in Ready state
- Shows resource consumption per model deployment (CPU/RAM requested vs limits)

**Talking points:**
- *"Morning standup question answered in 20 seconds. The MLOps engineer doesn't need to know which namespaces the models live in, kubectl syntax, or deployment names — just asks naturally."*
- *"Covers the full inference stack: Ollama backend, the llama3 model in prod and staging, the Open WebUI frontend. One query, full picture."*
- *"Any unhealthy service would be flagged immediately — before the team starts their day and before users notice."*

**ROI:**
- **Daily health check:** 10–15 min (4+ kubectl commands across namespaces, manual correlation) → 20s — saves **~56 hours/year per MLOps engineer** (260 working days)
- **Proactive detection:** issues caught before the first user request of the day vs discovered when a user reports an error
- **Knowledge dependency eliminated:** engineer doesn't need to know namespace names, deployment names, or kubectl syntax — onboarding new team members takes minutes, not weeks

---

## Scenario 12 — Promote staging model to prod (~30s, 2-step) ✅ validated
**Persona: MLOps engineer** — *"We validated llama3:0.6.5 in staging. Time to promote it to prod."*

**Step 1 prompt — check staging is ready:**
> *Is the llama3 model in staging on vibops-dev healthy and running the right image? I want to promote it to prod.*

**Tools triggered:** `setup_kubeconfig` → `get_deployment_status` (staging/llama3) + `get_deployment_status` (prod/llama3) in parallel

**What the agent produces:**
- Staging: llama3 1/1, image `ollama/ollama:0.6.5`, healthy
- Prod: llama3 currently on `ollama/ollama:0.6.5` (or previous tag), shows diff
- Confirms it's safe to promote

**Step 2 prompt:**
> *Good. Pin prod llama3 to the same image as staging and confirm the rollout.*

**Tools triggered:** `patch_deployment(name: llama3, namespace: prod, image: ollama/ollama:0.6.5, cluster: vibops-dev)` → `get_deployment_status`

**Talking points:**
- *"This is the MLOps promotion workflow: validate in staging, diff against prod, promote with one sentence. No YAML PR, no kubectl patch syntax."*
- *"The agent does the diff automatically — it checks both environments in parallel before the engineer commits to the change."*
- *"Image pinned explicitly — no more `latest` drift. The agent enforces the right practice without the engineer having to remember."*

**ROI:**
- **Promotion workflow:** 20–30 min (manual diff + kubectl patch + rollout watch) → 2 prompts + 30s — **97% reduction**
- **Drift incidents prevented:** untagged `latest` images are a top-3 cause of unexpected model behavior changes — explicit pinning enforced by default
- **Confidence:** automatic pre-promotion diff means engineers promote with verified parity, not assumptions

---

## Scenario 13 — Detect misconfigured inference workloads (~20s)
**Persona: MLOps engineer / Engineering manager** — *"Are our LLM services properly configured for production? No surprise OOMKills, no unbounded resource usage."*

**Prompt:**
> *Audit all LLM inference workloads on vibops-dev. Flag any deployment running without resource limits, with fewer replicas than expected in prod, or with an untagged image.*

**Tools triggered:** `setup_kubeconfig` → `get_cluster_resources` → `get_deployment_status` (multiple deployments in parallel)

**What the agent produces:**
A table of all inference services with a risk column:
- `ollama` — no resource limits → **HIGH RISK** (unbounded RAM, can starve other pods)
- `prod/llama3` — untagged `latest` image → **MEDIUM RISK** (silent drift on restart)
- `staging/llama3` — 1 replica → OK for staging
- `open-webui` — memory limit set (2Gi) → OK

**Talking points:**
- *"Production readiness audit in one question. In a real org this takes a spreadsheet, a kubectl script, and a meeting. Here it's 20 seconds."*
- *"The agent doesn't just list config — it flags what it means: no limits on Ollama means one bad request can take down the entire node. That's the kind of insight that prevents 3am incidents."*
- *"This runs every morning, or on a trigger before any major traffic event. The audit becomes a habit instead of a fire drill."*

**ROI:**
- **Audit cycle:** ad-hoc spreadsheet + meetings (~2 hr, typically monthly) → 20s on demand — can gate every deployment or run every morning
- **Incident cost avoided:** an OOMKill caused by missing resource limits = avg 2–4 hr P2 incident; at $5k–$20k per incident, one catch pays for months of tooling
- **Shift-left:** misconfiguration caught before traffic hits, not during an incident — changes the economics of ops from reactive to preventive

---

## Scenario 14 — Deploy a new model for experimentation (~30s) ✅ validated
**Persona: MLOps engineer** — *"A researcher wants to test mistral. I need to get it running quickly without touching prod."*

**Prompt:**
> *Deploy an Ollama container for mistral in the ai namespace on vibops-dev with 1 replica for the research team.*

**Tools triggered:** `setup_kubeconfig` → `deploy_webapp(name: mistral, image: ollama/ollama:latest, namespace: ai, replicas: 1, cluster: vibops-dev)`

**Note:** Use `deploy_webapp` not `deploy_model` — avoids the mandatory GPU audit (rule 6) which is irrelevant for a CPU-only cluster and adds noise to the demo.

**What the agent produces:**
- Creates namespace `ai` if needed (already exists here)
- Deploys a new `mistral` Deployment + NodePort Service in `ai`, 1 replica
- Confirms pod is Running
- Reminds that prod namespaces are untouched

**Reset after demo:**
```bash
docker exec vibops_worker kubectl --context kind-vibops-dev delete deployment mistral -n ai --ignore-not-found
docker exec vibops_worker kubectl --context kind-vibops-dev delete service mistral -n ai --ignore-not-found
```

**Talking points:**
- *"From researcher request to running container in one sentence. No YAML, no hand-off to the platform team, no waiting."*
- *"The agent scoped it correctly to the `ai` namespace — prod untouched by design."*
- *"Same flow for any Ollama-compatible model. The MLOps team iterates on models as fast as they iterate on code."*

**ROI:**
- **Researcher → running model:** 30–45 min (DevOps ticket + YAML + review + deploy) → 1 sentence + 30s — **99% reduction**
- **Experimentation velocity:** teams evaluate more models in the same time — competitive advantage in ML iteration speed
- **Platform team freed:** zero-touch provisioning for sandbox environments — platform engineers focus on infrastructure, not request tickets

---

## Scenario 15 — Rolling update with validation gate (~45s, 2-step)
**Persona: MLOps engineer** — *"I want to update the prod inference service to a new model version, but I need to validate it didn't break before I declare success."*

**Step 1 prompt:**
> *Update the llama3 deployment in prod on vibops-dev to image ollama/ollama:0.6.5, then check the logs to confirm the model loaded correctly.*

**Tools triggered:** `setup_kubeconfig` → `patch_deployment(namespace: prod, image: ollama/ollama:0.6.5)` → `get_deployment_status` → `get_recent_logs`

**What the agent produces:**
- Patches the image, waits for rollout
- Pulls recent logs from the new pod
- Confirms model loaded (or flags startup errors)

**Step 2 prompt (if logs look good):**
> *Looks good. Make a note that prod llama3 is now on 0.6.5 and was validated today.*

**Tools triggered:** (memory or audit trail)

**Talking points:**
- *"Deploy + validate in a single conversation. The engineer doesn't switch between terminal, logs viewer, and wiki — one interface, one flow."*
- *"If the logs showed an error, the engineer would say 'roll it back' and VibOps would revert with one more sentence. Full deploy/validate/rollback loop without leaving the chat."*
- *"This is the MLOps inner loop at speed: deploy → observe → decide. VibOps compresses it from 10 minutes to under 1."*

**ROI:**
- **Deploy + validate loop:** 15–20 min (kubectl set image + watch + manual log tailing + wiki update) → 45s — **97% reduction**
- **Context switching eliminated:** terminal, log viewer, Slack, wiki → single conversation; each switch costs 5–10 min of cognitive ramp-up
- **Audit evidence built-in:** the conversation itself (deploy event + log validation + human decision) is compliance evidence — no separate runbook to update

---

## Autonomous Incident Response scenarios (no GPU required)

---

## Scenario 20 — Autonomous incident diagnosis + remediation (~45s, 2-step) ✅ validated
**Persona: SRE / On-call** — *"A pod is crashing. I need to know why and fix it — without touching kubectl."*

**Step 1 prompt:**
> *The open-webui pod in the ai namespace on vibops-dev keeps crashing. Diagnose what's wrong and tell me what to do.*

**Tools triggered:** `setup_kubeconfig` → `analyze_pod_failure(name: open-webui, namespace: ai, cluster: vibops-dev)`

**What the agent produces:**
- Root cause: OOMKill (exit code 137)
- Current memory limit, restart count
- Last 3 log lines before crash
- Recent Kubernetes events (Warning/BackOff)
- Concrete recommendation: increase memory limit to 2Gi

**Step 2 prompt:**
> *Fix it. Raise the memory limit to 2Gi.*

**Tools triggered:** `remediate_incident(name: open-webui, namespace: ai, cause: OOMKill, memory_limit: 2Gi)` → `patch_deployment`

**What the agent produces:**
- Applies the memory limit patch
- Confirms pod rolled out on new spec, Running
- Restart count reset to 0

**Talking points:**
- *"Full incident loop in two sentences: diagnose → fix. No kubectl, no runbook, no log parsing by hand."*
- *"analyze_pod_failure correlates three data sources in parallel: events, describe, and logs — then returns a single structured diagnosis. An SRE would need 4–6 kubectl commands to get the same picture."*
- *"The remediation is cause-aware: OOMKill → patch limits, ImagePullBackOff → rollback, CrashLoopBackOff → restart. The agent picks the right action automatically."*

**ROI:**
- **MTTR:** 20–40 min (page → wake up → diagnose → fix → verify) → 45s — **99% reduction**
- **On-call cognitive load at 3am:** 6 kubectl commands with exact flag syntax → 2 natural language sentences
- **Error prevention:** cause-aware remediation eliminates the wrong fix (e.g. restarting a pod that needs more memory, which just crashes again)

---

## Intelligence & Performance scenarios (no GPU required)

---

## Scenario 16 — Model benchmarking (~45s) ✅ validated
**Persona: MLOps engineer** — *"Before I put llama3 behind the API gateway, I need to know its real latency numbers."*

**Prompt:**
> *Benchmark the ollama service in the ai namespace on vibops-dev. Run 5 requests against llama3 and give me the p50/p95/p99 latency.*

**Tools triggered:** `setup_kubeconfig` → `benchmark_model(name: ollama, namespace: ai, model: llama3, requests: 5)`

**What the agent produces:**
- Finds the running ollama pod, execs a Python benchmark loop inside the container
- Returns p50/p95/p99 latency in ms, min/max/avg, estimated throughput per replica

**Talking points:**
- *"Real latency numbers measured inside the cluster — not a synthetic curl from your laptop. This is the number your users will experience."*
- *"The benchmark runs inside the pod: no port-forward, no network hop. Closest possible measurement to actual inference latency."*
- *"Next sentence: 'Plan capacity for 20 RPS at under 500ms' — VibOps uses these numbers to compute the replica count."*

**ROI:**
- **Benchmark setup:** 30–60 min (write locust/k6 script, run from external, parse results) → one sentence
- **Decision quality:** right-sizing based on real latency vs guesswork prevents both over-provisioning (cost) and under-provisioning (SLA breach)

---

## Scenario 17 — Capacity planning (~15s) ✅ validated
**Persona: MLOps engineer / Engineering manager** — *"We're expecting 50 RPS next quarter. How many replicas do I need?"*

**Step 1 prompt (after benchmarking):**
> *Based on the benchmark (p99: 3200ms, avg: 2500ms), plan capacity for llama3 to handle 50 RPS at under 2000ms p99. Each replica needs 4 CPU and 8GB RAM.*

**Tools triggered:** `plan_capacity(model: llama3, target_rps: 50, target_p99_ms: 2000, observed_p99_ms: 3200, observed_rps: 0.4, cpu_per_replica: 4, memory_gb_per_replica: 8)`

**What the agent produces:**
- Recommended replica count with 20% headroom
- Total CPU, memory (and GPU if applicable)
- HPA min/max range recommendation
- Notes on whether the target latency is achievable on CPU

**Talking points:**
- *"Little's Law in one sentence: concurrency = throughput × latency. VibOps runs the math so engineers don't have to."*
- *"The 20% headroom is built in — don't show up to a traffic spike with exactly enough capacity."*
- *"This feeds directly into the next action: 'Scale llama3 to X replicas on vibops-dev.' One conversation, full loop."*

**Step 2 prompt:**
> *Scale llama3 in the ai namespace to the recommended number of replicas.*

**ROI:**
- **Capacity planning:** half-day engineering exercise + spreadsheet → 15s from observed latency to replica count
- **Cost discipline:** right-sized from the start, no over-provisioning "just in case"
- **SLA confidence:** quantified answer replaces gut feel — engineering manager can commit to SLA targets

---

## Scenario 18 — Workload placement (~25s) ✅ validated
**Persona: DevOps / Platform engineer** — *"I have two clusters and I need to decide where to deploy a new service."*

**Prompt:**
> *I need to deploy a new inference service requiring 4 CPU cores and 8GB RAM with 2 replicas. Which of my clusters has the capacity?*

**Tools triggered:** `find_best_cluster(cpu_cores: 4, memory_gb: 8, replicas: 2)`

**What the agent produces:**
- Ranked list of all kind clusters (vibops-dev, apalacha) with available CPU/memory
- Fit assessment: which clusters can absorb the workload
- Score per cluster (100-point scale based on available headroom)
- Recommendation with rationale

**Talking points:**
- *"The agent scans every cluster in parallel — no manual `kubectl describe node` loop across environments."*
- *"It scores by fit, not just 'has resources' — it accounts for headroom so you don't land on a cluster that's 95% full."*
- *"Next action: 'Deploy it to vibops-dev' — one more sentence and the workload is running."*

**ROI:**
- **Placement decision:** 20–30 min (SSH into each cluster, kubectl describe nodes, manual calculation) → 25s
- **Mis-placement prevention:** deploying to a full cluster causes immediate OOMKill or Pending pods — this check costs 25 seconds vs potentially hours of incident recovery

---

## Scenario 19 — Auto-healing trigger (~20s) ✅ validated
**Persona: SRE / On-call** — *"I'm tired of getting paged at 3am for CrashLoop pods. Can VibOps handle it automatically?"*

**Prompt:**
> *Set up an auto-restart rule: whenever a pod has more than 3 restarts in the last 10 minutes, automatically restart the deployment. Alert me on Slack when it fires.*

**Tools triggered:** `create_trigger(source: kubernetes, condition: gt, threshold: 3, metric: pod_restarts, action: restart_service, notify_channel: slack)`

**What the agent produces:**
- Creates a trigger rule: `pod_restarts > 3 in 10min → restart_service`
- Confirms the rule is active with its ID
- Explains: the trigger will fire automatically, restart the deployment, and notify via Slack

**Talking points:**
- *"This is the self-healing loop: detect → act → notify. No human in the loop for a known-safe remediation."*
- *"The SRE defines the policy once. VibOps enforces it 24/7 without an on-call page for a restart."*
- *"For destructive actions (rollback, scale-down), the trigger pauses and asks for confirmation — same guardrail as manual actions, same dry-run preview."*

**ROI:**
- **On-call pages avoided:** a team with 3 CrashLoop incidents/week saves ~6 hours of on-call time/week — $15k+/year in engineer time
- **MTTR for restarts:** 30–45 min (page → wake up → diagnose → restart) → <1 min automatic
- **SLA protection:** automated response in under 60 seconds vs human response in 30+ minutes — recovers 99.9% SLA from a 99.5% reality
- **Safe automation:** even automated triggers go through the same policy gate — no silent destructive action, even from a rule

---

## Scenario 21 — SLO definition + compliance monitoring (~20s) ✅ validated
**Persona: Engineering manager / MLOps** — *"I need to commit to a latency SLA with the product team. How do I know if we're meeting it?"*

**Step 1 prompt:**
> *Set an SLO for llama3 in the prod namespace: p99 latency must stay under 2000ms, 99.9% of the time. Alert me on Slack if we breach it.*

**Tools triggered:** `list_notification_channels` → `create_slo(service: llama3, namespace: prod, slo_type: latency, threshold: 2000, target_percent: 99.9)` → (creates Prometheus alert trigger)

**What the agent produces:**
- SLO stored: `llama3 latency ≤ 2000ms, 99.9% target, 60min window`
- Prometheus trigger created: fires when p99 > 2000ms
- Slack `#ops-alerts` wired for budget burn alerts

**Step 2 prompt:**
> *Are we currently meeting the llama3 SLO?*

**Tools triggered:** `get_slo_status(service: llama3, slo_type: latency, namespace: prod)`

**What the agent produces:**
- Current p99 from Prometheus vs 2000ms threshold
- Compliance status: ✅ MEETING SLO or 🔴 SLO BREACH
- Error budget remaining

**Talking points:**
- *"SLO defined in one sentence, enforced automatically via Prometheus. No dashboard to build, no alert YAML to write."*
- *"The SLO check is live data from Prometheus — not a cached number, not a gut feel. The engineering manager can share this with the product team in real time."*
- *"If the SLO is breached, the next sentence is: 'Scale llama3 to 5 replicas' or 'Run a benchmark to find the bottleneck.' Full SRE loop from the same chat."*

**ROI:**
- **SLO setup time:** 1–2 days (define metrics, configure Prometheus rules, write Grafana alerts, document) → one prompt — **99% reduction**
- **Compliance visibility:** real-time answer vs monthly review meeting — engineers can verify SLO status before any deploy
- **Accountability:** SLO definition stored and auditable — engineering manager has evidence for product team commitments

---

## GPU scenario stubs (when GPU cluster is available)

These require a cluster with NVIDIA GPU nodes (EKS/GKE p3/a2 instances, or on-prem with NVIDIA device plugin).

## GPU-0 — Bootstrap GPU Operator (~3min)
**Persona: Platform engineer** — *"I just added a GPU node. I need the NVIDIA stack running before the ML team starts."*

**Prompt:**
> *I just added a GPU node to the vibops-dev cluster. Set up the NVIDIA GPU Operator so the node is ready for inference workloads.*

**Tools triggered:** `get_cluster_resources` (detect GPU node labels) → `helm_add_repo(nvidia)` → `helm_install(gpu-operator, namespace=gpu-operator)` → `accelerator_diagnose` (wait for driver + device-plugin + dcgm-exporter Running) → `accelerator_get_metrics` (confirm capacity visible)

**What the agent produces:**
- Detects the new GPU node via cluster resource scan
- Adds the NVIDIA Helm repo and installs the GPU Operator in one shot
- Polls operator status until driver, device-plugin, and DCGM exporter are all Running
- Reports total GPU capacity now visible to the scheduler

**Talking points:**
- *"One prompt bootstraps the entire NVIDIA stack — driver, device plugin, DCGM exporter. No Helm values file to write, no namespace to create manually."*
- *"The agent waits for the operator to be healthy before declaring success — it doesn't just fire-and-forget the Helm install."*
- *"After this, GPU-A through GPU-E run directly — the cluster is inference-ready."*

> Tip: pre-load the GPU Operator image on the node before the demo to avoid a 2–3 min pull delay.

**ROI:**
- **Bootstrap time:** 45–90 min (read NVIDIA docs, write Helm values, debug driver install) → one prompt + 3 min — **97% reduction**
- **Error surface eliminated:** driver version mismatch, wrong namespace, missing node label — the agent handles all of it
- **Repeatability:** same prompt works on any new GPU node, any cluster — zero runbook maintenance

---

## GPU-A — Capacity check (~10s)
**Persona: MLOps engineer** — *"Before I book a GPU deploy, I need to know if we actually have room."*

**Prompt:**
> *I need to deploy a llama3-70b inference server. Do we have enough A100 GPUs available on the prod cluster to run it with 4 GPUs?*

**Tools triggered:** `get_gpu_status` → `check_gpu_capacity`

**What the agent produces:**
- Current GPU inventory: total, allocated, free per node
- Feasibility verdict: yes/no with available headroom
- If insufficient: what's consuming the GPUs and what to free

**Talking points:**
- *"One question before spending money on a deploy. If there's no capacity, the agent says so immediately — no failed deployment, no wasted 10-minute pod pull."*
- *"It shows exactly what's blocking: 'gpu-node-2 has 2 free A100s, gpu-node-1 is fully allocated by llama3-prod.' Actionable, not just a number."*

**ROI:**
- **Failed deploy cost avoided:** a GPU deploy that fails on Pending pods wastes 10–30 min of engineer time plus cloud GPU allocation cost
- **Audit trail:** capacity check is logged — engineering manager can see who checked before deploying

---

## GPU-B — MIG partitioning (~30s, interactive)
**Persona: Platform engineer** — *"Three teams need GPU access but we only have 2 A100s. I need to share them without a fight."*

**Prompt:**
> *Partition the A100s on gpu-node-1 into 3g.40gb MIG slices so multiple teams can share the GPU.*

**Tools triggered:** `get_mig_status` → `configure_mig` (guardrail fires, confirm required) → device plugin restart

**What the agent produces:**
- Current MIG state per node
- Guardrail: explains the impact (node drain required, running pods affected) and waits for confirmation
- After confirm: applies MIG profile, restarts device plugin, confirms new virtual GPU inventory

**Talking points:**
- *"MIG configuration is one of the most error-prone GPU operations — wrong profile, missed node drain, device plugin not restarted. VibOps handles the full sequence correctly every time."*
- *"The guardrail here is intentional: MIG reconfiguration affects running workloads. The agent surfaces the risk clearly before acting."*
- *"Result: 2 physical A100s → 6 virtual 40GB slices. Three teams, zero GPU fights."*

**ROI:**
- **GPU utilization:** 1 model per GPU → 3 models per GPU — **3× capacity from existing hardware**
- **Hardware spend deferred:** delay next GPU purchase by multiplying effective capacity through partitioning
- **Ops complexity:** MIG setup typically requires GPU expertise + runbook — here it's one sentence with guardrail

---

## GPU-C — NIM deployment (~5min)
**Persona: MLOps engineer** — *"I need an OpenAI-compatible inference endpoint for llama-3.1-8b, production-grade, today."*

**Prompt:**
> *Deploy the NVIDIA NIM for llama-3.1-8b-instruct on the GPU cluster with 2 GPUs.*

**Tools triggered:** `accelerator_diagnose` + `get_cluster_resources` → `nim_list_catalog` → `nim_profiles` → `nim_deploy` (guardrail) → `nim_status` → `nim_test`

**What the agent produces:**
- GPU audit: confirms 2 GPUs available, operator healthy
- NIM catalog lookup: finds llama-3.1-8b-instruct, shows GPU profiles and VRAM requirements
- Deploys NIM via Helm (NGC secret + chart), waits for pod Ready
- Runs a live inference test (`/v1/chat/completions`) and returns the response

> Tip: pre-pull the NIM image to avoid 10–30 min NGC download during a live demo.

**Talking points:**
- *"From zero to OpenAI-compatible inference endpoint in one conversation. The agent handles NGC auth, Helm chart, GPU profile selection — everything."*
- *"The GPU audit before deploy is mandatory: VibOps never launches a NIM blind. If the infra isn't ready, it says so before spending 10 minutes on a failing pull."*
- *"The live inference test at the end is the proof: real tokens, real latency, production-ready endpoint."*

**ROI:**
- **Time to inference endpoint:** 2–4 hours (NGC docs, Helm values, NGC secret, debug) → one conversation + pull time — **95%+ reduction**
- **GPU waste prevented:** failed NIM deploys due to insufficient VRAM or missing operator are caught before launch
- **OpenAI compatibility:** drop-in replacement for OpenAI API — zero app code changes to switch to on-prem inference

---

## GPU-D — GPU cost report (~10s)
**Persona: Engineering manager / FinOps** — *"I need to justify our GPU spend to the CFO and identify where we're wasting money."*

**Prompt:**
> *How much are our GPUs costing us this week? Break it down by team and flag anything that looks like waste.*

**Tools triggered:** `get_gpu_cost_report(hours: 168, gpu_price_per_hour: 2.50)`

**What the agent produces:**
- Total GPU fleet cost for the period (GPUs × $/hr × hours)
- Breakdown by namespace/workload: allocated cost per team
- Idle GPU count with wasted $ amount
- Recommendation: scale down, time-slice, or release idle reservations

**Talking points:**
- *"CFO-level question answered in 10 seconds. Total spend, breakdown by team, and which GPUs are sitting idle burning budget."*
- *"$2.50/hr × 1 idle GPU × 168 hours = $420 of waste identified automatically. One conversation pays for itself."*
- *"This runs weekly as a trigger report — FinOps gets a Slack message every Monday with the GPU waste number. No dashboard, no query, no manual export."*

**ROI:**
- **GPU waste identification:** typically discovered quarterly in budget reviews (if at all) → weekly automated report
- **Cost reduction:** 1 idle A10G GPU at $2.50/hr = $1,800/month saved if caught and released — scales with fleet size
- **FinOps maturity:** GPU cost visibility from day one, no custom dashboards or data pipelines required

---

## GPU-E — Idle GPU detection + rightsizing (~15s)
**Persona: Platform engineer / FinOps** — *"We're paying for GPUs but I suspect half of them are barely used. Show me what we can optimize."*

**Prompt:**
> *Are any of our GPU workloads underutilizing their allocation? I want to know what we can scale down or time-slice.*

**Tools triggered:** `accelerator_detect_waste(threshold_pct: 10)` → idle GPU nodes/pods list → recommendation to `configure_gpu_timeslicing` or `patch_deployment`

**What the agent produces:**
- List of GPU nodes and pods with utilization below threshold
- Per-workload breakdown: allocated GPUs vs observed utilization
- Concrete recommendations: which workloads to time-slice, which to scale down
- Estimated cost savings if recommendations are applied

**Talking points:**
- *"GPU utilization <10% for an hour = a workload monopolizing a GPU it barely uses. Time-slicing turns 1 wasted GPU into 4 shared virtual GPUs."*
- *"The agent doesn't just show the problem — it proposes the fix and executes it in the next sentence: accelerator_detect_waste → configure_gpu_timeslicing → confirm → done."*
- *"This is the rightsizing loop for GPU infra: measure → identify waste → act. VibOps closes it in one conversation instead of a monthly FinOps review."*

**ROI:**
- **Utilization improvement:** GPU time-slicing on an idle GPU → 3–8× more workloads on same hardware
- **Cost per inference:** lower utilization per workload = lower effective cost/token without buying more GPUs
- **Discovery time:** idle GPU identification (kubectl + DCGM query + manual correlation) → 15 seconds automated

---

## Image build & CI pipeline scenarios

> **Prerequisites for scenarios 22–25:**
> - `GIT_TOKEN` set (GitHub PAT, scope: `repo` + `workflow`)
> - `GHCR_TOKEN` set for push to ghcr.io (or `DOCKERHUB_TOKEN`)
> - Configure them in Admin → Git and store registry token via the Secrets tab
> - These scenarios use a real repo (`acme/api-server`) — substitute your own repo name

---

## Scenario 22 — Build and push a Docker image from source (~90s) ✅ validated
**Persona: DevOps / Platform engineer** — *"A developer merged a security patch. I need a new image in the registry in the next 10 minutes — before the prod deploy window opens."*

**Step 1 prompt:**
> *The security fix just landed in main on acme/api-server. Clone the repo, build the image with the Dockerfile at the root, tag it v1.4.3-hotfix, and push it to ghcr.io/acme/api-server. Use my git_token and ghcr_token secrets — I don't want credentials hardcoded anywhere.*

**Tools triggered:** `git_clone(repo: acme/api-server, ref: main, token: @secret:git_token)` → `docker_build_push(image: ghcr.io/acme/api-server:v1.4.3-hotfix, registry_token: @secret:ghcr_token)`

**What the agent produces:**
- Clones the repo at the latest main commit — SHA logged
- Streams the Docker build layer by layer in the chat: `Step 1/12 — FROM python:3.11-slim`, `Step 4/12 — RUN pip install...`, exactly what you'd see in a terminal
- Login via `--password-stdin`: token never appears in any log line, process list, or audit record
- Push completes: `ghcr.io/acme/api-server:v1.4.3-hotfix` — digest returned: `sha256:4a7c3b9e...`

**Step 2 prompt:**
> *Good. Pin the prod deployment to that exact digest — I don't want it to drift on the next pod restart.*

**Tools triggered:** `patch_deployment(name: api-server, namespace: prod, image: ghcr.io/acme/api-server@sha256:4a7c3b9e..., cluster: vibops-dev)`

**What the agent produces:**
- Patches the deployment to the digest — not the tag. Immutable reference.
- Confirms rollout: `api-server 2/2 Running — image: ghcr.io/acme/api-server@sha256:4a7c3b9e...`

**Talking points:**
- *"Two sentences: security patch in prod, pinned to a digest. Without VibOps: checkout locally, docker build, docker push, copy the digest from terminal output, edit values.yaml or run kubectl set image, verify rollout. That's 6 manual steps and 20–30 minutes — for a process that happens multiple times per week."*
- *"The credential story: the agent calls `docker login --password-stdin`. The token is never in any command argument, never in any log line, never in the process list. This is enforced at the connector level — it's not a convention a developer could accidentally bypass."*
- *"The digest is a cryptographic guarantee. `v1.4.3-hotfix` is a mutable tag — anyone can overwrite it. `sha256:4a7c3b9e...` is immutable. If this image is in prod at 3am and a pod restarts, it will pull exactly this image — not whatever `latest` resolves to that day."*
- *"Every step is in the audit trail: commit SHA, build job ID, push digest, who triggered it, when. 'What image is in prod, when was it built, and from which commit?' — instant answer, no digging."*
- *"This runs on the VibOps gateway — the machine that lives next to your cluster. Not on a developer laptop with a different Docker version, a different base image cache, a different build context."*

**ROI:**
- **Time per build cycle:** 20–30 min (checkout, build, push, copy digest, patch deployment, verify) → 2 sentences + build time — **90% reduction**
- **At scale:** a DevOps team doing 10 build/push cycles per week × 25 min × $75/hr = **$1,560/week, $81k/year** — just in manual build overhead for one active project
- **"Works on my machine" builds:** 1 in 5 manual builds fails due to local env differences (Docker version, base image cache, missing layer) → extra 30 min debug per incident × 2 incidents/week = **$5,850/year** in wasted debug time per engineer
- **Security patch SLA:** unpatched prod image window goes from 30+ min (manual) to ~5 min (build time only) — critical for CVE response SLAs
- **Audit compliance:** "which commit is in prod and who deployed it?" answered in 1 query vs a manual git log + kubectl + Slack archaeology session

---

## Scenario 23 — CI gate before deploy (~2–4min, 2-step) ✅ validated
**Persona: DevOps / MLOps** — *"The team ships fast but we've had two staging incidents this quarter from untested deploys. I need a mandatory CI gate that nobody can forget or skip."*

**Step 1 prompt:**
> *Before we deploy anything to staging today, trigger the integration-tests.yml workflow on acme/api-server against the main branch. Wait for the result — if it fails, I want to know before we touch the cluster.*

**Tools triggered:** `ci_trigger(repo: acme/api-server, workflow: integration-tests.yml, ref: main)` → `ci_wait(repo: acme/api-server, run_id: <polled from runs API>, timeout: 900)`

**What the agent produces — happy path:**
- Dispatches the GitHub Actions `workflow_dispatch` event
- Polls the run status every 5 seconds — visible in the tool log pane
- `✅ integration-tests.yml — success — 2m 14s — run #9831742`
- Direct link to the GitHub Actions run summary

**What the agent produces — failure path:**
- `❌ integration-tests.yml — failure — 1m 47s`
- Agent stops: *"The integration tests failed on run #9831742. I won't proceed with the deploy. Here's the link to the failing step."*
- **No cluster action happens.** The gate is structural — the agent does not ask "are you sure?", does not offer to override, does not deploy on the next prompt unless the tests are fixed and retriggered.

**Step 2 prompt (after CI passes):**
> *Tests passed. Deploy the api-server Helm release to staging on vibops-dev, set the image tag to main, and confirm the pods are healthy.*

**Tools triggered:** `helm_upgrade(release: api-server, namespace: staging, cluster: vibops-dev, set: image.tag=main)` → `get_deployment_status`

**What the agent produces:**
- Helm upgrade: revision 8 → `api-server` upgraded
- `2/2 pods Running` in staging — rollout confirmed

**Talking points:**
- *"The gate is real. When the tests fail, VibOps stops — it doesn't ask 'are you sure?' and proceed anyway. This is enforced structurally: ci_wait returns a terminal status and the agent branches on it, exactly like the PolicyEngine confirmation flow for destructive actions."*
- *"No new CI/CD YAML to write. VibOps triggers the GitHub Actions workflows you already have — it's not a parallel CI system, it's the orchestration layer that connects your existing pipelines to your deploy flow."*
- *"The Admin → CI panel shows this run the moment it's triggered: repo, workflow, branch, live status, duration, and a direct link to the GitHub Actions log. Every team member can see the gate status without leaving the console."*
- *"This works identically for GitLab CI: same prompt, same behavior, `ci_trigger` dispatches a GitLab pipeline instead. The connector normalizes the two providers — your operators don't need to know which one you're using."*
- *"The audit trail logs two jobs: ci_trigger and ci_wait, both with inputs and outputs. 'Did we run CI before this deploy?' is now a queryable fact, not a process question."*

**ROI:**
- **Bad staging deploys:** a team shipping 20 times/week typically sees 2–3 untested deploys/week slip through — each costs 30–45 min of debug + rollback = **$75–$112/incident** × 120/year = **$9,000–$13,500/year per team** in wasted debugging time
- **Bad deploy reaching prod:** 1–2 times/year for a team without a mandatory CI gate → P2 incident = 2–4 hours × 2 engineers at $75/hr = **$300–$600 per incident** + revenue exposure (SaaS at $1M ARR loses ~$115/min)
- **Context switching cost:** without VibOps, each deploy cycle requires 4–5 tool switches (terminal → GitHub Actions UI → kubectl → Slack → back) at ~15 min recovery each = 60–75 min of invisible friction per deploy × 20 deploys/week = **$1,125–$1,406/week, ~$65k/year per engineer**
- **Zero new CI infrastructure:** the CI connector reuses existing GitHub Actions / GitLab CI pipelines. No new YAML to write, no new secret to rotate, no new system to maintain — the marginal cost of the gate is one prompt

---

---

## Scenario 24 — Full pipeline: clone → build → CI → deploy (~5min) ✨ crown jewel
**Persona: DevOps / Platform engineer** — *"PR #47 just merged. I want to go from source code to a validated deployment in staging without opening a terminal — and I want the chain of custody documented for the next SOC 2 audit."*

**Prompt:**
> *PR #47 just merged to main on acme/api-server. Here's the full release flow: clone main, build and push the image to ghcr.io/acme/api-server:1.5.0 using my ghcr_token, trigger the smoke-tests.yml workflow on that same branch, wait for it to complete — if it passes, deploy the api-server Helm release to staging on vibops-dev using the exact image digest. If the tests fail, stop and tell me what broke.*

**Tools triggered (sequential, agent manages the chain):**
1. `git_clone(repo: acme/api-server, ref: main, token: @secret:git_token)` → commit SHA: `a3f8c21`
2. `docker_build_push(image: ghcr.io/acme/api-server:1.5.0, registry_token: @secret:ghcr_token)` → digest: `sha256:9f1e2d8c...`
3. `ci_trigger(repo: acme/api-server, workflow: smoke-tests.yml, ref: main)` → run_id: `9831742`
4. `ci_wait(run_id: 9831742, timeout: 900)` → `success — 2m 31s`
5. `helm_upgrade(release: api-server, namespace: staging, cluster: vibops-dev, set: image.digest=sha256:9f1e2d8c...)` → revision 12

**What the agent produces:**
- Progress visible step by step in the tool log — the operator watches the pipeline execute in real time
- Docker build streams layer by layer during step 2
- CI polling every 5 seconds during step 4 — status updates visible
- Final confirmation: *"api-server deployed to staging. Image: `ghcr.io/acme/api-server:1.5.0@sha256:9f1e2d8c...`. Smoke tests: success in 2m 31s (run #9831742). Helm revision 12. Commit: a3f8c21."*

**If smoke tests fail at step 4:**
- Agent halts before helm_upgrade: *"Smoke tests failed on run #9831742 after 1m 47s. The image was built and is available at `ghcr.io/acme/api-server:1.5.0` but I didn't touch staging. Fix the tests and re-run the pipeline."*
- Staging cluster is in exactly the state it was before — no partial deploy, no rollback needed
- The build image is preserved in the registry — no need to rebuild when tests are fixed

**Talking points:**
- *"That's a full CD pipeline — source code to validated staging deployment — in one sentence. Without VibOps: open a terminal, checkout, docker build (10 min), docker push, copy the digest from the output, open GitHub Actions, kick off the workflow manually, wait, open kubectl, helm upgrade with the digest, verify rollout. That's 8 manual steps, 4 tool switches, and 45–60 minutes of a senior engineer's time. Every time a PR merges."*
- *"The chain of custody is automatic: git commit SHA `a3f8c21` → image digest `sha256:9f1e2d8c...` → CI run #9831742 → Helm revision 12. Every link in the chain is in the VibOps audit trail. When your auditor asks 'what's in staging and what approved it?', that's a one-query answer."*
- *"Image pinned to a digest, not a tag. `1.5.0` is a mutable label — anyone can overwrite it. `sha256:9f1e2d8c...` is cryptographically immutable. The pod running in staging at 3am is guaranteed to be the exact image that passed your smoke tests — not whatever the tag resolves to that day."*
- *"The CI gate is structural. When smoke tests fail, step 5 never runs. Not 'VibOps asked and the engineer said no' — the deploy branch literally does not execute. Same guarantee as the PolicyEngine confirmation gate for destructive actions."*
- *"Any team member can trigger this — not just the senior DevOps engineer who knows the Docker push syntax and the kubectl set image command. The knowledge is in the prompt, not in the person."*

**ROI:**
- **Time per release cycle:** 45–60 min manual (checkout, build, push, kick CI, wait, deploy, verify) → one sentence + pipeline execution time — **95% reduction**
- **At scale:** a team shipping 10 releases/week × 50 min × $75/hr = **$625/week, $32,500/year** — and this is before accounting for the incidents that manual pipelines generate
- **CD pipeline setup cost avoided:** writing and maintaining a GitHub Actions or Jenkins CD pipeline for this flow = 3–5 days initial + 2 hrs/month maintenance = **$2,250–$3,750 one-time + $1,800/year** per project, per pipeline variant — VibOps replaces this with zero infrastructure
- **SOC 2 audit preparation:** reconstructing "what commit is in prod, which CI run approved it, and who deployed it" manually takes 1–2 days per quarter = **$4,500–$9,000/year** in compliance overhead — the VibOps audit trail answers this instantly for every deployment
- **Wrong-digest deploys:** copy-pasting a 64-character sha256 digest from terminal output is a well-known error source — one transposed character = wrong image in prod. Automatic digest propagation from build step to deploy step eliminates this class of error entirely
- **Team scaling:** onboarding a junior engineer to run the full release flow takes days when the process lives in runbooks; with VibOps it takes one prompt demonstration

---

---

## Scenario 25 — Registry inspection + image drift detection (~20s)
**Persona: MLOps engineer / Platform engineer** — *"We had a mystery regression last week. A pod restarted in prod and started returning different outputs. I want to know if we have any environments running untagged images before it happens again."*

**Step 1 prompt:**
> *Do a registry audit for me: list all available tags for ghcr.io/acme/api-server, then check what image tag prod and staging are actually running. Tell me if anything is untagged, running latest, or if the two environments have drifted from each other.*

**Tools triggered:** `registry_list_tags(image: ghcr.io/acme/api-server, token: @secret:ghcr_token)` → `get_deployment_status(name: api-server, namespace: prod)` + `get_deployment_status(name: api-server, namespace: staging)` in parallel

**What the agent produces:**
- Registry: 23 tags — `v1.5.0`, `v1.4.3-hotfix`, `v1.4.2`, `v1.4.1`, `v1.4.0`, `main`, `latest` ...
- Prod: `api-server` running `ghcr.io/acme/api-server:latest` — **⚠ RISK: untagged image, imagePullPolicy: Always**
- Staging: `api-server` running `ghcr.io/acme/api-server:v1.5.0` — pinned, OK
- **Drift detected:** prod is behind staging by 2 versions. Prod is on `latest`, staging is on `v1.5.0`.
- *"Prod is running `latest` with `imagePullPolicy: Always`. Any pod restart — OOM, node drain, rolling update — will pull whatever `latest` resolves to at that moment. This is most likely the cause of your mystery regression last week."*

**Step 2 prompt:**
> *Pin prod to the same image as staging right now. I want both environments on v1.5.0.*

**Tools triggered:** `patch_deployment(name: api-server, namespace: prod, image: ghcr.io/acme/api-server:v1.5.0)` → `get_deployment_status`

**What the agent produces:**
- Prod patched to `v1.5.0`, rollout confirmed: `2/2 Running`
- *"Prod and staging are now both on `v1.5.0`. `latest` drift risk eliminated."*

**Talking points:**
- *"The mystery regression last week was almost certainly this: a pod restarted in prod, pulled `latest`, and got a newer model than the one that was running. No deploy happened. No one noticed. The image just quietly changed. VibOps flags this in 20 seconds — before the next restart."*
- *"This is a cross-layer check: registry state + running deployment state, compared and correlated in a single query. Manually, that's: log into the GHCR UI, list tags, open a terminal, kubectl get deployment in prod, kubectl get deployment in staging, compare the image strings by hand. 10–15 minutes of mechanical work, easy to miss a detail under pressure."*
- *"Two separate risks surfaced and fixed in one conversation: the untagged image (drift risk) and the prod/staging version gap (promotion gap). In a typical ops review, you'd catch at most one of these — and only if someone thought to check."*
- *"`imagePullPolicy: Always` with an untagged image is the configuration that killed the reliability of production systems you thought were stable. It's not rare: surveys consistently show 30–40% of production deployments have at least one service running `latest`. VibOps makes this visible and fixable in seconds."*
- *"Run this as a pre-deploy gate every time: 'Check the registry before we promote to prod.' It costs 20 seconds and eliminates an entire class of regression."*

**ROI:**
- **Registry audit time:** 10–15 min (GHCR UI + 2× kubectl + manual comparison) → 20s — **97% reduction**; a 5-service platform audited daily: 10 min × 5 × 260 days = **217 hrs/year = $16,275/year** in manual audit overhead eliminated
- **Image drift incident cost:** avg 45 min to diagnose (correlate restart event + image pull log + registry state) + 15 min to fix = **$75 per incident**; teams typically experience this 1–2×/month = **$900–$1,800/year per team**; at 10 teams: **$9,000–$18,000/year** in drift-related incident cost
- **Mystery regression from `latest`:** the harder cases — where `latest` pulled a breaking model change — cause P2/P3 incidents (2–4 hrs × 2 engineers = $300–$600) and user-facing quality degradation; with SaaS revenue at $1M ARR, **each unexplained regression episode costs $500–$2,000** in engineering + trust
- **Avoided registry tooling cost:** JFrog Xray, Anchore, or similar registry scanning platforms start at **$10k–$50k/year**; this audit capability is built into VibOps with no additional license
- **Pre-deploy gate at zero marginal cost:** running this check before every prod promotion adds 20 seconds per deploy and eliminates the entire drift risk category — the ROI is asymmetric: 20 seconds of prevention vs a 45-min incident every time it's skipped

---

## Scenario 26 — Deploy a private image to Kubernetes (~60s, 2-step)

**Context:** The team has just pushed a new image to their private GHCR registry (e.g., result of Scenario 22). They now want to deploy it to their production Kubernetes cluster. The cluster has never pulled from this registry before — no pull secret exists yet.

**Prerequisites:**
- A running Kubernetes cluster reachable from the VibOps worker (any distribution: EKS, GKE, AKS, RKE2, bare metal)
- `GHCR_TOKEN` stored as `@secret:ghcr_token`

---

**Step 1 prompt:**
> *We need to deploy ghcr.io/acme/api-server:v1.2.3 on the prod cluster, namespace api. The registry is private. Set up the credentials and deploy it on port 8080.*

**Tools triggered (in sequence):**
1. `setup_kubeconfig(cluster: prod-cluster)` — configures kubectl context
2. `create_pull_secret(name: ghcr-pull-secret, registry: ghcr.io, registry_username: acme-bot, registry_token: @secret:ghcr_token, namespace: api)` — creates/updates the pull secret (idempotent)
3. `deploy_webapp(name: api-server, image: ghcr.io/acme/api-server:v1.2.3, port: 8080, namespace: api, image_pull_secret: ghcr-pull-secret)` — creates Deployment + NodePort Service with `imagePullSecrets`

**What the agent produces:**
- *"Pull secret `ghcr-pull-secret` created in namespace `api` — registry credentials stored."*
- *"Deployment `api-server` (ghcr.io/acme/api-server:v1.2.3) deployed in namespace `api` on port 8080 with imagePullSecrets: ghcr-pull-secret."*
- No `ImagePullBackOff`. No manual `kubectl create secret`. One prompt.

---

**Step 2 prompt:**
> *Good. Now update it to v1.2.4 — image is already in the registry.*

**Tools triggered:** `patch_deployment(name: api-server, namespace: api, image: ghcr.io/acme/api-server:v1.2.4)`

**What the agent produces:**
- Deployment patched, rollout confirmed: `2/2 Running`
- *"The pull secret is already in place — no credentials step needed for updates."*

---

**Talking points:**
- *"The most common reason a Kubernetes deploy fails in practice is not a bug in the app — it's `ImagePullBackOff` because no one set up credentials for the registry. VibOps handles that in the same prompt as the deploy. You don't even have to think about it."*
- *"This works on any cluster you have kubectl access to — EKS, GKE, AKS, on-prem, bare metal. It's not kind-specific. Whatever is in your kubeconfig is a valid target."*
- *"`create_pull_secret` uses `--dry-run=client -o yaml | kubectl apply` — it's idempotent. Running it again on the next deploy rotation doesn't fail, doesn't create duplicates. It just refreshes the token if it changed."*
- *"Step 2 shows the steady-state flow: once the secret exists, every subsequent deploy is a single `patch_deployment`. The credential setup is a one-time operation per cluster/namespace pair."*
- *"In a typical team without VibOps, this is: find the right `kubectl create secret` syntax, get the registry URL right, get the base64 encoding right, apply it to the right namespace, then run the deployment manifest — 15–20 minutes for a developer who doesn't do it daily, and at least one StackOverflow lookup. With VibOps: one prompt, 10 seconds."*

**ROI:**
- **ImagePullBackOff incidents:** avg 20–30 min to diagnose and fix (check pod events, find correct `kubectl create secret` syntax, apply to right namespace, re-trigger rollout) — **$42–$63 per incident** at $125/hr; teams typically hit this 3–4×/year per cluster × 5 clusters = **$630–$1,260/year** in avoidable toil
- **New cluster onboarding:** each new cluster requires pull secrets to be replicated to every namespace; without automation, 5 namespaces × 3 registries × 15 min = 225 min per cluster onboard; at 3 new clusters/year: **$1,406/year** saved
- **Reduced deploy friction on regulated environments:** teams deploying to airgapped or restricted clusters (banking, healthcare, defense) cannot use public images — private registry is mandatory; every deploy requires a credential step; VibOps absorbs this entirely
- **Reduced on-call escalation:** `ImagePullBackOff` on a prod cluster at 2am generates P2 alerts — cost is $300–$800/incident (on-call premium + incident management) vs. a credential check that takes 10 seconds
- **Compound effect with Scenario 22:** the S22 + S26 chain covers the full cycle: source code → built image → credential setup → deployed to K8s. This is what a mature GitOps pipeline does. VibOps does it via natural language in under 3 minutes.

---

## Scenario 27 — GitOps loop: ArgoCD auto-sync (~30s, 2-step)

**Context:** The team uses ArgoCD to manage their cluster. Today, every time a developer merges to main, someone has to remember to go into the ArgoCD UI and click "Sync" — or the cluster silently falls behind git. VibOps closes this loop.

---

**Step 1 prompt:**
> *Enable auto-sync on the api-server application in ArgoCD. I want the cluster to update automatically whenever we push to git. Also enable self-healing — if someone patches the cluster manually it should revert to git.*

**Tools triggered:**
1. `argocd_get_app(name: api-server)` — reads current spec (implicit in enable_auto_sync)
2. `argocd_enable_auto_sync(name: api-server, prune: true, self_heal: true)`

**What the agent produces:**
- *"Auto-sync enabled on 'api-server' (prune=true, selfHeal=true)."*
- *"ArgoCD will now sync automatically within 3 minutes of any git push. Manual cluster changes will be reverted to the git state."*

---

**Step 2 prompt:**
> *Good. Now update the image to v1.3.0 in the Helm values and push it. Don't sync manually — I want to see auto-sync kick in.*

**Tools triggered:** `git_clone` → `git_patch_yaml(file: helm/values.yaml, path: image.tag, value: v1.3.0)` → `git_commit_push`

**What the agent produces:**
- Commit pushed to `main`
- *"Commit pushed. ArgoCD will detect the change within 3 minutes and apply it automatically — no manual sync needed. Monitor with argocd_get_app(name: api-server) to see the rollout."*

**Talking points:**
- *"Before this, every git push needed a human to remember to sync ArgoCD. With auto-sync enabled, the cluster is always exactly what's in git — nothing more, nothing less. The human step is gone."*
- *"selfHeal=true is the stronger guarantee: even if an engineer patches a deployment directly with kubectl, ArgoCD will revert it within 3 minutes. Git is the only source of truth."*
- *"prune=true means resources you delete from git are also deleted from the cluster. Without it, deleted manifests accumulate silently and you end up with ghost deployments consuming resources you forgot about."*
- *"This is the difference between 'we have ArgoCD' and 'we have GitOps'. Many teams install ArgoCD but keep triggering syncs manually — they have the tool but not the practice. VibOps sets the practice in one prompt."*
- *"You can also disable it: argocd_disable_auto_sync before a manual intervention window, re-enable after. The agent handles the maintenance window without UI access."*

**ROI:**
- **Manual sync overhead:** each git push requires a human to open the ArgoCD UI, find the app, click Sync — avg 3–5 min; at 8 deploys/day × 250 days = 2,000 syncs/year × 4 min = **133 hrs/year = $9,975/year** in wasted engineering time
- **Missed sync incidents:** when someone forgets to sync, prod runs stale code; avg 45 min to notice + diagnose + fix = **$94/incident**; teams report this 2–3×/month = **$2,256–$3,384/year**
- **Drift from manual kubectl patches:** without selfHeal, manual fixes accumulate; at audit time (SOC2, ISO27001), unexplained config drift = findings; each finding = **$2,000–$5,000** in remediation + auditor time
- **ArgoCD UI access elimination:** with VibOps, operators who don't have ArgoCD UI credentials can still manage sync policy via the agent — reduces access proliferation and audit surface

---

## Scenario 28 — Cloud registry deploy: ECR / GCR / ACR (~45s)

**Context:** The client runs EKS on AWS (or GKE on GCP, or AKS on Azure). Their images are in a private cloud registry. The equivalent of Scenario 26, but the token is managed by the cloud provider and expires — it can't be stored as a static PAT.

---

**EKS + ECR variant**

**Prompt:**
> *We need to deploy our new API to EKS. The image is in our ECR registry at 123456789.dkr.ecr.eu-west-1.amazonaws.com/api-server:v2.1.0. Set up the credentials and deploy it in the api namespace.*

**Tools triggered:**
1. `create_ecr_pull_secret(name: ecr-pull-secret, registry: 123456789.dkr.ecr.eu-west-1.amazonaws.com, region: eu-west-1, namespace: api)`
   — fetches short-lived token via `aws ecr get-login-password`
2. `deploy_webapp(name: api-server, image: 123456789.dkr.ecr.eu-west-1.amazonaws.com/api-server:v2.1.0, port: 8080, namespace: api, image_pull_secret: ecr-pull-secret)`

**What the agent produces:**
- *"ECR pull secret 'ecr-pull-secret' created in namespace 'api' (token valid 12 hours)."*
- *"Deployment 'api-server' running v2.1.0 in namespace 'api'."*

---

**GKE + Artifact Registry variant**

**Prompt:**
> *Deploy the model server on GKE. Image is europe-west1-docker.pkg.dev/acme-project/ml-models/inference:v3.0. Use the GCP service account from vault.*

**Tools triggered:**
1. `create_gcr_pull_secret(name: gar-pull-secret, registry: europe-west1-docker.pkg.dev, key_json: @secret:gcp_sa_key, namespace: ml)`
2. `deploy_webapp(name: inference-server, image: europe-west1-docker.pkg.dev/acme-project/ml-models/inference:v3.0, port: 8080, namespace: ml, image_pull_secret: gar-pull-secret)`

---

**Talking points:**
- *"ECR tokens expire after 12 hours. In a standard setup, that means someone has to refresh the pull secret manually before each deploy rotation, or the next pod restart fails with ImagePullBackOff. VibOps fetches a fresh token automatically every time you call create_ecr_pull_secret — you never manage token expiry."*
- *"The same interface works for ECR, GCR, and ACR. Your ops team doesn't need to know the specific aws ecr / gcloud auth / az acr commands for each cloud. One natural language prompt, the agent picks the right action."*
- *"This is particularly valuable for multi-cloud setups: some workloads on AWS, some on GCP, some on Azure. Without VibOps, that's three different credential workflows, three different CLI syntaxes. With VibOps, it's the same prompt."*

**ROI:**
- **ECR token refresh overhead:** 5 min per cluster per refresh cycle; at 2 clusters × 2 refreshes/day × 250 days = 2,500 refreshes/year × 5 min = **208 hrs/year = $15,625/year** at $75/hr SRE cost
- **ImagePullBackOff from expired ECR token:** P2 incident at 2am — avg $500 per incident (on-call + incident management); happens 4–6×/year per team = **$2,000–$3,000/year**
- **Multi-cloud credential standardisation:** eliminating per-cloud documentation, onboarding, and tribal knowledge — **$3,000–$5,000/year** in knowledge management overhead for a 5-person ops team

---

## Scenario 29 — OpenShift deploy (~45s, 2-step)

**Context:** Enterprise prospect running OpenShift (common in banking, telecom, public sector, defense). Their platform team uses OpenShift because of its security defaults and enterprise support. VibOps works on OpenShift — same interface, two additional actions for OpenShift-specific primitives (SCC + Route).

---

**Step 1 prompt:**
> *Deploy our inference API on OpenShift, namespace inference. Image is registry.acme.com/inference-api:v1.0. The app needs to run as a non-root user so it'll need the anyuid SCC.*

**Tools triggered:**
1. `create_pull_secret(name: acme-pull-secret, registry: registry.acme.com, registry_username: robot, registry_token: @secret:acme_registry_token, namespace: inference)`
2. `openshift_add_scc(scc: anyuid, service_account: default, namespace: inference)`
3. `deploy_webapp(name: inference-api, image: registry.acme.com/inference-api:v1.0, port: 8080, namespace: inference, image_pull_secret: acme-pull-secret)`

**What the agent produces:**
- *"Pull secret 'acme-pull-secret' created in namespace 'inference'."*
- *"SCC 'anyuid' added to serviceaccount 'default' in namespace 'inference'."*
- *"Deployment 'inference-api' running v1.0 in namespace 'inference'."*

---

**Step 2 prompt:**
> *Now expose it externally at inference-api.apps.acme.com.*

**Tools triggered:** `openshift_create_route(service: inference-api, hostname: inference-api.apps.acme.com, namespace: inference)`

**What the agent produces:**
- *"Route 'inference-api' created — inference-api.apps.acme.com → inference-api in namespace 'inference'."*

---

**Talking points:**
- *"OpenShift has stricter security defaults than vanilla Kubernetes — the SCC system prevents containers from running as root by default. This is a good thing for security, but it means nearly every workload needs an SCC configured before it can start. VibOps handles this in the same prompt as the deploy."*
- *"Routes are OpenShift's equivalent of Ingress. The syntax is different, the YAML is different, the oc CLI is different — but the VibOps prompt is identical. An operator who knows 'expose it at this hostname' doesn't need to know whether the cluster uses Ingress or Routes."*
- *"Your OpenShift platform team doesn't need to give every developer oc CLI access or OpenShift console access. They can expose VibOps as the ops interface — and the platform team keeps full audit trail of every action taken."*
- *"Everything else — deploy_webapp, patch_deployment, scale_cluster, get_recent_logs, health_check — works unchanged on OpenShift. You don't learn a new tool, you just gain two new actions for OpenShift-specific primitives."*

**ROI:**
- **OpenShift SCC friction:** every new workload requires SCC configuration; without automation, this is a ticket to the platform team (avg 2–4 hour SLA) × 3 new workloads/sprint × 26 sprints = **156–312 hrs/year of platform team tickets** at $125/hr = **$19,500–$39,000/year** in coordination overhead
- **oc CLI onboarding:** teaching developers the oc CLI, OpenShift console, and RBAC adds 1–2 days per new hire; at 5 hires/year × 1.5 days × $600/day = **$4,500/year** in onboarding overhead
- **Route configuration errors:** incorrect hostname, missing TLS termination, wrong port — each a 30–60 min debug session; at 2×/month = **$1,875–$3,750/year**
- **Audit trail for compliance:** OpenShift clusters in regulated sectors require evidence of every change; VibOps audit log satisfies this automatically — replaces or supplements manual change management ticketing

---

## Scenario 30 — Slurm HPC: multi-node GPU training job submission (~60s, interactive)

**Persona: MLOps engineer** — *"We have a Slurm cluster for large-scale training. I need to launch a multi-node job without logging into the head node."*

**Context:** The client runs GPU training on a bare-metal Slurm cluster (not Kubernetes). Their MLOps team currently SSHes into the head node to run `sbatch` manually — no audit trail, no approval gate, no visibility for the wider team. The SSH key is stored in VibOps Secrets Vault. The cluster is registered in VibOps as a Slurm gateway (see Scenario 33) — connection via `slurm_config` JSONB, transport REST > SSH+JSON, no env vars required.

---

**Step 1 prompt:**
> *Check the GPU capacity on our Slurm cluster (gpu.hpc.acme.com) — specifically the gpu partition. How many nodes are available and what's the queue looking like?*

**Tools triggered:**
1. `slurm_get_cluster_info(host: gpu.hpc.acme.com, partition: gpu)`
2. `slurm_list_jobs(host: gpu.hpc.acme.com, partition: gpu, state: running)`

**What the agent produces:**
- *"Cluster gpu.hpc.acme.com — gpu partition: 8 nodes, 64 GPUs (A100 80GB). 5 nodes available, 3 running jobs (2 pending). Estimated wait for 4-node allocation: ~12 minutes based on current queue depth."*

---

**Step 2 prompt:**
> *Submit a training job: 4 nodes, 8 GPUs per node, run train.py with batch_size=512, epochs=50. Use the gpu partition. Job name: llm-finetune-v3.*

**Tools triggered:**
1. `slurm_submit_job(job_name: llm-finetune-v3, nodes: 4, gpus_per_node: 8, partition: gpu, script: train.py, host: gpu.hpc.acme.com, dry_run: true, ssh_key: @secret:slurm_ssh_key)`

**What the agent produces (dry run preview):**
```
#!/bin/bash
#SBATCH --job-name=llm-finetune-v3
#SBATCH --nodes=4
#SBATCH --gpus-per-node=8
#SBATCH --partition=gpu
#SBATCH --output=/var/log/slurm/llm-finetune-v3-%j.out
#SBATCH --error=/var/log/slurm/llm-finetune-v3-%j.err

srun python train.py --batch_size=512 --epochs=50
```
*"This will request 4 nodes × 8 GPUs = 32 A100s. Confirm to submit?"*

---

**Step 3 prompt:**
> *Yes, submit it.*

**Tools triggered:** `slurm_submit_job(confirmed: true, ...)`

**What the agent produces:**
- *"Job submitted — ID: 48291. Status: PENDING (waiting for 4-node allocation). Estimated start: ~12 min. Use slurm_get_job_status(48291) to track progress."*

---

**Talking points:**
- *"The dry-run step is not optional theatre — it's how you prevent a 32-GPU allocation mistake at $12/hr per GPU. The sbatch script is shown before any job is scheduled."*
- *"The SSH key never leaves VibOps Vault. The MLOps engineer typed @secret:slurm_ssh_key — they never saw the key, it was never in chat history, it was never on their laptop."*
- *"The job ID is automatically saved to the agent's memory. Next session, the engineer can ask 'what happened to llm-finetune-v3?' and the agent will know job ID 48291 without them remembering it."*
- *"This is the same VibOps interface the team uses for Kubernetes. Slurm cluster or K8s cluster — same natural language prompt, same audit log, same policy gate. The platform team doesn't run two operations workflows."*

**ROI:**
- **sbatch error rate:** misconfigured `--nodes`, `--gres`, wrong partition — each failed allocation wastes queue wait + engineer time; avg 45 min per incident × 3/month = **$337/month = $4,050/year** at $75/hr
- **GPU idle time from misallocation:** requesting wrong node count or wrong partition causes jobs to sit pending instead of running; at $12/hr × 32 GPUs × 2 hr avg delay × 3/month = **$2,304/month**
- **Audit trail for HPC:** Slurm logs job IDs but not *who* submitted *what* and *why*; VibOps adds org/user attribution to every submission — satisfies security review requirements without additional tooling
- **SSH access elimination:** every MLOps engineer with Slurm access is an attack surface; VibOps eliminates the need for individual SSH keys on the head node — **reduces privileged access scope**

---

## Scenario 31 — Slurm HPC: monitor training progress and tail logs (~30s)

**Persona: MLOps engineer** — *"My training job is running — I want to check progress without SSH-ing into the cluster."*

**Context:** Job 48291 (llm-finetune-v3) is running on 4 nodes. The engineer wants to check the status and pull the last 50 lines of training logs — from their laptop, via the VibOps console.

---

**Prompt:**
> *What's the status of my llm-finetune-v3 job? Show me the last 50 lines of logs.*

**Tools triggered:**
1. `slurm_get_job_status(job_id: 48291, host: gpu.hpc.acme.com)`
2. `slurm_get_job_output(job_id: 48291, host: gpu.hpc.acme.com, lines: 50)`

**What the agent produces:**
- *"Job 48291 (llm-finetune-v3) — RUNNING. Node list: gpu-node-[03-06]. Wall time: 01:23:47 / 08:00:00. Exit code: N/A (still running)."*
- Last 50 lines of training output, e.g.:
```
Epoch 12/50: loss=1.847 | acc=0.623 | lr=2.4e-5
Epoch 12/50: throughput=1,842 tokens/s | grad_norm=0.91
Epoch 13/50: loss=1.791 | acc=0.641 | lr=2.3e-5
...
```

---

**Talking points:**
- *"No SSH. No `squeue`. No `tail -f`. The engineer opens the VibOps console, types one sentence, and sees live training metrics — from anywhere, including mobile."*
- *"Compare this to the alternative: SSH key management for every MLOps engineer, head node access, knowing the exact log file path in /var/log/slurm/llm-finetune-v3-48291.out. VibOps handles all of that transparently."*
- *"The log path is resolved automatically from the job ID. The engineer doesn't need to know the Slurm job output naming convention."*
- *"This is real-time ops intelligence — you see gradient norm, throughput, and loss trend without leaving the ops platform. Useful for catching diverging runs early and cancelling before wasting more GPU time."*

**ROI:**
- **SSH overhead per monitoring check:** 3–5 min (open terminal, SSH, navigate to log path, tail) vs 10s (VibOps prompt); at 6 checks/day × 5 MLOps engineers × 250 days = **7,500 checks/year × 4 min saved = 500 hrs/year = $37,500/year**
- **Early divergence detection:** catching a failed training run at epoch 13 instead of epoch 48 saves ~70% of GPU compute; at $12/hr × 32 GPUs × 6 hr saved = **$2,304 per early catch**; conservative 2 catches/month = **$55,296/year**
- **Access audit:** every log read is recorded in VibOps audit log — who checked what job, when — satisfying compliance requirements for regulated environments

---

## Scenario 32 — Slurm HPC: cancel a runaway job (~20s, interactive)

**Persona: MLOps engineer / SRE on-call** — *"The training job is diverging — loss is exploding. Cancel it before we burn more GPU budget."*

**Context:** Job 48291 is consuming 32 A100s at $12/hr each = $384/hr. The loss curve is clearly diverging (loss went from 1.8 to 14.3 in 3 epochs). The engineer needs to cancel it immediately.

---

**Prompt:**
> *Cancel job 48291 on gpu.hpc.acme.com. Loss is diverging — kill it.*

**Tools triggered:**
1. `slurm_cancel_job(job_id: 48291, host: gpu.hpc.acme.com, dry_run: true)`

**What the agent produces (confirmation gate):**
- *"This will send SIGTERM to job 48291 (llm-finetune-v3) on 4 nodes. The job will be terminated and the allocation released. Confirm?"*

---

**Follow-up prompt:**
> *Yes, cancel it.*

**Tools triggered:** `slurm_cancel_job(job_id: 48291, confirmed: true, ...)`

**What the agent produces:**
- *"Job 48291 cancelled. Signal SIGTERM sent. Allocation for 4 nodes (32 GPUs) released. Estimated cost savings: ~$384/hr × remaining 6h17m = $2,413 recovered."*

---

**Talking points:**
- *"The confirmation gate matters here — cancelling the wrong job ID on a shared HPC cluster affects other teams. The agent shows you exactly what it's about to do before it does it."*
- *"Notice the cost estimate in the confirmation. VibOps knows the wall time limit and current runtime — it can calculate the remaining GPU cost and show it inline. This is ops intelligence, not just command execution."*
- *"On a shared Slurm cluster, 32 A100s blocked by a diverging job are 32 A100s not available to the rest of the team. Speed of cancellation is a team resource issue, not just a personal cost issue."*
- *"Alternative without VibOps: SSH to head node, run `squeue -u $USER`, find the job ID, run `scancel 48291`, confirm status with `squeue`. Five steps, each requiring Slurm expertise. With VibOps: one sentence."*

**ROI:**
- **GPU cost recovery from fast cancellation:** cancelling a diverging 32-GPU job 30 min faster than the manual process saves 32 × $12/hr × 0.5 hr = **$192 per incident**; at 3 diverging runs/month = **$6,912/year**
- **Prevent accidental cancellation:** the dry-run gate prevents `scancel` on the wrong job ID — each misfired cancel on a production job = 2–4 hr re-run + team disruption; at $12/hr × 32 GPUs × 3 hr = **$1,152 per incident avoided**
- **On-call response time:** an SRE receiving a GPU budget alert at 2am can cancel via VibOps console without SSH credentials to the Slurm head node — eliminates the "I don't have the SSH key on this machine" blocker

---

## Scenario 33 — Connect a Slurm cluster via the console (~2min)
**Persona: Platform engineer / HPC admin** — *"We have a bare-metal HPC cluster with Slurm. I want to onboard it to VibOps without touching any config files."*

**Context:** The team uses the new gateway form (Sprint B) that exposes `gateway_type` and `slurm_config`. No env vars, no restart required — the form generates a JSONB config stored per-gateway in the DB.

---

**Step 1 — Register the Slurm gateway via the console form:**
1. Open console → **Fleet** tab → **"Add a gateway"** (or ⚙ Admin → Gateways → New Gateway)
2. Name: `hpc-slurm-prod` | Clusters: `gpu-partition`
3. **Gateway type:** select **Slurm (HPC)**
4. Slurm section appears:
   - Host: `slurm.hpc.acme.com` | SSH user: `vibops` | SSH port: `22`
   - slurmrestd URL: `http://slurmctld:6820` (optional — enables REST transport)
   - SSH key secret: `slurm-ssh-key` (references VibOps Secrets Vault)
5. Click *Register gateway* → token shown once → deploy the gateway agent via Helm on the HPC head node

**Step 2 prompt:**
> *The Slurm gateway just came online. Confirm it's visible and show me the current GPU job queue on gpu-partition.*

**Tools triggered:** `list_gateways` → `slurm_list_jobs(partition: gpu-partition, state: running)`

**What the agent produces:**
- Gateway `hpc-slurm-prod` online, 1 cluster registered, last ping < 30s ago
- Running jobs on gpu-partition with job IDs, user, GPU count, start time, partition
- Summary: *"3 running jobs, 32 GPUs allocated (A100 80GB), 2 jobs pending in queue."*

**Talking points:**
- *"No YAML. No env var. No restart. A platform engineer fills in a form, deploys one Helm chart, and the Slurm cluster appears in VibOps. 2 minutes vs a full day of connector configuration."*
- *"The SSH key is referenced by name — `slurm-ssh-key` — the plaintext never leaves the VibOps Secrets Vault. The audit log records who added the gateway and when."*
- *"Notice the gateway type is 'slurm' — the same VibOps gateway agent works for Kubernetes, Slurm, or hybrid (both on the same node). One binary, multiple cluster types."*

**ROI:**
- **Onboarding time:** HPC cluster onboarding (manual SSH config, env var management, service restart) → 2 min form fill + Helm deploy
- **Security surface:** eliminates per-engineer SSH keys on the head node — one gateway credential, audited, revokable

---

## Scenario 34 — Slurm GPU accounting: live tracking + exact end times (~15s)
**Persona: FinOps / MLOps engineer** — *"I want to see how many GPU-hours each Slurm job consumed, including jobs that finished in the last hour."*

**Context:** The `workloads` table is updated every 60s by the Celery beat task. For running jobs it calls `squeue --json`; for recently completed jobs it queries `sacct --json --starttime=<now-120s>` to capture the exact `end_time` from Slurm accounting — not a poll-time approximation.

---

**Prompt:**
> *Show me the GPU-hours consumed by each Slurm job on hpc-slurm-prod in the last 24 hours. Which jobs used the most GPU compute?*

**Tools triggered:** `get_workload_gpu_hours(cluster: hpc-slurm-prod, type: slurm_job, hours: 24)` → workloads table query ordered by gpu_seconds_accumulated desc

**What the agent produces:**
- Ranked table of Slurm jobs: job ID, owner, partition, GPU count, started_at, ended_at (exact from sacct), GPU-hours
- Total GPU-hours consumed across all jobs in the window
- Running jobs shown with accumulated GPU-hours so far (updated every 60s)
- Jobs terminated between polls shown with their sacct exact end time (not rounded to poll boundary)

**Talking points:**
- *"Each row in this table was written by VibOps every 60 seconds as the job ran. When the job ended, sacct gave us the exact end timestamp — not 'sometime in the last 60 seconds' but the actual Slurm completion time."*
- *"GPU-hours = gpu_count × runtime. For a 4-GPU job that ran 6 hours: 24 GPU-hours. At $3/hr per A100 = $72 per job. Multiply across 200 jobs/month and you have your chargeback report."*
- *"The data is already in the DB — no Prometheus query, no SSH at query time. The workload tracking is continuous; the query is instant."*

**ROI:**
- **Chargeback accuracy:** GPU-hours from sacct exact end times vs poll-boundary approximation → up to 1 min per job → at scale (500 jobs/day) this is 500 GPU-minutes saved in billing precision
- **Visibility:** teams see their GPU consumption in real-time, not at month-end billing surprise
- **Zero infrastructure:** no additional timeseries DB, no Slurm accounting export scripts

---

## GPU-F — Per-workload GPU metrics (Workloads sub-tab) (~10s)
**Persona: MLOps engineer / Platform engineer** — *"I want to see GPU utilization by pod, not just by cluster. Which pod is actually burning the GPU?"*

**Context:** The Workloads sub-tab in FinOps (Sprint 16/17) shows live per-pod GPU metrics from DCGM/ROCm-SMI via Prometheus. Slurm jobs appear in the workloads table (Sprint A/B). The view is unified.

---

**Prompt:**
> *Show me the top 10 GPU-consuming workloads on vibops-dev right now — which pods are actually using compute vs just holding allocations?*

**Tools triggered:** `get_top_consuming_workloads(cluster: vibops-dev, limit: 10)`

**What the agent produces:**
- Ranked table: workload name, namespace, type (k8s_pod / slurm_job), GPU util %, memory used MB, power W, cost estimate $/hr
- Low-utilization workloads (< 20%) highlighted in yellow — candidates for time-slicing
- Summary: *"llama3 (prod) — 87% util. eval-run-7 (staging) — 3% util, 8GB allocated, 0.3% power: prime candidate for release."*

**Console path:** FinOps tab → Workloads sub-tab → select cluster → live table auto-refreshes

**Talking points:**
- *"This is the difference between cluster-level and workload-level GPU visibility. Cluster says 60% utilized. Workload view says: prod is at 87%, staging eval is at 3% and has been for 4 hours."*
- *"The yellow highlight is intentional — it's not a warning, it's an action prompt. Click 'Release GPU' and the agent scales down the staging deployment in the next sentence."*
- *"For Slurm jobs, the data comes from the workloads table — persistent, historical. For K8s pods, it's live Prometheus. Same UI, two data sources, unified view."*

**ROI:**
- **Idle GPU identification time:** manual DCGM query + namespace correlation → 10 seconds automatic per cluster
- **Action loop closed:** identify waste → agent scales down or time-slices → confirmed in same conversation

---

## Scenario 35 — VM lifecycle management (~30s, interactive)

**Prompt:** *"List all VMs on proxmox-cluster-01, find any stopped VMs wasting resources, resize the stopped one to 2 vCPU and 4 GB RAM, then start it."*

**Expected flow:** `proxmox_list_vms` → identify stopped VM → confirm resize → `proxmox_resize_vm(confirmed=true)` → `proxmox_start_vm`

**What to show:** Agent identifies waste (stopped VM with 16 vCPU allocated), proposes rightsizing, asks confirmation, executes — full HITL loop.

---

## Scenario 36 — GPU passthrough correlation (~20s, read-only)

**Prompt:** *"Show me the GPU workloads running on VM gpu-h100-01 in the apalacha cluster. What's the total cost?"*

**Expected flow:** Agent calls `run_kubectl` or reads from the workloads table to show the correlation chain: VM gpu-h100-01 (8× H100 passthrough) → K8s node gpu-h100-01 → llama3.1-70b-finetune workload (8 GPU, running 22h) → $528 estimated cost.

**What to show:** The 3-layer correlation that no other tool provides — VM hardware → K8s orchestration → GPU workload cost.

---

## Scenario 37 — VM snapshot management (~30s, interactive)

**Prompt:** *"Create a snapshot of gpu-node-02 before we do the CUDA driver update, call it pre-cuda-update."*

**Expected flow:** `proxmox_create_snapshot(vmid=601, node=pve-gpu-1, name='pre-cuda-update')` → confirmation → success. Then: *"Now list snapshots for gpu-node-02."* → `proxmox_list_snapshots` → shows the new snapshot.

**What to show:** Safe maintenance workflow on GPU VMs — snapshot before change, restore if needed.

---

## Reset between demos

```bash
# Token helper (reuse across curl commands below)
TOKEN=$(docker exec vibops_core python -c "
from app.auth import create_token; from app.user_context import UserContext
ctx = UserContext(user_id='1', username='admin', org_id='1', org_name='Acme', is_org_admin=True, teams=())
print(create_token(ctx))")

# Scenario 5 — remove nginx from apalacha/demo
docker exec vibops_worker kubectl --context apalacha delete namespace demo --ignore-not-found

# Scenario 3/8 — restore prod/llama3 to 3 replicas
curl -s -X POST http://localhost:8000/api/v1/jobs \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"action": "patch_deployment", "payload": {"name": "llama3", "namespace": "prod", "replicas": 3, "cluster": "vibops-dev"}}'

# Scenario 7 — restore prod/llama3 to untagged image (so setup step creates revision 2 cleanly)
curl -s -X POST http://localhost:8000/api/v1/jobs \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"action": "patch_deployment", "payload": {"name": "llama3", "namespace": "prod", "cluster": "vibops-dev", "image": "ollama/ollama"}}'

# Scenario 10 — delete feature-test cluster if created
docker exec vibops_worker kind delete cluster --name feature-test

# Clear all active port-forwards
docker restart vibops_worker
```

## Pre-demo checklist

```bash
docker compose ps        # all services Up/healthy
curl http://localhost:8003   # console loads
docker ps | grep kindest     # 3 kind nodes for vibops-dev + 2 for apalacha
```

- Browser open on http://localhost:8003, chat panel open
- `docker logs -f vibops_agent` in a terminal — shows live tool calls during demo
- No active port-forwards: `docker restart vibops_worker` to clean slate
