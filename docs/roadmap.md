# VibOps — Technical Roadmap

_Last updated: 2026-11-02 · v0.68.0_

## Principles

- Ship value iteratively — no big bang releases
- Each item is independent and can be prioritized separately
- Connect Gateway items are gated on having a first Connect client signed
- Enterprise segment features are as valid as CSP features — roadmap serves both

---

## Done — shipped ✓

### Core platform
- [x] Multi-cluster discovery and resource audit
- [x] Production safety guardrails (confirmation required for destructive ops)
- [x] Dry-run preview — `reversibility`, `resolved_params`, `estimated_cost_hourly_usd`
- [x] PolicyEngine default-deny — every action must be in TOOL_CATALOG (ADR 0001)
- [x] Two-tier authorization — `evaluate()` for API callers, `evaluate_system()` for Celery workers (ADR 0002)
- [x] Multi-tenant isolation — row-level `org_id` from JWT, never from request body (ADR 0003)
- [x] Rate limiting — sliding window, Redis ZSET, 60 req/60s/org (ADR 0004)
- [x] Endpoint auth invariant — router-level enforcement + CI test (ADR 0005)
- [x] Structured logging (structlog JSON, hot-path events on all critical paths)
- [x] Request correlation — `RequestIdMiddleware`, `X-Request-ID` propagated to workers
- [x] Job SLIs — `GET /api/v1/metrics/jobs` (throughput, success rate, p50/p95 by action)
- [x] Secrets vault — Fernet-encrypted, recursive payload resolution, never logged
- [x] Pipelines — multi-step with `on_failure: rollback` guards, `evaluate_system()` gate per step
- [x] Trigger rules — event-driven automation (GPU utilization, alert state, schedule), AND/OR logic
- [x] Org invites — one-time link, 48h TTL, single-use, revocable

### Multi-Accelerator Abstraction (Sprints 4a–7)
- [x] `AcceleratorConnector` ABC — vendor-agnostic interface over all GPU/accelerator vendors
- [x] Unified data model — `WorkloadSignature`, `UnifiedDeviceDescriptor`, `UnifiedDeviceMetrics`
- [x] 11 unified tools — `accelerator_diagnose`, `accelerator_detect_waste`, `accelerator_workload_match`, `accelerator_get_metrics`, `accelerator_deploy_workload`, `accelerator_portability_check`, `accelerator_cost_estimate`, `accelerator_install_operator`, `accelerator_list_devices`, `accelerator_partition_device`, `accelerator_get_capabilities`
- [x] NVIDIA connector refactored — inherits `AcceleratorConnector`, vendor-specific tools removed from public API
- [x] AMD ROCm connector — SPX/DPX/QPX/CPX partitioning, dynamic exporter discovery
- [x] Intel Gaudi connector — dynamic namespace/resource detection, GAUDI_* metrics
- [x] AWS Trainium/Inferentia connector — Neuron SDK, Trn1/Trn2/Inf1/Inf2
- [x] Google TPU connector — v3/v4/v5e/v5p/v6e, topology-aware, GKE label detection
- [x] Groq connector — LPU managed service, per-token cost model, probe-based metrics
- [x] CI guardrails — `test_no_new_nvidia_specific_tools_when_accelerator_equivalent_exists`
- [x] ADR 0010 — GPU operations abstraction layer positioning
- [x] ADR 0011 — Four-dimensional moat strategic positioning
- [x] ADR 0012 — Accelerator cost schema (structural anchoring vs pricing resolution)

### FinOps Engine (Sprints 8–9, 14–14.5)
- [x] Tier 3 reselling architecture — `org_type`, `reseller_id`, white-label name/slug (ADR 0013)
- [x] Pricing engine — 7-level specificity cascade, floor/ceiling, markup transparency (ADR 0014)
- [x] Budget enforcement — soft cap (alert) + hard cap (block), deduplication
- [x] Chargeback reporting — monthly snapshot per org, idempotent generation, vendor breakdown
- [x] At-submission pricing — prices frozen at job creation, never recalculated (ADR 0015)
- [x] Cloud vs. on-prem formulas — `formula_type` discriminator, TCO normalization
- [x] Pricing tiers — `on_demand`, `spot`, `reserved_1y`, `reserved_3y`
- [x] `accelerator_detect_waste` — snapshot-based idle GPU detection, vendor-agnostic
- [x] **Sprint 14** — FinOps UI 4 sous-onglets (Waste / Budget / Chargeback / Alerts)
- [x] **Sprint 14** — Budget live spend from jobs (`_get_monthly_spend` fallback on Job records)
- [x] **Sprint 14** — EOM forecast (`daily_burn_rate`, `spend_forecast_eom_usd`)
- [x] **Sprint 14** — `generate_from_jobs()` — chargeback auto depuis Job records, plus besoin de `vendor_usage`
- [x] **Sprint 14** — `team_breakdown` sur ChargebackReport — coûts par namespace
- [x] **Sprint 14** — `GET /finops/spend/trend` — 12 mois historiques + sparkline UI
- [x] **Sprint 14** — Waste enrichi : `waste_score` (0-100), `scanned_hours_ago`, `estimated_waste_usd_per_month`
- [x] **Sprint 14.5** — 20 contract tests HTTP couvrant tous les endpoints FinOps (ADR 0019)

### Operational Dataset & RLHF (Sprints 10–13)
- [x] `WorkloadSignature` — typed descriptor for accelerator targeting + data governance
- [x] Job outcome tracking — `outcome`, `failure_reason_category`, `actual_cost_usd`, duration
- [x] `_classify_failure()` — typed taxonomy: oom / timeout / network / quota / driver_error / config
- [x] `RecommendationEvents` — captures followed/ignored/overridden signals
- [x] Dataset stats API — `GET /api/v1/dataset/stats` (6-group health snapshot)
- [x] Framework auto-detection — `WorkloadDetector` on container image (10+ frameworks)
- [x] Consent model — `pseudonymized` / `anonymized` / `opted_out` per org (ADR 0018)
- [x] Anonymization engine — HMAC-SHA256 pseudonymization, allowlist payload filter
- [x] Export API — JSONL jobs + training exchanges (alpaca/sharegpt/chatml formats)
- [x] RLHF feedback loop — thumbs up/down per agent response, wired into training export
- [x] `workload_context` on `TrainingExchange` — cluster/gateway/domain correlation

### Agent Behavioral Model
- [x] 13 mandatory rules in system prompt (ADR 0007) — act directly, parallel execution, anti-loop, confirmation flow, etc.
- [x] Language policy — agent responds in user's language (ADR 0008)
- [x] 3-layer testing stack — L1 form, L2 coherence, L3 behavioral (ADR 0009)
- [x] Incident response workflow — `correlate_incident` → `analyze_pod_failure` → `remediate_incident`
- [x] Epistemic honesty — `confidence` field, "not observed ≠ not present"
- [x] Multi-accelerator routing — `accelerator_*` tools mandatory, vendor-specific tools FORBIDDEN
- [x] GitOps workflow — `git_clone` → `git_patch_yaml` → `git_commit_push` → `git_create_pr`
- [x] NIM workflow — `nim_list_catalog` → `nim_profiles` → GPU audit → `nim_deploy`
- [x] Memory system — `save_memory` / `recall_memory`, proactive saving after incidents and decisions
- [x] **Proactive agent engine** — 7 event-driven insight types, dashboard "Proaction Required" panel with click-to-chat, auto-acknowledge on remediation, toast notifications (ADR 0029) ✓ v0.33.0

### Observability
- [x] Prometheus webhook integration (`POST /api/v1/webhook/grafana`)
- [x] Alert JSON → natural language → agent pipeline
- [x] Multi-source incident correlation (`correlate_incident` — logs + events + metrics + deployment)
- [x] Prometheus missing detection + auto-install offer (helm kube-prometheus-stack)
- [x] SLO monitoring — `create_slo`, breach triggers remediation or trigger rule

### Multi-tenancy & Auth
- [x] Organisation → Team → Member RBAC model
- [x] JWT enriched with org + teams + scope
- [x] Admin panel: Teams / Users / Audit / Memories / Notifications / Secrets / Integrations / Licence
- [x] Password change, refresh token (7 days)
- [x] **Sprint 15** — Tier 3 secret isolation (`is_system` gate — cross-org fallback restreint aux shared credentials explicites)

### Licence & Packaging
- [x] RS256 JWT licence — vendor holds private key, clients cannot forge
- [x] Trial 14 days, plan enforcement (users_max, clusters_max, gpu_max)
- [x] Helm chart `helm/vibops` — HPA, PDB, ServiceMonitor, TLS
- [x] `scripts/package-delivery.sh` — air-gapped delivery package
- [x] `scripts/onboard-client.sh` — CSP / Enterprise segment-aware (Helm/K8s)
- [x] ~~`scripts/update-docs.sh` — post-sprint doc bump (version, date, counts, Known limitations)~~ removed 02/11/2026: it read a `-sprintN` tag that no longer exists and had not run since the sprint era; the figures it bumped are now `scripts/update-figures.py`, and a « Last updated » date moves with the content, not with a script
- [x] **Sprint 15** — `make pilot-create-client` — provisioning Docker Compose pilot en une commande
- [x] **Sprint 15** — `docs/runbooks/pilot-runbook.md` — checklist go-live complète

### Résilience & Observabilité (Sprint 15)
- [x] `restart: unless-stopped` sur tous les services docker-compose
- [x] Service `backup` — `pg_dump` quotidien compressé, rétention 30 jours
- [x] Timeout connecteur `asyncio.wait_for(1200s)` — FAILED propre avant kill Celery
- [x] Prometheus + Grafana default-on (suppression du profil `observability`)
- [x] `GET /health` enrichi avec check worker Celery
- [x] 3 alerting rules : service down, failure rate >10%, budget hard cap
- [x] Counter `vibops_jobs_total{action, status}` dans le worker

### Workload Persistence & Slurm Collector (Sprints A/B — v0.17.3–0.17.5)
- [x] `workloads` table — `upsert_workloads()`, `mark_terminated_workloads()`, `finalize_completed_workloads()`; shadow-write alongside Prometheus live-query path
- [x] `WorkloadSnapshot` dataclass — canonical representation for K8s and Slurm collectors
- [x] `KubernetesWorkloadCollector` — Prometheus-based running GPU workload discovery
- [x] `sync_workloads` Celery Beat task (60 s) — multi-gateway, multi-collector dispatch
- [x] `GET /api/v1/workloads` + `GET /api/v1/workloads/{id}` — filtered listing + detail endpoints
- [x] `SlurmWorkloadCollector` — REST (slurmrestd v0.0.38) → SSH+JSON fallback; `parse_alloc_gres()` for GRES multi-type
- [x] `SlurmGatewayConfig` — validated config dataclass with secret name references
- [x] `gateway_type` + `slurm_config` JSONB on Gateway model (migration `d5e6f7a8b9c0`)
- [x] Hybrid gateways — both K8s and Slurm collectors run; snapshots merged
- [x] sacct integration — `collect_completed()` captures terminal jobs between polls; `finalize_completed_workloads()` writes exact timestamps
- [x] Console Workloads sub-tab in FinOps panel
- [x] Console gateway form — gateway_type select, Slurm config section, prometheus_url field
- [x] ADR 0024 — Slurm workload collector (transport hierarchy, GRES parsing, secret management)
- [x] **Sprint A/B** — `node_name` on Workload model + KubernetesWorkloadCollector populates from Prometheus Hostname; vm-usage joins workloads by node_name ✓ v0.26.0
- [x] **Sprint C** — `VmGpuCollector` — GPU workload discovery on VMs without K8s (bare-metal CUDA, rendering, VDI, HPC/Slurm). SSH + nvidia-smi polling, `vm_gpu_config` on Gateway model. ✓ v0.27.0

### Agent Catalog UX & Tool Policy (Sprint 1 — 2026-05-30)
- [x] **OPS-A01** — Agent Catalog schema drawer: click any action to view its full input schema (description, typed parameters, required/optional fields, enum values)
- [x] **OPS-D01** — Per-org `requires_confirmation` policy override — org admins can force confirmation on any action regardless of connector default
- [x] **OPS-E03** — Per-org `requires_external_approval` policy override — route any action through external approval workflow
- [x] **OPS-E06** — `ToolPolicyOverride` model + `PATCH /api/v1/catalog/{action}` endpoint — persistent, audited, per-org policy storage
- [x] Action search field: replaced `<input>` with `<div contenteditable>` — browsers no longer autofill the search box
- [x] Security: `starlette==0.47.2` pinned, PYSEC-2026-161 tracked (blocked by `prometheus-fastapi-instrumentator` starlette<1.0.0 ceiling)
- [x] CI: all connector test warnings eliminated (`pf_proc.terminate` AsyncMock → MagicMock)

### AgentOps Sprint 2 — Approvals, Tag Search, Declarative Policy (2026-05-30)
- [x] **#5** — Async approval notifications: `ChannelService.notify_approval_request()` dispatches to all active org channels (Slack Block Kit with Approve/Reject URL buttons, HTTP webhook, email, PagerDuty)
- [x] **#5** — Admin Approvals console sub-tab: list pending approval gates, approve/reject directly from the console (JWT-authenticated `POST /approvals/{gate_id}/approve|reject`)
- [x] **#2** — Tag-based search in Agent Catalog: `ToolSpec.tags` field + `_CONNECTOR_TAGS` fallback mapping (25 connectors), tag dropdown filter, clickable tag chips, `?tag=` query param on `GET /catalog`
- [x] **#6** — Declarative YAML policy format + OPA/Rego compatibility (ADR 0026): `org_policy_rules` table, `PUT /api/v1/policy`, YAML rules with `deny`/`require_confirmation`/`require_approval`/`require_role`/`allow` effects, match conditions (action glob, namespace, env, cluster, replicas comparisons), OPA sidecar mode via `OPA_URL`
- [x] CI: pre-commit hook auto-regenerates `docs/openapi.json` and stages it — no more manual regen after schema changes

### AgentOps Sprint 3 — Execution History, Session Replay, LLM-as-Judge (2026-05-30)
- [x] **#1** — Action execution history per tool: `GET /api/v1/catalog/{action}/history` returns total/success/failure counts, success rate, average duration, and the 20 most recent runs — surfaced in the catalog schema drawer
- [x] **#3** — Session replay: click any job in the history to open a step-by-step replay modal — each tool call is shown with its input, output, timestamp, and duration; long jobs are paginated (20 steps per page)
- [x] **#4** — LLM-as-judge evaluation: `EvalRubric` + `JobEvaluation` models, async Celery eval task, full CRUD API (`/eval/rubrics`, `/eval/evaluations`); rubrics define weighted criteria and a scoring prompt; evaluation is triggered from the replay modal; results (score 0–1, per-criterion scores, justification) are stored and displayed inline
- [x] **#4** — Multi-provider LLM judge: provider `"vibops"` (default) inherits `LLM_PROVIDER`/`LLM_API_KEY`/`LLM_BASE_URL`/`LLM_MODEL` from env — evaluations automatically use the same LLM as the agent (Anthropic, vLLM, Groq, Together, Ollama…); explicit `"claude"`, `"openai"`, `"ollama"` providers also supported per rubric
- [x] Admin → **Eval Rubrics** sub-tab: create rubrics, define criteria with weights, choose LLM provider/model; rubrics list with run counts

### AgentOps Sprint 4 — Anomaly Detection, Live Cost, L2 Scanner (2026-05-30)
- [x] **A** — Proactive GPU anomaly detection: `AnomalyEvent` model + Celery Beat task `vibops.detect_anomalies` every 5 min; detects `gpu_idle` (<10%), `gpu_spike` (>90%), `node_loss`, `utilization_drop` (>30 pt drop) from `GpuMetricHistory`; deduplication + auto-resolution; notifies configured channels; Dashboard widget with severity badges + manual resolve
- [x] **A** — Anomaly API: `GET /api/v1/anomalies`, `GET /anomalies/open`, `POST /anomalies/{id}/resolve` (org_admin)
- [x] **B** — Live workload cost attribution: `GET /finops/workloads/live-cost` — running workloads × elapsed time × ClusterRate formula → `estimated_cost_usd` per workload, sorted by cost desc; FinOps Workloads panel shows live cost table + total
- [x] **C** — L2 LLM-as-judge auto-scanner: `EvalRubric.is_auto_scanner` flag — when enabled, every job completion (success or failure) automatically triggers `evaluate_job` Celery task; checkbox in Admin → Eval Rubrics form
- [x] fix(tests): `authed_client` fixture in conftest.py; all 12 `test_triggers.py` failures fixed (401 auth + transaction isolation)

### MCP Server (`VibOpsai/vibops-mcp`)
- [x] 16 observation tools — clusters, deployments, jobs, GPU metrics, MTTR, cost, gateways, alerts, pipelines…
- [x] 14 action tools — scale, deploy, helm upgrade/uninstall, kubectl, git clone, create secret, trigger pipeline, Slurm (6 tools)
- [x] 3 config tools — set cluster rate, register/delete gateway
- [x] 22 governance tools — anomalies, AI Act, compliance reports, audit chain, policy, agent identities, dependency graph, LLM-as-judge
- [x] 4 FinOps tools — budget, chargeback, spend trend, waste analysis
- [x] **117 tools total** — published on PyPI (`vibops-mcp`) + GitHub

### Security
- [x] CVE scanning — `pip-audit` on all `requirements.txt` + Trivy filesystem scan, blocking on HIGH/CRITICAL, runs on every push and PR
- [x] **Security agent (DAST)** — 8 automated pentest checks (scope bypass, auth bypass, tenant isolation, input injection, rate limiting, privilege escalation, IDOR, header injection); weekly Celery Beat schedule + on-demand `POST /security/scan`; dev/prod mode awareness (downgrades expected findings); critical/high findings auto-create ProactiveInsight; results in `security_scan_results` table; SOC 2 CC7.1 continuous monitoring evidence; 9 tests (ADR 0030)
- [x] **Compliance agent** — 8 SOC 2 runtime checks (CC6.1, CC6.2, CC7.1, CC7.2, CC7.4, CC8.1, A1.2, C1.1) verifying controls are active at runtime; daily Celery Beat + on-demand API; non-compliant findings auto-create ProactiveInsight; 10 tests (ADR 0031) ✓ v0.35.0
- [x] **Security Sprint (2026-06-20) — 19 vulnerabilities fixed across 5 commits (v0.20.1)**
  - CRITICAL: cross-org access bypass in `tenants.py` — `_enforce_org_isolation()` on all 13 org-scoped routes
  - HIGH: LDAP injection — `escape_filter_chars()` before filter substitution
  - HIGH: `python-jose` CVEs (PYSEC-2024-232/233) in gateway → replaced with `PyJWT==2.13.0`
  - HIGH: password reset token logged in plaintext — removed
  - HIGH: audit ingest `org_id` spoofing — `X-Internal-Key` required in all environments
  - HIGH: httpOnly cookies + CSRF — ADR-0006 closed; `vibops_access` / `vibops_refresh` cookies, double-submit XSRF pattern, stream tickets for EventSource
  - MEDIUM: webhook cross-tenant job execution — `org_id` scoping on all webhook-triggered jobs
  - MEDIUM: Vault key silent plaintext fallback → `ValueError`
  - MEDIUM: gateway job routes scoped by `org_id`
  - MEDIUM: gateway `/docs` disabled in production; CORS wildcard guard; `run_kubectl` marked destructive
  - LOW: `Permissions-Policy` header; CSP `frame-src` scoped to Grafana URL; kubeconfig upload 1 MB limit
  - HARDENING (11 fixes): real client IP in login alerts, account lockout (5 attempts / 15 min), rate limit on forgot/reset-password, auth bypass dev-only, HSTS, security headers on core, Swagger off in prod, dev token guard, configurable alert email, JWT expiry 2h, no exception leak in proxy

### Connect Gateway
- [x] `vibops-worker` standalone image + Helm chart `charts/vibops-connect`
- [x] Gateway heartbeat + cluster metrics push
- [x] Bearer token auth, atomic job claim
- [x] Onboarding wizard in console

---

### AgentOps Sprint 5 — Compliance, SSO, Agent Lifecycle + Graph (2026-05-30)

**Issue #7 — EU AI Act compliance controls mapping**
- [x] `AIActControl` model — per-article compliance status (Art9/12/13/14/15/17)
- [x] `POST /compliance/ai-act/seed` — idempotent seeding of the 6 core articles
- [x] `GET /compliance/ai-act` + `GET /compliance/ai-act/score` — list + compliance score
- [x] `PATCH /compliance/ai-act/{id}` — update status / notes / evidence URL
- [x] Console Compliance tab — AI Act widget with article cards and inline status update

**Issue #8 — SOC 2 / GDPR automated compliance report generation**
- [x] `ComplianceReport` model — status (`pending` → `ready` | `failed`), JSON summary
- [x] `POST /compliance/reports` — async generation via FastAPI BackgroundTasks
- [x] Report analyzes AuditLog for SOC2 CC controls, GDPR articles, HIPAA safeguards
- [x] `GET /compliance/reports` + `GET /compliance/reports/{id}` — list and detail
- [x] Console report generation form + table with status badges

**Issue #9 — SSO SAML/OIDC integration**
- [x] OIDC columns on Organization model (provider, issuer, client_id, encrypted secret, JIT, default_role)
- [x] `GET/PUT/DELETE /sso/config` — org admin OIDC configuration management
- [x] `GET /sso/oidc/login` — initiate OIDC authorization code flow (browser redirect)
- [x] `GET /sso/oidc/callback` — exchange code for token, JIT provision user, issue VibOps JWT
- [x] Supported providers: `azure_ad`, `okta`, `google`, `custom`
- [x] Console SSO tab — toggle, provider config form, status badge

**Issue #10 — Agent identity lifecycle management**
- [x] `AgentIdentity` model — Fernet-hashed API keys, rotation tracking, revocation
- [x] `POST /agent-identities` — create identity (raw key shown once)
- [x] `POST /agent-identities/{id}/rotate` — rotate key (new raw key shown once)
- [x] `POST /agent-identities/{id}/revoke` — immediate revocation
- [x] `DELETE /agent-identities/{id}` — hard delete
- [x] Console Agent Identities tab — creation, rotation, revocation, deletion

**Issue #11 — Agent dependency graph**
- [x] `AgentDependencyEdge` model — directed graph: agent → model / connector / sub-agent
- [x] `POST /agents/dependencies` — record/upsert edge (call_count incremented on repeat)
- [x] `GET /agents/{agent_id}/dependencies` — edges from a specific agent
- [x] `GET /agents/graph` — full org graph (nodes + edges for visualization)
- [x] `DELETE /agents/dependencies/{id}` — prune stale edge
- [x] Console graph panel — nodes and edges table

**v0.18.0 — 5 issues closed, 28 new tests, 22 new API endpoints, 4 new Alembic migrations**

---

### AgentOps Sprint 6 — Connector Catalog Extensions + Dynamic Agent Tool Loading (2026-06-04)

**Vendor-specific connector tools**
- [x] `AmdConnector` — `amd_list_devices` (ROCm device listing via `rocm-smi`), `amd_partition_device` (MIG-equivalent GPU partitioning)
- [x] `IntelConnector` — `intel_list_devices` (Gaudi device listing via `hl-smi`)
- [x] `TPUConnector` — `tpu_list_devices` (GCP TPU listing via `kubectl get tpu`), `tpu_install_operator` (TPU operator Helm install)
- [x] `TrainiumConnector` — `trainium_list_devices` (neuron-ls inventory), `trainium_estimate_cost` (Trainium cost estimation vs GPU equivalent)
- [x] `GroqConnector` — `groq_list_devices` (Groq LPU inventory via Groq Cloud API)
- [x] All vendor tools registered in `VENDOR_TOOL_GUARDRAILS` CI allowlist with justification; catalog tests updated to superset assertions

**OutscaleConnector — full TOOL_CATALOG (15 actions)**
- [x] OKS managed Kubernetes: `outscale_list_clusters`, `outscale_get_cluster`, `outscale_create_cluster`, `outscale_delete_cluster`, `outscale_get_kubeconfig`, `outscale_upgrade_cluster`
- [x] Node pools: `outscale_list_node_pools`, `outscale_create_node_pool`, `outscale_scale_node_pool`, `outscale_delete_node_pool`
- [x] Flexible GPU: `outscale_list_gpu_catalog`, `outscale_list_flexible_gpus`
- [x] Account: `outscale_list_vms`, `outscale_get_quota`, `outscale_get_consumption`
- [x] Console connector catalog: Google TPU entry added

**Dynamic agent tool loading**
- [x] `CoreClient.get_catalog()` — fetches `/api/v1/catalog` at agent startup
- [x] `AgentService._refresh_tools()` — merges catalog tools into agent context on boot; agent exposes ~243 tools (vs 150 hardcoded)
- [x] Startup hook in `agent/app/main.py` — `_refresh_tools()` called via `@app.on_event("startup")`
- [x] Dynamic dispatch fallback in `_execute_tool()` — any catalog tool not in the hardcoded set is dispatched via `CoreClient.run_job`

**Bug fixes**
- [x] Fix 500 on `GET /api/v1/catalog/{action}/history` — broken `func.cast(Job.status == JobStatus.SUCCESS, ...)` SQLAlchemy syntax simplified to a clean `func.count` query

**Security**
- [x] `PyJWT 2.12.0 → 2.13.0` — patches PYSEC-2026-175, PYSEC-2026-176, PYSEC-2026-177, PYSEC-2026-178, PYSEC-2026-179

**v0.19.0 — 18 files changed, 7 new connector tools, 15 Outscale actions, dynamic tool loading, 1 security fix**

---

### AgentOps Sprint 7 — Security hardening, FinOps attestation, Ascend NPU, White-label routing (2026-06-14)

**Issue #16 — Confirmation gates on all destructive DELETE routes**
- [x] `DELETE /gateways/{id}` and `DELETE /gateways/{id}/clusters/{name}` — dry-run preview (jobs_cancelled, clusters_removed) before confirmed=true deletion
- [x] `DELETE /secrets/{name}` — pre-flight existence check + confirmation gate
- [x] `DELETE /agent-identities/{id}` — dry-run shows name + revocation status
- [x] `DELETE /triggers/{rule_id}` — dry-run shows rule name + enabled status
- [x] All gates return 200 with impact preview without `?confirmed=true`

**Issue #17 — Auth standardization**
- [x] Router-level `dependencies=[Depends(get_current_user)]` on all protected routers (30 files audited)
- [x] Mixed-auth routers (gateways.py — JWT + gateway Bearer) explicitly excluded with comment
- [x] `briefing.py` — `require_write` at router level

**Issue #13 — Approval gate user context**
- [x] `ApprovalGate` model: `requested_by_user_id`, `requested_by_username`, `estimated_cost` columns
- [x] Migration inlined into `a2b3c4d5e6f7` (CREATE TABLE) to avoid ALTER TABLE ordering issues
- [x] `POST /jobs` — passes user context + estimated_cost from dry-run preview to gate creation
- [x] `GET /approvals` and detail endpoint — return user context fields
- [x] Console Approvals panel — shows requesting user + estimated cost badge

**Issue #12 — Signed billing export (BYOC enterprise)**
- [x] `GET /api/v1/finops/billing/export?month=YYYY-MM` — cryptographic attestation endpoint
- [x] HMAC-SHA256 over canonical (sorted-keys) JSON payload, keyed with `SECRET_KEY`
- [x] `signed_at` embedded inside the payload — timestamp tampering also breaks the signature
- [x] 12 contract tests: shape, signature validity, tamper detection (cost, org_id), validation, auth
- [x] Verification recipe in endpoint docstring (4 lines of Python, no VibOps SDK needed)

**Huawei Ascend NPU connector — agent integration**
- [x] `AscendConnector` — `ascend_list_devices`, `ascend_get_metrics`, `ascend_partition_device` (3 Ascend-specific tools + full `accelerator_*` abstract methods)
- [x] Hardware: Ascend 910B (64GB HBM2e), 910A (32GB), 310P (16GB inference); Kubernetes resource `huawei.com/Ascend910`
- [x] npu-smi metrics: Aicore utilization, HBM memory, temperature, power; simulated fallback for demo clusters
- [x] vNPU partitioning: full/half/quarter modes; semantics explicitly documented as NOT equivalent to NVIDIA MIG or AMD CPX
- [x] 22 tests (tool catalog, registry, npu-smi parser, list/metrics/partition/diagnose)
- [x] Agent `_RUN_JOB_TOOLS`: `ascend_list_devices`, `ascend_get_metrics`; `_CREATE_JOB_TOOLS`: `ascend_partition_device`
- [x] System prompt: Ascend vendor-specific tool section with vNPU semantics and target market context

**White-label custom domain routing**
- [x] `Organization` model: `white_label_domain` (unique, indexed, max 253 chars) + `white_label_contact_email`
- [x] Alembic migration `b1c2d3e4f5a6`
- [x] `GET /api/v1/branding` — public endpoint resolves CSP brand from `Host` header; falls back to VibOps defaults
- [x] `PUT /resellers/me` — accepts `white_label_domain` + `white_label_contact_email`; 409 on domain clash
- [x] Console: fetches `/branding` on init; applies name to `document.title` and header logo for white-label orgs
- [x] `t()` i18n function substitutes `contact_email` in all licence hint strings when `is_white_label: true`
- [x] Endpoint auth CI guard: `/branding` added to public allowlist with justification comment

**v0.20.0 — 4 issues closed, 12 new tests, 1 new public endpoint, 2 new model columns**

### Hardening, catalogue and agent runtime — ADR 0045 to 0073 (22 Sept → 1 Nov 2026)

Work this file did not record while it was being done. One line per decision; the ADR
carries the evidence, the CHANGELOG the release.

**Tenancy and data**
- [x] Tenancy as a database constraint, and isolation the database enforces — 46 of 47 tables under policy, `audit_logs` closed by decision (ADR 0045, 0047) ✓ 22/09/2026
- [x] Erasure, and what survives it (ADR 0046) ✓ 22/09/2026
- [x] Backups and retention documented, with the restore nobody has run named as the gap (ADR 0048) ✓ 23/09/2026
- [x] Work moved out of the routes — the rules apply from now on, the migration is opportunistic (ADR 0049) ✓ 03/10/2026
- [x] The audit chain forked under concurrency — fixed (ADR 0050) ✓ 04/10/2026
- [x] The refusal ratchet: every unnamed refusal in the suites named, 123 → 0 in three waves, five real defects found on the way; the authorization family held at zero (ADR 0052) ✓ v0.56.0
- [ ] Integrating with an Azure-only customer (ADR 0051) — proposed 11/10/2026, not decided

**Hypervisors and migration**
- [x] A migration layer: assess from the job that gathered the inventory, a campaign (waves, cap, window), the executor and the gesture that lets it move, rollback to ESXi with the proof that stops a split brain, five routes, six agent tools and three deliberately missing ✓ v0.56.0

**Gateway confinement and pass-through**
- [x] What confines the gateway, measured — three gaps closed the same day: confinement from the kernel, one capability granted, the metadata address closed, no inherited credentials in subprocesses (ADR 0054) ✓ v0.57.2–0.57.3
- [x] kubectl pass-through runs reads only, bounded where it runs (ADR 0056) ✓ v0.57.12; a write runs on the organisation's word, open by default with the switch to close it (ADR 0058) ✓ v0.59.0
- [x] Node maintenance, metadata, manifests and config catalogued, each with its proof; gateway chart grants the RBAC by name (ADR 0059) ✓ v0.59.0
- [ ] An R&D window before a group goes into production, on a fleet that already has its own CLI (ADR 0055) — proposed 21/10/2026, nothing decided

**Schedulers and accelerators**
- [x] NVIDIA Run:ai (KAI): scheduler queues read and priced, a queue capped, training jobs read and run with admission proven; two defects only a real install could show ✓ v0.56.3–0.57.0
- [x] NVLink domains read and never implied; a GB200 no longer reported as a B200 ✓ v0.57.0; an NVL72 under Kubernetes — ComputeDomains, and a drain that knows NVLink (ADR 0063) ✓ v0.63.0
- [x] Ray operated through kubectl and the API server's service proxy; a node's maintenance end to end with one proof, shown on the demonstration cluster (ADR 0061) ✓ v0.61.0–0.62.0
- [x] DSX Flex: VibOps as Infrastructure Management Agent (ADR 0064), a breach as a push-driven trigger with a permanent subscription (ADR 0065), a `power_cap` with an executing hand in DPS (ADR 0066); both probes repeatable against a real bus ✓ v0.63.0–0.65.0
- [x] Network ops, stage 1: HPE Aruba Central and Juniper Mist connectors; `aruba_halt` and `aruba_set_wlan` ship with their proofs (ADR 0073, proposed) ✓ v0.68.0

**Agent runtime**
- [x] The catalogue an organisation receives is the one its sites configure (ADR 0053, 0060) — the closed backlog entry below has the detail ✓ v0.60.0–0.60.1
- [x] The agent meters its own model calls into core's inference logs, cache split kept (ADR 0057) ✓ v0.57.12–0.60.0
- [x] The confirmation reaches the connector for every destructive action, not 37 of 90, and does not depend on the model remembering it ✓ v0.57.7–0.57.9; confirmation in chat follows the catalogue, and the model's word never counts (ADR 0062) ✓ v0.62.0
- [x] The dataset had recorded nothing for thirteen days — fixed; which tools a turn reached for and whether they worked is recorded; the PROVEN rate is readable without SQL ✓ v0.57.0–0.57.6
- [x] The operation graph: blast radius before an action, from live reads, resolved by the agent at the confirmation gate (ADR 0067) ✓ v0.65.2–0.66.0; operation graph and topology graph are two reads, not one (ADR 0071) ✓ 01/11/2026
- [x] Operational memory: an action's prior proven outcomes recalled at the confirmation gate (ADR 0068) ✓ v0.67.0
- [x] A behavioral eval harness for the agent, stage 1 (ADR 0069) ✓ v0.65.2
- [x] The agent's turn is a declared state machine, enforced at one chokepoint and verified against the live paths (ADR 0070) ✓ v0.66.0
- [ ] Tool exposure at scale: deterministic hierarchical selection, not agent-driven navigation (ADR 0072) — direction accepted 01/11/2026, not built

---

## P1 — Backlog (prioritized)

### Technical debt & hardening (architecture review, 12–14 Sept 2026)

Findings from a full-repository review. Ordered by what they cost if ignored, not by
difficulty. Full rationale and evidence: the review document and the commits cited.

- [x] **Decompose `agent_service.py`** — was 6,505 lines at 1 test / 135 lines, the
  lowest test density in the repo. Now 987, and 96.6% covered. Split into
  `tools_catalog`, `tool_routes`, `core_calls`, `vm_operations`, `incident_operations`,
  `job_operations`, `gateway_operations`, `prometheus_queries`. `_execute_tool` went
  from 963 lines to 110 and is a dispatcher again; `chat_stream` went from 1% to 100%
  covered. Characterization tests came first at every step and caught eleven defects,
  each fixed in its own commit. Remaining: extracting the loop itself — optional, the
  file is no longer a liability. (14 Sept 2026)

- [x] **Extend post-action verification to the actions that still lack a proof** —
  *(24/09: the mechanism itself shipped with ADR 0038 and runs by default; this entry
  described it as absent, which it no longer is. What remains is coverage.)* The agent
  otherwise reports success on a tool's return code: a 200 proves the API accepted the
  manifest, not that a pod started or a GPU was reserved. **48 of 83 destructive actions
  still declare no proof.** Twelve of them (Outscale, Scaleway) are blocked on the
  agent having no path to the action itself rather than on any missing read —
  exposing those connectors to the agent is the prerequisite, and a product call. — counted by `VERIFICATION_PENDING`, which CI forbids from
  growing. The system prompt asks for
  verification (rule 2, "VERIFY VIA TOOLS, NEVER FROM MEMORY") but **line 34
  contradicts it** — "when all tools have returned status=success, the task is done,
  NEVER rerun ... on grounds of verifying". Nothing enforces it either way.

  This would be the third mechanism of the same family as the policy engine and the
  JWT-anchored isolation: a guarantee that fails loudly instead of relying on the
  model's goodwill. The policy engine says *no*; the token says *on whose behalf*;
  verification would say *it is actually done*. Commercially, it is the one of the
  three a CIO will ask you to prove.

  Scope — 71 actions are declared `destructive` across connectors, but they share
  proofs; roughly ten cover the bulk of the risk (deploy_model, helm_upgrade,
  deploy_webapp, nim_deploy, scale, delete):
  - declare a verification spec beside each destructive action, the way
    `supports_dry_run` already sits in `ToolSpec` (~2 days)
  - implement the proofs that matter: pods Running and Ready, rollout converged, GPU
    allocated, and for inference an actual request returning a response — the only
    check that crosses the whole stack (~3–4 days)
  - enforce it in the loop: no exit after a destructive action without proof. The
    delicate part — a rollout takes minutes, so each action needs its own timeout
    (~3 days)
  - fix the prompt contradiction on line 34 (~1 hour, but nothing applies without it)
  - on failure, pod logs and events go back into the context, not a status code

  ~8–12 days. Specification and rationale:
  [`docs/agent-execution-loop.html`](agent-execution-loop.html), which states the thesis
  as "200 does not mean deployed", and ADR 0038 for the mechanism.

  **Step 1 landed (14 Sept 2026).** `VerificationSpec` sits in `ToolSpec` beside
  `supports_dry_run`; six actions declare a proof; the field is carried through the
  core catalogue so it reaches the agent. A CI invariant makes the declaration
  mandatory: of 74 destructive actions, 6 are proven and 68 are listed in
  `VERIFICATION_PENDING`, a list that may shrink and never grow — a new destructive
  action arrives with its proof or CI stops it. Two are blocked rather than pending:
  `delete_deployment` has no collection read exposed to the agent (a failing
  single-object read cannot tell "deleted" from "blind"), and `helm_rollback` needs a
  `revision_matches` predicate.

  **Step 2 landed (15 Sept 2026).** The three predicates are implemented in
  `agent/app/services/verification.py`, at 100% branch coverage, with a
  cross-package invariant asserting that what connectors may declare and what the
  agent can evaluate are the same set. Verdicts are three, not two: `UNKNOWN` — the
  evidence could not be obtained — is never reported as proof, since a check that
  passes while blind is worse than no check. Writing the predicates surfaced that
  `get_deployment_status`, the proof tool for four of the six declarations, returned
  a pending job instead of the deployment state; fixed first.

  **Step 3 landed (15 Sept 2026).** Enforcement sits in `_execute_tool`, wrapping
  the dispatch, so both chat paths are covered without duplicating the loop. The
  lookup keys on the effective action — `create_job` and `confirm_action` carry the
  real one in their payload — and the verdict rides on the result the model
  receives, with an instruction for each of the three cases. Rule 5 of the system
  prompt no longer contradicts rule 2: it forbids repeating work, not checking it,
  and tells the model the harness has already done the checking. 31 enforcement
  tests, 100% on the three methods touched.

  **Step 4 landed (15 Sept 2026), completing the mechanism.** On a `disproven`
  verdict the harness reads the evidence — events, then container logs — and
  attaches it to the same tool result, so the agent explains the failure instead of
  reporting it. Which evidence is declared beside the proof, not inferred: the four
  Kubernetes declarations carry one, the two `absent` ones do not, because a Helm
  release still listed has no pod to inspect. Each piece is capped on its own so the
  verdict survives beside it.

  **Verified against a real cluster (15 Sept 2026).** kind + the full stack, a
  deployment with an image that does not exist. The verdict was right first time —
  `disproven`, "only 0/2 replicas ready" — with `ImagePullBackOff`, the pod name and
  the offending image in 2 551 characters. Three defects on the way there, none
  visible from a unit test because each lives at a seam the tests mock: the proof
  tool was refused by the PolicyEngine, the events that explain a failure are on the
  Pod and not the Deployment, and the readable summary was being discarded in favour
  of the job envelope.

  **Coverage landed in sixteen lots between 15 and 24 Sept 2026, and the ratchet has
  held since.** Measured 02/11/2026 from `connectors/tests/test_verification_spec.py`:
  122 destructive actions, 110 proven, 12 in `VERIFICATION_PENDING`, `MAX_PENDING = 12`.
  Every destructive action added since arrived with its proof — node maintenance
  (ADR 0059), Aruba Central and Mist (ADR 0073). The twelve left are blocked by their
  shape, not waiting for a read, and each reason is written beside its entry in the
  test: five restores (`proxmox_restore_snapshot`, `vsphere_restore_snapshot`,
  `xo_restore_snapshot`, `xo_restore_backup`, `vme_backup_restore`) whose effect is
  disk content that no catalogue read sees; `accelerator_install_operator` and
  `accelerator_partition_device`, one entry carrying several opposite effects chosen
  by a parameter, which a fixed declaration cannot express; `run_kubectl`, an
  arbitrary command; `ci_trigger`, whose proof is keyed on a run id the action
  returns rather than receives; `cerebras_deploy_inference`, with no endpoint listing
  on the connector; `helm_upgrade`, which the agent has no path to; and
  `configure_gpu_timeslicing`, whose predicate waits for a GPU node to confirm that
  `replicas` is populated.

- [x] **Twenty agent tools the PolicyEngine refuses** — closed 18/09/2026, verified
  again 25/09/2026. `connectors/tests/test_agent_tools_are_known.py` now holds
  `DEAD_AGENT_TOOLS = set()` and `MAX_DEAD = 0`; measured independently the same day,
  123 agent job tools all resolve into the 348 catalogued actions, and no blocklisted
  action is dead either.

  Ten were dispatched by a connector with no `TOOL_CATALOG` entry. Of the ten dead,
  four were aliases the agent never followed (`get_dcgm_metrics` → `accelerator_get_metrics`,
  `get_gpu_operator_status` → `accelerator_diagnose`, `get_gke_credentials` /
  `get_aks_credentials` → `update_kubeconfig_*`), two were implemented because GKE and
  AKS node-pool scaling did not exist to alias, and three MIG tools returned to
  `NvidiaConnector` — restoring `get_mig_status` also gave the two MIG writes their
  proof and took them out of `VERIFICATION_PENDING`.

  The alias fix needed one more repair: `_TOOL_ACTION_ALIASES` was applied only in the
  `_JOB_TIMEOUTS` branch of `_execute_tool`, so the four tools living in `_RUN_JOB_TOOLS`
  would have kept dispatching under their old names — the alias written and inert.

  Still true and not covered here: the MIG predicates are written against the exact
  shape `_query_mig_state` returns, and no A100 has confirmed the node labels behave
  as the connector assumes.
- [x] **Filter the tool catalogue — per organisation, not per task** — shipped under a
  different principle than the one this entry asked for. A per-task filter infers the
  user's intent, and ADR 0053 (16/10/2026) refuses it: the filter drops a tool the
  moment the classifier is wrong, and the failure is invisible — the agent simply
  cannot do something it could do yesterday, and says so convincingly. What shipped
  filters on what is *derivable*. v0.45.0 withheld the six single-platform families
  when the platform is absent; ADR 0060 (26/10/2026, v0.60.0) generalised it: each
  gateway reports which of its connectors are configured on its site, core does the
  same for its environment, and `agent/app/services/tool_filter.py` withholds a tool
  only on that positive evidence, failing open on any doubt, and says in the system
  prompt what was withheld and why. Measured 26/10/2026 before the cut: 494 tool
  definitions, about 65,000 tokens per call. ADR 0072 (01/11/2026) records the next
  layer — deterministic hierarchical staging for a tenant whose own catalogue outgrows
  one flat menu — as a direction, not yet built, and rules out agent-navigated tool
  search. The placement this entry asked for holds: the filter runs before the call,
  in front of `llm_client`, whichever model sits behind.

- [ ] *(not planned)* **Mid-loop resume after a crash** — listed on the execution-loop
  diagram, deliberately left out. The diagram contradicts itself here: it asks for
  resume while noting "no replay: an upgrade is not idempotent". A `helm_upgrade`
  interrupted midway is not resumable, it is to be diagnosed. The honest version of
  that box is the journal, which the HMAC-chained `audit_log` already largely provides.

- [ ] **Typed contracts between agents, before any event bus** — ADR 0034's first
  stated need is *typed contracts*, which is a schema problem, not a transport one.
  Pydantic models over the existing tables deliver most of the value with nothing
  deployed. Measure whether the pain persists before committing to the ~15-day bus.

  Decided and written into ADR 0034 on 15/09/2026; the ADR had been left at
  "Draft (research needed)" while its conclusion lived only here, so a reader of the
  ADR would have concluded the opposite of what was decided.

  Scope, measured rather than recalled. Three shared models, **14 touchpoints across
  12 distinct modules** — the model definitions themselves are not touchpoints:

  | Model | Modules | Touchpoints |
  |---|---|---|
  | `AnomalyEvent` | 8 | 7 — written by `anomaly_task`, `agent_anomaly_task`, `vm_anomaly_task`, `gpu_health_task`; read by `proactive_agent_task`, `compliance_checker`, `api/v1/anomaly` |
  | `ProactiveInsight` | 6 | 5 — `proactive_agent_task`, `compliance_check_task`, `security_scan_task`, `compliance_checker`, `api/v1/insights` |
  | `BudgetAlert` | 3 | 2 — `budget_service`, `api/v1/finops` |

  `compliance_checker` and `proactive_agent_task` each read two of the three: the
  cross-domain consumers, where the missing contract costs most.

  Two earlier figures in this entry were wrong. "14 modules and 4 producers" for
  `anomaly_events` conflated the table name with the model and named
  `k8s_anomaly_task`, which does not write it. The ~2–3 day estimate was anchored on
  that one model; the real scope is three. **~3–4 days.**

- [ ] **Encrypt the Cloudflare → origin leg** — the firewall (13/09) closed direct
  access to the origin, which was the bulk of the risk. Traffic between the edge and
  Helsinki still crosses transit providers in clear, session tokens included. A
  Cloudflare Origin CA certificate (free, 15 years, no renewal to watch) plus SSL mode
  *Full (strict)*. Cloudflare itself flags Flexible mode as insecure. ~1 hour.

  **Procedure written 26/09/2026: `docs/runbooks/origin-tls.md`.** Not executed —
  it needs the Cloudflare dashboard and SSH to the origin, neither of which the
  repository carries. Measured the same day from outside: `demo.vibops.ai` is the
  proxied host and answers only through Cloudflare, so the firewall half is
  confirmed working. The origin address is deliberately not recorded — it cannot
  be read from outside, which is the point of the edge. The runbook carries the two
  ways this goes wrong: switching to *Full (strict)* before the origin serves TLS
  returns 502 to every visitor, and stopping at *Full* encrypts the leg without
  authenticating it — which looks finished on the dashboard and leaves the
  interception path open.

  **Deferred on purpose, 26/09/2026.** `demo.vibops.ai` is a demonstration host,
  not a customer-data production system, and the firewall already closed the leg
  that mattered — the origin is unreachable except through Cloudflare, verified
  the same day. Adding origin TLS now puts a certificate and a proxy change on the
  critical path of the deployment packages going out, for a host whose exposure is
  a demo session. It is an hour well spent later, not now.

  **What flips this back on:** the day `demo.vibops.ai` carries real customer data,
  or the day the same Cloudflare zone fronts a production host. Then the clear leg
  stops being a demo concern.

- [ ] **Enable Redis persistence before routing events through it** — production runs
  `appendonly no` with only spaced RDB snapshots (up to one hour). Harmless today
  (Redis is a Celery broker, data lives in PostgreSQL), material the day anomalies and
  budget alerts transit through it. Decide alongside the event bus, not after. ~15 min.

- [x] **Extend `--check` to product figures** — `bump-version.sh --check` guards the 18
  version locations and works. The same drift hit the documented counts: 26, 31 and 36
  connectors were claimed for 33 real, 59 to 130 tools for 117. Corrected by hand on
  13/09; nothing prevents the next drift. A counting script plus a CI step. ~1 day.

  Closed, though not through `bump-version.sh`. `tests/test_public_figures.py`
  (24/09/2026, a CI step) recomputes every public figure from the code and compares
  it with what is written: the README, the MCP server's README, and the vibops.ai
  home page under `VIBOPS_CHECK_PUBLIC_SITE=1` since that page lives in another
  repository. `scripts/figures-for-collateral.py` does the same for the commercial two-pagers, as
  a manual check before a document is sent — see the `docs/commercial/` entry below for
  why that one is not in CI.

  **02/11/2026 — the maintained docs too.** The user guide said 258 actions for 441. A
  current figure in `docs/` is now written inside a `<!-- fig:NAME -->` marker;
  `scripts/update-figures.py` rewrites every marker from the code, `--check` refuses a
  stale one, and the public-figures suite does the same in CI. Dated figures — history tables, the 24/09 narrative — carry no marker and are
  left alone; the marker, not the sentence, is what separates a claim from a record.

- [ ] **Delete `deploy.yml`** — restricted to tags on 13/09 but wholly redundant. Its
  Helm job stops for want of a `KUBECONFIG` secret (no remote deploy has ever run); its
  build job produces three images `release-images.yml` rebuilds on the same tags, plus
  five more. Confirm no Helm deployment is planned, then remove. ~30 min.

- [ ] **Decide on the leaked admin password** — removed from all five scripts (#34 and
  `b4067a8`), but it remains readable in git history via `git log -p`, for anyone who
  has or had repository access. If it opens anything beyond the seed fixtures, it must
  be **changed**, not merely erased. History rewriting is possible but invalidates every
  clone; rotation is simpler. Decision, not development.

- [x] **Reconcile the figures in `docs/commercial/`** — settled 26/09/2026, and the
  settlement is *not* to correct them. Seven documents contradict the product; two
  dossiers contradict themselves between their FR and EN versions (RFI v3: 59 tools
  in French, 130 in English; v5: 70 and 130), and the valuation document counts 195
  actions against 348 — understating by 44% the product whose value it establishes.

  They stay as they are, because they may already have been sent. Rewriting the
  archive would diverge from the copy the recipient holds, which is worse than a
  dated figure: nobody could then tell what was actually claimed.

  What is closed is the recurrence. `tests/test_public_figures.py` freezes those
  seven names and recomputes the figures from the code; any *new* document under
  `docs/commercial/` that contradicts them fails CI. The list may shrink — a
  document reworked or withdrawn comes off it — and may never grow, with a test
  that refuses an entry which no longer contradicts anything, so the list cannot
  quietly become a carpet.

  **Reversed on 21/10/2026.** The CI guard over `docs/commercial/` was removed: an
  unmaintained file retyped on every release measures the release cadence, not the
  product. What replaces it is `scripts/figures-for-collateral.py`, run by hand before
  a document goes out, while `tests/test_public_figures.py` keeps guarding the figures
  that are actually public (README, MCP README, the site). The archive stays as it
  was, for the reason above.

- [ ] **Choose between `STATUS.md` and `CHANGELOG.md`** — two parallel histories in
  different formats. `CHANGELOG.md` was brought up to date on 13/09 (177 commits);
  `STATUS.md` still stops at 09/09. Whichever is authoritative, the other will drift
  unnoticed — exactly how the counts above went wrong.

  Settled by practice rather than by decision, as of 02/11/2026: `CHANGELOG.md` is
  complete to v0.68.0 (backfilled 01/11), `STATUS.md` still announces v0.41.0 of
  06/09 and has received one count edit since. What is left to decide is whether
  `STATUS.md` is deleted or rewritten as a pointer.

- [x] **`beat` and `gateway` image tags** — `release-images.yml` publishes 8 tags from
  6 Dockerfiles; no compose references those two, and `worker`/`beat` duplicate the
  `core` image. Two builds paid per release for nothing. ✓ Removed from the matrix on
  09/10/2026; six images remain, and the comment in `release-images.yml` carries the
  measurement — about 19 minutes of runner time per release, beat 15 and gateway 4.


### FinOps maturity
- [ ] **Reseller FinOps dashboard** — aggregate FinOps views for reseller orgs (~27h total):
  - API: `GET /resellers/me/finops/summary` — per-customer spend MTD, top spenders, total (4h)
  - API: `GET /resellers/me/finops/chargeback/{year}/{month}` — cross-customer chargeback breakdown (3h)
  - API: `GET /resellers/me/finops/spend-trend` — aggregated 12-month trend across all customers (4h)
  - Tests: 3 routes × happy path + edge cases (5h)
  - Console: "Customers" tab in FinOps — table with spend/budget/trend per client, stacked chart, client filter, reseller guard (10h)
  - OpenAPI regen (0.5h)
- [ ] **Reseller data visibility controls (RGPD)** — configurable per-customer data sharing:
  - Customer opt-in/opt-out on what the reseller can see
  - Level 1 (billing only): GPU/h consumed, total cost — minimum for invoicing
  - Level 2 (ops): + cluster names, namespace, workload count — for MCO
  - Level 3 (full): + model names, agent names, detailed usage — opt-in only
  - Default: Level 1 (billing only) — RGPD safe
  - Stored on Organization model: `reseller_visibility_level` field
  - API routes filter response fields based on customer's visibility level
  - Consent recorded in audit trail
- ~~[ ] `accelerator_detect_waste` — time-series mode: sustained underutilisation over N hours (not just snapshot)~~ ✓ Sprint 15
- ~~[ ] Chargeback generation — automated monthly Celery Beat task (currently admin-triggered)~~ ✓ Sprint 15
- [x] **GPU passthrough correlation (MOAT)** — detect PCIe passthrough in VM config, match VM hostname ↔ K8s node, unified FinOps (VM + GPU cost on same asset). Fleet VM table: GPU column + drill-down drawer (hypervisor → K8s → workload → combined cost). ✓ v0.26.0
- [x] **VM chargeback** — cost per tenant based on VM resources (vCPU/h + RAM/h + disk). Rate configurable per hypervisor. Aggregated monthly report per tenant. Same model as GPU chargeback but for CPU/RAM/disk. ✓ v0.37.0 (30/08/2026) — three routes under `/finops/vm-chargeback`, reseller markup, GPU passthrough cost included; UI in v0.38.0. The entry was never ticked.
- [ ] **Chargeback export (pre-invoice)** — CSV/PDF export per tenant with consumption detail (GPU/h, VM/h, cost, period), ready to import into ERP (Sage, SAP, etc.). Signed HMAC for integrity. Covers both GPU and VM chargeback. ~1 day. *Partly there (checked 02/11/2026): `GET /finops/billing/export` returns the GPU chargeback report as HMAC-SHA256-signed JSON — the integrity half. CSV/PDF for ERP import and the VM chargeback are not in it.*
- [x] **Scheduled triggers (cron)** — user-defined cron expressions in triggers (e.g. "run VM waste scan every Monday at 8am"). Add schedule type to TriggerRule model + UI toggle in Automations tab. Essential for MCO recurring tasks. ✓ v0.38.0 (31/08/2026) — `schedule_cron` on `TriggerRule`, evaluated every 60 s via croniter; the entry was never ticked.
- [ ] Cloud pricing API integration — live AWS/GCP/Azure GPU rates (currently manual ClusterRate)
- [x] VM cost history — VmCostSnapshot table, 12-month spend trend parity with GPU ✓ v0.29.0
- [x] Currency conversion — EUR/USD dynamic symbol from budget.currency ✓ v0.29.0
- [x] White-label routing — custom domains per CSP via `white_label_domain` — `GET /branding` resolves CSP brand from Host header ✓ Sprint 7
- ~~[ ] Budget enforcement on pre-Sprint 9 jobs — sum Job records instead of ChargebackReport~~ ✓ Sprint 14

### Dataset & RLHF maturity
- [ ] Dataset UI — consent management + dataset export controls in console (ADR 0018 — Decision 5)
- ~~[ ] GPU utilization per-job — per-pod DCGM via gateway (attribution currently impossible with concurrent workloads)~~ ✓ Sprint 4 (live cost attribution via ClusterRate × elapsed time)
- ~~[ ] Salt rotation migration plan for `DATASET_PSEUDONYMIZATION_SALT`~~ ✓ Sprint 15
- ~~[ ] Reseller consent ownership — which org sets consent for reseller_customer orgs~~ ✓ Sprint 15 (ADR 0020 Decision 2)

### Platform
- [x] Per-cluster role assignments — user X = operator on prod, readonly on dev
- [x] Multi-org admin UI — Customers tab for reseller orgs: create/list customer orgs, pricing rules, overrides, 7 proxy routes, 21 tests ✓ v0.31.2
- [ ] Spot preemption enforcement — scheduling-level, not just metadata
- [ ] Committed billing enforcement — reserved_1y/3y tiers beyond metadata
- [x] Vendor/accelerator_type heuristic detection from payload — 18 patterns, fallback when WorkloadSignature absent ✓ v0.31.1
- [x] `scale_cluster` split into `scale_cluster_up` / `scale_cluster_down` — separate dry-run emphasis ✓ v0.31.1

### Intelligence
- ~~[ ] Proactive incident detection — agent monitors metrics autonomously between sessions~~ ✓ Sprint 4 (anomaly detection Beat task)
- [x] **Proactive agent engine** — 7 event-driven insight types (stale_anomaly, gpu_health_warning, budget_warning, job_failure_pattern, deployment_health, capacity_forecast, cost_optimization); Celery Beat every 5 min; SQL-only (~5ms/run); deduplication + auto-acknowledge; dashboard "Proaction Required" panel with click-to-chat; toast notifications for critical insights; 31 tests ✓ v0.33.0
- [x] Datadog GPU polling — Celery beat task, virtual gateway type "datadog", writes to gpu_metrics_history ✓ v0.30.0
- [x] Alert correlation across multiple services — AlertCorrelator groups by cluster/namespace/node, 5-min window, root cause heuristic, 14 tests ✓ v0.31.2
- [x] Predictive GPU failure — temperature trend, sustained high util, utilization cliff; Celery beat 10min; 14 tests ✓ v0.31.2
- ~~[ ] L2 LLM-as-judge scanner — non-blocking, catches subtle prompt↔schema contradictions~~ ✓ Sprint 4 (is_auto_scanner on EvalRubric)

### Connect Gateway
- [x] Gateway capability discovery — gateway reports connector actions at each ping, core stores and exposes via API ✓ v0.29.1
- [x] mTLS option between gateway and core — client cert via MTLS_CLIENT_CERT/KEY/CA_BUNDLE env vars + Helm values ✓ v0.29.1

### Image build & CI connector
- [x] `docker_build` — build a Docker image from a local context / cloned repo (600s timeout, layer-by-layer log streaming)
- [x] `docker_tag` — retag an existing local image (fast, synchronous)
- [x] `docker_push` — login + push to GHCR / Docker Hub / GitLab Registry / self-hosted; token via `--password-stdin`, masked in logs; returns digest
- [x] `docker_build_push` — combined build + push; digest returned for Helm image pinning
- [x] Full build→push→deploy pipeline: `git_clone` → `docker_build_push` → `helm_upgrade` in one conversation
- [x] Admin → Git panel — org-level token + Apps & repositories management table (inline edit, unlink)
- [x] Git tab inline repo-link form — link any app to its repo without leaving the main view
- [x] CI connector — `ci_trigger`, `ci_status`, `ci_wait`, `registry_list_tags`; GitHub Actions dispatch + GitLab pipeline trigger; reuses GIT_TOKEN
- [x] Admin → CI panel — provider status card + pipeline runs table (App / Workflow / Branch / Status / Duration / Triggered / Link)
- ~~[ ] Registry connector — list images, inspect tags, detect untagged `latest` across a private registry~~ ✓ Sprint 6 (`ContainerRegistryConnector`: `registry_list_repos`, `registry_list_tags`, `registry_check_image`, `registry_delete_tag` — Harbor/ECR/GAR)
- [ ] Kaniko support — in-cluster builds without Docker daemon (required for locked-down Kubernetes environments)

### Local cluster image loading (Sprint 16 patch)
- [x] `kind_load_image` — load a locally built image into kind's containerd (bypasses Docker daemon)
- [x] `k3d_load_image` — load a locally built image into k3d cluster
- [x] `minikube_load_image` — load a locally built image into minikube (any driver)
- [x] `k3s_load_image` — load via `docker save | k3s ctr images import -` async pipe

### Private registry pull secrets (Sprint 16 patch)
- [x] `create_pull_secret` — idempotent `imagePullSecret` for any registry (dry-run + apply)
- [x] `create_ecr_pull_secret` — AWS ECR: auto-fetches login token via `aws ecr get-login-password` (12h TTL)
- [x] `create_gcr_pull_secret` — GCP GCR: service account JSON → `_json_key` dockerconfigjson
- [x] `create_acr_pull_secret` — Azure ACR: service principal credentials
- [x] `deploy_webapp` `image_pull_secret` param — patches deployment spec after creation

### ArgoCD auto-sync (Sprint 16 patch)
- [x] `argocd_enable_auto_sync` — sets `syncPolicy.automated` with `prune` + `selfHeal` options
- [x] `argocd_disable_auto_sync` — removes `syncPolicy.automated`, reverts to manual sync
- [x] Agent prompt: ArgoCD drift remediation workflow (`argocd_diff` → `argocd_sync` or enable auto-sync)

### OpenShift (Sprint 16 patch)
- [x] `openshift_add_scc` — `oc adm policy add-scc-to-user` for SCC-blocked workloads
- [x] `openshift_create_route` — `oc expose service` with optional hostname; replaces create_ingress on OpenShift
- [x] Agent prompt: OpenShift-specific routing rules (use Route instead of Ingress, SCC before pod start)

### Demo scenarios (Sprint 16 patch)
- [x] Scenario 26 — Private registry K8s deploy (`create_pull_secret` → `deploy_webapp(image_pull_secret=…)`)
- [x] Scenario 27 — ArgoCD auto-sync on push (enable_auto_sync + git_commit_push, no manual sync)
- [x] Scenario 28 — Cloud registry deploy (ECR+EKS and GCR+GKE variants)
- [x] Scenario 29 — OpenShift deploy (`openshift_add_scc` + `deploy_webapp` + `openshift_create_route`)

### Audit trail verifiable by a third party (ADR 0044)

An audit trail that only its operator can check is a claim, not evidence.

- [x] **Sign every field a reader acts on** — the chain signed the action, the actor and the
  outcome, and left `payload`, `result`, `matched_rule` and `reason` outside the signature:
  `namespace: prod` could become `namespace: dev` with `/audit/verify` still reporting the
  chain intact. Version 2 covers them; version 1 rows keep verifying under version 1 rather
  than being re-signed, and `/audit/verify` reports how many rows are held under each.
  ✓ 21 Sept 2026
- [ ] **Ed25519 beside the HMAC, public key published** — HMAC is symmetric, so verifying
  requires the key that can forge. Asymmetric signatures let a customer or an auditor check an
  export without being handed the means to write one.
- [x] **Anchor the chain head where the operator cannot rewrite it** — hourly, into the
  customer's SIEM first: it already receives the exports, it adds no outbound destination and
  it works air-gapped. A WORM bucket or an RFC 3161 timestamp authority for those who want a
  neutral third party.
  ✓ 28/09/2026 — `AuditAnchor`, the hourly `anchor_audit_chains` beat task into the
  customer's SIEM, and `/audit/verify` reporting whether the chain is anchored and when.
  WORM and RFC 3161 remain options, not built.
- [ ] **Sign inside a KMS/HSM** so the private key cannot be taken elsewhere, and log every
  signing operation.
- [ ] **`vibops audit verify` in the SDK** — checks the chain and the anchors offline. A
  verification you must ask the audited party to run is not a verification. The SDK's
  `verify_chain()` today calls the server's `/audit/verify`, which is the audited party
  running it; the offline check is not written (02/11/2026).

The boundary is published with it: this makes retroactive rewriting infeasible, and it does
not make the record true. An operator who never writes an event, or writes a false one as they
act, is untouched by any of it — that needs the cluster's own API server and admission logs
beside ours, and saying so is worth more than a claim that does not hold.

### GreenOps — carbon as a second unit (ADR 0043)

Decided and costed, not scheduled. Full rationale, data-model mapping and risks:
`core/docs/adr/0043-greenops-carbon-as-a-second-unit.md`.

Everything after the first step is arithmetic on its number, and the count of persisted power
measurements today is zero — so the order matters more than usual.

- [x] **Prompt caching, then capability-derived tool filtering** — outside the GreenOps scope and to
  be done first: 310 tools, roughly 43,800 tokens on every call. A cost and latency matter
  before an environmental one. ✓ v0.45.0 — the filter withheld 98 of 310 tools when their
  platform is absent; intent-based filtering was never built, and ADR 0053 says why.
  Generalised per organisation by ADR 0060 (v0.60.0).
- [x] **Per-cluster measurement-sources page** — the first deliverable, before any collector.
  DCGM needs the GPU Operator; without it the collection returns nothing and "nothing" renders
  as zero. A footprint dashboard that silently under-reports is worse than none.
  ✓ 28/09/2026 — `GET /greenops/measurement-sources`, console section under FinOps. Produces
  no kWh and no gCO2e by design; it names what each cluster can and cannot measure, and
  distinguishes `absent` (a prerequisite is missing) from `not_applicable` (nothing to measure)
  from `unsupported` (no field exists yet). On main, not yet tagged.
- [x] **`power_w` and `energy_wh` in `gpu_metrics_history`** — the step that measures.
  ✓ 28/09/2026 — four columns (`power_w`, `energy_wh`, `quality`, `source`), a DCGM collector
  in `connect/worker.py` **disabled by default** (`VIBOPS_COLLECT_POWER=1`), and the ping
  handler writing a time-series row only for the clusters that reported one. A cluster with no
  sensor writes no row rather than a row of zeros. Retention already covered this table at 90
  days since 22/09 — checked rather than assumed; what was missing is the `(org_id,
  recorded_at)` index the nightly purge walks.
- [ ] **`PowerConsumedWatts` on the Redfish connector** — the second sensor. Gateway-only
  (ADR 0043 decision 6): a node with `gateway_id` null is refused and reported, never read by
  core — that would be core opening a connection into the customer's management VLAN, which
  the outbound-HTTPS-only architecture promises not to do.
- [ ] **Publish the collection overhead before enabling anything by default** — forty BMC calls
  a minute on a forty-node fleet, on equipment that is slow and fails often. A product that
  sells discretion measures its own cost first.
- [x] **Declared entry: `annual_kwh` on `cluster_rates`** — a `declared`-quality figure with no
  sensor at all, from a field operators already fill in.
  ✓ 28/09/2026 — `annual_kwh` + `kwh_source` (declared / metered / estimated), settable
  independently of the pricing formula because a kWh is a physical quantity and not a pricing
  input. Taken before the two columns above on purpose: those without a collector are fields
  nothing writes, which is the shape this ADR exists to refuse. On main, not yet tagged.
- [x] **Factors** — grid intensity on the `llm_backend_rates` pattern, PUE per site,
  `carbon_method` as provenance. A missing factor yields `null`, never a default.
  ✓ 28/09/2026 — `grid_factors` (zone, year, gCO2e/kWh, required source) and `pue` /
  `pue_source` / `grid_zone` on `cluster_rates`. The table **ships empty and stays empty**:
  no bundled national average, because a factor is the number a gCO2e is multiplied by and
  the product must not be the one that chose it. Versioned by year so a footprint computed
  for 2025 gives the same answer when re-run in 2027. On main, not yet tagged.
- [x] **Surfaces** — gCO2e beside `cost_usd` in the FinOps routes and the console.
  ✓ 28/09/2026 — `energy` served on both chargeback routes, `GET /greenops/energy` for the
  current period without waiting for the monthly report, and an ENERGY tile in the same KPI
  grid as SPEND (decision 1: a second unit on the FinOps axis, not a parallel journey). The
  tile shows `—` and never `0` when nothing is declared, carries its method, and names the
  clusters that declare nothing.
- [ ] **The waste panel, and attribution by utilisation-weighted GPU-seconds** — both wait on
  per-cluster GPU-hours: idle energy is per cluster, and so is the weighting.
- [x] **`kwh` and `gco2e` in the monthly chargeback report** — beside `gpu_hours`. This is what
  the demand actually asked for, and it appears in none of the incoming specification's seven
  phases.
  ✓ 28/09/2026 — an `energy` block on `ChargebackReport` carrying the figure, its quality, the
  method, the clusters counted and those left out. Computed in the upsert both entry points
  share, so no month can look consumption-free because one path forgot.
- [ ] **Per-cluster GPU-hours, so energy can be attributed** — the ADR assumed the hard part
  was done because *cost* attribution is. It is not for energy: `VendorUsage` carries vendor,
  accelerator type and GPU-hours, `Job` carries a gateway id, and neither carries a cluster —
  while the declared consumption is per cluster. Until that field exists the energy figure is
  an organisation total and says so; splitting it by GPU-hour share would assume every cluster
  is equally efficient. One field on the usage rows, not a programme.
- [ ] **Idle share as a third figure** — the energy detected as idle, beside the two above.
  Needs the attribution item first: idle is per cluster.
- [x] **RGESN as framework #20** — 78 criteria, 10 automatic evaluators that propose while a
  human confirms.
  ✓ 28/09/2026 — seeded and scored by the engine that already ran for nineteen referentials:
  no new route, no new tool, one word in the agent prompt. Generated from
  `config/rgesn/rgesn_criteria.yaml`, which the core image now ships; the weights, priorities
  and evaluators stay in that file rather than becoming columns. The evaluators themselves are
  **not** written yet — the 78 controls exist and are human-attested for now.
  **Still blocking before anything is published**: the official Arcep wording (the titles are
  summaries, the YAML says so in its own header) and the priority split cross-checked against
  the official tool. On main, not yet tagged.
- [x] **Exports (SCI)** — feed the tool where the customer's reporting is assembled rather
  than replace it.
  ✓ 28/09/2026 — `GET /greenops/export/sci` returns every component of
  `((E x I) + M) / R` with its provenance, and **no score**: ISO/IEC 21031 requires all four
  terms and M, the allocated manufacturing emissions, is collected nowhere in this product.
  A number labelled SCI that dropped M silently is the first thing an auditor tests.
- [ ] **Exports (NumEcoEval)** — blocked, and on their side of the fence.
  `GET /greenops/export/numecoeval` ships the inventory VibOps can supply, flagged
  `importable_as_is: false`: the specification's own annex A says to retrieve the official
  integration kit and align the exact headers and reference values before emitting their four
  CSVs, and a blank `modele` column is a known import failure. Guessing the schema would
  produce files that fail to import, or import wrong. What remains is one session with the kit.
- [ ] **Embodied carbon (M)** — the term that would make an SCI score possible at all. Needs
  the hardware profiles the ADR parks: GWP per machine, lifetime, source.

Not planned here, and named so nobody assumes otherwise: low-carbon scheduling (the
specification's optional phase 6), a CSRD ESRS E1 export, VibOps's own footprint, and the
RGESN declaration of VibOps as a product. Never: "N tonnes saved thanks to VibOps" — that
requires a counterfactual we cannot observe.

Every figure leaves with its perimeter attached: the GPU fleet under management, not the rest
of the datacentre, the workstations, the network, the storage or the software lifecycle.

### Onboarding
- [x] Step 3 GitHub: webhook setup UI in onboarding wizard (optional, copy URL + repo/branch/action config) ✓ v0.31.1
- [x] Post-onboarding checklist: floating widget, 4 auto-tracking items, localStorage dismiss ✓ v0.24.1
- [x] UI wizard — 5-step onboarding in console (LLM provider, K8s/VM infra, notifications) ✓ v0.24.0

---

## P2 — Medium term

### Enterprise
- ~~[ ] SSO / SAML integration (required for large enterprise procurement)~~ ✓ Sprint 5 (OIDC: Azure AD, Okta, Google, custom — JIT provisioning)
- ~~[ ] LDAP/AD user provisioning~~ ✓ Sprint 6 (LDAP/AD auth with JIT provisioning, TLS/STARTTLS, UI in Admin → Security tab)
- ~~[ ] Audit log export → SIEM (Splunk, Datadog, S3)~~ ✓ Sprint 6 (push: Splunk HEC + Datadog Logs API v2; pull: CEF/LEEF/JSON already existed)
- [ ] Custom GPU alert thresholds per team
- [ ] Multi-org licence (enterprise with multiple BUs on one instance)

### Accelerator vendors
- ~~[ ] Intel Habana Gaudi 3 (next-gen, different driver stack)~~ ✓ Sprint 6 (`intel_list_devices` via `hl-smi`)
- ~~[ ] Additional cloud TPU generations as they release~~ ✓ Sprint 6 (`tpu_list_devices` + `tpu_install_operator`)
- [ ] Accelerator vendor SDK version matrix — tested compatibility table
- [ ] NVIDIA vGPU (GRID) support — collect vGPU metrics from hypervisor host, correlate vGPU ↔ VM, GRID licence cost in FinOps. Available on demand — 1 sprint if a prospect requires it.

### MCP Server
- [ ] MCP tool coverage parity with full agent tool set
- [ ] MCP server Helm chart for self-hosted deployment
- [x] SDK: typed Python client (`sdk/`) — 9 resource namespaces, async-first with sync wrapper, auto-retry, typed exceptions, MIT licensed, 19 tests ✓ v0.35.0

### Agent Fleet (custom graph, zero external dependencies)

**Shipped (4 agents):**
- [x] Ops Orchestrator — 224 tools, 19 rules, 7 guardrails, conversational ✓ v0.1
- [x] Proactive Sensor — 7 event-driven insight types, 5-min Celery beat ✓ v0.33.0
- [x] Security Scanner — 8 DAST pentest checks, weekly + on-demand ✓ v0.34.0
- [x] Compliance Verifier — 8 SOC 2 runtime checks, daily ✓ v0.35.0

**Phase 2 — Optimization agents:**
- [ ] Cost Optimizer — continuous FinOps recommendations (placement, sizing, spot vs reserved, idle scale-down)
- [ ] Capacity Planner — GPU demand forecasting at 30/60/90 days, procurement alerts
- [ ] Vendor Arbitrator — real-time cost/performance comparison across NVIDIA, AMD, Intel, Cerebras; optimal placement recommendations

**Phase 3 — Autonomous operations:**
- [ ] Incident Responder — auto-remediate P3/P4 incidents without human intervention (diagnose → fix → verify → resolve)
- [ ] Release Manager — canary deploy validation, auto-rollback on metric regression, progressive rollout
- [ ] Drift Detector — compare GitOps desired state vs actual cluster state, alert and auto-reconcile
- [ ] SLA Monitor — continuous SLO verification, auto-escalation on breach, trend-based early warning

**Phase 4 — Governance & intelligence:**
- [ ] Data Guardian — RGPD enforcement (consent verification, retention policies, anonymization triggers, right-to-erasure automation)
- [ ] Chaos Agent — controlled fault injection to test resilience (GPU failure simulation, network partition, OOM scenarios)
- [ ] Knowledge Agent — learns from past incidents and recommendations, enriches future diagnostics with historical patterns. The per-action half shipped as ADR 0068 (v0.67.0): an action's prior proven outcomes are recalled at the confirmation gate.
- [ ] Onboarding Assistant — conversational wizard for new clients (replaces HTML wizard with AI-guided setup)

**Infrastructure:**
- [ ] Agent graph dispatcher — **research done 2026-09-13** (ADR 0034). Redis Streams
  consumer groups retained: at-least-once, pending-entry tracking, replay, and Redis 7
  is already deployed — zero new infrastructure. Temporal ruled out (dedicated server +
  database for 8 agents), Prefect/Dagster ruled out (acyclic by construction, cannot
  express `anomaly → insight → action → anomaly`), LangGraph ruled out (built for LLM
  agents; ours are deterministic domain services). **Do the typed contracts first** —
  see below — and only build the bus if the pain persists. ~15 days if pursued.
- [ ] Agent fleet dashboard — console panel showing all agents, status, last run, findings count
- [ ] Inter-agent communication protocol — agents trigger each other via DB tasks (security → ops, compliance → security)

### Console frontend architecture
- [x] Split `index.html` (9285 lines) into Jinja2 partials — 18 partials, skeleton 406 lines ✓ v0.32.0
- [x] Split `vibops.js` (5305 lines) into 13 JS modules — Object.assign assembler (38 lines) ✓ v0.32.0

### Surfaced by the positioning work and the Bull engagement (7–9 Nov 2026)

**Decided 10/11/2026 (David):** build the autonomous 3 a.m. sync scenario plus the missing
Slurm actions, in this order — (1) gateway job outcomes into the signed journal, (2) Slurm
requeue / drain / resume, (3) ArgoCD event intake, (4) a trigger that launches an agent
diagnosis with its proof, (5) the receipt, (6) the demo environment with ArgoCD, (7) end-to-end
test and hardening; the rollback blast radius is optional. Order of magnitude 17 days plus 3
for Slurm, demo-operational; 5–10 more on Bull's own cluster. Rationale: a customer need
(Bull's answer 5 — night-time sync failures "to be defined by SLO/SLA"), and an asset
whatever happens: a human on-call doing it by hand would price any SLA out of reach.

Two independent sources, measured against the code at v0.70.3. The first four items
come from the resale model (MSP/CSP service lines on top of VibOps) and apply to any
partner, Bull or not. The rest come from the first Bull meetings: connectors for Bull's
suites, and compatibility with a GitOps practice — which is a property of a site, not of
a sales channel, and applies to any customer running GitOps, in direct sale or in resale.
Prospect-driven items say so; none of them is promised to anyone.

- [ ] **Operator attribution in the audit journal** — no field distinguishes the
  owner's human, the house AI, a partner or a third-party agent. The agent calls core
  under the `agent-service` subject with the human's name (`agent/app/services/core_client.py`)
  while its own `/audit/ingest` writes the human's id; `triggered_by` is fixed to
  `vibops-agent`; an API token resolves to its owner; agent identities authenticate only
  at the LLM proxy. Without it there is no billing per operator, no partner commission,
  no operator reputation. Adding actor and gateway to the row means a signature
  version 3 — the chain already signs the identity fields.
- [x] **Gateway job outcomes into the signed journal** ✓ 10/11/2026 — `POST /gateways/{id}/jobs/{job_id}/result`
  writes status, result and logs to `jobs` and stops; the only writer of outcomes to the
  audit chain is the local Celery worker (`log_job_outcome_sync`). Every remotely
  executed action therefore has its decision and creation signed, and its outcome in an
  unsigned table. Prerequisite for billing per intervention and for the receipt.
  *Done: the route now calls `log_job_outcome(source="gateway")` after its commit; two
  witnesses in `tests/test_a_gateway_result_lands_in_the_audit_chain.py`, counter-proved
  against the previous route.*
- [ ] **The mandate as an object** — *the receipt shipped 11/11/2026 (ADR 0075, below):
  ask, policy decision, execution, proof, result, signed, citing the mandate and the Argo
  revision — for trigger-started runs.* The mandate: a standing delegation — which actor may
  do what, where, within which bounds, who approves beyond. Today it is cited in the receipt
  as the organisation's tool-policy override per action (who, when); it is not yet something a
  customer can be handed as one document.
- [ ] **Per-actor tool policy** — `tool_policy_overrides` is unique on (action, org):
  a partner cannot be given narrower bounds than an employee, nor a third-party agent
  narrower than the house AI. Needed before any outsider operates through a gateway.
- [ ] **Energy connector for Bull's Smart Energy Management Suite** *(prospect-driven,
  proposed, not measured)* — BEO exposes a CLI and a REST API with an OpenAPI
  specification behind OpenID Connect, and can set power limits "on any part of the
  infrastructure"; ARGOS is its name on XH3500. Reads: power, energy, temperature per
  node, rack, partition. Writes: set and lift a cap, destructive, proven by reading the
  cap back. Same shape as the DPS connector (ADR 0066); the DSX Flex `power_cap` hint gets
  a second hand.
- [ ] **JARVICE XE connector** *(prospect-driven, proposed)* — REST `/jarvice/submit`,
  `/batch`, `/status`, `/tail`, `/terminate`, API key per tenant; proof from job status;
  usage back to FinOps per tenant.
- [x] **Slurm: requeue, node drain and resume** ✓ 11/11/2026 — the connector had six
  actions (cluster info, list jobs, submit, cancel, status, output); the Bull brief had
  claimed requeue and drain as shipped and was corrected on 09/11/2026. Now ten:
  `slurm_get_node` (the read behind the proofs), `slurm_requeue_job` (`scontrol requeue` /
  `requeuehold`; slurmrestd has no requeue endpoint, so REST sites go through SSH and say
  so), `slurm_drain_node` (`State=DRAIN` with a sanitised, required reason — nothing is
  evicted, running jobs finish, the message says it) and `slurm_resume_node`. Each write
  declares its proof: `job_requeued` (restart count read from `scontrol show job` /
  `restart_cnt`, or PENDING again; RUNNING without a restart read stays UNKNOWN),
  `slurm_node_drained`, `slurm_node_resumed` (a node still `down` after RESUME is
  DISPROVEN). Demo mode covers all four within one process. *Not measured against a real
  Slurm: every SSH and HTTP call is mocked in `tests/test_slurm_node_and_requeue_actions.py`;
  the first real cluster is Bull's lab.* The preview does not yet name the jobs on the
  node — the agent reads `slurm_list_jobs` and `slurm_get_node` first, as the catalogue
  tells it to.
- [x] **ArgoCD event intake** ✓ 11/11/2026 — `POST /webhooks/argocd`, the third brick.
  Unlike the GitHub and Grafana doors (one platform secret, everything under the reserved
  organisation), it is authenticated with an organisation API token, so a notification
  from ArgoCD on a customer's cluster lands in that customer's signed chain, as one row
  with action `argocd_event` — `success=false` and ArgoCD's message as `reason` for
  `on-sync-failed`, `on-health-degraded` and `on-sync-status-unknown`. No table of its
  own: the chain is what the receipt, the SLA evidence and `list_audit_logs` already read.
  The body is our contract, rendered by one template in `argocd-notifications-cm`
  (`docs/api-reference.md`): `event` is derived from the three status fields when the
  template leaves it out, `<no value>` is treated as absent, unknown fields — `org_id`
  included — are dropped (ADR 0003). One row per (organisation, application, event,
  revision) per five minutes, fail-open without Redis. Written through
  `audit.record_event`, which raises rather than logging: an inbound event the chain does
  not hold is one that did not happen, and ArgoCD retries on a 5xx. *Not yet received from
  a real ArgoCD: the template is written from the notifications catalogue, and the demo
  environment with ArgoCD (brick 6) is where it gets measured.* The next brick hooks into
  `receive_argocd_event`.
- [x] **A trigger that launches an agent diagnosis with its proof** ✓ 11/11/2026 — ADR 0074,
  the fourth brick. Trigger source `argocd`, push-driven like `dsx` (ADR 0065): the webhook
  door matches the organisation's enabled rules by application selector and event, honours
  the cooldown, and fires. A catalogued action becomes a tenant job carrying the event,
  gated by `evaluate_system` (destructive only with `confirmed: true` in the rule). The
  action `agent_diagnosis` starts an **unattended agent run** instead — a Celery task mints
  a JWT for `trigger:<rule>` / `watch:<name>` in the organisation and calls the agent's chat
  with `confirm: false`, always. The mandate is the organisation's tool policy, nothing new:
  confirmation turned off for `argocd_rollback` lets the night run roll back and read the
  result back; left on, the run stops at the gate with a proposal and its blast radius. The
  run leaves one chain row, action `agent_diagnosis`, source `trigger`: the rule, the
  event's row, the tools, the aggregated verdict, the held proposal, the diagnosis — or the
  agent's unreachability as a failure. *Not yet run against a live agent and a live ArgoCD:
  brick 6. The console's automations screen does not offer the source yet (nor `dsx`); the
  API and the agent's `create_trigger` tool do.* Migration `b7e2a9c4d1f3`.
- [x] **The receipt** ✓ 11/11/2026 — ADR 0075, the fifth brick. `GET /receipts/{id}` reads the
  chain outwards from an `agent_diagnosis` row: the event row it names (the ask), the run's own
  rows under `watch:<rule>` with their read-back verdicts (the execution), the first later
  `argocd_event` saying synced (the result ArgoCD confirmed), the organisation's tool-policy
  override for each action that ran or was held (the mandate — who decided, when), the timeline
  (detected, reacted, recorded, resolved, durations), the Git and ArgoCD references, and the
  proof: every cited row re-verified against its signature, the external anchor if one covers
  it. A tampered row is named in the receipt, not hidden by a refusal. Nothing stored: a
  receipt beside the chain would be a second record that could disagree with the first. JSON
  and markdown; `GET /receipts` lists them; two agent tools. *Open: the mandate as an object; a
  receipt for a conversation-driven intervention; the console page; the receipt attached to
  the night-watch notification.*
- [x] **The demo environment with ArgoCD** ✓ 11/11/2026 — the sixth brick, on the demo host's
  own k3s: ArgoCD v3.6.1 (API in plain HTTP on NodePort 30444, dex and applicationset off,
  reconciliation 60 s), a private GitOps repository laid out Bull's way (Kustomize package,
  cluster overlay, two prepared failure branches), the Application `inference` with automated
  sync, the notifications webhook to `POST /webhooks/argocd` under a demo-organisation API
  token, the gateway `k3s-live` recreated with the ArgoCD connector configured (its ping says
  so), and the Caddy route for the door. Measured: synced and Healthy in 15 s, the first
  notification sent with the documented body — and answered 404 by core v0.68.0, which has no
  door yet. `docs/runbooks/demo-argocd-night-watch.md`. *What is left for a night to run end
  to end (brick 7): release and deploy, create the rule, decide the mandate.*
- [x] **The night, end to end** ✓ 11/11/2026 — the seventh brick. v0.71.0 tagged and deployed on
  the demo host (migration applied, both gateways refreshed), the rule `night-watch-dc-live`
  created, and two nights run for real (`docs/runbooks/demo-argocd-night-watch.md`). Night 1,
  propose tier: degraded health detected 11:50:37, run started 10 s later, ten tools, the right
  rollback proposed and held, receipt `proposed` with twelve rows verified, then `resolved` by
  the morning's Git revert 193 s after detection. Night 2, act tier: failed sync detected
  12:44:26, run 21 s later, a diagnosis naming the day's three commits — and the rollback held
  anyway. Three defects measured and fixed the same day: the run's identity had no scope so
  the agent's guardrail refused every Kubernetes read (v0.71.1); the task crashed after
  writing its row, an attribute read on a committed session (v0.71.1); and **the agent read
  the tool policy before scoping its client to the organisation, so the organisation's
  decision not to be asked had never reached the gate — in the console either, since
  16/10/2026** (v0.71.2). Also found: the suite wrote 48 test lines into the real licence
  registry, and Dependabot's graph for core failed on every push since v0.70.3 (both v0.71.1).
  Night 3 (v0.71.2, confirmation off): the rollback left the gate and parked at the approval
  gate — the organisation's row also carried `requires_external_approval`; the mandate is two
  switches, and the receipt now cites both and reads a parked job as a proposal (v0.71.3).
  **Night 4 (both switches off): failed sync detected 13:42:00, run 14 s later, rollback
  executed at 13:43:00 and read back `proven`, receipt `resolved` 1 min 16 s after detection,
  eight signed rows verified.** ArgoCD takes five minutes to declare a rejected patch failed;
  the detection time is ArgoCD's, not ours. *Worker tracebacks unrelated to the watch:
  `detect_agent_anomalies` fails on a UUID it cannot serialise. Open: the receipt's
  `decided_by` is the admin's user id, as the tool-policy route stores it.*
- [ ] **sbatch generation quality** — on the demo the agent produced
  `--ntasks-per-node=8 --gpus-per-task=1` with `srun … torchrun --nproc_per_node=8`,
  i.e. 64 processes per node for 8 GPUs; an HPC audience reads it in seconds. Validate
  the srun/torchrun combination in the submit preview, or offer templates.
- [ ] **The 3 a.m. sync, autonomous** *(prospect-driven — Bull, 10/11/2026)* — today the
  scenario runs as a conversation the morning after: `argocd_get_app`, `argocd_diff`, events
  and logs, `argocd_rollback` under confirmation with its declared proof, audit. The night
  version ran for real on 11/11/2026 on the demo host — twice, with the defects it found
  fixed the same day (brick 7, above). This is the backlog's Incident Responder, scoped to
  one scenario, and the natural proof-of-value project with Bull. *The user guide's "Prometheus alerts" paragraph claimed an agent-side alert intake
  no route provided; rewritten on 11/11/2026 to what exists.*
- [ ] **GitOps: a code guardrail against direct writes on Argo-managed resources** — the
  ArgoCD notification webhook shipped 11/11/2026 (above); this is what remains.
  The guardrail reads the Argo tracking label before a Kubernetes write and refuses,
  naming the Git path (overlaps the Drift Detector agent above). The organisation's tool
  policy already closes direct writes org-wide; this makes it hard-wired. Build only if a
  customer asks — Bull raised the question on 09/11/2026.
- [ ] **Demo hygiene** — three test gateways in VibOps Demo (`xxxx`, `jfjfjjf`,
  `tototot`, never connected) show as unreachable in the fleet; the waste summary keeps the
  last successful scan per gateway, so `scw-par` still reports two idle L4 from 05/10 after
  the GPU pool was deleted (a fresh scan clears it); the Slurm demo mode is dated
  10/05/2026 and names every job `vibops-demo-job`; the DPS demo mode's canned state does
  not persist across jobs, so a confirmed `dps_apply_power_policy` is DISPROVEN by its own
  read-back — stop at the preview on stage.

---

## Out of scope for now

- **Managed service** — operating client infrastructure on their behalf. Requires dedicated ops team. Revisit at scale. *Reaffirmed 08/11/2026: VibOps is the software that MSPs and CSPs deliver their managed services with — service lines run by agents under the partner's responsibility, white-labelled, priced per machine. VibOps supplies the engine, the bounds and the receipt; the partner keeps the customer and the liability.*
- **VibOps SaaS Cloud** — hosted VibOps as SaaS. Target markets (sovereignty-constrained CSPs and enterprises) require on-premise. Revisit for smaller clients without own infra.
- **Native charts** (without Grafana dependency) — revisit when monitoring tab proves insufficient.
