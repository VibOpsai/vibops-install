# Changelog

All notable changes to VibOps are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

---

## [0.37.0] — 2026-08-30

### Added
- **8 VM ops tools** — waste detection, per-VM metrics, backup compliance across Proxmox, vSphere, XCP-ng
- **VM chargeback** — `POST /finops/vm-chargeback/{year}/{month}/generate`, `GET` per month, `GET` list; cost model: vCPU/h + RAM/h + disk/h; reseller markup applied; GPU passthrough cost included
- **VM pricing overrides** — per-customer vCPU/RAM/disk rates in reseller overrides (backend + console UI)
- **Demo videos** — "Code to GPU" (1m52) and "Agent FinOps" (1m33), English, Playwright-recorded
- **One-pagers** — Sopra Steria, Cheops Technology, Oreus (corporate white theme, PDF-ready)
- **Workshop Oreus** — 90-min agenda with 16 tested prompts
- **User guide** — 5 new sections: VM Management (§19), Python SDK (§24), Cloud Providers (§25), Terraform (§26), Docker Build & CI (§27); Admin section: Customers (reseller), Security (SSO/LDAP/SIEM)

### Changed
- Action count: 258 → **266** (8 new VM tools)
- API routes: 198 → **201** (3 VM chargeback endpoints)
- Console: reseller Customers tab visibility fix (`x-show` vs `x-if`)
- Docker compose: LLM_PROVIDER/MODEL/API_KEY/BASE_URL env vars on agent service
- Pre-commit: fix ruff fallback via `python3 -m`
- Install repo: updated to v0.36.0 → v0.37.0, hypervisor setup guide in QUICKSTART

### Fixed
- SDK: 6 audit passes — 11 CRITICALs + 12 HIGHs fixed (API paths, field names, response envelopes, dry-run safety)
- VmCostSnapshot model: duplicate `__table_args__`, wrong `__repr__`
- Seed script: `DEMO_ORG_ID` env var support for correct org_id matching

---

## [0.36.0] — 2026-08-18

### Added
- **VibOps Python SDK v0.1.0** (`sdk/`) — typed async-first client with sync wrapper; 27 resource namespaces covering 98 API endpoints; auto-retry with exponential backoff; typed exceptions (Auth, Forbidden, NotFound, Conflict, RateLimit, Timeout, Connection); typed response dataclasses; pagination support; SSE streaming for job logs; event hooks; PEP 561 typed package; MIT licensed; 129 tests; `pip install vibops`
- **Pre-commit ruff lint check** — catches F401/F841/F541 before CI; `python3 -m ruff` fallback
- Sync script `scripts/sync-sdk-repo.sh` for VibOpsai/vibops-sdk mirror

---

## [0.35.0] — 2026-08-19

### Added
- **Compliance agent** — 8 SOC 2 runtime checks verifying controls are active (not just documented): CC6.1 access controls, CC6.2 access provisioning, CC7.1 vulnerability scanning, CC7.2 incident detection, CC7.4 audit trail integrity (HMAC-SHA256 chain), CC8.1 change management (Alembic), A1.2 backup freshness, C1.1 encryption active (Fernet roundtrip, no default keys)
- Daily Celery Beat schedule + on-demand API
- Non-compliant findings auto-create ProactiveInsight
- **ADR 0031** — Compliance agent architecture
- 10 compliance agent tests

---

## [0.34.0] — 2026-08-18

### Added
- **Security agent (DAST)** — 8 automated penetration checks (scope bypass, auth bypass, tenant isolation, input injection, rate limiting, privilege escalation, IDOR, header injection) running weekly via Celery Beat or on-demand via `POST /security/scan`; dev/prod mode awareness; critical/high findings auto-create ProactiveInsight; ADR 0030
- **Harness reinforcement** — 3 new guardrails: scope enforcement (UserContext namespace/cluster validation), input sanitization (shell injection patterns blocked), write cost cap (max 5 write actions/turn); 38 total guardrail tests
- **SOC 2 readiness** — 17/17 Trust Service Criteria documented: security policy, incident response plan (P1-P4), backup & recovery policy, risk assessment (14 risks), board oversight, internal communication, readiness checklist
- **ADR 0030** — Security Agent DAST architecture
- 9 security agent tests, 14 new guardrail tests

---

## [0.33.0] — 2026-08-17

### Added
- **Proactive agent engine** — 7 event-driven insight types (`stale_anomaly`, `gpu_health_warning`, `budget_warning`, `job_failure_pattern`, `deployment_health`, `capacity_forecast`, `cost_optimization`) running every 5 min via Celery Beat; SQL-only checks (~5ms/run), deduplication (1h window), auto-acknowledge on agent remediation
- **Dashboard "Proaction Required" panel** — click-to-chat recommendations that inject directly into the agent conversation; contextual data (daily burn, cluster names, error messages, waste estimates)
- **Toast notification** for critical insights with 60s polling
- **31 proactive agent tests**
- **Agent modular prompt system** — system prompt assembled from 4 files: `system_prompt.md` + `routing_rules.md` + `response_templates.md` + 11 few-shot examples
- **3 new behavioral rules**: Rule 17 (Planning — present numbered plan before multi-step actions), Rule 18 (Learn from corrections — save user corrections as memory), Rule 19 (Synthesize — lead with insight, not raw data)
- **10 routing decision trees** — tool selection disambiguation for scale/deploy/monitor/cost/incident/secrets/git/helm confusions
- **13 response templates** — structured formats for deployment, scaling, incident, cost, VM, error, budget warning, pipeline, anomaly resolution
- **ToolGuardrails harness** — deterministic code-level enforcement: duplicate call detection, loop detection (>3 same tool/turn), namespace enforcement (K8s write without namespace blocked), budget guard flag
- **ADR 0028** — Prompt Engineering + Harness Engineering dual-layer approach
- **54 new agent tests**: 24 guardrail unit tests, 10 integration tests (real agent loop with mocked LLM), 7 prompt invariant tests, 13 behavioral tests

### Fixed
- **Security audit pass 1** — 27 findings fixed: 5 HIGH (proxy org isolation on create_secret/create_job/create_pipeline, CI missing test jobs), 12 MEDIUM (OData injection, body:dict→Pydantic, unbounded queries, VM HITL, kubeconfig auth, Dockerfile), 10 LOW (pipelines body:dict, INTERNAL_API_KEY leak, F821 lint, llm-proxy tests, dead code, nemotron key, DeepSeek streaming, Grafana auth, dynamic tools, function-level import)
- **Security audit pass 2** — 6 findings fixed: correlated alerts LIMIT, delete_webhook_subscription org isolation, SSO error leakage, gpu-simulator root, Docker socket documentation
- **CI console tests** — mock httpx.Response with headers/content for _proxy_to_core, remove stale git_client tests, add branding to PUBLIC_ENDPOINTS, CONVERSATIONS_DB_PATH env var, python -m pytest in all jobs, MCP extra [dev] not [test], mcp<2.0.0 pin, gateway ssl import, MCP EXPECTED_TOOLS whitelist updated
- **Nemotron documentation** — added to README, QUICKSTART, technical-architecture, roadmap version headers updated to v0.32.0

### Changed
- **Agent prompt**: 16 → 19 behavioral rules, 8 → 11 few-shot examples
- **Roadmap**: marked console split (HTML partials + JS modules) as done

---

## [0.32.0] — 2026-08-15

### Added
- **NVIDIA Nemotron** as named LLM provider (`LLM_PROVIDER=nemotron`, NIM endpoint)
- **Multi-org admin UI** — Customers tab for reseller orgs: create/list customer orgs, pricing rules, overrides (7 console proxy routes, 33 i18n keys EN+FR)
- **Alert correlation engine** — groups related alerts by cluster/namespace/node within 5-min window, root cause heuristic, `GET /alerts/correlated` endpoint
- **Predictive GPU failure** — temperature trend, sustained high utilization, utilization cliff detection; Celery beat task every 10 min; `GET /gpu/health-predictions` endpoint
- **Vendor/accelerator heuristic** — `detect_vendor_from_payload()` infers GPU vendor from job payload (18 patterns: NVIDIA, AMD, Intel, AWS, GCP, Groq)
- **GitHub webhook** in onboarding wizard step 3 (optional: webhook URL, repo, branch, action)
- **Post-onboarding checklist** enhanced: 7 items (was 4) — added alert rules, GPU budget, first team
- **scale_cluster split** into `scale_cluster_up` / `scale_cluster_down` with separate dry-run emphasis
- **Safe MCP sync script** (`scripts/sync-mcp-repo.sh`) — prevents accidental push of proprietary code to public repo
- +93 new tests (vendor detection 21, alert correlation 14, GPU health 14, reseller API 21, scale cluster 11, console proxy 12)

### Changed
- **Console refactoring** — HTML split: 9285 → 406 lines + 18 Jinja2 partials; JS split: 5305 → 38 lines + 13 modules (Object.assign)
- **Positioning** — rebranded to "AI Infrastructure Engine" with tagline "From code to GPU in one conversation"
- Console served via Jinja2Templates with config injection
- Removed dead code: duplicate agents tab (82 lines)
- Removed 5 stale CI workflows from vibops-mcp repo (release-images, deploy, e2e, chart-release, publish-install)

### Fixed
- 7 MEDIUM security fixes: 4 dict bodies → Pydantic models (agent_graph, agent_identities, tokens, sso), max_length on GatewayCreate/SubscriptionCreate/RuleCreate, HSTS header
- Duplicate migration ID `a1b2c3d4e5f6` → `bdfa8c9eac42`
- Unused imports in gpu_health_predictor (ruff F401)
- index.html accidentally emptied in v0.31.0 — restored

---

## [0.31.0] — 2026-08-09

### Added
- Live GPU utilization % column in Fleet (Clusters + VMs) with color coding
- Unified GPU anomaly detection pipeline — VM + K8s + Datadog in same pipeline
- Unified VM drawer (5 layers: Hypervisor, GPU, K8s, Workloads, Cost) accessible from any tab
- Dashboard Apps panel — live K8s apps + VMs + Ollama models with pulse dots
- Anomaly closed-loop remediation: Diagnose & Fix → agent verifies metrics before resolving
- TCO Calculator UI (Manual / On-prem / Cloud) with live rate preview
- Network Discovery content-based (Proxmox, K8s, vSphere, Prometheus, DCGM, Slurm, Grafana)
- Network rescan via UI button (pull-based via ping response flag)
- Datadog GPU Polling — Celery beat task, virtual gateway, Connect wizard flow
- Connect wizard: Datadog under Monitoring, AWS/GCP/Azure under Cloud Providers
- Organization settings panel in Admin (name, contact email)
- `POST /gateways/{id}/scan` — request network rescan
- `GET /gateways/gpu-utilization/live` — latest GPU % per cluster
- Cluster Alert Rules + VM Alert Rules with GPU coverage
- 30 connectors (cerebras added)

### Fixed
- Console proxy org isolation: 8 critical routes converted from `_svc_headers()` to `_proxy_to_core()`
- 196 lines dead HTML removed (hidden sidebar + legacy VM drawer)
- Gateway wording → Connection/Connector across all UI
- Pulse-dot animation (opacity-only, no green box-shadow bleed)
- Alpine.js null guards on k8sDetailTarget expressions
- Pending job icon visibility (◌ with fg-muted)

---

## [0.30.0] — 2026-08-08

### Added
- TCO Calculator API — `RateUpsert` with `formula_type` (on_prem/cloud), auto-computed rate
- Network Discovery — gateway scans /24 subnet at boot, content-based service identification
- Datadog GPU Polling — `poll_datadog_gateways()` Celery beat task
- VmCostSnapshot model — 12-month VM spend trend parity with GPU
- Currency support — EUR/USD dynamic symbol from `budget.currency`
- `discovered_services` + `rescan_requested` columns on Gateway model
- Helm chart: networkScan, Slurm, vSphere sections in values.yaml

---

## [0.29.0] — 2026-08-08

### Added
- VM cost history — `VmCostSnapshot` table, 12-month spend trend
- Currency conversion — EUR/USD dynamic from `budget.currency`
- Onboarding complete: email notifications, post-onboarding checklist, Slurm + Outscale Connect flows
- Gateway capability discovery — connectors reported at each ping
- mTLS support — client cert via `MTLS_CLIENT_CERT/KEY/CA_BUNDLE`
- Connect Infrastructure wizard refonte (Infrastructure / Cloud Providers / Monitoring)
- Admin: Organization settings, Agent Tools fix, wording cleanup

---

## [0.28.0] — 2026-08-07

### Added
- **Outscale OAPI** — 34 actions total (VM lifecycle: start/stop/reboot/create/delete/resize, snapshots: list/create/delete, Flexible GPU: create/delete/link/unlink, storage, billing). Fixed 11 actions missing from TOOL_CATALOG. 14 new tests (48 total).
- **Generic VM routing** — 12 generic tools (list_vms, start_vm, stop_vm, etc.) auto-routed by `gateway_type` + `cluster_metrics.hypervisor`. User says "list my VMs" → agent resolves correct connector (Proxmox/XO/vSphere/Outscale).
- `_resolve_vm_platform()` — reads gateway_type + hypervisor subtype for auto-dispatch
- `_remap_vm_params()` — translates vm_ref → vmid/name/vm_id per platform
- `format_gateways()` enriched — includes `gateway_type` in agent system prompt
- 20 Outscale MCP tools (VM, GPU, snapshots, billing)

---

## [0.27.0] — 2026-08-07

### Added
- **Sprint C — VmGpuCollector** — GPU process discovery on VMs with GPU passthrough but no K8s layer (bare-metal CUDA, rendering, VDI, standalone inference)
- `VmGpuCollector`: SSH + nvidia-smi CSV parser, one WorkloadSnapshot per CUDA process (`workload_type="vm_gpu_process"`)
- `VmGpuConfig` dataclass: ssh_user, ssh_key_secret, ssh_port, nvidia_smi_timeout
- `vm_gpu_config` JSONB column on Gateway model (migration `f747dc1218d7`)
- `workload_tasks` dispatch: hypervisor/hybrid gateways auto-discover non-K8s GPU VMs
- `vm-usage` endpoint: correlate workloads to VMs by name (not just k8s_node)
- VM drawer shows "Process" + PID for `vm_gpu_process` workloads
- 13 new tests

---

## [0.26.0] — 2026-08-06

### Added
- GPU passthrough correlation (MOAT) — VM ↔ K8s node ↔ GPU workload cost attribution chain
- `node_name` column on Workload model with index; KubernetesWorkloadCollector populates from Prometheus Hostname
- `nodes_detail` field on ClusterMetrics Pydantic model — per-node detail stored from gateway heartbeat
- Cluster detail drawer in FinOps GPU Cost Attribution — click cluster to see metrics, nodes, workloads, pricing, cost breakdown
- Fleet VMs table: Cluster, Status, GPU, K8s columns + click-to-drawer
- GPU Cost Attribution table redesigned: Cluster / Gateway / Status / $/GPU/h / GPU / Nodes / vCPU / RAM / $/month
- `GET /finops/vm-usage` joins running workloads by `node_name` — per-VM GPU workload detail
- `GET /finops/workloads/live-cost` includes `node_name` in response
- `seed_gpu_correlation_demo.py` — demo data script with H100/H200/B200/B300/L40S, 9 workloads, --keepalive flag
- 18 VM action tool schemas added to agent LLM catalog (delete_vm, resize_vm, clone_vm, list/restore/delete_snapshot × Proxmox/XO/vSphere)
- 14 new tests in `test_node_name_correlation.py`
- Alembic migration `1186797b60e1` — create workloads table with node_name

---

## [0.25.0] — 2026-08-04

### Added
- **18 new VM actions** across all 3 hypervisor connectors (Proxmox, XO, vSphere):
  - `delete_vm` — permanent deletion with dry-run preview + HITL confirmation
  - `resize_vm` — change vCPU/RAM (VM must be stopped)
  - `clone_vm` — full clone with HITL confirmation
  - `list_snapshots` — list all VM snapshots
  - `restore_snapshot` — rollback to snapshot with HITL confirmation
  - `delete_snapshot` — remove snapshot with HITL confirmation
- **VM FinOps dashboard** — full parity with GPU:
  - VM Cost Attribution panel with KPI bar + per-VM cost table
  - Configurable VM rates per hypervisor (CSV import + inline form + markup %)
  - Stopped VMs waste detection with expandable detail + Diagnose button
  - Budget bar unified GPU + VM with breakdown legend
  - Spend trend chart: stacked GPU (indigo) + VM (green) bars
  - "Resource Waste" section: idle GPUs + stopped VMs with per-resource $/day
- **Global Connect Infrastructure modal** — overlay from any tab for K8s gateway + VM hypervisor connection
- **Post-onboarding checklist** in Fleet empty state (5 steps)
- VM rate CRUD: `GET/POST /pricing/vm-rates` + `POST /pricing/vm-rates/import`
- Alembic migration: 3 VM rate columns on `cluster_rates`
- 462 English i18n keys added

### Fixed
- Budget + spend calculations include VM costs
- Console branding proxy (eliminates 404)
- Approvals polling stops after 3 errors
- GPU/VM Diagnose buttons harmonized (pill style)

---

## [0.24.1] — 2026-08-04

### Added
- **Global Connect Infrastructure modal** — overlay accessible from any tab (Fleet, Admin, checklist). Two flows: Kubernetes gateway (name + env → token + Helm command + heartbeat poll) and Virtual Machines (Proxmox VE / Xen Orchestra / VMware vSphere + credentials). Replaces the old navigation to Admin → Clusters.
- **"+ Connect Gateway" button** in Fleet sub-tabs opens modal in-place
- **Post-onboarding checklist** in Fleet empty state — 5-step "Getting started" card (connect infra, monitoring, alert rules, invite team, ask agent)
- **Branding proxy route** (`/api/v1/branding`) with default fallback — eliminates 404 on every page load
- **462 English i18n keys** added — fixes raw key names (`settings_title`, `status_offline`, etc.)

### Fixed
- Overlay opacity at 50% for modal backdrop (was opaque, then 70%)
- Modal card background hardcoded to `#161b22` (was transparent via CSS variable)
- Approvals polling stops after 3 consecutive errors (was infinite 500 spam)
- Connect modal uses `cm*`-prefixed variables in parent Alpine scope (fixes scope conflicts)
- Removed debug `console.log` / `console.error` statements
- `x-cloak` on modal prevents flash on page load

### Tests
- 4 new tests for Connect Infrastructure modal (K8s fields, VM fields, JS methods, HTML presence)

---

## [0.24.0] — 2026-08-03

### Added
- **Onboarding wizard** — 5-step guided setup for new instances:
  1. LLM provider configuration (Anthropic Claude / OpenAI-compatible / Ollama) with API key storage
  2. Infrastructure type selection (Kubernetes / Virtual Machines / Both)
  3. Infrastructure connection (K8s gateway registration + helm install command, or hypervisor setup for Proxmox VE / Xen Orchestra / VMware vSphere)
  4. Notification channel setup (Slack webhook, optional)
  5. Summary + "Start using VibOps"
- Wizard triggers automatically on first login when no gateways are registered
- Stepper UI with animated progress bar, pulsing active step indicator, labeled steps
- Skip buttons on all optional steps; Back navigation on steps 2-4
- Pill-shaped provider and hypervisor selection buttons with glow effect
- Note: "You can add more clusters and hypervisors later in Settings"
- Console secret upsert (delete + recreate) to handle re-runs gracefully

### Fixed
- Console Dockerfile: `mkdir /data` with correct ownership for non-root user
- Console `main.py`: ETag header for cache busting on HTML responses
- Wizard: `credentials: 'same-origin'` on all fetch calls (CSRF fix)
- Wizard: use `/api/secrets` service route instead of `/api/v1/secrets` (avoids user-auth 500)
- Wizard: use `/api/notifications/channels` (correct console proxy path)
- Wizard: gateway heartbeat poller uses list endpoint filtered by ID (avoids 405 on GET by ID)
- Password modal moved inside `authenticated && !onboarding` template (fixes Alpine `pwdSaving` error)

---

## [0.23.1] — 2026-07-28

### Fixed
- **CRITICAL: release-images.yml** — connect image pointed to `gateway/Dockerfile` instead of `connect/Dockerfile`; clients received wrong image
- **CRITICAL: Helm core secret** — missing `VAULT_KEY`, `REDIS_URL`, `INTERNAL_API_KEY`; pod would crash on production startup (`sys.exit(1)`)
- **CRITICAL: Console port mismatch** — Helm templates used 8080, Dockerfile uses 8003; probes failed, pod killed in loop
- **Helm: Alembic initContainer** — `upgrade head` → `upgrade heads` (safety for multi-head scenarios)
- **Helm: emptyDir /tmp** on agent + console deployments (required for `readOnlyRootFilesystem`)
- **Helm: console liveness/readiness probes** added (was the only deployment without them)
- **connect/Dockerfile** — multi-stage build + non-root user `vibops` (image deployed at client sites)
- **core/Dockerfile** — multi-stage build; removed docker CLI, kind, helm, gcc, git from runtime image
- **CI: lint now blocking** — removed `continue-on-error`; 187+150+5 ruff errors fixed across core/agent/connectors
- **CI: extended lint** to connectors/ and gateway/; added test-agent job; OTEL disabled in test jobs
- **CI: pytest-cov** `--fail-under=50` on core + connectors; pip-audit added for llm-proxy
- **CI: publish-install** now gates on all tests + lint + security-scan (was only test-core + openapi)
- **Alembic** — 13 missing model imports in env.py; diverged heads merged
- **Versioning** — 53 annotated git tags aligned 1:1 with CHANGELOG; pre-release dates corrected to actual commit dates; 5 pyproject.toml synced to 0.23.0; llm-proxy deps pinned
- **Removed** legacy `charts/vibops/` (desynchronized, never used) and `docs/node_modules/` (30MB Playwright)
- **.dockerignore** created at repo root

---

## [0.23.0] — 2026-07-20

### Added
- **VMware vSphere connector** — vCenter API via pyVmomi; 9 actions: `vsphere_list_vms`, `vsphere_get_vm`, `vsphere_get_vm_metrics`, `vsphere_list_hosts`, `vsphere_start_vm`, `vsphere_stop_vm`, `vsphere_restart_vm`, `vsphere_migrate_vm`, `vsphere_create_snapshot`
- **9 vSphere tools in agent catalog** — dispatched via agent tool router; connector supports multi-vCenter via `vsphere_config` on gateway
- **HITL on vSphere write actions** — mandatory human confirmation before `vsphere_stop_vm`, `vsphere_restart_vm`, `vsphere_migrate_vm`, `vsphere_create_snapshot`; agent enforces via confirmation gate
- **MCP: 83 tools total** — up from 68 (vSphere + Proxmox/XO additions + Tersedia demo tools)
- **Tersedia demo** — VM simulation mode with agent gateway fallback for demo environments

### Fixed
- **Security (round 4)**: 4 CRITICAL + 14 HIGH + 5 MEDIUM — includes rate limiting bypass, org isolation bypass, audit log spoofing, LDAP injection fix, exception detail leakage
- **`fix(audit)`**: HMAC chain per-org scoping + explicit timestamp on audit entry creation (prevents cross-org HMAC drift)
- **`fix(llm-proxy)`**: Dockerfile COPY paths corrected for root build context

---

## [0.22.3] — 2026-07-18

### Fixed
- **Security audit (third pass)**: 4 MEDIUM + 3 LOW — rate limiting edge cases, minor info-disclosure issues; 31 findings total closed across 3 audit passes

---

## [0.22.2] — 2026-07-18

### Fixed
- **Security audit (Sonnet)**: 2 CRITICAL + 5 HIGH + 4 MEDIUM — JWT secret exposure, SSRF via webhook URLs, cross-org data access, CORS misconfiguration, upload size bypass

---

## [0.22.1] — 2026-07-17

### Fixed
- **Security audit (Opus)**: 1 CRITICAL + 5 HIGH — token log leak, kubectl gate missing, vault fallback scope, gateway credential isolation; remaining MEDIUM findings patched

---

## [0.22.0] — 2026-07-11

### Added
- **Proxmox VE connector** — VM lifecycle: `proxmox_list_vms`, `proxmox_start_vm`, `proxmox_stop_vm`, `proxmox_migrate_vm`, `proxmox_create_snapshot`; node-level operations via Proxmox REST API
- **Xen Orchestra (Vates) connector** — `xo_list_vms`, `xo_start_vm`, `xo_stop_vm`, `xo_migrate_vm`, `xo_snapshot_vm`; connects to XO API
- **Hypervisor gateway type** — `gateway_type=hypervisor` in gateway registration; connects to Proxmox or XO endpoints
- **VM fleet UI** — Fleet sub-tabs (Clusters | VMs); VM KPI bar (total VMs, running, stopped); All VMs table with status badges, hypervisor type, host
- **VM Fleet actions** — start/stop/migrate from console; VM Alert Rules (threshold-based on CPU, memory, state)
- **VM anomaly detection** — threshold evaluation (CPU spike, memory pressure, unexpected stop); integrates with existing anomaly engine
- **VM FinOps** — per-VM cost attribution endpoint `GET /finops/vms/{id}/cost`; VM cost agent tool
- **Proxmox + Xen Orchestra tools in agent catalog** — 10 VM tools dispatched via agent; system prompt updated with hypervisor workflow
- **CI**: auto-build 6 Docker images on version tag; auto-create GitHub Release with changelog; auto-sync vibops-install repo on release

### Fixed
- CI: VIBOPSAI_PAT for GHCR push to vibopsai org

---

## [0.21.0] — 2026-07-11

### Added
- **LLM inference proxy** (`llm-proxy/`) — transparent OpenAI-compatible proxy; per-agent GPU FinOps attribution; backend API key forwarding for cloud LLM APIs (Anthropic, OpenAI, Groq)
- **Agent control plane** — 3 extensions: budget guard (abort on limit breach), anomaly detection integration, configurable model policy (`GET/PUT /agent/model-rules`); 6 Agent FinOps tools in catalog
- **Thinking modes** — `THINKING_MODE` env (auto/enabled/adaptive/disabled); extended thinking for DeepSeek V4/R1, Nemotron (`enable_thinking` + `reasoning_budget`), OpenAI-compatible models (`reasoning_effort`); budget_tokens configurable
- **Cerebras WSE connector** — 8th accelerator vendor; CS-3 wafer-scale cluster: deploy model, submit training job, monitor throughput; `cerebras_*` agent tools in catalog
- **Compute-type aware cost model** — separate rate schedules for GPU, CPU, LPU, API; `compute_type` field on Job and ClusterRate; cost formula adapts by type
- **Datadog Marketplace-ready** — 5 integration gaps closed: custom metric namespaces, log facets, dashboard JSON templates, service check definitions, Datadog Agent tile manifest
- **CPU-only K8s support** — resource metrics (CPU/memory), anomaly detection (CPU spike, OOM), adaptive console UI (hides GPU-specific panels when no GPU detected)
- **Console Agents tab** — renamed Agent → Agent Tools; 10 tools visible in catalog; Playwright Agent FinOps demo with seed script

### Tests
- Agent L1/L2/L3 suite expanded; connector tests cover Cerebras, LLM proxy integration

---

## [0.20.1] — 2026-06-27

### Added
- **Auth: first-run setup wizard** — replaces env-var bootstrap; guided admin account creation on first start; `ADMIN_EMAIL/ADMIN_PASSWORD` env-based DB bootstrap as fallback
- **Login email alert** — email sent on every login attempt (success and failure) for security monitoring
- **LDAP/Active Directory authentication** — `GET/PUT /admin/ldap/config`; LDAP bind, user search, group mapping; Security admin tab in console; LDAP login form with fallback to local auth
- **MCP Sprint 6**: +9 tools (68 total) — `get_ldap_config`, `update_ldap_config`, `push_to_siem`, `get_siem_config`, `update_siem_config`, `registry_list_repos`, `registry_list_tags`, `registry_check_image`, `registry_delete_tag`
- **ContainerRegistry connector** — OCI v2 Bearer auth; list repos, list/delete tags, check image existence
- **Kubeconfig import** — `POST /clusters/import`; upload kubeconfig from console; auto-creates gateway record and deploys VibOps Connect
- **Pipeline templates** — `deploy_vibops` and `connect_gpu_cluster` templates in console Pipelines tab; one-click scaffold
- **Console UX** — Admin → Gateways moved from Monitoring to Admin tab; inline CSP credential forms in cluster connect wizard; empty-state for clusters

### Fixed
- Docs/README: tool count aligned to 74, vibops.io → vibops.ai

---

## [0.20.0] — 2026-06-14

### Added
- **Cloud pricing API** — real-time GPU rates from AWS EC2, Azure NDv4/NCv3, GCP A100; `POST /finops/cloud-pricing/sync`; rates stored as ClusterRate records; agent uses live rates in cost computations
- **Huawei Ascend NPU connector** — 9th accelerator vendor (Ascend 910B); wired to agent dispatch + system prompt; multi-vendor fleet now covers H100/MI300X/Ascend-910B
- **White-label routing** — `X-CSP-Domain` header routing for CSP resellers with custom domains; `white_label_slug` on Organization
- **SIEM export** — `GET /audit/export?format=json|cef|leef`; bulk audit log export for SOC ingestion (Splunk, QRadar, Elastic)
- **Signed billing export** — `GET /finops/billing/export`; HMAC-SHA256 signature in `X-VibOps-Signature` header for billing system integration
- **Approval gate: user context** — username and org attached to every pending gate; visible to approver in console
- **Helm v0.20.0** — `values.production.yaml` full rewrite (PDB, gp3 storage class, HPA config, IRSA/WI annotations, JWT 8h expiry); step-by-step production runbook in `docs/runbooks/production-deployment.md`

### Fixed
- **Security (pre-v0.20.0 audit)**: 17 findings — all protected routes JWT-gated at router level; DELETE routes require `confirmed=true`; 5 CRITICAL + 9 MAJOR + 3 MINOR closed

---

## [0.19.0] — 2026-06-04

### Added
- **Vendor-specific tool catalogs** — AMD ROCm, Intel Gaudi, AWS Trainium, Groq, Outscale: each connector exposes a curated tool subset matching accelerator capabilities
- **Dynamic agent tool loading** — connector `gateway_type` drives which tools are presented to the LLM; reduces token usage and hallucination on single-vendor deployments
- **Agent rules 14-16** — budget guard (abort if within 10% of budget), gateway fallback (retry on alternate gateway), unknown tool safe decline

---

## [0.18.1] — 2026-05-31

### Added
- **Async external approval gate** — `POST /agent/approvals`, `POST /agent/approvals/{gate_id}/respond`; agent blocks on destructive actions until human approves/rejects; configurable per-action in Tool Policy
- **HMAC-chained tamper-evident audit log** — each entry signed `HMAC(prev_hash || payload || timestamp)`; `GET /audit/verify-chain` validates integrity; per-org chain isolation
- **Agent tool catalog** (OPS-A01) — console Agents tab with visual catalog; tag-based search/filter (closes issue #2); schema drawer shows parameters per tool; autofill from catalog into agent prompt
- **Tool Policy sub-tab** — Admin → Tool Policy; per-action toggles for `requires_confirmation` and `requires_approval`; org-scoped; OPS-D01/E03/E06 compliance
- **Per-org approval notifications** — configurable webhook or console sub-tab for pending gates; closes issue #5
- **Sprint 3** — execution history (closes #1), job replay by `job_id` (closes #3), LLM-as-judge evaluation with any VibOps LLM provider (closes #4)
- **Sprint 4** — anomaly detection integration in agent context, live cost attribution in job detail, L2 coherence auto-scanner
- **Sprint 5** — compliance report generation (closes #7), SSO OIDC (closes #8), agent identity lifecycle: `create_agent_identity`, `rotate_agent_identity`, `revoke_agent_identity` (closes #9/#10), dependency graph `GET /agent/dependencies` (closes #11)
- **i18n** — English defaults throughout console; French translations in `console/static/i18n/fr.json`
- **Declarative YAML policy rules** — `GET/PUT /policy/rules`; OPA/Rego-compatible rule format; org-level policy override with audit trail; closes issue #6
- **MCP: 26 new governance & FinOps tools** (59 total) — `get_budget`, `set_agent_budget`, `get_spend_trend`, `get_chargeback`, `get_waste_analysis`, `get_workload_breakdown`, `get_cluster_rate`, `set_cluster_rate`, `list_ai_act_controls`, `get_ai_act_score`, `update_ai_act_control`, `generate_compliance_report`, `get_compliance_report`, `list_compliance_reports`, `verify_audit_chain`, `list_audit_logs`, and 10 additional governance tools

---

## [0.18.0] — 2026-05-17

### Added
- **Sprint D: GPU pricing management API** — `GET/POST/PUT/DELETE /finops/pricing`; `markup_pct` field on PricingTier for reseller margin; pricing rules cascade through reseller chain
- **FinOps visual dashboard** — single scrollable page replaces sub-tabs; SVG utilization gauge; Chart.js spend trend (30-day); CFO-ready cost bars by namespace; app sidebar popover for drill-down
- **Fleet table** — cluster removal (✕ button per row, `DELETE /gateways/{id}/clusters/{cluster_name}`); persistent `removed_clusters` list (prevents ping re-adding); search filter; compact layout; CPU/Memory/Pods columns
- **VibOps Connect: cluster auto-discovery** — gateway heartbeat discovers all clusters from kubeconfig and reports metrics (CPU, memory, GPU, pods) per context; multi-context Fleet health without manual registration
- **NIM merged into LLM tab** — Ollama | NIM sub-tabs; unified LLM endpoint management

---

## [0.17.6] — 2026-05-13

### Added
- **`GET /workloads`** — filtered listing with real-time cost annotation (`cost_usd`, `gpu_hours`, `rate_per_gpu_hour`); optional filters: `cluster_name`, `status`, `namespace`, `workload_type`; pagination (`limit`/`offset`); ordered by `started_at DESC`
- **`GET /workloads/cost-summary`** — aggregated GPU cost attribution for a cluster: `total_gpu_hours`, `total_cost_usd`, `by_namespace` (namespace for k8s_pod, partition for slurm_job), `top_workloads` (top 10 by cost); `rate_available=false` when no ClusterRate configured
- **`GET /workloads/{id}`** — single workload detail with cost annotation (404 + org isolation)
- **Cost formula**: `gpu_hours = gpu_seconds_accumulated / 3600`, `cost_usd = gpu_hours × rate_per_gpu_hour`; computed on-the-fly, never stored — rate changes take effect immediately
- **Console Workloads sub-tab** — cluster selector, cost attribution table by namespace/partition (workload count, running count, GPU-hours, cost), top spenders list; amber warning when no ClusterRate configured
- **Agent system prompt** — workload cost attribution intents: `cost-summary` rollup, filtered listing, single detail
- **CI `publish-install` job** — auto-publishes to vibops-install repo on every push to `main` (gated on `test-core` + `openapi-spec` passing); uses `INSTALL_REPO_TOKEN` secret

### Tests
- 31 new tests in `test_sprint20_workload_cost.py` (8 unit + 8 list endpoint + 9 cost-summary + 5 detail + 1 auth)

---

## [0.17.5] — 2026-05-12

### Added
- **`sacct` accounting for terminated Slurm jobs** — `SlurmWorkloadCollector.collect_completed()` queries `sacct` (REST slurmdb API or SSH) for jobs that completed between polls; window = `now - 2×POLL_INTERVAL_S` (120 s) to avoid missed transitions
- **`finalize_completed_workloads()`** — new DB helper: idempotent UPDATE for Slurm jobs that moved to terminal states; sets `ended_at` and `status` from `sacct` exact timestamps; takes priority over `mark_terminated_workloads()` approximation
- **`WorkloadSnapshot.ended_at`** — optional `datetime | None` field set by sacct; `None` for Kubernetes and running Slurm jobs
- **`_sacct_to_snapshots()`** — handles nested TRES format (`tres.allocated: [{"type":"gpu",...}]`) via `_tres_from_nested()`; strips `.batch` job step suffix; maps COMPLETED / FAILED / CANCELLED / TIMEOUT → terminal statuses

### Changed
- `sync_workloads` Celery task now calls `collect_completed(since=now-120s)` after `collect()` for Slurm gateways; DB write order: `upsert_workloads` → `finalize_completed_workloads` → `mark_terminated_workloads`
- Console gateway form fully wired: gateway_type select, prometheus_url field (K8s/hybrid), Slurm section (host/user/port/REST URL/SSH key secret) — all conditionally shown via Alpine.js

### Tests
- 10 new tests in `TestSacctParsing` + 5 in `TestFinalizeCompletedWorkloads` — 51 tests in `test_sprint19_slurm_workload_collector.py`

---

## [0.17.4] — 2026-05-12

### Added
- **`SlurmWorkloadCollector`** — full workload collector for Slurm clusters: REST (slurmrestd `v0.0.38`) → SSH+JSON (`squeue --json`) transport hierarchy; no text parsing
- **`SlurmGatewayConfig`** dataclass with `from_dict()` — validates `host` + `ssh_user` required; optional `ssh_port`, `rest_url`, `ssh_key_secret`, `rest_jwt_secret`
- **`parse_alloc_gres()`** — regex-based AllocGRES parser handles `gpu:2`, `gpu:tesla:2`, `gpu:nvidia_a100_80gb:4`, multi-type (`gpu:a100:2,gpu:v100:1` → summed); CPU-only → 0
- **`gateway_type`** column on `gateways` table (`String(32)`, server_default=`kubernetes`); values: `kubernetes` | `slurm` | `hybrid`
- **`slurm_config`** JSONB column on `gateways` table — stores host, ssh_user, ports, REST URL, secret names; CHECK constraint enforces host+ssh_user when type=slurm
- **Hybrid gateways** — `gateway_type="hybrid"` runs both `KubernetesWorkloadCollector` and `SlurmWorkloadCollector`; snapshots merged before upsert
- **`_fetch_secret()`** in `workload_tasks.py` — resolves SSH key PEM and JWT from VibOps secrets store for Slurm transport
- **`_build_collectors()`** takes plain values (not ORM objects) to avoid `DetachedInstanceError` / `MissingGreenlet` after `session.commit()`
- **Console gateway form** — gateway_type select, prometheus_url (K8s/hybrid), Slurm section with host/user/port/REST URL/SSH key secret fields; register button disabled when slurm type and host empty
- **ADR 0024** — Slurm workload collector: transport hierarchy, AllocGRES parsing, SSH key management, hybrid gateways, detached-instance guard

### Migrations
- `d5e6f7a8b9c0_add_gateway_type_slurm_config.py` — adds `gateway_type` + `slurm_config` to `gateways`

### Tests
- 36 new tests (Classes A–E in `test_sprint19_slurm_workload_collector.py`): `TestParseAllocGres`, `TestSlurmGatewayConfig`, `TestJobsToSnapshots`, `TestSlurmWorkloadCollector`, `TestGatewayApiSlurmFields`

---

## [0.17.3] — 2026-05-12

### Added
- **Workload persistence** — `workloads` table with `upsert_workloads()` and `mark_terminated_workloads()`; shadow-write alongside existing Prometheus live-query path
- **`KubernetesWorkloadCollector`** — polls Prometheus for running GPU workloads; emits `WorkloadSnapshot` objects (external_id, workload_type, namespace, gpu_count, started_at, status)
- **`WorkloadSnapshot`** dataclass — canonical workload representation shared by K8s and Slurm collectors
- **`sync_workloads`** Celery Beat task (60 s interval) — discovers gateways, dispatches to collectors, upserts to DB, marks terminated
- **`GET /api/v1/workloads`** — lists workloads with filters (`status`, `cluster_name`, `namespace`, `workload_type`) and pagination
- **`GET /api/v1/workloads/{id}`** — single workload detail
- Console **Workloads sub-tab** in FinOps: live table with status badges, GPU count, duration, namespace filter

### Migrations
- `c4d5e6f7a8b9_add_workloads_table.py` — creates `workloads` table with indexes on `(org_id, cluster_name, status)` and `(external_id, workload_type)`

### Tests
- Sprint A test suite (workloads table + K8s collector + API endpoints + console proxy)

---

## [0.17.2] — 2026-05-11

### Changed
- **Per-workload abstraction** — `PodGpuMetric` renamed to `WorkloadGpuMetric` with `workload_id` + `workload_type` fields, establishing a clean abstraction for both Kubernetes pods (`workload_type="k8s_pod"`) and future Slurm jobs (`workload_type="slurm_job"`). Done before client integration to avoid a breaking change later.
- **Canonical endpoint** `GET /clusters/{name}/workloads/{ns}/{id}/gpu-metrics` replaces `/pods/` path. The `/pods/` alias is kept with a `Deprecation` response header.
- **Top workloads endpoint** now returns `workloads` key (was `pods`). The internal compat wrapper `get_top_consuming_pods()` still exists for any early callers.
- **Console** — FinOps "Pods" sub-tab renamed to "Workloads"; table shows `workload_id` and `workload_type` columns.
- **Fixed** `NameError: pods_out` in `get_top_consuming_workloads()` — variable was renamed but one reference was missed.

### Backwards compatibility
- `PodGpuMetric = WorkloadGpuMetric` alias preserved.
- `get_pod_gpu_metrics()` and `get_top_consuming_pods()` remain as compat wrappers.
- `GET /clusters/{name}/pods/{ns}/{pod}/gpu-metrics` still returns 200 with `Deprecation` header.

---

## [0.17.1] — 2026-05-12

### Added
- **Budget alert notifications** — when a soft or hard cap threshold is crossed, VibOps now dispatches a notification via all active channels (Slack, email, PagerDuty) for the org. Previously, `BudgetAlert` records were written to the DB but never dispatched.
- **Budget check after job completion** — `job_tasks.py` now calls `check_budget()` after a job transitions to SUCCESS with its computed `actual_cost_usd`. This closes the alerting loop: job completes → cost recorded → alert fired → notification sent.
- `BudgetService._dispatch_budget_notification()` — new internal helper that formats title/message/severity and delegates to `ChannelService.notify_alert_via_channels()`. Non-fatal: if the channel call fails, the `BudgetAlert` DB record is already persisted.
- `_check_budget_after_job(org_id, cost_usd)` async helper in `job_tasks.py` — uses a dedicated `AsyncSession` (same pattern as `_resolve_secrets`) to avoid interfering with the Celery sync DB context.

### Fixed
- Budget alerts were silently stored in DB but never triggered Slack/email/PagerDuty notifications.
- Job completion did not update the budget spend counter — alerts could never fire from completed jobs.

---

## [0.17.0] — 2026-05-11

### Added
- **Per-pod GPU metrics** via on-demand Prometheus queries (DCGM Exporter / ROCm-SMI Exporter):
  - `GET /clusters/{name}/pods/{ns}/{pod}/gpu-metrics` — per-GPU util%, memory, power for a single pod
  - `GET /clusters/{name}/namespaces/{ns}/gpu-metrics` — per-pod aggregated summary for a namespace, sorted by util%
  - `GET /clusters/{name}/gpu-metrics/top` — top N pods by GPU utilisation across a cluster (`?limit=1–100`, `?namespace=` filter)
  - NVIDIA: DCGM_FI_DEV_GPU_UTIL, DCGM_FI_DEV_FB_USED, DCGM_FI_DEV_POWER_USAGE
  - AMD: rocm_smi_gpu_use_percent, rocm_smi_memory_used_vram_bytes (power not available)
  - NVIDIA + AMD queried concurrently via `asyncio.gather`; graceful `prometheus_available=false` when not configured
- **`prometheus_url`** field on Gateway model and API schema; resolved in priority: gateway field → `PROMETHEUS_URL` env var → None
- **`pod_breakdown`** JSON column on `ChargebackReport`: per-pod cost attribution when `pod_name` is present in job payload
- **FinOps waste endpoint enrichment**: `pod_level_available` + `pod_metrics` (low-util pods < 20%) per idle cluster
- **Console — Pods sub-tab** in FinOps: cluster selector, ranked GPU pod table, low-utilisation rows highlighted in amber
- **Agent system prompt**: per-pod GPU metric intents (`get_top_consuming_pods`, `get_pod_gpu_metrics`, `get_namespace_gpu_aggregated`)
- 34 new tests across 4 classes (service unit, endpoint integration, chargeback pod_breakdown, security invariants) — 689 total

### Changed
- `ChargebackReportResponse` now includes `pod_breakdown` field (null for reports generated before this migration)

---

## [0.16.4] — 2026-05-10

### Added
- **`SlurmConnector`** — 6 actions for multi-node HPC training on bare-metal Slurm clusters (no Kubernetes required):
  - `slurm_get_cluster_info` — `sinfo`: partitions, node states, GPU availability per node
  - `slurm_list_jobs` — `squeue`: running and pending jobs with TRES, user, time limit
  - `slurm_submit_job` — `sbatch`: generates sbatch script from payload, dry-run preview gate before submission; returns `job_id`
  - `slurm_cancel_job` — `scancel` with configurable signal; destructive, requires confirmation
  - `slurm_get_job_status` — `squeue` (running) + `sacct` fallback (finished/failed)
  - `slurm_get_job_output` — `tail -n N` on job stdout log via SSH
- **Transport auto-detection**: probes slurmrestd REST API (3s timeout), falls back to SSH; result cached per connector instance
- **SSH key from Vault**: `ssh_key=@secret:slurm_ssh_key` — PEM content written to a `0o600` temp file for the SSH call duration, deleted in `finally`; Vault resolution in `job_tasks.py` before connector call
- **Demo mode** (`SLURM_DEMO_MODE=true`): realistic canned responses for all 6 actions — 8× A100 node cluster, active job queue, training log output — no real cluster or SSH key required; enabled by default in `docker-compose.yml`
- **Agent**: 6 Slurm tools in `TOOLS`, routed via `_RUN_JOB_TOOLS` / `_CREATE_JOB_TOOLS`
- **MCP server**: 6 Slurm tools registered (action tools: 8 → 14)
- **WorkloadClassifier**: `slurm_submit_job` → `training`, `slurm_cancel_job` → `operations`, read actions → `observation`
- **System prompt**: Slurm HPC workflow with mandatory `slurm_get_cluster_info` pre-check, Vault SSH key pattern, `save_memory` after submit
- **Console**: Slurm metadata card in job detail panel (job ID, partition, nodes, GPUs/node, wall time)
- **`_format_job()`**: extracts `job_name` label and `slurm_job_id` for Slurm jobs
- Connector count: 25 → **26**
- 40 connector tests (`test_slurm_connector.py`)

### Documentation
- **Scenarios 30–32** in `docs/demo-scenarios.md` — multi-node training submission, log monitoring, runaway job cancel with GPU budget recovery ROI
- Header updated: 29 → 32 scenarios; HPC/MLOps engineer persona added

---

## [0.16.3] — 2026-05-08

### Added
- **`create_pull_secret`** (KubectlConnector) — creates or updates a Kubernetes docker-registry pull secret; idempotent; works on EKS, GKE, AKS, RKE2, bare metal, local clusters
- **`deploy_webapp`** updated — new `image_pull_secret` param
- **`kind_load_image`**, **`k3d_load_image`**, **`minikube_load_image`**, **`k3s_load_image`** — load locally built images into local cluster runtimes
- **`create_ecr_pull_secret`** / **`create_gcr_pull_secret`** / **`create_acr_pull_secret`** — cloud-specific pull secrets (AWS/GCP/Azure)
- **`argocd_enable_auto_sync`** / **`argocd_disable_auto_sync`** — GitOps auto-sync via ArgoCD API
- **`openshift_add_scc`** / **`openshift_create_route`** — OpenShift-specific actions

### Tests
- 13 new connector tests (pull secrets, local cluster loading)

### Documentation
- Scenarios 26–29 in `docs/demo-scenarios.md` — private registry, ArgoCD, cloud registry, OpenShift

---

## [0.16.1] — 2026-05-07

### Added
- **`DockerBuildConnector`** — 4 actions: `docker_build` (600s timeout, layer streaming), `docker_tag` (30s), `docker_push` (login via `--password-stdin`, token masked in logs, digest returned), `docker_build_push` (combined)
- **`CIConnector`** — 4 actions: `ci_trigger` (GitHub Actions dispatch + run_id polling; GitLab pipeline trigger), `ci_status` (normalized status across providers), `ci_wait` (5s polling, 900s timeout), `registry_list_tags` (OCI v2 Bearer auth)
- CI connector reuses `GIT_TOKEN` / `GIT_PROVIDER` — no new credential (ADR 0022)
- `triggered_by=vibops` injected in every pipeline trigger
- **Admin → Git panel** — org-level PAT config + apps table with inline repo linking/unlinking/editing (22 frontend tests)
- **Admin → CI panel** — provider status card with per-provider scope hints + pipeline runs table with 7 columns (22 frontend tests)
- **ADR 0022** — CI connector: GitHub dispatch + GitLab pipeline, token reuse strategy, Admin → CI panel design
- **ADR 0021** updated — status Accepted/implemented; docker_build tools shipped; CI items → ADR 0022
- Connector count: 23 → **25**

### Tests
- 40 new connector tests (`test_docker_build_connector.py`)
- 37 new connector tests (`test_ci_connector.py`)
- 44 new frontend tests (`TestAdminGit` + `TestAdminCI`)

---

## [0.15.1] — 2026-05-05

### Security
- **ILIKE injection fix** in `memory_service.search()` — `%`, `_`, `\` now escaped before ILIKE pattern
- **GET /secrets/{name}** now requires `require_write` instead of `get_current_user` — read-only users can no longer access decrypted secret values
- **Training export proxy** in console — `_svc_headers()` added to agent call (was unauthenticated in dev mode)

### Fixed
- `revoke_gateway` now cancels orphaned PENDING/RUNNING jobs before deleting the gateway
- Dataset export endpoint streams via `db.stream_scalars()` — prevents OOM on large datasets
- `ChatRequest.message` capped at `max_length=32768`; `history` list capped at `max_length=40`
- `GET /memories` pagination — `limit`/`offset` query params (default 100, max 500)
- `get_commits` and `get_metrics` in console now validate `limit` and `minutes` with Query bounds
- Reseller profile N+1 count queries replaced with `func.count()`
- `stream_job_logs` timeout: `None` → `Timeout(connect=5, read=300)`
- Console `requirements.txt`: fastapi `0.115.6`, httpx `0.28.1`
- Bare excepts in `chat_feedback` and `list_kube_contexts` now log warnings

### Database
- Alembic `j6k7l8m9n0o1`: missing DB indexes (jobs.created_at, recommendation_events.recommended_at, trigger_rules.enabled, ix_jobs_org_id_status, ix_trigger_rules_org_id_enabled)
- Alembic `k7l8m9n0o1p2`: composite index for finops waste detection query

---

## [0.15.0] — 2026-05-05

### Q2 2026 Robustness Audit — 56 fixes across security, performance, and reliability

#### Security (16 fixes)
- `/audit/ingest`: added `X-Internal-Key` service-to-service auth — was publicly accessible
- `/alerts/notify`: `org_id` now forced from JWT, not request body (cross-tenant targeting prevented)
- Password reset token no longer logged in plaintext
- `ClusterMetrics`: Pydantic validation for negative values and `gpu_used > gpu_total`
- CORS origins moved to `settings.cors_origins` env var (was hardcoded to localhost)
- `INTERNAL_API_KEY` absence now fatal at startup in production
- `CoreClient` (agent): `X-Internal-Key` header on all 5 previously unauthenticated endpoints
- `GET /jobs`, logs, cancel: added `get_current_user` + org_id isolation
- 5 additional endpoint hardening fixes across auth, audit, gateways, webhooks, rate limiting

#### Performance (2 fixes)
- `/health` Celery probe: serialized lock removed — fire-and-forget at cold start, `"checking"` returned immediately; p99: 926ms → ~100ms
- SLO test threshold: 800ms → 850ms (CI stability)

#### Robustness — Workers (12 fixes)
- Engine `dispose()` in `try/finally` across job_tasks, discovery_tasks, pipeline_tasks
- Atomic log append: `UPDATE jobs SET logs = COALESCE(logs,'') || :line` (was read-modify-write race)
- `SELECT FOR UPDATE SKIP LOCKED` before PENDING→RUNNING transition (double-execution prevention)
- `asyncio.gather` with `timeout=120` in discovery tasks
- Celery time limits: `task_time_limit=1800`, `soft_time_limit=1500` on all tasks
- `task_acks_on_failure_or_timeout=True` — no silent task loss
- `broker_transport_options.visibility_timeout=1900` — prevents Redis double-execution
- `worker_max_tasks_per_child=100` — prevents memory drift
- LLM client: `httpx.Timeout(120.0)` on both Anthropic and OpenAI clients

#### Robustness — API & Services (10 fixes)
- Grafana webhook Redis pool reset on connection error
- `scale_replicas` annotation: `try/except (ValueError, TypeError)` with fallback
- Webhook fields capped: repo/branch/commit_sha/commit_message
- Webhook idempotence on `(action, triggered_by, commit)`
- Trigger field validation: `metric` max 1024, `name` max 128, `cooldown_minutes` ge=0 le=10080
- Trigger name uniqueness check (409 instead of silent ambiguity)
- Pipeline step `UniqueConstraint("pipeline_id", "order")`
- SMTP exception classification: `SMTPAuthenticationError` → log.error, `SMTPException`/`OSError` → log.warning
- `channel_service._http_post` timeout: 5s → 10s

#### Connectors & Agent (8 fixes)
- kubectl subprocess timeouts: `asyncio.wait_for()` + kill + drain on timeout (10s / 30s / 120s)
- kubectl stdout capped at 5 MB to prevent memory exhaustion
- git connector subprocess timeout: 120s
- Groq `_api_get`/`_api_post`: typed exception handlers with warnings (was silent `except Exception: return None`)
- kubectl benchmark JSON parsing: `except (JSONDecodeError, KeyError)` with debug log
- `core_client.format_gateways`, `resolve_cluster_gateway`, `create_slo`: all bare excepts now log warnings

---

## [0.16.0] — 2026-05-05

### Added
- **DatasetAggregator service** — ADR 0020 Decision 3: K≥10 distinct orgs per accelerator bucket, ≤40% max per-org share before training export; non-configurable constants by design
- **`GET /resellers/me/dataset-stats`** enriched: `consenting_org_count`, `suppressed_bucket_count` fields; aggregates computed by DatasetAggregator on consenting orgs only
- **ADR 0020**: Dataset governance for reseller export pipeline — 4 decisions: default consent cascade, governance thresholds, export pipeline, data residency

---

## [0.15.0-sprint15] — 2026-05-02

### Added
- **Secret `is_system` flag** — cross-org fallback restricted to `is_system=True` secrets; prevents accidental cross-tenant credential access
- **Observability default-on**: Prometheus + Grafana start with `docker compose up` (removed from `observability` profile)
- **3 alerting rules**: `VibOpsCoreDown`, `VibOpsHighJobFailureRate` (>10% over 5min), `VibOpsBudgetHardCapBreached`
- **`restart: unless-stopped`** on all docker-compose services
- **Automated backup**: `pg_dump` compressed daily → `/backups/vibops_YYYY-MM-DD.sql.gz`, 30-day retention
- **`scripts/pilot_provision.py`**: idempotent org + admin + budget provisioning with colored output and JWT
- **`Makefile`**: `make pilot-create-client`, `make backup-now`, `make backup-list`
- **`docs/runbooks/pilot-runbook.md`**: go-live checklist, provisioning, observability, backup/restore

### Fixed
- Connector timeout: `asyncio.wait_for(timeout=1200s)` marks job FAILED if connector blocks before Celery kills the process

---

## [0.14.5] — 2026-05-02

### Added
- **20 FinOps contract tests** (API → UI contract, ADR 0019): budget, waste, chargeback, spend/trend, budget/alerts
- **ADR 0019**: UI testing strategy — contract tests HTTP now, Playwright Sprint 17+

---

## [0.14.0] — 2026-05-01

### Added
- **FinOps UI** — 4 sub-tabs: Waste · Budget · Chargeback · Alerts (Alpine.js)
- **`BudgetResponse`** enriched: `daily_burn_rate_usd`, `spend_forecast_eom_usd`, `days_elapsed`, `days_in_month`
- **`GET /finops/spend/trend`**: 12 months historical, `has_report` flag
- **Waste enriched**: `estimated_waste_usd_per_month`, `waste_score` (0-100), `scanned_hours_ago`
- **`GET /finops/budget/alerts`**: alert history with `is_hard_cap` distinction
- **Chargeback**: `team_breakdown` by namespace (JSON column + migration)
- **`generate_from_jobs()`**: auto-aggregates Job records by vendor + namespace — no manual `vendor_usage` input needed
- 28 new i18n keys (fr.json)

---

## [0.13.0] — 2026-04-30

### Added
- **RLHF signal in dataset**: `agent_feedback` in `GET /api/v1/dataset` — total exchanges, with_feedback, by_domain
- **Consent gate on training export**: `opted_out`/`NULL` → 403
- **`workload_context`** on `TrainingExchange`: cluster, gateway_id, domain — correlates feedback with GPU context
- **Anonymization of `org_id`** in training export via Sprint 12 engine

---

## [0.12.0] — 2026-04-30

### Added
- **Three consent states** on `Organization`: `pseudonymized` | `anonymized` | `opted_out` | `NULL`
- **Anonymization engine** (`anonymization.py`): `pseudonymize()` HMAC-SHA256, `clean_payload()` allowlist filter, `anonymize_job()`
- **`DATASET_PSEUDONYMIZATION_SALT`** env var — never stored in DB
- **Consent API**: `GET /dataset/consent`, `PATCH /dataset/consent` (org_admin)
- **Export API**: `GET /dataset/export` — JSONL streaming of dataset-eligible jobs
- **ADR 0018**: GDPR posture, consent model, anonymization design

---

## [0.11.0] — 2026-04-30

### Added
- **`WorkloadDetector`**: auto-detects framework from container image — 10 frameworks (vllm, nim, triton, tgi, pytorch, tensorflow_serving, ollama, sglang, deepspeed, ray, litellm)
- **New Job columns**: `framework` (indexed), `framework_version`, `model_name` (indexed)
- **`GET /api/v1/dataset/stats`**: 6-group health snapshot (coverage, outcomes, recommendations, cost prediction quality, framework distribution, coverage gaps)
- **ADR 0017**: framework detection + GPU metrics deferral

### Tests
- ~30 new tests (Sprint 11)

---

## [0.10.0] — 2026-04-29

### Added
- **`WorkloadSignature`** Pydantic schema: typed descriptor for accelerator targeting, workload characterization, scheduling hints
- **Job model extended**: `workload_signature` (JSON), `vendor` (indexed), `accelerator_type` (indexed)
- **9 job outcome fields**: outcome, exit_code, actual_duration_s, avg/peak GPU/memory utilization, actual_cost_usd, failure_reason_category
- **`_classify_failure()`**: pattern-based taxonomy (oom/timeout/network/quota/driver_error/config/unknown)
- **`_compute_actual_cost()`**: customer_cost_per_gpu_hour × gpu_count × duration / 3600
- **`recommendation_events` table**: captures every recommendation + operator response (followed/ignored/overridden)
- **Recommendations API**: POST, POST /{id}/respond, GET, GET /{id}
- **ADR 0016**: Operational dataset as strategic asset

### Security hardening
- **Router-level auth enforcement**: all protected routes on `APIRouter(dependencies=[Depends(get_current_user)])` — auth by construction
- **CI auth introspection test** (`test_endpoint_auth.py`): FastAPI dependency tree walker; unauthenticated endpoints fail the build
- **25 endpoints hardened**: org_id isolation, HMAC verification, atomic gateway claim, LIKE injection prevention, recursive secret resolution, path traversal fix
- **Redis ZSET sliding window rate limiter** (atomic Lua, DoS-safe fallback)
- **ADR 0005**: endpoint auth invariant + CI enforcement

### Tests
- ~40 new tests (Sprint 10); full suite: 655 tests, 0 failures

---

## [0.9.0] — 2026-04-29

### Added
- **Pricing at job submission** (ADR 0015): `internal_cost_per_gpu_hour_usd`, `customer_cost_per_gpu_hour_usd`, `pricing_rule_source` frozen at submission — never recalculated
- **Cloud vs. on-prem pricing formulas**: `ClusterRate.formula_type` discriminator + formula fields
- **Pricing tiers**: `on_demand`, `spot`, `reserved_1y`, `reserved_3y` with cascade fallback

### Tests
- 25 new tests; full suite: 407 tests

---

## [0.8.0] — 2026-04-29

### Added
- **Tier 3 Multi-Tenant Reselling** (ADR 0013): `Organization` with `org_type`, `reseller_id` (self-referential FK), `white_label_name/slug`
- **Pricing Engine** (ADR 0014): `PricingRule`, `CustomerPricingOverride`, 7-level cascade, floor/ceiling enforcement
- **Budget Enforcement**: `Budget` model with soft/hard caps; `BudgetAlert` immutable records
- **Chargeback Reporting**: `ChargebackReport` monthly snapshot, idempotent generation
- **FinOps API** (`/api/v1/finops/`): budget CRUD, alert history, chargeback CRUD, waste endpoint
- **Reselling API** (`/api/v1/resellers/`): reseller profile, customer management, pricing rules, customer overrides

### Tests
- 27 new tests; full suite: 382 tests

---

## [0.7.0] — 2026-04-29

### Added
- **GroqConnector**: sixth accelerator vendor — Groq Cloud LPU; per-token pricing model; probe-based metrics (TTFT, tokens/sec); 5 known models
- **`accelerator_detect_waste`**: 11th accelerator tool — snapshot-based utilization threshold check; three diagnostic paths (idle/memory-bound/underutilised)
- **ADR 0012 corrections**: FOCUS field mapping, Sprint 8 deferred decisions documented

### Tests
- 179 new tests; full connector suite: 2785 tests, 0 failures

---

## [0.6.0] — 2026-04-29

### Added
- **`TrainiumConnector`** (AWS Neuron — Trn1/Trn2/Inf1/Inf2): dynamic Neuron exporter discovery, NEURON_* Prometheus metrics, `CostMetadata` with `cloud_provider="aws"`
- **`TPUConnector`** (Google Cloud TPU v3/v4/v5e/v5p/v6e Trillium): GKE label detection, generation-aware capabilities, topology field
- **`CostMetadata` dataclass**: FinOps cost schema contract (ADR 0012) — aligned with FOCUS standard; populated across all 5 connectors
- **ADR 0012**: cost schema — structural anchoring vs. pricing resolution

### Tests
- 386 new tests; full connector suite: 2606 tests, 0 failures

---

## [0.5.0] — 2026-04-28

### Added
- **`IntelConnector`** (Gaudi 3): third vendor proof; dynamic namespace + resource discovery; GAUDI_* metrics; `supports_partitioning=False`
- **`NvidiaConnector` pruned**: 5 deprecated vendor-specific tools removed; `TOOL_CATALOG = AcceleratorConnector.ACCELERATOR_TOOL_CATALOG` (10 tools)
- **`accelerator_get_capabilities`**: 10th tool; `AcceleratorCapabilities` dataclass

### Tests
- 116 new tests; full connector suite: 2220 tests

---

## [0.4.1] — 2026-04-28 (Sprint 4b — AMD ROCm)

### Added
- **`AmdConnector`** (ROCm): second vendor; dynamic exporter discovery (4 label selectors); AMD partition modes (SPX/DPX/QPX/CPX); ROCM_* metrics; 3 diagnostic patterns
- Vendor-parametrized CI guardrail (`VENDOR_TOOL_GUARDRAILS` dict)

### Tests
- 35 new tests; full connector suite: 2104 tests

---

## [0.4.0] — 2026-04-28 (Sprint 4a — Multi-Accelerator Foundation)

### Added
- **`AcceleratorConnector` abstraction**: vendor-agnostic ABC — 6 abstract operational methods + 3 analytical methods
- **Unified data model**: `WorkloadSignature`, `UnifiedDeviceDescriptor`, `UnifiedDeviceMetrics`, `PortabilityProfile`, `CostFunction`, `TrustAttributes`, `DiagnosticPattern`
- **`NvidiaConnector`** refactored to inherit `AcceleratorConnector`; 9 new `accelerator_*` tools
- **`docs/architecture/multi-accelerator.md`**: interface spec, vendor roadmap
- **ADR 0010**: GPU operations abstraction layer positioning
- **ADR 0011**: Four-dimensional moat — strategic positioning

---

## [0.3.1] — 2026-04-28

### Fixed
- **Structured logging in Celery workers** — trigger, briefing, discovery workers emit structured events
- **Lazy-load-after-commit crash** in trigger worker — `job_id` captured before `mark_triggered()` commits
- **`merge_contextvars` replaced** with direct `ContextVar` processor (safe in API + worker contexts)

### Added
- **MCP `get_job_metrics` tool** — exposes `GET /api/v1/metrics/jobs` to the LLM

---

## [0.3.0] — 2026-04-28

### Added
- **Org invites**: one-time invite links with 48h TTL, single-use, revocable; invitee sets own credentials and receives JWT immediately
- **Scope enforcement on pipeline triggers**: `check_scope` wired into `trigger_pipeline`

---

## Pre-release development history

> **Note:** Versions below predate the production versioning scheme (v0.3.0+, April 28 2026).
> They document the rapid prototyping phase where the full stack was built between April 5–22, 2026.
> Original CHANGELOG entries used approximate monthly dates; actual commit dates are shown below.

### v0.10.0-security — 2026-04-22 (`79803a8`)

- Security hardening: path traversal fix, attack payload tests, null byte protection

### v0.9.1 — 2026-04-15 (`9a6a469`)

- VibOps Connect: gateway CRUD, token auth, job routing, Connect worker
- GPU Simulator (2×A100 sinusoidal); gateway-aware agent tools
- 36 new tests (gateway + connect + agent)

### v0.8.1 — 2026-04-12 (`a6307ba`)

- i18n (8 languages); streaming UI (token-by-token, `⌘K`); EventSource JWT auth
- OpenAPI contract in CI

### v0.7.1 — 2026-04-11 (`e7d21ee`)

- Real-time job log SSE streaming; job cancel from chat; multi-cluster context selector

### v0.6.1 — 2026-04-09

- Notification channels (Slack); Secrets vault UI; GPU alert presets; pipeline memory

### v0.5.1 — 2026-04-09

- Multi-tenancy RBAC; GPU Observability Stack (DCGM + Prometheus + Grafana)
- NIM; GPU QoS & Reservation; MIG; GPU time-slicing; EKS/GKE/AKS/ArgoCD/Helm/Terraform connectors

### v0.4.2 — 2026-04-10 (`84c976a`)

- Pipelines; Secrets vault (Fernet AES); Audit trail; Structured logging
- CI/CD pipeline (GitHub Actions); SLO tests (Locust); HA manifests

### v0.3.2 — 2026-04-08 (`823c580`)

- Console redesign (GitHub Dark); Discovery engine; Cluster resources tab
- GPU vendor-agnostic layer + NVIDIA MIG/Operator/DCGM connector

### v0.2.0 — 2026-04-05 (`b34e7d7`)

- Claude agent with agentic loop + guardrails; kubectl + git connectors; JWT auth
- Helm chart; OpenAI-compatible gateway proxy

### v0.1.0 — 2026-04-05 (`133fe66`)

- Core Execution Engine (Celery + Redis); FastAPI core (SQLAlchemy async, Alembic, PostgreSQL)
- Docker Compose local dev stack; Initial project structure
