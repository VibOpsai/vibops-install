# VibOps — Technical Roadmap

_Last updated: 2026-08-31 · v0.38.0_

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
- [x] `scripts/update-docs.sh` — post-sprint doc bump (version, date, counts, Known limitations)
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
- [x] **68 tools total** — published on PyPI (`vibops-mcp`) + GitHub

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

---

## P1 — Backlog (prioritized)

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
- [ ] **VM chargeback** — cost per tenant based on VM resources (vCPU/h + RAM/h + disk). Rate configurable per hypervisor. Aggregated monthly report per tenant. Same model as GPU chargeback but for CPU/RAM/disk. ~2 days.
- [ ] **Chargeback export (pre-invoice)** — CSV/PDF export per tenant with consumption detail (GPU/h, VM/h, cost, period), ready to import into ERP (Sage, SAP, etc.). Signed HMAC for integrity. Covers both GPU and VM chargeback. ~1 day.
- [ ] **Scheduled triggers (cron)** — user-defined cron expressions in triggers (e.g. "run VM waste scan every Monday at 8am"). Add schedule type to TriggerRule model + UI toggle in Automations tab. Essential for MCO recurring tasks. ~2 days.
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
- [ ] Knowledge Agent — learns from past incidents and recommendations, enriches future diagnostics with historical patterns
- [ ] Onboarding Assistant — conversational wizard for new clients (replaces HTML wizard with AI-guided setup)

**Infrastructure:**
- [ ] Agent graph dispatcher — custom state machine in DB (`agent_tasks` table) + Celery routing. No LangGraph/CrewAI dependency. ADR 0032.
- [ ] Agent fleet dashboard — console panel showing all agents, status, last run, findings count
- [ ] Inter-agent communication protocol — agents trigger each other via DB tasks (security → ops, compliance → security)

### Console frontend architecture
- [x] Split `index.html` (9285 lines) into Jinja2 partials — 18 partials, skeleton 406 lines ✓ v0.32.0
- [x] Split `vibops.js` (5305 lines) into 13 JS modules — Object.assign assembler (38 lines) ✓ v0.32.0

---

## Out of scope for now

- **Managed service** — operating client infrastructure on their behalf. Requires dedicated ops team. Revisit at scale.
- **VibOps SaaS Cloud** — hosted VibOps as SaaS. Target markets (sovereignty-constrained CSPs and enterprises) require on-premise. Revisit for smaller clients without own infra.
- **Native charts** (without Grafana dependency) — revisit when monitoring tab proves insufficient.
