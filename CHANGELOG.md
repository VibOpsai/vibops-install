# Changelog

All notable changes to VibOps are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

_Nothing yet._

## [0.58.0] — 2026-10-25

### Added

- **The agent meters its own model calls.** Every call's tokens — input, cache
  read, cache write, output — and latency are recorded per request and handed
  to core's inference logs after the exchange, under `agent_id = "vibops-agent"`
  and the caller's organisation, so the FinOps agent-usage view now includes
  the product's own consumption. Priced only when `LLM_USD_PER_MTOK_INPUT` and
  `LLM_USD_PER_MTOK_OUTPUT` are set; otherwise the row says `unpriced`, never
  `$0`. Until now the agent's consumption was on no metered path and
  `inference_logs` held nothing about it. ADR 0057.

### Fixed

- **The internal inference-log batch writes under the system scope.** A
  service caller carries the shared key and no tenant, so row level security
  refused every row — measured on the demonstration instance the first time
  the agent handed over its usage. The llm-proxy had been refused the same
  way since RLS landed, silently; the table was empty for that reason.
- **The kubectl pass-through runs reads only, at the connector.** `kubectl_exec`
  was declared "execute a command inside a running pod", marked non-destructive,
  and implemented as an arbitrary kubectl runner — an operator-role API caller
  could `kubectl delete` through it with no confirmation, and the MCP verb
  allowlist never reached the connector. Both pass-throughs now refuse any
  non-reading verb before a process starts, name the verb, and point to the
  catalogued action; the catalogue entry says what the code does. ADR 0056.
- **An upgrade from a release that predates a chart key no longer fails.**
  `helm upgrade --reuse-values` hands the template the previous release's
  computed values, in which a key the chart has just invented does not exist.
  The first upgrade to 0.31.3 failed outright — `nil pointer evaluating
  interface {}.enabled` — refused rather than applied, and it would have
  refused at every customer site. Chart 0.31.4 reads the block nil-safely, and
  absence now means the chart's own default rather than nil, so an upgrade that
  never mentioned `networkPolicy` still gets the policy.

  The deeper problem is not the template: with `--reuse-values` a **new default
  never applies at all**, so the `securityContext` added in 0.31.2 would have
  shipped and silently done nothing. The runbook now says
  `--reset-then-reuse-values`.

## [0.57.3] — 2026-10-21

### Added

- **The kernel enforces what the image used to merely assert.** Chart 0.31.2.
  Neither the pod nor the container carried a `securityContext`: the process ran
  as uid 1000 because the image said so, not because the cluster required it, so
  an image regression would have produced a root pod silently, no syscall filter
  applied, and every capability the runtime grants by default was still held.
  Now declared — `runAsNonRoot` with uid/gid 1000 and `fsGroup`, a
  `RuntimeDefault` seccomp profile, `allowPrivilegeEscalation: false`, and every
  capability dropped.

  `readOnlyRootFilesystem` ships **off**, which is the measurement talking: `/`
  was already unwritable to uid 1000 inside a running gateway, while `/tmp`,
  `/app` and `/home/vibops` were writable and both kubectl and helm use them.
  Enabling it mounts `emptyDir` at the first two, wired so the flag is one word;
  what is not measured is whether anything writes under `/app` at runtime, and
  the failure mode of being wrong is a gateway that will not start at a customer
  site.

## [0.57.2] — 2026-10-21

The three gaps ADR 0054 measured, all in the component customers install on
their own clusters. Verified afterwards on real hardware: a subprocess that saw
the gateway token and 25 variables now sees neither and inherits four, and the
link-local metadata address that accepted a connection now times out.

### Fixed

- **A subprocess no longer inherits credentials it has no use for.** Measured
  inside a running gateway, through the connectors' own `run_command` rather
  than the container's declared environment: `VIBOPS_TOKEN` visible, 25
  variables inherited. One default caused it — `env=None` reaching
  `create_subprocess_exec`, where None means inherit everything — and every
  kubectl, helm and git the product ran could read the credential a gateway
  authenticates to core with, along with every other connector's.

  The environment is now built from three declared layers, with
  `NEVER_FORWARDED` applied over all of them, so a forbidden name cannot return
  through a connector, a prefix, the operator passthrough, or an explicit
  dictionary — four connectors were doing the last of those, each building
  `{**os.environ, …}`. The distinction that makes it safe rather than merely
  strict: a binary we launch may read its **own** credentials, because kubectl
  against EKS execs a plugin that reads `AWS_*` and cutting that would break
  every cloud site; it may not read another connector's, and around forty such
  names belong to connectors that speak HTTP from Python and launch nothing.

### Added

- **A gateway grants one capability rather than all of them.** Chart 0.31.0.
  `kubectl auth can-i --list` returned 87 rules on a gateway's service account,
  21 of them carrying a write verb, granted to the pod as a whole — so an
  operator who wanted queue governance alone, one `patch` on one resource, had
  to grant all twenty-one. `rbac.write` now names five families: workloads,
  exec, networking, namespaces, schedulerQueues. `allowWrite: true` still grants
  exactly what it granted, asserted against the list measured before the split.
- **The chart ships a NetworkPolicy.** There was none anywhere on the cluster
  because the chart shipped none, and the pod could open a connection to any
  public host and to the link-local metadata address. Ingress is now denied
  entirely — nothing needs to reach a gateway, it polls outward — and egress
  stays open minus that range. Deny-by-default egress is deliberately *not*
  shipped: a gateway reaches a vCenter, a BMC or a cloud API at addresses the
  customer chooses, and a list we wrote would be wrong at the first site and
  would fail as a network fault rather than a configuration one.

### Changed

- **The demo host runbook says what v0.57.1 actually measured.** Core no longer
  connects as the `vibops` superuser — it announces `vibops_app`, RLS
  applicable, and the runbook had claimed the opposite for two weeks while step
  4 already grepped for that exact line. Step 3 edited `docker-compose.yml` by
  `sed`, four paragraphs below a note explaining the version lives in `.env`.
  And a new section: the host is not the whole demo — the GPU part executes in
  gateway pods elsewhere, there are two of them registering one cluster under
  two names, and a pinned `image.tag` makes `helm upgrade --reuse-values` report
  *Upgrade complete* while the pod keeps the old image.
- **Two ADRs.** 0054, what confines the gateway, measured — written because a
  vendor announcement raised the question and the useful answer turned out to be
  about us; amended the same day with what shipped. 0055, an R&D window before a
  group goes into production, on a fleet that already has its own CLI: four
  branches, two unknowns that decide between them, and what does not exist on
  our side listed before what does.

## [0.57.1] — 2026-10-21

### Fixed

- **A queue the scheduler does not know is refused, the way an absent scheduler
  is.** `submit_training_job` checked that KAI was installed and not that the
  queue existed. A job sent to a misspelled queue was accepted and its pod sat
  Pending for ever, because the scheduler does not complain about a queue it
  does not know. The refusal now names the queues that do exist. Found by
  creating a real `batch/v1` Job on a demonstration cluster while intending to
  exercise a refusal path; the Job and its namespace were removed and the
  removal verified.

### Changed

- **`docs/commercial/` is no longer under the public-figures guard.** Three
  tests and the frozen-archive list are gone. Those documents are not
  maintained, and the guard's only remaining effect was to oblige someone to
  retype them: the same two 2-pagers went 366 → 368 → 370 actions in two days,
  once per release that registered a new action, each edit made because the
  build had stopped and none because a reader had been misled. What this gives
  up is written where the tests were — a new commercial document may now quote a
  figure the product denies, and nothing will say so. `README.md`,
  `mcp/README.md` and the public site stay checked.

## [0.57.0] — 2026-10-20

### Added

- **Run a training job from VibOps, and prove it was admitted.**
  `submit_training_job` lands a job on the cluster, and a verification predicate
  reports what actually happened to it. Pending is UNKNOWN, not DISPROVEN: a pod
  that has not been scheduled yet has not failed.
- **Read the training jobs, their queue and their GPU request.**
  `list_training_jobs` finds the operators present rather than assuming one. On
  a cluster with none it answers "no training operator installed" and says how
  many CRDs it looked through, instead of answering an empty list.
- **Record which tools a turn reached for, and whether they worked.** The
  training dataset gains an anonymised trajectory per exchange — the shape of
  each call and its outcome, never its arguments — alongside the existing count.
  A thumbs-up was the only signal before; a trajectory with verdicts is one that
  does not need a human.

### Fixed

- **The reward signal never reached storage — two breaks in one path.** 185
  exchanges collected on the demonstration host, `with_feedback: 0`, after a day
  of clicking. The console's relay carried no Authorization header, so the
  agent's `/feedback` answered 401; and the agent then built an unscoped
  `CoreClient` whose service token carries an empty `org_id`, which core
  correctly refused with 403 against the exchange's organisation. Both are now
  held by tests that look at what goes on the wire.
- **NVIDIA is a vendor, not the rule.** GPU resource names and the queue label
  were read from the vendor table rather than written for one manufacturer.

## [0.56.9] — 2026-10-20

### Added

- **Cap a queue, so an unbounded exposure can be closed.** `kai_set_queue_limit`
  writes the cap, reads it back, and refuses in five named cases rather than
  one. Measured on a real installation: the default queue sat at `quota 0, limit
  -1` — burst unbounded.
- **Read the NVLink domain, and refuse to imply one.** `get_gpu_topology`
  reports the domains a cluster exposes, and reports their absence as absence —
  not as zero, and not as a number it could not measure.

### Fixed

- **A GB200 was reported as a B200.** The workload detector matches SKUs by
  pattern, and a pattern contained in another has to be tested after it. A
  structural test now asserts that ordering for every containing pair, so the
  next SKU cannot reintroduce it.
- **The reading now says what it does not contain.** A parent queue has no
  reserved cost of its own; it reported one.
- **The tools described themselves in the scheduler's vocabulary, not the
  operator's.** Four descriptions rewritten.
- **A chart change was pushed without a version.** The RBAC change shipped under
  a number that already designated something else.

### Changed

- **CI refuses to republish a chart version instead of overwriting it.**
  chart-releaser skips an existing version silently, and the `helm push` that
  follows replaces an OCI tag without a word, so a chart change pushed without
  moving `version` republished the same number with different contents, in
  green. It happened to 0.30.0 and 0.30.6. The check runs at the point where the
  overwrite would happen, because no CI job fetches git history.

## [0.56.8] — 2026-10-19

### Fixed

- **The same quota/limit inversion came back through the other action.** The
  first fix had been applied to one action's rendering; the phrase now lives in
  the shared resource summary, and a test asserts that both actions word it
  identically.

## [0.56.7] — 2026-10-19

### Fixed

- **The figures were right and the table was not.**
- **The three scheduler actions can now be routed to a cluster.**

## [0.56.6] — 2026-10-19

### Fixed

- **It answered "not installed" about a machine that was not the cluster.**
- **The organisation's tool policy was never read — a missing slash.** The
  generic client methods built `/api/v1catalog` and got a 404, which read as "no
  policy".

### Changed

- **The release-images workflow states a measured wall, not an estimate.** Per
  image: worker 11m09, core 8m50, connect 5m37, agent 5m03, llm-proxy 3m20,
  console 3m14.
- **The day's comments and docstrings were translated to English**, per the
  repository's language rule.

## [0.56.5] — 2026-10-19

### Fixed

- **The gateway could not read the scheduler's queues, and could not name its
  cluster.** The product's own service account was missing the RBAC the chart
  had never granted — invisible for as long as the feature was verified with an
  administrator's kubeconfig instead of the account the product actually uses.

## [0.56.4] — 2026-10-19

### Fixed

- **Three fields the browser sent and the agent never received.** `cluster`,
  `gateway_id` and `confirm` were declared at both ends and dropped by the
  console in the middle, silently, because the model did not declare them. A
  question about scheduler queues therefore probed the default gateway, and a
  destructive action an operator had confirmed arrived unconfirmed.
- **Every answer said "on this cluster" and named no cluster.**
- **The gateway refused the new connector, and the chart could not open it.**
- **The connector count stopped measuring the day the scheduler connector
  shipped.**

### Changed

- **The accessibility scan has a timeout that fits it.** 75 surfaces, measured
  at 2.8 minutes.

## [0.56.3] — 2026-10-19

### Added

- **Read NVIDIA Run:ai's scheduler queues, and put a price on them.** Measured
  on a real installation: 6 queues, 4 schedulable, with the reserved cost
  computed per queue rather than declared.

### Fixed

- **A real installation found two defects the fixtures could not.** Which is the
  point: a mock validates an action that has no effect.

## [0.56.2] — 2026-10-16

### Fixed

- **The Tool Policy screen now changes what the agent does.** It did not.
- **A dying SSE stream says why instead of closing in silence**, and "agent
  unavailable" no longer destroys the evidence of what went wrong.
- **`deploy_model` failed on every Hugging Face model id**, and a deployment
  served a model nobody had asked for.
- **A cluster name is resolved, not rewritten into a kind context.**
- **Polling a job was blocked as a duplicate call.**
- **Three frontend defects**, including an overscroll fix that had been aimed at
  the wrong element.

## [0.56.1] — 2026-10-16

### Fixed

- **`deploy_webapp` reserves the GPUs its schema advertises.**
- **`deploy_model` can tell the server which model to load.**
- **Two claims in the demonstration script had become false**, one of which
  could have bitten during a live demonstration.

## [0.56.0] — 2026-10-16

The largest release of the series, 39 commits, on three fronts.

### Added

- **A migration layer.** Assess a migration from the job that gathered the
  inventory; decide what migrates from the vSphere inventory; a campaign, which
  is the plan — waves, cap, window; the executor and the gesture that lets it
  move; rollback to ESXi with the proof that stops a split brain; five routes;
  and six agent tools, with three deliberately left out.
- **The gateway can be pinned to a pool** (chart 0.29.6 → 0.30.0).

### Fixed

- **A cluster holding an L4 and an H100 announced itself as an L4.**
- **`vme_convert_image` reported a success it had not observed.**
- **The chain broke at 29 VMs, in two places.**
- **A campaign's items were readable by the neighbouring tenant.**
- **Five DAST controls announced a verdict they had never reached**, and the
  coverage gate was reading through a blind spot and understating by ten points.

### Changed

- **The refusal ratchet of ADR 0052 reached zero**, in three agent waves: 134
  tests, then 73, then 98, taking the unnamed refusals from 123 to 64 to 6 to
  none — and five real defects came out of the exercise.
- **`core/app` and the heaviest guards are in English**, in five passes, along
  with the ratchet's own blind spots that the first passes exposed.

## [0.55.5] — 2026-10-14

### Fixed

- **A caller with no organisation reached every organisation's tenants routes.**
  Seventeen sites, up to tenant erasure: `""` is not the system scope, so the
  comparison was skipped entirely. The agent's own service token carries exactly
  that.
- **One message served three status codes** on the recommendations routes,
  flattening a tenancy refusal into "operation failed".

### Changed

- **No authorization refusal is left without a test**, and the public mirrors
  now receive a tag along with the content.

## [0.55.4] — 2026-10-13

### Fixed

- **The server announced the MCP library's version, not its own.** Found by
  speaking MCP to the binary freshly installed from PyPI — `initialize` on
  stdin, the response read from stdout:

  ```
  serverInfo {"name": "vibops", "version": "1.30.0"}
  ```

  `1.30.0` is the version of the `mcp` SDK, while the package was 0.55.3.
  `FastMCP` has no `version` parameter (its signature in 1.30.0 takes `name`,
  `instructions`, `website_url`, `icons` and twenty others, not that one); the
  low-level server accepts one and it defaults to `None`, and that `None` is
  what makes the library fall back to its own. A client reading it learned
  nothing about this product. Nothing was broken, which is the problem: a field
  that exists, is filled, and does not inform.

  The assignment goes through a private attribute for want of a public route, and
  that is acceptable only because the observable is held by a test:
  `test_the_announced_version_is_ours.py` queries
  `create_initialization_options()` — the method the library itself calls to
  build its answer — rather than the attribute. Counter-proved two ways: removing
  the assignment restores 1.30.0, and *renaming* the internal does too, because
  Python accepts any attribute name and raises nothing. A test on the assignment
  would have passed in the second case.
- **The DAST scanner announced an isolation it had never checked.** Its three
  requests all answered 500 — its synthetic tenants had stopped being uuids —
  while it reported "cross-org scope isolation verified".
- **CC8.1 served its own `CompileError` as evidence** in SOC 2 reports, 21 times
  out of 21, for six months.
- **A guard asked whether anything publishes, not whether this does.**

### Changed

- **The twenty-one tests excluded from the default suite since April now run**,
  seven of them having been red the whole time; an excluded marker must now be
  run somewhere or be declared.
- **`compliance_checker` becomes a package**, eight checks by family — with ADR
  0049 amended to say that a service is not split by size, and how one is
  measured.
- **The five compliance tests nothing had run since April.**

## [0.55.3] — 2026-10-13

### Fixed

- **`Publish to PyPI` failed at its very first step on its first flight, and
  both defects were in the workflow I had just written.**

  `actions/checkout` reported `fatal: repository '…/vibops/' not found`.
  Declaring `permissions` on a job **replaces** the default set rather than
  adding to it, and the first version carried only `id-token: write` — so the
  `GITHUB_TOKEN` lost `contents: read`. This repository is private, and GitHub
  answers 404 rather than 403 for a private repository the token may not see, so
  a missing permission presented itself as a missing repository. The job died
  before building anything.

- **And the version/tag check made recovery impossible**, which only shows when
  you need to recover. On a `workflow_dispatch`, `GITHUB_REF_NAME` is the branch
  name, so it would compare "main" against "0.55.2" and refuse every time —
  forbidding the one way out when a tag ships with a broken workflow, which is
  exactly the situation it created. It is now conditioned on
  `github.ref_type == 'tag'`, where it protects something: a publication
  triggered by a tag.

  The other seven tag workflows passed, so `VibOpsai/vibops-mcp` received
  everything that was waiting — the vendor neutralisation, the sub-total guard
  and the `oidc.py` split. Only PyPI did not.

## [0.55.2] — 2026-10-13

### Added

- **Nothing published `vibops-mcp`, so it sat six months behind.** Measured on
  the index: **0.1.0, uploaded 2026-04-19**, while the repository was at 0.55.1.
  Its public page therefore carried the old vendor-foregrounding summary and two
  dead project URLs — the `.io` domain, which does not exist, and the lowercase
  GitHub organisation, a 404 — both of which the repository's own
  `pyproject.toml` had corrected long ago. They were wrong only in the metadata
  of a release nobody had superseded.

  `publish-pypi.yml` publishes `mcp/` on a version tag through OIDC trusted
  publishing, so it carries no token: `id-token: write` and nothing else. It
  fails until the project is declared on PyPI's side, and failing loudly is the
  point. Two pre-flight checks run before the upload, because a PyPI version is
  permanent: `twine check`, and an assertion that the built version equals the
  tag — which catches tagging without having run `scripts/bump-version.sh`.
  Tested locally: passes on `v0.55.1`, refuses `v0.55.0`, `v1.0.0` and
  `v0.55.1-rc1`. No `skip-existing`, because a silent skip would report a
  success without publishing.

  The SDK is deliberately not published: `sdk/README.md` promises
  `pip install vibops` and the name is absent from the index, but reserving a
  name there is permanent and commits to support — the maintainer's call, not a
  technical consequence.

- **Every announced tool sub-total is now counted, and two were wrong.** The
  server exposes 117 tools and three independent measurements agree, because
  `check-tool-parity.sh` counts the total on every push. The sub-totals were
  counted by nobody: `# ── Action tools (37) ──` sat above 60 registrations and
  `# ── Governance tools (27) ──` above 29, so the five section comments summed
  to 92 for a server exposing 117.

  The README was right throughout — its eight families match their tables
  exactly and document the 117 name by name. What looked like a discrepancy is
  two legitimate groupings: `get_vm_usage` is registered under Observation and
  documented under Hypervisors, being an observation tool about VMs. The guard
  checks each grouping against itself and confronts them only by their totals.

  Twice this guard measured nothing, and the counter-proof said so: its pattern
  knew only the README's `(18 tools` form and not the code's `tools (60)`, so
  all five sections were skipped; and a title with no parentheses escaped the
  check entirely, until a test required every group to announce a number.

### Changed

- **The published MCP repository stops foregrounding one vendor.** Maintainer's
  decision. `mcp/` is mirrored verbatim on tag, so five places were corrected
  across the whole mirrored directory rather than the file the question was
  about: the README's three installation sections became one generic
  configuration block — the two JSON blocks were identical to the character,
  which is the point of MCP — plus an alphabetical table of where each client
  reads it; the **package description on PyPI**, the most visible mention of
  all; a module docstring; the issue template; and a test fixture naming a
  vendor model. The symmetric enumeration of supported providers in
  `tools/governance.py` is kept: it is factual, and removing it would make a
  tool's documentation poorer rather than more neutral.


- **`sso/oidc.py` is a package — 541 lines, split per ADR 0049 decision 3.** It
  crossed the ~450-line threshold the day before, when the issuer-verification
  fix added a function and forty lines of comment. The seam is not "routes one
  side, machinery the other" — there were 156 lines of route against 385 — but
  the role of each piece, and each piece was placed from the names it depends
  on, computed by AST at extraction rather than guessed: `_state.py` (the HMAC
  state protecting the callback from CSRF), `_providers.py` (URLs and issuers
  derived from the provider name, **zero free names**), `_token.py`,
  `_provisioning.py`, `routes.py`. Nothing over 200 lines.

  `scripts/check-route-split.sh` reports eight checks green, and it had to be
  fixed first to get there: it did not support a nested module. Its reference
  files went to a directory it never created, and — the part that matters — its
  importability check built `from app.api.v1.sso/oidc import …`, a syntax error,
  so **the check could never succeed**. A false failure rather than a false
  pass, but a check that cannot succeed measures nothing, and for a non-nested
  module it had never been wrong. `sso/` is already a split package, so nested
  modules will recur.

  Two findings the split surfaced, which is what the procedure is for.
  `_VALID_PROVIDERS` existed **twice** in this package — in the old `oidc.py`
  and in `config.py` — and the `oidc.py` copy had no reader anywhere; it now
  lives in `_providers.py` and `config.py` imports it, one vocabulary in one
  place. And the two guards keyed on `sso/oidc.py` failed loudly at the split
  with a `FileNotFoundError` naming the vanished file, which their own comment
  says is the intent. Retargeted, then counter-proved by removing
  `system_scope()` from both routes: the guard fails naming the handler.

  Recorded about check 8: it reported "no guard names a vanished file" while two
  guards named one. The general guard it delegates to recognises paths built
  from `parents[n] / "..."`, not bare strings in a data table, so it cannot see
  those keys. No silent hole — a stale key crashes at runtime by design — but
  the message is wider than the measurement.

### Added

- **The SSO `id_token`'s issuer was never verified, and the refusal that said
  so was dead code.** `_verify_id_token` called `pyjwt.decode` with `audience=`
  and no `issuer=`. Measured on the project's PyJWT 2.15.0: without that
  parameter any `iss` is accepted; with it, `InvalidIssuerError` is raised. So
  the `except pyjwt.InvalidIssuerError` branch and its
  "id_token issuer mismatch." message could never fire — the product announced
  a protection it was unable to emit, on the authentication path.

  What remained as a binding was `aud == oidc_client_id` and the public key from
  the provider's JWKS. Not enough: for `google` that JWKS is a single global
  endpoint hardcoded in `_get_jwks_uri`, and Microsoft serves the same signing
  keys across tenants. The `iss` claim is precisely what separates one tenant
  from another.

  **The fix had a trap, and a test holds it.** Azure puts the issuer URL
  followed by `/v2.0` in `iss`, while the JWKS URL is built from the form
  without the suffix — so a strict comparison would refuse every valid Azure
  token while announcing "issuer mismatch", a refusal that looks like a
  detection and is an outage. PyJWT accepts a sequence (verified), so
  `_expected_issuers` returns both forms for Azure, both of Google's historical
  forms, and stays strict for Okta and `custom`. An organisation with SSO
  enabled and no issuer URL is now refused with a message naming that cause,
  rather than verified without an issuer — that is the one refusal this series
  *adds*, deliberately.

  Behaviour change on a live authentication path, taken because no installation
  is on OIDC today. Counter-proved four ways: `issuer=` removed (the pre-fix
  state) fails the issuer test; Azure's `/v2.0` form removed fails the Azure
  test; the empty-issuer tuple verifying anyway fails the configuration test;
  the trailing slash left in place fails the table test.

- **The four refusals of `policy/scope.py` are now exercised.** `check_scope`
  is the fence every submitted action crosses — `api/v1/jobs/create.py` through
  `services/job_admission.py`, and `api/v1/pipelines/trigger.py` directly — and
  its four refusals are what stops a member of one team acting on another's
  namespace, cluster, environment or action.

  One property nothing else protected: at `scope.py:36` the cluster is read
  under **two** keys, `payload.get("cluster") or payload.get("context")`,
  because kubectl connectors say `context` and the rest of the product says
  `cluster`. Had either stopped being read, an action aimed at a cluster outside
  the fence would cross it by using the other key — no error, no trace, no test
  falling. Both keys are now held, and required to produce the same message.

  Both directions of the `None` rule are held too. `None` in `allowed_*` means
  *no restriction*, deliberately: a team without a list is not a team without
  rights, and the opposite would mean adding a team to a user removes their
  access. Treating `None` as an empty list fails five tests including both
  witnesses — the inversion closes everything and reads like a hardening.

  And one correction recorded in the file itself: its org-admin test holds the
  property, not the line. The short-circuit exists twice — at the top of
  `check_scope` and inside each of the five `UserContext` predicates — so
  removing the one in `scope.py` alone makes no test fail. Measured by doing it;
  the digest moved and nothing fell. Both layers must go for the test to fail. A
  docstring claiming to pin a line it does not pin is exactly the green that
  measures nothing.

- **The four refusals of `/auth/refresh` are now exercised, 281 → 273 overall
  with the above, and 37 → 29.** That endpoint keeps a session alive and it authenticates nothing
  beforehand — the token presented *is* the identification — so its four
  refusals are all that separates the call from issuing a token to anyone.

  Two of them carry a security property rather than a politeness.
  `login.py:165` checks `data.get("type") != "refresh"`, which is what stops an
  access token being spent as a refresh token: without it a thirty-minute token
  exchanges for a fresh one indefinitely, so it is worth as long as its
  signature rather than thirty minutes. The test presents a real access token,
  the one the product hands out at every login. And `login.py:203` compares the
  password-hash fingerprint `create_refresh_token` embeds — there is no
  revocation list, so that comparison is the **only** mechanism by which
  changing a password closes the sessions already open.

  Counter-proved four ways, and the fourth is the one worth having: comparing
  the fingerprint backwards — closing *every* session instead of the stale ones
  — fails the positive witness at the same time. Closing too much is a defect
  too, and no test that only checks the refusal would see it.

  The file's fifth refusal is deliberately left alone: it already has a test,
  acquired on 02/10 when it turned out **no session could be renewed on a Helm
  installation** — the user read went out without system scope, matched no
  branch of the ADR 0047 policy, returned zero rows, and the server blamed the
  account for a perfectly valid token.

- **The seven refusals of `app/auth.py` are now exercised, 288 → 281 and
  44 → 37.** That file is not one file among others: it is the dependency every
  protected route mounts, by security invariant 1 —
  `APIRouter(dependencies=[Depends(get_current_user)])`. None of its seven
  refusals had its message named by any test, so if one of them had stopped
  refusing, nothing in the suite would have fallen.

  Each test calls the function and checks both the code and the message, and
  each carries a positive witness — a `developer`, an org admin, a service
  account, a token that resolves — without which a function refusing everyone
  would pass all seven. Counter-proved by disarming each guard in turn: the two
  `decode_token` branches swapped, signature verification turned off, anonymous
  access made unconditional, both role doors neutered, the API token's
  `expires_at` condition removed, the `is_active` filter removed. Seven
  mutations, seven named failures.

  Two findings while writing them. The "token missing" refusal **does not fire
  in development mode** — `_authenticate` returns `UserContext.anonymous()`
  there, which is the warning every log in this repository prints — and the
  suite runs in `development`, so a test written without noticing observes no
  refusal at all. The test now holds both halves, and the second is the one that
  protects something: were the `app_env` comparison to break, production would
  authenticate without a token, silently. `staging`, `prod`, `dev`, `test` and
  the empty string are all checked to refuse.

  And **the file committed the very evasion it documents.** Its first version
  quoted, in quotes, to warn against it, the exact message used as the ratchet's
  gaming example. The quotation was enough: the count fell from 288 to 271 for
  seven tests, the other ten being the sites carrying that message. Measured by
  comparing the count with and without the file. The quotation is gone, the
  budget falls by seven rather than seventeen, and both files now record why —
  it is the sharpest demonstration that this ratchet measures a string, not
  coverage.

- **A ratchet on the service layer, which nothing was counting — and it is not
  a volume cap.** `api/` and `workers/` each had one; `services/`, the
  destination of the ADR 0049 refactor, had none. Measured by commit date:
  `services/` held **58 queries across 16 files** on 12/09 and **336 across
  55** today. The ADR's own Consequences section says that growth is "the
  expected shape", so a budget forbidding any rise would turn the refactor's
  success into a test failure. This one asks a rise to be **justified** — by
  naming the origin layer whose budget fell by as much in the same commit —
  while the second property can only fall.

  Writing it exposed four blind spots in the two existing ratchets, 74 of the
  336 queries, 22% of the real figure:

  - **`self._db` — 43 queries in 9 files.** `\bdb\.` matches inside
    `self.db.` because the dot is a word boundary, but not inside `self._db.`
    because `_` is a word character. Nine files read exactly zero under the
    worker predicate while executing queries, led by `pricing_service.py` (9)
    and `cluster_rate_service.py` (8). The same shape as the `sess` undercount
    of the same day, one spelling further.
  - **`refresh` — 31 calls, a SELECT each**, in no method list in the
    repository.
  - **`query` — the legacy ORM API, and the worst of the four.**
    `rollback_service.py:45` and `:83` run `db.query(Memory).filter(...)
    .first()`. The file contains no `select(` at all, so it escapes the route
    ratchet's strict predicate *and* its broad one — the predicate written
    precisely to catch a statement built in one place and run in another. Both
    existing ratchets classify that file as holding no SQL.
  - **`get` qualified by receiver — 12 queries.** The worker ratchet counts
    `get` in its budget but excludes it from its receiver guard, for a sound
    reason: 205 `.get(` calls here across 62 receivers, of which 12 are on a
    session. A session spelled anew that queried only through `.get(` would
    escape that budget *and* that guard. A dedicated test closes it.

  The second property is the one that can only fall: **an object whose name
  promises a computation does not query.** Five offenders, 25 queries —
  `compliance_checker.py` alone holds 16, including a raw
  `SELECT version_num FROM alembic_version` at line 470, on Alembic's migration
  table, from a compliance service. Five files of the same family hold zero,
  which is what makes the rule tenable rather than pious: `job_admission.py`
  carries the eight admission gates of `POST /jobs`, extracted from a 303-line
  route, without a single query.

  What no call-based predicate can see is written in the docstring rather than
  papered over: `erasure_service.py:114` is one written site and ~47 statements
  (a loop over the 47 `org_id`-bearing tables); `audit.log_action()` makes four
  round trips from call sites counted as zero; `channel_service.py:440` opens a
  second psycopg2 session inside an async service; nested `selectinload` fans
  out; and lazy loading in the five synchronous files issues SELECTs with no
  call syntax at all.

  Every property was counter-proved by mutating the tree and watching the named
  test fail — a new query, a removed one, a new session spelling, a session
  hiding behind `.get(`, SQL added to `job_admission.py`, `compliance_checker.py`
  renamed out of the perimeter, and a declared `Result` that is not one. The
  rename is the known way to silence the second property, so a survey guard
  freezes the perimeter's size and names both the largest offender and the
  counter-example.

---

## [0.55.1] — 2026-10-12

### Fixed

- **`psql` exits 0 on a failed statement, and that hid the fix above.** The
  seeder fix shipped with an SQL comment containing `` `DO $$ ... END $$` ``,
  written inside a dollar-quoted block — where `$$` closes the string, so the
  rest of the block is parsed as SQL:

  ```
  ERROR:  syntax error at or near ".."
  LINE 166:   -- `DO $$ ... END $$`, l'echec annulait le bloc entier
  ```

  The script printed "Done." and exited 0, with **zero** workloads and **zero**
  insights written. The guard added alongside saw nothing: `dedup_key` was
  named, correctly. Two defects the same day, the second introduced by the
  first's comment.

  The `$$` is only one way to break that SQL. What is guarded is that a failure
  shows: `ON_ERROR_STOP=1` on all eight `psql` invocations of the two seeders,
  and a test that requires it. Verified end to end afterwards on a v0.55.1
  stack — `seed-dev.sh` writes 18 workloads and 5 insights, and
  `validate-seed.sh` passes every check including
  `live-cost running_workloads > 0`, the one that failed in CI.

- **Workload sync only ever visited the first gateway.** The nine attribute
  reads in `_sync_all_gateways` were the first statements *of each iteration* of
  `for gw in gateways:`, and `await session.commit()` sits inside that same loop.
  The first gateway was fine; from the second on, `org_id = gw.org_id` touched an
  instance the previous iteration's commit had expired, and the refresh is a lazy
  load from async code:

  ```
  workload_sync_ok     org=… cluster=gpu-staging upserted=0
  workload_sync_failed err=greenlet_spawn has not been called
  ```

  The comment directly above the offending line said exactly the right thing —
  "read all gateway attributes before entering the commit loop" — and the code
  did it one line too late. The mitigation was written and inert.

  Measured on the demonstration host: **42 gateways**, **30**
  `workload_sync_failed` in 30 minutes (the task runs every minute), and all 13
  `workloads` rows still carrying `updated_at` = 2026-09-09, the seed date. A
  month of syncing one gateway a minute, logged every time, while the table held
  enough rows that a glance said nothing was wrong. The outer handler also
  reported `{"error": …, "synced": 0}` — zero, although one gateway had
  committed.

  The snapshot now happens before the loop, so nothing is left for a commit to
  expire; the loop body is unchanged, `gw` appearing nowhere else in it.
  `core/tests/test_la_synchro_des_workloads_visite_toutes_les_passerelles.py`
  requires both the absence of the `error` key and one `workload_sync_ok` per
  gateway, because a task that visits nothing raises no error either. Restoring
  the defect makes it fail with production's own message, verbatim.

- **Both seed scripts broke on a v0.55.0 database, and took the workloads with
  them.** Neither named `dedup_key` in its `INSERT INTO proactive_insights`.
  The column is NOT NULL with a `''` default since migration `d5f9b2c3e47a`,
  and `uq_insight_identity` covers `(org_id, insight_type, dedup_key)` — so two
  rows of one type both took the empty key and the second raised
  `UniqueViolation`. Reproduced on the migrated test database:
  `seed-dev.sh` on its two `cost_optimization` rows, `seed-cloudsigma-demo.sh`
  on its two `idle_gpu` rows.

  Each script runs inside a single `DO $$ ... END $$`, so the failure rolled
  back the **whole block**: in `seed-dev.sh` the workloads inserted at lines 257
  and 275 vanished along with the offending insert at line 352. The tag's
  "E2E Pipeline Tests" job failed on `live-cost running_workloads > 0 — =0`
  while the seeder printed "0 workloads" and nothing else. Green on v0.54.6,
  red on v0.55.0 — the regression was ours.

  The migration's docstring said this change "cannot come alone" and named the
  two worker tasks that built a `ProactiveInsight` directly. The workers were
  checked; the seed scripts were not.
  `core/tests/test_no_raw_insert_bypasses_the_insight_identity.py` closes that
  path — `test_one_finding_one_insight_row.py` only forbids the Python
  constructor, and the SQL route was uncovered. It carries a survey guard, since
  an empty scan would declare the repository healthy, and it fails naming the
  file when the key is dropped again.

  The published v0.55.0 images are not affected: the defect is in repository
  scripts, not in the product. Migrating an existing database is safe —
  `local-standby.sh update` and the demo upgrade do not re-seed. Seeding a fresh
  installation does, and that is what breaks.

---

## [0.55.0] — 2026-10-12

### Fixed

- **A guard reported a tool missing because it had found it.**
  `scripts/check-tool-parity.sh` declared `get_siem_config` absent from the
  agent catalogue. It is at `agent/app/services/tools_catalog.py:3546` and
  always was. The same script, on the same tree, said "OK" locally and
  "MISSING 1 tool(s)" in CI from identical input — 310 agent tools and 117 MCP
  tools on both sides.

  ```bash
  if ! echo "$agent_tools" | grep -qxF "$tool"; then
  ```

  `grep -q` exits at its first match, `echo` then writes into a closed pipe and
  takes an EPIPE, and `set -o pipefail` makes that failure the pipeline's
  status — so `! pipeline` is true *because* grep found the name. The script
  said so itself and nobody had read the line: `echo: write error: Broken
  pipe`. It is a race between how much echo wrote and when grep exits, so the
  verdict depends on where the name sorts and on the machine; any tool could
  have been denounced. `tests/test_no_script_turns_a_match_into_a_miss.py`
  forbids the pattern wherever `pipefail` is on, and found two more on its
  first run (`bump-version.sh`, `check-route-split.sh`) — both small enough
  that the write landed in the pipe buffer before grep could exit, which is why
  they had never fired.

- **A pipeline task reported a success having closed nothing.**
  `_finish_pipeline` caught every exception, logged it and returned, while
  `execute_pipeline` returns `{"status": "success"}` three lines below without
  consulting it. Any write failure at closing time left the pipeline `running`
  forever while Celery marked the run SUCCESS and a Slack notification went
  out. The `raise` now sits behind the log, the shape `workers/job_tasks.py`
  already uses in five places. A pipeline row that no longer exists does not
  raise — an erasure (ADR 0046) is legitimate and a deleted row cannot stay
  `running` — but it is logged instead of dropped.

  Two writes stopped lying on existing columns at the same time:
  `record_step_success` clears `PipelineStep.error`, so a step replayed
  successfully no longer shows last run's `ImagePullBackOff` beside a green
  status; and `finish_pipeline` writes `error` as given, `None` included, so a
  pipeline finishing SUCCESS after a tolerated step failure
  (`on_failure="continue"`) no longer serves that message beside a success. The
  tolerated failure stays readable on the step and its `Job`, which is where
  the console looks for detail.

- **A VM anomaly that stopped was never closed.** The three detections in
  `vm_anomaly_task` were guarded by their *numerator* — `vm_stopped > 0`,
  `vm_cpu > 0`, `vm_mem > 0` — and the `_resolve` call sits inside the `else`
  of those blocks. The day every VM restarts, `vm_stopped` is 0, the whole
  block is skipped, and `vm_down` stays open forever on a cluster where nothing
  is wrong. Only a fleet permanently keeping at least one VM stopped — the case
  that does not need closing — could ever close. The guard now tests the
  denominator alone.

  Decided and held by a test rather than fixed: when the gateway goes silent or
  the cluster leaves `cluster_metrics`, the anomaly stays open. Absence of data
  is not evidence the condition ended, and the stale-anomaly check already
  surfaces anomalies open for more than an hour.

- **Six more anomaly reads did not read what they claimed.** The node filter
  was `context::text LIKE '%"<name>"%'`; measured on an event whose context is
  `{"node": "node-1"}`, the pattern for `node_1` also matched — `_` is a LIKE
  wildcard — so a node named `node_1` answered for `node-1`'s event, its own
  anomaly never opened, and it closed the other one; a node named `%` answered
  for every event in the cluster. Now `context->>'node' = :node`.
  `gpu_snapshots` did not filter `gateway_id` although the caller groups on it
  and labels the event with it, so two gateways declaring one cluster name read
  each other's samples and a 5% fleet beside a 95% fleet averaged to 50%, while
  `node_loss` fired on the smaller one every pass. `resolve_events_for_*`
  recomputed `datetime.now()` per call, so four conditions ending together got
  four `resolved_at`. And `gateways_with_cluster_metrics` selected a column
  nobody reads, with an `IS NOT NULL` that did not filter what it announced:
  SQLAlchemy persists Python `None` into JSONB as JSON `null`, so those rows
  passed and only a Python `isinstance` guard in another file caught them.

- **Four passages a client reads announced something false.** The GPU health
  check gave the latest sample as current utilization with no time bound, so a
  cluster silent for three weeks displayed a three-week-old figure as "GPU
  utilization on X at 4%" and recommended redistributing on top of it. The same
  check picked its redistribution target by `avg(gpu_pct) ASC LIMIT 1` with no
  sample floor, so a single stray 0% reading beat a cluster measured a hundred
  times — the exact profile of a cluster that just died, which the advice then
  named as the destination. The capacity forecast compared two half-weeks and
  printed the gap as "+X%/week" while dividing it by 3.5 for the projection
  beside it, so the number shown was half what its unit claimed. And the budget
  warning called `max(gpu_total)` of under-utilized clusters "N idle GPUs" with
  a dollar figure that was 30% of current burn, unrelated to that fleet.

- **The waste estimate contradicted the client's own configuration.**

  ```python
  waste_monthly = (100 - avg_pct) / 100 * 2.0 * 24 * 30
  ```

  The `2.0` was a hardcoded "$2/GPU-hour" while `ClusterRate.rate_per_gpu_hour`
  holds the rate the client configured and that `workloads`, `metrics`,
  `finops/spend` and `finops/vm` all read. And there was no size factor at all:
  the rest of the formula is one GPU-month, so a 4-GPU and a 512-GPU cluster
  both announced "~$1,224/month" at 15% utilization. Fleet size now comes from
  the query and the rate from a single batched read keyed on the `(org,
  cluster)` pair; with no rate configured the dollar sentence disappears and
  `rate_available: false` says so, the contract `api/v1/workloads.py` already
  applies.

### Changed

- **The SLO gate on `POST /api/v1/jobs` was failing one release in seven on
  noise.** Seven CI measurements of its p50: 263, 280, 338, 357, 400, 412 and
  577 ms, against a 500 ms threshold. The 577 failed this release; re-run on
  **the same commit** the same test returned 263 ms and 28.1 req/s against
  15.4 — a factor of 2.2 on latency with identical server code. The job runs
  only `uvicorn`, no worker and no beat, so none of the commit's code executed
  there at all.

  The noise belongs to this call rather than to the runner: in the red run the
  three GETs stayed flat (52 → 55 ms on `GET /jobs`) and the burst on this same
  endpoint moved 4%, while the single request took 44%. Unverified hypothesis:
  it is the only call in the list that writes — a `jobs` row plus a Redis
  enqueue — and disk-sync time on a shared runner varies far more than its CPU.

  The threshold is now 900 ms, and what that costs is written beside it: at 900
  it takes 2.5× the observed median to fail, so a regression that merely
  doubled latency would pass. The p99 budget of 1500 ms stays the real latency
  promise. A threshold that fails one run in seven blocks releases without
  saying anything about the product, and gets raised blind at the first failure
  — which is how a guard stops measuring. Making this measurable again means a
  baseline recorded on the same runner, or a trimmed statistic over far more
  iterations; both are a project, not a threshold.

- **The insight identity key covers `idle_gpu`, which saved a seeded finding.**
  Simulating the collapse read-only on the demonstration database before
  applying it: 1 657 rows for 16 groups, and 35 distinct titles before, 16
  after. The 19 vanishing titles were listed one by one — seventeen are worker
  repeats of one condition with a changing figure, and two were seeded. One of
  those, "1 underutilized GPU in Zurich", would have been deleted: `idle_gpu`
  was not in the key table, so both seeded rows took the empty key and fell
  into one group where the other won on recency. Keyed on
  `context->>'cluster'`, which both carry, the collapse yields 17 groups and 17
  titles. `idle_gpu` is the one entry no code produces; the migration says so
  rather than dressing it as a product rule.

- **The idle figure is a number of GPUs nobody reserved.**
  `list_idle_clusters` gained `avg(gpu_total) - avg(gpu_used)` — averaged, not
  taken at the peak, since a `max(gpu_total) - min(gpu_used)` would add one
  instant's fleet to another's allocation. Both columns are shown: the fleet is
  what there is to shrink, the unallocated average is what sleeps in it. It
  stays "unallocated" and not "idle", because `gpu_pct` is an allocation ratio
  and a GPU reserved by a pod computing nothing counts as allocated; real
  idleness is measured per device by `/finops/waste`.


### Fixed

- **Two anomaly detectors had never been able to create anything.**
  `k8s_anomaly_task` and `vm_anomaly_task` built their `INSERT` with nine
  columns, `title` not among them, while `anomaly_events.title` is NOT NULL with
  no default — in the model and in migration `7ad8aac9da83`. Every creation
  raised `NotNullViolation`, `get_sync_db` rolled the pass back, and the task
  returned its dictionary without a row or an error.

  The proof was in the data rather than the code: on 12/10 the demonstration
  database held `idle_gpu` (4) and `gpu_idle` (1), both from the ORM path, and
  **zero** `node_not_ready`, `memory_pressure`, `disk_pressure`, `vm_down`,
  `vm_cpu_high`, `vm_memory_high`. A month of running, not one event of those
  six types. The seven call sites now pass a title in the form the two working
  tasks use — a short noun phrase naming the condition and the place.

  **Neither task had any test**, which is what let this live, and it is the
  third time this shape has hit this subsystem: on 09/10 `anomaly_task` lost its
  creations because a stdlib logger received structlog keywords, raised, rolled
  back and reported success. `test_une_anomalie_k8s_arrive_en_base.py` drives
  the task end to end and reads the table rather than the returned dictionary —
  which is the figure that lied. Verified by removing `title` again: three tests
  fail and the healthy-node control does not move.

- **A health check was called a restart.** `_check_deployment_health` groups by
  action and counts both `restart_service` and `health_check`, but titled every
  result "Service restarted Nx in 1 hour" while the description correctly said
  "the action 'health_check'". Three health observations in an hour — what
  monitoring on a fifteen-minute schedule does — announced instability on a
  healthy cluster. Measured: 31 successful `health_check` jobs on the demo, all
  carrying a cluster, and zero `deployment_health` insight, because three in the
  *same* hour are needed and the 31 span a month. Latent, not visible, and it
  would have surfaced with any more frequent scheduler. The title names the
  action now.

  And `health_check` does belong in this check — verified rather than assumed.
  It is not a periodic probe: the action is dispatched by the Grafana alert
  webhook (`api/v1/grafana_webhooks.py`, the `action == "health_check"` branch),
  and no `beat_schedule` entry creates it. A `health_check` job exists because
  something alerted, so three in an hour on one cluster are three alerts, which
  is precisely the instability this check looks for. The demo's 31 are 30 seeded
  rows and one triggered by the agent, which disproves nothing either way. Only
  the title was wrong.

- **Two open events lost a whole pass.** `has_single_open_event` called
  `scalar_one_or_none()`, so a second open event of the same type raised
  `MultipleResultsFound` up through `detect_anomalies`, rolling back everything
  including anomalies already detected on other clusters. Nothing guaranteed the
  uniqueness it assumed: `ix_anomaly_events_cluster_open` is not unique and the
  deduplication behind it is a `SELECT` then an `INSERT`, so two concurrent
  workers are enough to create the state that breaks the next pass. The query
  carries `LIMIT 1` now — same answer for zero or one row, `True` instead of a
  raise for two.

### Changed

- **Worker SQL: 84 queries down to 40, behaviour unchanged.** Three extractions
  run in parallel on disjoint files: `proactive_agent_task.py` 16 → 0 into a new
  `services/insight_sources.py`, `pipeline_tasks.py` 10 → 0 into
  `services/pipeline_service.py`, and the four anomaly tasks 18 → 0 into
  `services/anomaly_service.py`. 47 new tests, each written so that replacing
  the extracted function with `return []` fails a named test — the trap measured
  on 07/10, where six of eight extracted methods could be emptied unnoticed
  because the tests only asserted HTTP 200.

  Identity of behaviour was proved, not assumed: for the insight extraction a
  script replays the seven `_check_*` from both versions against a fake session
  that compiles every statement to the PostgreSQL dialect — 16 of 16 identical
  SQL texts, same emission order.

  Part of the drop is accounting rather than real, and the ratchet says so: the
  success branch of `pipeline_tasks` called `db.get(Job, job_id)` three times to
  write three attributes and the service calls it once. The identity map already
  served the second and third, so PostgreSQL never saw more than one SELECT —
  this ratchet counts written calls, not round trips.

  `gateway_heartbeat.py` keeps its 15 queries on purpose: it runs on a
  synchronous session from `system_sync_session(engine)`, and moving them means
  deciding that question first.

### Fixed

- **1 645 insight rows for 16 findings, and the deduplication was working
  exactly as written.** Measured on the demonstration database on 12/10:
  `cost_optimization` held 784 rows for three clusters, `stale_anomaly` 783 for
  a single finding. `proactive_agent` runs every five minutes and its dedup
  window was one hour, so a condition that persists produces 24 rows a day —
  33 days × 24 = 792 expected against 784 observed. Nobody had measured the
  consequence: the insight list a customer looks at was 98 % duplicates, and
  the notification fired once an hour for as long as the condition lasted.

  A finding's identity is now a database constraint rather than a convention:
  `uq_insight_identity` on `(org_id, insight_type, dedup_key)`, with the key
  each check already used as its `context_key`. `dedup_key` is `''` and never
  NULL — two NULLs are distinct in PostgreSQL, which would have left the
  783-row case undeduplicated.

  `app/services/insight_service.record_insight` is the only place that creates
  one: a single `INSERT ... ON CONFLICT DO UPDATE` replacing the dedup `SELECT`
  plus the `INSERT`, atomic where the pair was not. It returns whether the row
  is new, so the notification fires once per finding instead of once per hour.

  The constraint could not land alone. Of the three places that created an
  insight, two did it unconditionally — `security_scan_task` and
  `compliance_check_task` — so their second run would have raised
  `IntegrityError`. Both go through the service in the same commit, keyed on
  `test_name` and `control_id`: the finding, not the run that found it.

  The migration collapses 1 645 rows to 16, keeping the first sighting's
  `created_at`, the group's `last_seen_at` and cardinality in `occurrences`,
  the latest observation's severity and text, and `acknowledged` if any row in
  the group was — an acknowledged finding must not come back unread.

  **Why eleven green tests could not see it.** `tests/test_proactive_agent.py`
  drove a fake session and asserted `db.add` was called with the right object.
  It stubbed the dedup query itself, so the window that was wrong was never
  executed. Those tests now record the upsert's bound values — they still
  measure which condition produces which insight — and the identity is checked
  against a real database in `test_one_finding_one_insight_row.py`, including
  the collapse, which imports the migration's own SQL rather than a copy.

  The worker ratchet added an hour earlier asked for its own reduction: 85 → 84.

### Added

- **A ratchet on the worker layer's SQL, which nothing was counting.** The
  ADR 0049 ratchet watches `app/api`, because that is what the ADR named.
  Measured 12/10: `app/workers` executes **85 queries across 18 files** —
  more than three times the route layer, now at 25. Two tests hold it: the
  count may not rise without a justification written in the file, and may not
  sit above what the code needs.

  It deliberately does **not** say that worker SQL must move to `services/`.
  The ADR decides that for routes only, and the reasoning does not transpose:
  a Celery task builds its own engine, does not share a pool across event
  loops, and several of those queries write a result no service has a reason to
  own. That decision is still open. What matters more for this layer is already
  guarded elsewhere — `test_background_work_opens_a_scope.py` checks a task
  opens a tenant scope, without which it reads zero rows, processes nothing and
  reports success.

  The number corrects one I reported earlier the same day. A hand count with
  `(db|session)\.execute\(` gave 56; it missed `sess.execute(`, fifteen
  queries in `gateway_heartbeat.py` where the session comes from
  `system_sync_session(engine)`. In the other direction, counting `.get(` by
  method alone would have tripled the figure — `environ.get`, `payload.get`,
  `data.get` are dictionary lookups, and only `db.get(` is a primary-key
  SELECT. So the receiver list is the thing that lies here, as the method list
  did for routes, and `test_no_new_query_receiver_appears` refuses to trust it:
  every receiver of the `execute/scalar/stream` family must be declared as a
  session or as something else, and an undeclared one fails the test by name
  instead of quietly leaving the count.

  A fourth test keeps that declaration honest, and earned its place on its
  first run by catching my own: I had declared `svc` as a non-SQL receiver,
  and `svc.fetch(` never appears in the watched family at all.

---

## [0.54.6] — 2026-10-11

Three things that were green and measured nothing, found by measuring rather
than by re-reading. A throughput threshold that enforced the mean while its own
row promised the p50. A 154-test suite that had never run once since it was
written. And — committed one commit after describing the defect — a guard that
accepted a workflow with no trigger. No product behaviour changes in this
release: the instruments were what was wrong.

### Fixed

- **The frontend suite measured nothing, and the reason recorded was half
  wrong.** `tests/test_frontend.py` — 154 Playwright tests against the console
  — was declared dead with "0 passing, 154 errors, for two independent and
  unconditional reasons". One of the two was not unconditional. Measured
  11/10: **97 pass, 57 fail**, and the suite runs in 7 minutes instead of 12.
  - `_alpine` read Alpine **v2** internals (`querySelector('[x-data]').__x.$data`)
    while the console serves Alpine 3.15.12. Verified against the live console:
    `.__x` is `undefined` and the expression raises `TypeError`. As
    `_reset_state` evaluates it before every test, this one did block all 154.
    It is `Alpine.$data(el)` now — the public Alpine 3 API — with reads and
    reactive writes both verified (`d.loginUsername` written, the `x-model`
    input follows). Note for later: `Object.keys` on that proxy returns 0, so
    never enumerate it.
  - `_login` sent an empty password, which is not a mistake: it is the
    product's own dev-mode auto-login (`_tryAutoLogin` in `init.js`) and what
    `.github/workflows/e2e.yml` builds with `AUTH_PASSWORD_HASH=` empty. The
    401 measured came from a stack running `APP_ENV=production` — a property of
    the target, not of the suite. The suite now skips naming the cause and the
    remedy instead of dying 154 times in a session fixture, takes
    `VIBOPS_E2E_USERNAME` / `VIBOPS_E2E_PASSWORD`, and `VIBOPS_E2E_REQUIRED=1`
    turns that skip into a failure so wiring it into CI cannot make a workflow
    green while measuring nothing.
  - Three state properties had been renamed in the product and the suite still
    wrote the old names, so those tests injected into properties that drive
    nothing: `adminTab` → `settingsTab`, `commits` → `gitCommits`,
    `commitsLoading` → `gitLoading`. Likewise `activeTab: "admin"`, a value the
    product no longer has — it is `settings`. That single rename brought back
    30 tests.
  - `index.html` wraps the whole application in
    `<template x-if="authenticated && !onboarding">`. On a console that knows
    no cluster, `onboarding` is `true`, nothing renders and `.nav-tab` counts 0
    — which is what made the suite look wholesale stale. The neutral state sets
    it to `false`; the five tabs then appear.
  - `_go` reached a screen by clicking a nav label. The nav now shows five
    labels (Dashboard, Fleet, Agents, Automations, FinOps) and four of the six
    the suite used are no longer among them, while every panel still exists
    (`activeTab` accepts eleven values). Twenty tests depended on a nav label
    to reach a screen unrelated to the nav; `_go` sets the tab by its product
    value now, and what the nav shows is checked in one place.
  - The file declared `TIMEOUT = 8_000` while Playwright applied its own 30 s
    default to every action, so one vanished selector cost 30 seconds. The
    declared timeout is the one that applies.
  - A new `VIBOPS_E2E_STUB_API=1` answers for the whole `/api/` surface from the
    test process. This suite injects its own Alpine state and asserts rendering;
    the backend only gated it. Measured: answering just `/auth/login` and
    `/auth/me` is not enough — `currentUser` fills, then another call takes a
    401 from the real backend and `authenticated` falls back to `false`. The
    integrated path stays covered by the Node suite in `e2e/`.

  The 57 that remained were then worked through: **143 pass, 0 fail, 1 xfail**,
  in 1 min 11 instead of 12 minutes, and `e2e.yml` runs the suite — so the
  declared-debt list in `tests/test_a_guard_still_looks_where_it_promises.py`
  is empty for the first time. Verified by removing the CI step again: the
  guard names the file.

  Only a third of what was left was the console moving. The rest were test
  defects no run had ever exposed — a toast pushed as `message` where the
  product reads `msg`; a count of attached elements where the product's guard
  is `x-show`, which hides without removing, so the count never varied; an
  assertion wrapped in `if toggle.is_visible()`, which passed without measuring
  anything whenever the toggle was absent; `input[x-model.number='…']`, not a
  valid selector — and the input is gone anyway, the product derives the
  threshold now. Plus one order dependence: `_reset_state` never cleared
  `apps`, so a previous test's table stayed rendered and two tests passed alone
  and failed in the suite.

  Three tests on the authentication path were moved out rather than fixed: with
  `auth_enabled: false` the console shows no login form and holds no token at
  all — `authToken` None, localStorage and cookies empty — while being
  `authenticated`, which is correct when there is no auth. That path belongs to
  the Node suite in `e2e/`, which has a real stack.

  One measurement is recorded rather than resolved: **Ctrl+` / Cmd+K do not
  toggle the chat panel.** The single keydown listener (`init.js:1259`) is
  registered — counted by instrumenting `addEventListener` before page load —
  the event carries exactly what its condition tests (`key='\``,
  `ctrlKey=true`), `chatPanelOpen` is writable, and nothing calls
  `stopPropagation`. The effect does not happen and the cause is not
  established. Marked `xfail(strict=True)`: if the shortcut starts working, the
  suite fails and the marker comes off.

- **A guard that accepted a workflow which never fires.** The same defect as
  everything above, committed one commit after describing it. The rendering
  suite was wired into `e2e.yml`, whose only trigger is `workflow_dispatch`
  (its nightly cron is commented out), and
  `test_every_guard_is_executed_by_a_workflow` accepted it because it asked
  whether a workflow *names* the file, never whether that workflow *runs*. It
  read no triggers at all. So the declared-debt list was emptied while the 143
  assertions still ran nowhere.
  - The guard now ignores workflows that only start on demand (`push`,
    `pull_request`, `pull_request_target` and `schedule` count — a schedule
    fires).
  - The suite gets its own `console-rendering` job in `ci.yml`, which is
    push- and PR-triggered. It needs no PostgreSQL, no Redis and no core:
    the suite stubs the whole `/api/` surface, so measured on 11/10 the 143
    pass against the console alone, started by uvicorn with a `CORE_API_URL`
    that leads nowhere. The integrated path stays in `e2e/`, which is why that
    workflow is on-demand — its Node suite calls the real Anthropic API.
  - The redundant `e2e.yml` step is removed.

  First run on a runner, in the CI of f3b66f95: `Console ready`, then
  **143 passed, 1 xfailed in 71.58s** — no skips, and three hundredths of a
  second off the local figure.

  Counter-proof, and the contrast is the point: making `ci.yml`
  `workflow_dispatch`-only — which would mean nothing runs in CI at all — gave
  **382 passed, 0 failures** under the old guard, and **335 failures** under the
  new one. Removing the new job alone makes it name `tests/test_frontend.py`.
  Workflow restored from a copy, digest identical.

  Two orphans found on the way, neither breaking anything today: the i18n key
  `scan_infra` is rendered by no template, and `convsOpen` survives in
  `init.js` with no markup left. Worth a look: `<template>` tags do not balance
  per file (`resources.html` ends on an unclosed opener, `secrets.html` has one
  closer too many, `index.html` one too few) — measured as harmless, the llm,
  automations and secrets panels all render correctly.

- **An SLO threshold measured the mean while its row promised the p50.** The
  throughput floor on `POST /api/v1/jobs` sat at 20 req/s for a concurrency of
  10 — exactly `10 / 500 ms`, the boundary at which the assertion becomes
  "mean ≤ 500 ms" while the same table row promises "p50 < 500 ms". The mean is
  always above the p50 once the tail is long, so the boundary was already
  stricter than the published promise. CI showed it on 11/10: p50=328 ms,
  p99=975 ms — **both declared latency SLOs met** — and the job red on
  19.7 req/s. Across the five runs whose figures are readable the measurement
  lands at 19.7 · 20.2 · 20.9 · 21.6 · 26.2 against a threshold of 20, so the
  red carried no information. The floor is 10 req/s now (mean ≤ 1000 ms, under
  the row's own p99, so it can no longer preempt a latency assertion), which
  still catches the one thing latency cannot see: that the requested
  concurrency actually happened — a server serialising those ten requests would
  return 2 req/s at the same mean.
- **The guard that was supposed to prevent this allowed the boundary.**
  `tests/test_slo_thresholds_are_the_documented_ones.py` has refused a
  `min_rps` above `concurrency / p50` since 04/10; it compared with `>` and so
  permitted the equal value. It compares with `>=` now. Verified by putting
  20 req/s back: the tightened guard names it, the previous one stayed silent
  on that row while failing on another — so it was running and able to fail.

---

## [0.54.5] — 2026-10-11

A safety control that reported itself enabled and did nothing. Everything else
is guards, tooling and one contract-identical split.

### Security

- **The per-org external-approval override did not gate.**
  `ToolPolicyOverride.requires_external_approval` is set through
  `POST /catalog/{action}/policy`, stored, merged over the connector
  declaration by `api/v1/catalog.py`, and returned as **active** by
  `GET /catalog`. Nothing read it in the decision path.

  `PolicyEngine._find_catalog_entry` returns the *static* connector catalog.
  Of the 32 connectors, 8 declare that flag and **none sets it to `True`** —
  the rest fall through to the `False` default — so the engine's condition was
  dead for every action a customer can call. And the engine is synchronous, so
  it never sees the organisation's row. `create_job`
  did fetch the override — and read only `requires_confirmation`.

  An administrator could require external approval on an action, see it
  displayed as required in the console, and have jobs execute with no gate.
  `docs/roadmap.md` marked the feature (OPS-E03) as delivered.

  Measured through the route, with a control: no override → 201;
  `requires_confirmation` → 409, as designed; `requires_external_approval` →
  **201, the job runs**. Two flags on the same row, set by the same route,
  displayed side by side. One gated. The other did nothing.

  Anyone on v0.54.4 or earlier who has set this flag is not protected by it.

- **`confirmed: true` would have bought its way past the gate.** Both flags sat
  in one `if` whose condition carried `not payload.confirmed`. Confirming means
  the caller states they read the preview — the same caller. External approval
  asks for somebody else. A gate the caller it constrains can open is not a
  gate. Separated, and the test proving it was counter-proved by restoring the
  old condition.

- **The approval request could vanish in silence.**
  `asyncio.create_task(ChannelService(db).notify_approval_request(...))` handed
  the *request* session to a detached task. FastAPI closes it when the response
  is rendered, and a detached task's exception goes nowhere: the job sat in
  AWAITING_APPROVAL and nobody was told. A gate whose request disappears
  quietly is worse than no gate, because it looks like it worked. This was the
  only place in the repository passing a request session to a detached task; it
  opens its own now.

  Fixing the first defect is what made this one reachable: that path was
  previously entered only by a declarative `require_approval` rule.

**Not changed, and stated rather than left implicit:** `evaluate_system` — the
pipeline and trigger path — deliberately skips destructive confirmation and the
role check, with its reasoning written down. It also skips the external
approval gate, and that part is *not* documented as deliberate. Pre-authorising
a pipeline is not the same as a named approver signing off each run. That is a
threat-model decision, not a defect to patch quietly.

### Changed

- **`compliance.py` is a package** (ADR 0049 decision 3): 537 lines → five
  files, largest 298. The seam is not three themes — `/controls` is the
  register, `/reports` the evidence pack with its 146-line background task, and
  `/ai-act` a compatibility surface whose four aliases delegate rather than
  duplicate. Verified: 14 routes under `/compliance` before and after,
  `docs/openapi.json` identical, auth map identical, no top-level name lost.
  Twelve of those fourteen are this package; `/compliance/check` and
  `/compliance/check/results` come from `compliance_checks.py`, which declares
  the same prefix on a router of its own — now recorded in the package
  docstring, because nothing else said it.

### CI

- **`Tests LLM Proxy`** — six tests that no workflow ran, while
  `vibops-llm-proxy` is built, signed, scanned and published at every release.
  Found by a new guard, not by hand.
- **`Tests counter-proof`** — see below.
- Two guards pointing at `api/v1/compliance.py` after it became a package. One
  was the guard that reports exactly that, doing its job; the other was in
  `agent/tests`, outside the scan `check-route-split.sh` performed. That scan
  covers the whole repository now, and its "verify these guards still bite"
  note became a **check** that fails — it reported 7 of 7 passing while two
  were broken.

### Guards

- Every `/api/v1/...` path a hand-written client uses is compared against the
  contract. This is what found the v0.54.4 agent defect.
- Every test file in every suite must be executed by some workflow. Written
  after a by-hand measurement of the same question got it wrong.
- Every declared exemption must correspond to a real finding. The one exemption
  in the repository had been exempting nothing since its creation: `versions`
  was not a watched source tree, so the flat glob it excused was invisible.
- The budget hard cap is now observed **through the route**, not only in the
  service. Six tests, four counter-proofs: the refusal removed, the `>=`
  boundary made strict, tenant scoping dropped from the spend query, and the
  hard cap swapped for the soft cap.

### Tooling

- **`counter-proof/`** — an MCP server with two deterministic tools:
  `prove_it_can_fail` (break what a guard protects, verify it cries, restore
  byte for byte) and `find_blind_guards` (flat globs over a source tree, and
  paths to files that no longer exist). **Internal for now** — nothing is
  published, and its README says so rather than documenting a `pip install`
  that would fail. Its own validation found the vacuous exemption above.

---

## [0.54.4] — 2026-10-10

One fix a user can feel. Everything else is the route layer being taken apart,
and it was verified to change nothing: the 287 operations of
`docs/openapi.json` are the same set before and after, each with the same
`security`, parameters, request body and responses, and the 159 component
schemas are byte-identical. Two splits reordered the document — a route
declared in a different file is serialised in a different place — and that
reordering is the whole diff.

### Fixed

- **The agent's spend-trend tool called a route that does not exist.**
  `agent/app/services/core_client.py` asked for `/api/v1/finops/spend-trend`;
  the route is `/api/v1/finops/spend/trend`. The method calls
  `raise_for_status()`, so any operator asking the agent for a spend trend got
  an exception — and the tool is in `tools_catalog.py`, so the model offers it.
  The MCP server calls the same tool and had the path right all along: one
  question, two surfaces, one correct.

  Nothing caught it. The test that covers the tool covers it well — it uses
  `create_autospec` over CoreClient to check the dispatcher reaches the right
  method with the right keywords — and it mocks the client, so the URL never
  exists while it runs.

### Changed

- **Seven route modules became packages** (ADR 0049 decision 3), their queries
  having left for `services/` earlier. The largest file in `core/app/api/` goes
  from 1 327 lines to 564 — and that one, `greenops.py`, is next.

  | | before | after |
  |---|---|---|
  | `finops.py` | 1 327 | 6 modules, largest 466 |
  | `tenants.py` | 778 | 7 modules, largest 224 |
  | `reselling.py` | 678 | 7 modules, largest 182 |
  | `gateways.py` | 686 | 6 modules, largest 253 |
  | `audit.py` | 665 | 6 modules, largest 182 |
  | `sso.py` | 639 | 4 modules, largest 480 |
  | `pricing.py` | 624 | 4 modules, largest 431 |

  Two were split along an authentication boundary rather than a theme.
  `tenants` exports two routers because whoever follows an invitation link has
  no account yet; `gateways` separates what a person calls with a JWT from what
  a machine calls with its gateway token, which the file's own order did not —
  `/scan` sat next to `/ping` with opposite audiences.

- **`GatewayService.latest_gpu_utilisation`** — the last query in
  `api/v1/gateways.py` moved to the service, with the `is_org_uuid` guard its
  siblings carry. ADR 0049's budget drops to 16 files / 30 queries, and
  `test_tenancy_column`'s unguarded comparisons from 9 to 8.

### Removed

- **Three CI jobs that reported success without doing anything.** The Helm job
  in `deploy.yml` announced six deployments while gated on a `KUBECONFIG`
  secret that does not exist. Its `build-push` job rebuilt core, agent and
  console — the same three as `release-images.yml` — and pushed them as
  `0.54.2`, `0.54` and `sha-…`, amd64 only, unsigned, unscanned, pulled by
  nothing; three redundant image builds per release, and three more Docker Hub
  pulls against the ceiling that broke v0.54.3. And `update-install-repo` ran a
  `sed` for `VIBOPS_VERSION` in a published file that pins by digest and holds
  no such string: seven occurrences in the source, zero in the target, so it
  printed "No version change — skipping" and exited green at every release.

- Two dead constants in `reselling.py`, duplicated from `dataset.py`, which is
  the only module that uses them.

### CI

- `Release Docker Images` and `Deploy` accept `workflow_dispatch` with a tag
  input. Before, rebuilding a release meant deleting its tag and pushing it
  again — rewriting a published tag to recover from a transient failure.
- The Release step named `github.ref_name`, which on a dispatch is the branch.
  The v0.54.3 rebuild therefore created a tag `main` and a Release called
  "VibOps main". Both resolved through the version input now; the stray tag is
  deleted.

### Guards

Eleven widened or written, after six were found to have stopped measuring
while files moved. One had been green for hours seeing 52 of 77 modules — the
failure it exists to prevent, happening to itself. New in `tests/`:

- every `/api/v1/…` literal in the six surfaces is compared against
  `openapi.json` — this is what found the spend-trend defect;
- no image may be published by more than one workflow, and no external
  repository may receive writes from more than one;
- no guard may enumerate a source tree with a flat `glob`, and every source
  path a guard builds must exist.

### Tooling

- `scripts/check-route-split.sh before|after <module>` — the seven checks of a
  split, which refuse to pass. It found two defects in itself on first real
  use, one of them a false "name lost" caused by `comm` sorting by locale where
  python sorts by bytes.
- `.claude/agents/contre-epreuve.md` and `route-splitter.md`, and
  `docs/specs/SPEC_COUNTER_PROOF.md`.

---

## [0.54.3] — 2026-10-09

> **⚠ Tagged on 09/10, built on 10/10.** This version was tagged with no
> images: `Release Docker Images` failed on Docker Hub's anonymous pull limit —
> every Dockerfile starts `FROM python:3.11-slim`, and that workflow
> authenticates only to ghcr. Three releases in one evening, each firing seven
> workflows that pull `postgres`, `redis`, `caddy` and `python` anonymously,
> went past the 100-pulls-per-6-hours ceiling.
>
> **Resolved on 10/10/2026.** The six images exist for linux/amd64 and
> linux/arm64, `:latest` points at them, and `vibops.ai/install.sh` defaults to
> v0.54.3. Two workflows had to be fixed before it could be finished: neither
> could be re-run without re-pushing a published tag, and the Release step named
> the branch rather than the version — see v0.54.4.
>
> **Still open:** authenticating Docker Hub in CI. A free account doubles the
> allowance and counts per account rather than per shared runner IP. That needs
> `DOCKERHUB_USERNAME` and a read-only token in the repository secrets.

A patch, and most of its entries are the same defect in different places: a
thing that does not happen, or happens wrong, and does not say so.

### Fixed — `GET /api/v1/pipelines/templates` answered 422; the endpoint was unreachable

`/pipelines/{pipeline_id}` was declared before `/pipelines/templates`, and
FastAPI compiles `{pipeline_id}` to `(?P<pipeline_id>[^/]+)` **even when the
parameter is annotated `uuid.UUID`** — the annotation only adds Pydantic
validation, which runs after the route has already won. So `templates` was taken
for an id:

```
before: 422 {"type":"uuid_parsing","loc":["path","pipeline_id"]}
after:  200 {"items":[{"name":"deploy_vibops",...
```

`list_pipeline_templates` had existed, been importable, been testable as a
function, and been unreachable over HTTP. `docs/user-guide.md` tells clients to
call it.

Fixed with the convertor — `{pipeline_id:uuid}` — rather than by reordering,
because a convertor does not depend on declaration order, and reordering is what
traded one defect for the other in v0.53.0. Same on
`/pipelines/{pipeline_id:uuid}/trigger`, which would otherwise claim
`POST /pipelines/from-template/trigger`.

**Visible consequence:** `GET /api/v1/pipelines/not-a-uuid` now answers 404
rather than 422. A path matching no route is a 404; the 422 was the other route
claiming it and then rejecting the value.

### Fixed — an evaluation with no score was recorded as a zero

`eval_task` is the LLM-as-judge. `float(data.get("score", 0.0))` meant a judge
that returned a justification and omitted `score` had its row written
`status="completed", score=0.0` — the worst possible mark, indistinguishable
from a severe but considered judgement. The module's own docstring promises the
opposite: "we fall back to a text justification with score=null". The log line
did the same, writing `score=0.00` for an absent mark.

**Clients reading `job_evaluations.score` will see `null` where they saw `0.0`**
on those rows. A real 0.0 is still 0.0.

`criteria` was in the signature, passed by the caller, and never read, so the
criteria a rubric declares were compared with nothing. The judge's answer is not
corrected — rewriting a measurement is how it becomes a fiction — the mismatch
is logged, naming what is missing and what is extra.

### Fixed — a trigger that could not read its metric counted as one whose condition was false

`vibops.evaluate_triggers` runs every sixty seconds. Its summary said
`{"triggered": 0, "skipped": 12, "errors": 0}` whether twelve rules were quietly
in cooldown, Datadog was down for all twelve, or twelve cron expressions were
invalid and would never fire again. `skipped` was incremented at six places for
six unrelated reasons.

The summary now carries **`unavailable`**: `skipped` means "evaluated, and it
was not supposed to fire"; `unavailable` means "could not decide". A non-zero
`unavailable` says an automation may be switched off, without reading a log.
Additive — nothing in the product or the console consumed these keys.

### Fixed — eight columns promised a server default the database did not have

`_timestamps.updated_at_column()` declares `server_default=func.now()` and says
in a comment that "the migration writes DEFAULT now()". For `alert_rules`,
`budgets`, `cluster_rates`, `llm_backend_rates`, `memories`, `pricing_rules`,
`tool_policy_overrides` and `workloads` it did not, while the other twenty-one
tables carrying `updated_at` all had it. On a NOT NULL column that means an
insert omitting `updated_at` failed on those eight and succeeded elsewhere.

**Nothing could see it:** `alembic/env.py` does not set
`compare_server_default`, which defaults to False, so autogenerate never
compares server defaults in either direction. Migration `c4e8a1b06d92`.

### Fixed — the internal service key was checked in a route body, and one copy refused with 403

The shared `X-Internal-Key` check is copied five times under two names and had
drifted into three shapes: a router dependency (three modules), an endpoint
parameter (`audit`), and **a call inside the route body** (`llm_rates`). The
third is invisible to the dependency tree, so `test_endpoint_auth.py` — the ADR
0005 walker that exists to find exactly this — could not see it, and the next
route on that router would have inherited nothing. Moved to the router.

And `agent_model_rules` answered **403** where the other four answer 401 — same
message, same situation, a different code depending on where you knocked, and
contradicting its own line above returning 401 for an unconfigured key. For a
wrong shared secret the caller failed to authenticate: 401. Invisible to the
only caller, `llm-proxy`, which tests `== 200` and nothing else.

### Changed — two annotations that lied about their column

`notification_channels.id` and `cluster_resource_metrics.id` were annotated
`Mapped[uuid.UUID]` over `String(36)` with `default=lambda: str(uuid.uuid4())`,
so the value is a `str` and always was. SQLAlchemy takes the type from
`mapped_column(...)`, so the annotation was documentation nothing compared to
reality. Believing it cost an hour twice in the week of 06/10. Now `Mapped[str]`.

### Changed — CI measures the product's coverage, and `e2e.yml` targets a runner that exists

Both coverage jobs ran `--cov=.` from their package directory, counting `tests/`
as covered product: **85 % reported against 69 % real** on core, 77 % against
62 % on connectors. Floors moved 50 → 65 and 60, since a floor of 50 against a
real 69 allowed a nineteen-point regression in silence.

`e2e.yml` was pinned to `runs-on: self-hosted` with no runner registered, so a
dispatch queued indefinitely rather than failing. Now `ubuntu-latest` — the job
already did `npx playwright install chromium --with-deps`, and
`e2e-pipeline.yml` builds the same stack there on every tag. **Not verified by
execution:** a dispatch calls the real Anthropic API and may run two hours.

### Added — six guards, each verified against its broken form

- **which route wins**, asked of the routing table rather than of a client: the
  decisions written out, plus a derived sweep requiring every route to be
  reachable by a path its own pattern generates. 302 assertions.
- **the model and the database agree on defaults**, two directions: a declared
  `server_default` the database lacks is a hard failure; a Python-only default
  gets a budget of 48, with both sides of the ratchet.
- **the internal key is a dependency**, recognising the guard by what it does
  rather than by name, and asking every internal endpoint to refuse a missing
  key, a wrong key, and everything when none is configured — and to *stop*
  refusing with the right one.
- **coverage is scoped to the product**, and its floor is close enough to be one.
- **no workflow waits for a runner nobody has.**
- **an annotation does not promise a type the column lacks**, both directions.

### Measured, for the record

`app/api` raises `HTTPException` at **337** places and **290 (86 %)** had never
been reached by a test — of which 55 are refusals: 22 × 401, 20 × 403, 8 × 402.
A refusal no test has exercised is a door nobody has pushed on. By contrast,
**0 of 288 routes are never called**, so the layer is exercised and the gaps are
branches inside it. That is the next frontier; the internal-key family above is
the first of it.

Coverage: `app/workers` 58 % → 61 %, `app/api` 60 %, `app/` total 69 %.

---

## [0.54.2] — 2026-10-09

_Section added on 09/10/2026, after the tag. The command that was supposed to
insert this heading used `sed '0,/re/s///'`, a GNU range the macOS sed ignores
without a word, so v0.54.2 shipped with its entries still filed under
`[Unreleased]`. The silent no-op, in the tool used to document the silent
no-ops._

### Fixed — two worker paths opened a session with no tenant scope

Found by doing what ADR 0047 has been asking for: setting `APP_ROLE_PASSWORD` on
a real installation, so the application connects as `vibops_app` and the 47
policies actually apply. The worker broke immediately.

```
Unable to start gateway heartbeat:
  new row violates row-level security policy for table "gateways"
```

**`gateway_heartbeat`** is the only synchronous module under `workers/` — it runs
in a `threading.Thread` started by `worker_ready`, not in a Celery task, and
builds its own engine. Its ten sessions were bare `with Session(engine)`, so the
`after_begin` listener set `app.current_org_id` to the contextvar's default, the
empty string, which matches no policy branch. The insert was refused, the
heartbeat thread never started, and that worker collected **no GPU metrics at
all**.

**`job_tasks.on_log`** is quieter and worse. It built its own `sessionmaker` and
ran `UPDATE jobs SET logs = ...` with no scope: under the constrained role that
matches no branch and updates **zero rows**, inside an `except Exception:
logger.debug(...)` that is deliberately non-fatal. Jobs would run with empty
logs and nothing would say why.

`tenant_scope.system_sync_session(engine)` is the synchronous counterpart of
`system_session`, and both sites use it now. The scope is set before the session
opens — `after_begin` does not come round again — and inside the thread, since a
`threading.Thread` starts on a fresh context and inherits none.

### Changed — the background-scope guard now recognises synchronous sessions

`test_background_work_opens_a_scope.py` exists for precisely the class above and
had been green since 03/10/2026. Its three patterns enumerated only the
asynchronous spellings — `AsyncSession(`, `*factory()`, `async_sessionmaker(` —
and the one synchronous module in the directory matched none of them. A predicate
that enumerates the shapes it knows measures its own vocabulary, not the code.

Widened to `with Session(` and `sessionmaker(`, it immediately found the
`job_tasks` site too. `db_sync.py` is the single declared exception — it *is* the
helper — with a test asserting it still sets the scope it is exempted for.

The heartbeat tests were blind for a different reason: they drove every function
through an **owner** engine, so they passed under both CI passes while the
product was broken. They now take the app-role engine when
`VIBOPS_TEST_APP_ROLE=1`, with cleanup and read-backs deliberately kept on the
owner — a `DELETE FROM gateways` without a scope removes zero rows silently, and
an assertion reading through the constrained role would pass on nothing.

Verified against the broken form, which is the whole point: with the bare
sessions restored, the owner pass still reports 54 passed — the blindness itself
— while the app-role pass fails on `new row violates row-level security policy
for table "gpu_metrics_history"`, and the static guard names four lines of
`gateway_heartbeat.py` with no database at all.

### Changed — the pre-commit hook runs the core suite twice, as CI does

The hook ran it once, as the owner. It now runs the second pass as `vibops_app`
too. That gap let a commit through that CI refused: a test doing `ALTER TABLE
audit_logs DROP CONSTRAINT`, which demands table ownership. The hook printed
"Tests OK" over half of what CI checks.

Reinstall it (`cp scripts/pre-commit .git/hooks/pre-commit`) — an already
installed copy keeps the single pass. Costs about a minute more when `core/` is
staged.

---

## [0.54.1] — 2026-10-09

### Changed — the release builds six images instead of eight

`vibops-beat` and `vibops-gateway` entered the release matrix on 08/09/2026 and
were in every release from v0.41.1. Each was built for two architectures, signed
with cosign, scanned by Trivy, pushed under two tags — and pulled by nothing,
ever.

`vibops-beat` was redundant by construction: the published compose runs beat from
`vibops-core` with `command: ["beat"]`. And `vibops-gateway` is **not** the
gateway image — that is `vibops-connect`, which stays. Verified before removing:
no compose service, no chart and no Helm template names either of them.

From the per-image timings the workflow records, this returns **19 minutes of
runner time per release**, of which beat was 15 — it was the slowest image in the
matrix. At the wall, little: the matrix is parallel and `worker` at 14 min takes
beat's place. The tags already in the registry are untouched.

The v0.45.11 entry below had already found this — "private, and used by nothing
[…] worth removing, not done here".

`tests/test_the_release_builds_only_images_something_pulls.py` now holds the
correspondence in both directions. The second direction is why it earns a file:
an `image:` naming something no release builds is a customer's first
`docker compose up` ending on `manifest unknown`, and nothing else in the
repository could see it — the compose declares a tag and the registry is checked
by nobody at commit time.

It reads each compose service's `image:` key rather than grepping for
`vibops-`, which also matches the network `vibops-dev`, the container
`vibops-connect-heartbeat` and the secret `vibops-tls`; a scan counting those
would compare two different things and pass.

### Fixed — `grid_factors` had no row level security on any installation

ADR 0047 names 47 tenant-scoped tables. A migrated database had **46** under
policy. The odd one is `grid_factors`, which carries an `org_id` like the rest —
confirmed on a live published install and on a freshly migrated schema, same
answer both times. Its `updated_at` column had no touch trigger either, so every
row's value stayed frozen at insertion.

Both halves have the same cause. `app/models/_rls.py` and
`app/models/_timestamps.py` each install through **two** paths: a migration for a
real database, and an `after_create` listener for whatever
`Base.metadata.create_all` builds. The table was added to `RLS_TABLES` by the
GreenOps work, after migration `d9e0f1a2b3c4` had closed the set at "forty-six of
forty-six" — and the listener covered the gap in the only place anyone was
looking, because the test suite was built by `create_all`. The suite reported ADR
0047 satisfied on 47 tables for three weeks while no client enforced 47.

Migration `b2d7f3e91a08` installs the policy and the trigger. Verified upgrade,
downgrade and re-upgrade against an already-migrated database.

### Changed — the test suite builds its schema from the migrations

`pytest_configure` ran `Base.metadata.create_all`. It now runs
`alembic upgrade heads`. That costs **0.95 s**, measured, and it is the schema
clients actually have. The `grid_factors` finding above is what it turned up on
the first run; two more differences came with it.

**152 NOT NULL columns** carry a server default in a migrated database and none
under `create_all`. The models declare `default=`, which SQLAlchemy applies to an
ORM insert; the migrations declare `server_default=`, which the database applies
to any insert, raw SQL included. So every raw-SQL writer in the product was
untestable here — `gateway_heartbeat._upsert_gateway` names neither
`removed_clusters` nor the timestamps in its INSERT, works on every real
installation, and raised `NotNullViolation` in the suite. That module sat at 23 %
coverage for this reason.

The dangerous direction is the other one, and it is worth stating plainly: a
column with a Python-side `default=` and no `server_default` in its migration
**passes the suite through the ORM and fails in production on the first raw-SQL
insert**, and nothing here could see it.

`ck_audit_logs_org_id_shape` also did not exist in the old test schema, so a test
could insert an `audit_logs` row the production database refuses. Its intent was
right — migration `a7b8c9d0e1f4` adds that CHECK `NOT VALID`, so legacy non-uuid
rows remain and must stay readable — and its method was not. It now writes the
row the way production holds it, before the constraint, and a second test pins
the other half: the shape reads, it no longer writes.

`test_the_suite_runs_the_schema_clients_have.py` keeps this from being quietly
reverted by someone making the suite faster, since the listeners that hid all of
it are still in the models. Verified against the broken form: re-adding a
`create_all` call to conftest fails it by name. Its head check reads alembic's
own `ScriptDirectory` — a regex over the version files reported eleven heads
where `alembic heads` reports one, because `down_revision` is a tuple at every
merge and `None` at the root.

### Fixed — a GPU saturation with no notification channel was recorded nowhere

`_check_gpu_thresholds` read the notification channels and dispatched inline,
then wrote the Alert History **inside `if sent:`**. On an installation with no
channel configured — which is every fresh one — a GPU saturation therefore left
no trace at all: nothing delivered, nothing in the console's Alert History, and a
`log.debug` below the default level as the only sign. Measured, same metrics and
gateway: 0 rows in `alert_history` with no channel, 1 with a Slack channel.

It is the converse of the defect already fixed for the hypervisor half, whose
alerts "reached Slack and nowhere else". The history is the record of what the
platform observed; tying it to a delivery made it a record of what the platform
managed to send. The GPU half now does what the VM half does, in the same order —
record the cooldown, send, write the history with whatever channels accepted,
including none. The cooldown is recorded unconditionally, which is what keeps an
unconditional history write from becoming 2 880 rows a day at a 30-second
cadence.

The import guard that opened the function is gone too: it imported four senders
and returned if that failed, so an unimportable notification layer stopped the
thresholds being *evaluated*, not just delivered.

### Added — 52 tests for the heartbeat, the product's only GPU metric writer

`gateway_heartbeat.py` is the largest module under `app/workers/` and ran at
**23 %**; it is now at **58 %**, and worker coverage overall is 58 % against the
39 % it started the day at. Nothing else writes `gpu_metrics_history` or
`cluster_resource_metrics`, which `detect_anomalies`, `predict_gpu_health` and
every GPU chart read.

Against the real database, not mocks: the tenant on every row, both metric
writers, registration and its identity file, the Kubernetes quantity parsers,
the thresholds and their cooldown, and one turn of the loop including a
collection failure it has to survive.

Two things recorded rather than fixed, because both are decisions:

- **`GATEWAY_ORG_ID` decides which tenant every metric belongs to, and neither
  compose file sets it.** Unset, `_org_id()` returns the reserved system
  organisation and says so once — its own docstring is explicit that the figure
  "will appear in no customer report", and on the running standby the
  self-registered gateway is indeed under `00000000-…`. Set to an organisation
  *slug*, which is the natural thing to type, every write raises
  `InvalidTextRepresentation` into the writers' blanket `except`: 0 rows, one
  warning per attempt, every 30 s. The heartbeat's own `UPDATE` carries no
  `org_id`, so the gateway keeps pinging and the console shows it **online** with
  empty charts.
- **`_parse_memory` returns 0 for a quantity it cannot read**, and that 0 is
  stored as `memory_capacity_bytes` — "a measurement of a site that was never
  measured", the shape `gpu_metric.py` rejects in its own comment. kubectl always
  emits a suffix, which is why it has not bitten; `1e3` and `1.5` are valid
  Kubernetes quantities all the same.

---

## [0.54.0] — 2026-10-09

### Added — Docker Compose connects the role the policies apply to

ADR 0047 gives tenant isolation to PostgreSQL, and it works only if the
application connects as a role without `BYPASSRLS`. Helm has done that since the
ADR. **Compose did not**, so on that installation path the 47 policies enforced
nothing and the application's own 215 hand-written `org_id` filters were the
whole of the isolation. Measured, same query, six rows across two tenants:

| role | without scope | scope = tenant A |
|---|---|---|
| `vibops_app` | 0 | 3 |
| `vibops` | 6 | 6 |

The scope the application sets on every transaction had no effect at all.

The evidence was in hand rather than assumed: migration f5a6b7c8d9e0 already
creates `vibops_app` with SELECT/INSERT/UPDATE/DELETE on all 57 tables on
**every** installation, and the whole core suite passes under it. Only a
password and the right to log in were missing. ADR 0047 had even named the work
— "giving the entrypoint a second URL is the work that would close it".

`DATABASE_URL` stays the owner and the migrations keep it; `VIBOPS_APP_ROLE_URL`
is what the application connects with afterwards. Three decisions inside:

- **every mode grants, not only the one that migrates.** `worker` does not
  depend on `core` in the published compose, so a grant done by one container
  would be raced by the others. `ALTER ROLE … WITH LOGIN PASSWORD` is idempotent,
  so each does it for itself.
- **the grant verifies, then refuses.** A role that exists, can log in and is
  *also* exempt from the policies reads exactly like success — the application
  connects, every page works, nothing isolates. The script exits non-zero on
  `rolsuper` or `rolbypassrls`.
- **the fallback is loud.** An installation whose `.env` predates this keeps
  working on the owner, and both the entrypoint and core's startup posture
  warning say what that costs.

**Upgrading an existing Compose install:** generate `APP_ROLE_PASSWORD` in `.env`
— `openssl rand -hex 32` — and recreate the containers. Without it nothing
breaks and nothing isolates at the database level, and the logs say so on every
start.

### Fixed — five scheduled tasks raised `TypeError` on a log line

Two styles of logging live here and read identically at the call site:

```python
_log.info("anomaly.created", cluster=name, org=org_id)   # structlog
logger.info("Retention: %s rows removed", total)          # stdlib
```

`logging.Logger.info` accepts `exc_info`, `stack_info`, `stacklevel` and
`extra` — nothing else. The first line is therefore correct against
`app.logging_config.get_logger` and a crash against `logging.getLogger`, and
only the binding, forty lines up, says which one it got. Five modules got the
wrong one: eighteen calls, each reached under a different condition.

**`vibops.detect_anomalies`, every five minutes since 30/05/2026 — 132 days.**
The worst of the five, because of where the crash sits:

```python
evt = _create_event(...)       # db.add + db.flush
_notify_anomaly(db, evt)       # the client's Slack fires here
created_count += 1
_log.info("anomaly.created", type=..., cluster=..., org=...)   # TypeError
```

Measured, four idle samples on one cluster:

```
RAISED TypeError: Logger._log() got an unexpected keyword argument 'type'
anomaly_events rows in the database: 0
notifications dispatched:            ['gpu_idle']
```

The alert went out and the anomaly did not exist. `get_sync_db` rolled back, so
the row that deduplicates the next run went with it: five minutes later the
same condition was detected and alerted again, for as long as it held — 288
times a day, with nothing in the console to click on.

**`vibops.refresh_cloud_pricing`, daily since 14/06/2026 — 117 days.** The
faulty line sits before the loop, so the task raised on every run without ever
updating a rate. A cluster on `formula_type="cloud"` has been billed against
whatever price was stored the day it was configured. It now also returns its
summary, as the other fourteen scheduled tasks do; it counted `updated` and
`errors`, logged them and returned `None`.

**`vibops.predict_gpu_health`** (since 15/08/2026) and **`vibops.proactive_agent`**
(since 17/08/2026) crash only once there is something to report — the first as
soon as a GPU metric is under an hour old, the second as soon as it creates an
insight. An idle system looks healthy and breaks at the moment the work
matters. `cloud_pricing_service` replaces a pricing API error with a
`TypeError`.

One of those calls is a `.debug`. `Logger.debug` only builds the record when
DEBUG is enabled, so it is harmless at INFO and breaks the worker on the day
somebody raises the log level to investigate something else.

The fix is the binding in five files. Every call site was already written in
structlog's form, and `app/logging_config.py` has exposed `get_logger` all
along — `retention_task.py` uses it correctly.

### Added — four guards for the worker layer

Ten of the twenty-two modules under `app/workers/` were at **0 % coverage**:
631 statements no test had ever imported. Worker coverage is now 52 % against
39 % (+356 statements), but the number is the side effect. What the four guards
buy is that the classes are caught at suite time instead of at boot, or never.

- **Every scheduled task runs once against the real schema.** The cheapest test
  in the suite and the one that found the first two defects above. An empty
  database on purpose: "completes with nothing to do" was never established for
  ten of these modules. It truncates what a task wrote either side of each run —
  `generate_monthly_chargeback` writes one record per organisation, 54 of them.
- **Every stdlib logger call is checked against its binding.** One test per file
  over all 218 modules in `core/app`. Not a ruff rule: the call is valid Python
  and the binding is a valid logger, so only something that resolves one to the
  other can see the fault.
- **Every worker module imports, is in an `include` list, and every
  `beat_schedule` name resolves to a registered task.** A renamed task is
  scheduled, logged, and never runs.
- **A detected anomaly reaches the product.** Seven tests against the real
  database: the row exists afterwards, nothing is alerted that is not recorded,
  a second run neither re-opens nor re-alerts, two tenants' anomalies land one
  each.

Every guard was verified against its broken form, and two of those checks
corrected the guard rather than the product. The logger scan's first version
resolved only `logging.getLogger` and called nineteen correct call sites
unresolved — all of them `from app.logging_config import get_logger`. And the
scheduled-task probe, reread against a reintroduced `retention_task` defect,
stays green: those two lines sit in an error branch and in a loop that only runs
when rows were deleted. The two files answer different questions and neither
covers for the other.

The real-database choice is deliberate. `chargeback_task.py` sits at **100 %
coverage** with every database call replaced by a `MagicMock`, and a mock would
have accepted every one of these `_log.info` calls without a murmur — the way
one accepted a write to `hashed_password`, an attribute the model does not have,
on 07/10/2026.

### Fixed — a Datadog gateway could capture a job no agent would ever run

`datadog_gpu_task.py` has never run. Its own docstring calls it a "Celery beat
task … every 60 seconds" and [0.30.0] below announced it as shipped on
08/08/2026; it carries no `@celery_app.task`, sits in no `include` list, in no
`beat_schedule`, and nothing in the repository calls it.

That alone would be an unavailable feature. What makes it worse is that the
console offers it. `cmRegisterDatadog()` in
`console/static/js/modules/fleet.js` stores the client's `DATADOG_API_KEY`,
`DATADOG_APP_KEY` and `DATADOG_SITE` as secrets, registers a gateway with
`gateway_type: 'datadog'`, then sets `cmHvConnected = true` and advances the
wizard to its final step. So a client could enter real Datadog credentials and
be told the source was connected, while:

- `gpu_metrics_history` stayed empty, with no error anywhere;
- the fleet showed that gateway **offline**, because `is_online()` wants a
  recent ping and this gateway has nothing to ping with — the wizard said
  connected, the fleet said offline, and nothing reconciled the two;
- and the gateway counted as able to run jobs. `NON_EXECUTING_GATEWAY_TYPES`
  names the types with no Connect agent, which `_find_gateway_for_cluster`
  skips and the cluster-name uniqueness guard does not count. It listed
  `virtual` and `hypervisor` and not `datadog`. Measured: a job for `prod-gpu`
  was routed to the Datadog gateway, and a legitimate registration for the same
  cluster name got a 409.

The routing half is fixed — `datadog` joins that list — and it needed no Datadog
access at all, being wrong on its own terms. `gateway_type` is `String(32)` with
no CHECK and the API declares it `Field("kubernetes", max_length=32)` with no
enum, so nothing refused a type nobody serves; a new test now reads the gateway
types straight out of the console's own JavaScript and requires each one to name
what serves it, with the routing list and that inventory checked against each
other in both directions.

Its first version read `fleet.js` alone, found two of the three types, and
reported its own blind spot as "the registration calls have been rewritten".
`hypervisor` is registered from `wizard.js`.

### Changed — the wizard's Datadog entry is greyed out until something collects

The collector stays unwired, decided 09/10/2026: scheduling a path no test has
ever exercised, against a client's monitoring API every sixty seconds, is not an
improvement on not running it. So the console no longer offers it. The entry is
`disabled` and reads "coming soon", in the same style as the AWS, GCP and Azure
entries three blocks above it.

Disabled, not deleted. `cmRegisterDatadog()` and the step 2 form stay in place so
that re-enabling is removing an attribute rather than rewriting a form.

The guard runs both ways, and both directions had to. Offering it while nothing
collects is the state this corrects. The other is quieter and would be easier to
miss: once the collector *is* wired, a button still greyed out means the product
does the work and no client can ask for it.
`test_the_console_offers_datadog_only_if_it_collects.py` fails on either, and was
verified against both — re-enabling the button with the collector unwired fails
three tests, and adding the module to `include` with the button disabled fails
one.

"Wired" there means Celery would actually call it — a task decorator, an
`include` entry, or a scheduled name — not that the code exists. And the scan is
anchored on the `>Datadog<` label rather than a line number, in a 1 000-line
template where everything moves.

The v0.30.0 claim below stays wrong until the collector runs, and is left
standing with this note rather than rewritten.

### Fixed — HSTS pinned `localhost` for everyone who ran the stack locally

Core and the console both send `Strict-Transport-Security` with
`includeSubDomains` — two years from core, one from the console. That is right
for a domain and wrong for `localhost`, which is the same name on every machine:
one response from a stack running locally pins that developer's localhost, for
every other project they have and not only this one. **Core sent it
unconditionally**, not even behind the `app_env` gate the console had.

The symptom is why this is a fix rather than a note. Under an HSTS pin a
self-signed certificate stops being a warning you can click through — there is
no "continue anyway" button — so the page does not open and nothing says why.
The pin outlives the stack that set it.

The condition is the **host**, not the environment, and that distinction was
measured: the demo host runs `APP_ENV=development` and is served over TLS on a
real domain, so gating core on production would have taken its HSTS away. The
console keeps its production gate and gains the host condition on top. IP
addresses are excluded too — RFC 6797 §8.1.1 says a user agent must not note
HSTS for one.

Duplicated in both services rather than shared: the console and core import
nothing from one another, they speak HTTP. Each test exercises the middleware as
well as the predicate, because a correct predicate the middleware ignores would
pass every other assertion.

### Added — ask an installation whether it runs what it believes it runs

The demo host sat two releases behind — through v0.52.2, which fixed a live
cross-tenant leak — while `Deploy` went green on every tag. Its compose carried
the image tags **literally**, so `VIBOPS_VERSION` in its `.env` was decorative:
the documented upgrade ran in full, every container restarted, everything
reported healthy, and the images were the same ones. Nothing *reported* said so.

Two checks, for the two halves of that.

**What the repository publishes** —
`core/tests/test_the_published_compose_stays_upgradeable.py`. Every image must
read `${VIBOPS_VERSION}` and fall back to a release tag, never `latest`, and all
of them must name the same version.

**What an installation actually is** — `scripts/check-install-drift.sh`. Three
facts from three sources, and their divergence is the defect: what the `.env`
declares, what `docker compose config` resolves, what `docker compose ps` runs.
Exits 1 on any gap; local or over ssh.

Not scheduled yet, and that is a decision rather than an omission: remote
surveillance would need either the version on a public endpoint — which names
the target — or ssh access for CI. Recorded as open in `docs/harness.md`.

**The first version did not catch it.** It held the declared-versus-resolved
comparison inside the "the stack is running" branch, so on a stopped directory
it announced "the stack is not running" and never named the gap between a `.env`
at v0.53.3 and a compose at v0.53.1 — with both figures printed immediately
above. It reported something and missed the subject, which is the defect it
exists to find.

### Added — a local standby on the published images

`scripts/local-standby.sh` brings up the **published** stack on a workstation,
for the day a remote environment goes down during a demonstration. It runs the
artefacts a client receives, on seeded demo data: no real data and no
`BACKUP_PASSPHRASE` on the laptop, by decision.

Bringing it up for real found four defects in it, each only visible from a
browser, and they are the reason it exists:

- **the overlay appended instead of replacing.** Compose merges list fields, so
  without `!override` the standby's binding joined the published one rather than
  taking its place: postgres carried 5432 *and* 15432. The stack died on "bind:
  address already in use" after starting half its containers. **And the test
  passed on it**, because it compared the two files as *written* rather than as
  merged — a check that reads what you typed instead of what runs. It now
  asserts the merged result through `docker compose config`, and a second test
  refuses that check skipping unnoticed. It earned its place immediately: the
  compose check had reported a pass three times while silently skipping.
- **no TLS, so the session cookies never came back.** The console sets its
  cookies `Secure` as soon as `APP_ENV=production`, and the standby *is*
  production — that is the point of it. A browser never returns a `Secure`
  cookie over `http://`. Login answered 200 and `/auth/me` 401, the sign-in
  screen looping without a word. `APP_ENV=development` would have fixed the
  symptom and opened anonymous access; the standby gets `tls internal` instead.
- **a redirect to a port it did not publish.** Caddy redirects http to https
  *without* a port, so `http://localhost:8080` answered 308 to
  `https://localhost/` — port 443, which nothing published. It now publishes 80
  and 443, and only the interface differs from the published compose.
- **`127.0.0.1` declared as a site was worse than omitting it.** Caddy excludes
  it from certificate management, because a certificate validates a name and the
  internal authority issues none for a bare IP. The http site accepted the
  connection and redirected to an https that did not exist — a network failure
  with no message rather than a plain refusal.

### Added — `docs/production-readiness.md`, measured rather than asserted

What is actually ready for production and what is not, with figures rather than
adjectives. Its headline finding: **CI's 82.14 % coverage includes the test code
itself, and the product's own coverage is 65.1 %.**

---

## [0.53.3] — 2026-10-08

**Aucun changement produit.** Le code de la v0.53.2, republié avec un manifeste
`linux/arm64` en plus de `linux/amd64`.

### Added — les images sont publiées pour arm64 comme pour amd64

L'arm64 avait été retiré le 13/09/2026, au motif mesuré que personne ne tirait
ces images : le développement sur Apple Silicon compile nativement, la
production tourne sur x86. Ce motif a cessé d'être vrai.

`scripts/local-standby.sh` tient sur un poste de travail la pile **publiée**,
prête pour le jour où un environnement distant tombe pendant une démonstration.
Elle doit faire tourner les artefacts qu'un client reçoit — sinon elle prouve
que le code compile, pas que la release fonctionne. Sur un portable arm64, elle
s'arrêtait net :

```
no matching manifest for linux/arm64/v8 in the manifest list entries
```

`setup-qemu-action` arrive avec : ce workflow ne l'a jamais porté, et l'arm64
d'avant le 13/09 reposait sur les gestionnaires binfmt que l'image du runner
installe d'elle-même. Cela marchait, et c'était un appui sur un détail de l'hôte
que rien ne déclarait.

**Attendez une release nettement plus lente.** L'arm64 est compilé sous QEMU sur
un runner x86 — les runners ARM hébergés ne sont pas acquis sur un dépôt privé
de compte personnel. La v0.53.2 a pris 3 minutes en amd64 seul ; l'ancienne
ligne du workflow parlait de « l'essentiel des 54 min par release ». Le chiffre
réel de la première release qui porte cette ligne est à inscrire dans le
workflow plutôt qu'estimé.

---

## [0.53.2] — 2026-10-08

A tenancy release. One live cross-tenant leak, ten more sites of the same shape
found by scanning for it rather than waiting for the next report, and the rule
encoded so a twelfth fails a test instead of a measurement.

Written down as it happened rather than assembled at tag time, which is how the
ten 0.52.x releases came to have no entry at all.

### Fixed — one tenant's alert channels were served to, and used for, another's

`GET /api/v1/alerts/channels` called `ChannelService.list()` with no argument,
and an absent tenant meant **every** tenant. Measured over HTTP with two
organisations: an authenticated user of one received the other's channel name
and type.

`notify_alert_via_channels` reads through the same method, so this was not only
disclosure — **an alert raised under a tenant-less identity was delivered to
every tenant's Slack and webhooks**, and `CoreClient()` defaults to the agent's
service token, which carries `org_id: ""`.

Row level security hid it on one installation path and not the other, which is
why it survived. Helm connects `vibops_app`, where the policy on
`notification_channels` returns zero rows for an unscoped read; Docker Compose
connects `vibops`, a superuser the policy does not apply to at all. Measured on
the same call: 4 channels across two tenants against 0.

The tenant is required now and a falsy one yields nothing rather than
everything — fixed at the parameter, because five other callers pass
`org_id or None` and were one empty string from the same read. The empty case is
logged rather than silent.

### Fixed — ten more reads treated an absent tenant as every tenant

The same shape, ten more times, found by scanning for it rather than by waiting
for the next report. A method declares `org_id: str | None = None`, filters
under `if org_id:`, and so means "this organisation, or **every** organisation"
— while console callers pass `org_id or None` and the agent's service token
carries `org_id: ""`.

Four were listings — trigger rules, webhook subscriptions, jobs, pipelines. Each
requires the tenant now and yields nothing without one; the two that return a
total return `([], 0)`, because an empty page beside a real count reads as a
loading failure rather than as isolation.

The rest each needed a different decision:

- **the waste report** read every tenant's `accelerator_detect_waste` scans. One
  organisation's idle GPUs in another's dollar figure is not a disclosure a
  reader questions, because the number looks like a number;
- **the GitHub push handler** is legitimately cross-tenant — a push carries a
  repository and an HMAC, not a tenant — and its method says so in its name now.
  It also had an `org_id` parameter no caller ever passed: a parameter that
  silently widens the scope, waiting for the first caller to believe it scoped;
- **the bare-metal inventory injection** puts BMC hostnames into a job payload.
  That branch was already unreachable, and was closed anyway, because an
  unreachable widening is a widening waiting for a caller;
- **the audit chain**, where returning nothing would have been the *wrong*
  default: an absent predecessor means a second root, which is the fork ADR 0050
  exists to prevent. A tenant-less row is filed under the reserved organisation,
  so the chain read and the lock now name that organisation too.

The two reads that genuinely cross tenants are named for it, so neither is
reachable by leaving an argument out, and the rule is held by a test rather than
by anyone remembering it.

**If you run Docker Compose, the database enforces no tenant isolation at all.**
That is ADR 0047's known limitation, measured again here: core connects as the
`vibops` superuser, the policies do not apply to it, and the same query returns
6 rows across two tenants where Helm's `vibops_app` returns 0. The hand-written
filters in the application are what stands in its place on that path — which is
why these ten were worth finding before someone else found them.

### Fixed — the test suite's own connection pool reached across event loops

`test_the_agent_can_write_an_audit_row` failed in four CI runs between 07/10 and
08/10 and passed in the others, always with `attached to a different loop`, and
the suite was green locally every time — so the colour was read as noise. It was
not. pytest-asyncio gives each test its own event loop, and `app.database.engine`
is a pooled module-level singleton unlike every engine `conftest.py` creates, so
a connection checked out by one test was handed to the next on a loop that no
longer existed. Every handler opening its own session instead of taking `get_db`
was exposed.

The application is unaffected, which was measured rather than presumed: uvicorn
runs one loop for the life of the process, and the Celery tasks that do open a
loop per task go through the synchronous `get_sync_db`, NullPool and disposed per
call. Had they used the async writer, `log_action` would have swallowed the error
and audit rows would have gone missing in silence.

### Fixed — the install smoke's uninstall assertion was a day older than the product

It asserted that exactly **one** PVC survives `helm uninstall`, measured on OVH
on 02/10 and true that day. ADR 0048 landed on 03/10 and added `vibops-backups`
with `helm.sh/resource-policy: keep`, plus the `vibops-backup-key` secret — both
surviving deliberately. The gate was therefore red on every release from v0.52.1
to v0.53.1, ten in a row, announcing "2 PVC" about a product behaving correctly.

The two volumes are now named rather than counted — a count says "2" and would
pass if the database volume vanished while a third appeared — and the backup key
is checked too.

### Changed — ADR 0049's figures, and three of them were wrong

The named perimeter is complete: of the ten files it listed, six hold no SQL,
`auth.py` was exempt in writing from the start, and three hold one or two
queries, which the ADR calls not debt. Re-measuring the 03/10 tree corrected
three published numbers — the one-or-two-query count (twelve, not twenty-seven),
"route functions" (411 counts every function in `api/`; the routes are 286), and
the starting point itself (46 files and 274 queries under a predicate that counts
`scalars`, `stream`, `stream_scalars` and `db.get`, against the 45 and 260 the
ADR opened with).

---

## [0.53.1] — 2026-10-08

### Fixed — v0.53.0 traded one broken approval route for the other

v0.53.0 made the admin approve/reject endpoints reachable by mounting the
public router last. The reasoning behind it was wrong in a way the tests did
not catch: Starlette's `uuid` convertor does restrict path matching, but
FastAPI does not use it for a `uuid.UUID`-annotated parameter — `{gate_id}`
compiles to `(?P<gate_id>[^/]+)` and the annotation only adds Pydantic
validation, which runs *after* the route has already won.

So the admin route then matched token-shaped segments too, and the emailed
approve/reject links answered 422 `uuid_parsing`. Measured on the demo host
right after the upgrade, which is where it was caught.

The paths are written `{gate_id:uuid}` now. Both conditions are needed and
only one was understood before: the convertor stops a token reaching the admin
route, and the mount order stops a `gate_id` reaching the broader `{token}` —
the two paths are not disjoint, one contains the other.

`test_approval_gate.py` asks the routing table with both shapes of segment
rather than asserting registration order. The order test it replaces passed
while encoding the wrong model, which is the whole reason this needed a second
release.

---

## [0.53.0] — 2026-10-08

ADR 0049 reaches the floor it set: the route layer went from 46 files holding
274 queries on 03/10 to 17 files holding 31, of which `auth.py` is excluded by
the ADR and the rest hold one or two — which the ADR calls not debt.

The starting figure is not the one the ADR opened with. It published 45 and 260,
counting only `db.execute(` and `session.execute(`, and that missed queries run
through `scalars`, `stream`, `stream_scalars` and `db.get` — including every
query in `approvals.py`, which is why that file had never appeared in any count.
Re-measured on the 03/10 tree with the corrected predicate, both ends of the
comparison use the same definition.

Eight live defects were found by the method rather than by a user, and each is
the reason this release exists. Every one of them was found the same way:
moving a query into a service, then neutering the service method and checking
whether anything noticed.

### Fixed — approving a destructive action from the console

`approvals.router` and `approvals.auth_router` both declared
`/approvals/{x}/approve` — a callback token in one, a `gate_id` in the other —
and FastAPI resolves in registration order. The public router came first, so it
captured every path and both admin endpoints were unreachable. The console
calls the `gate_id` form, so it received "Invalid or expired approval token"
for a gate it owned: **approving from the console never worked**, and only the
emailed link could release a job awaiting approval.

The public router is now mounted after the protected one. Nothing breaks and no
URL changes, because Starlette's `uuid` convertor only matches uuid-shaped
segments and a `token_urlsafe(32)` never is.

### Fixed — SSO and LDAP login on a Helm install

The OIDC callback resolves a user in order to learn which tenant they belong
to, so nothing has set `app.current_org_id` when it reads. Under ADR 0047 that
transaction matches no branch of the policy on `users` and reads zero rows.
Measured as `vibops_app`: the callback found no existing SSO user, tried to
create one, hit the unique constraint, re-read zero rows and answered 500. A
genuinely first login got past the insert and failed the other way. `ldap.py`
calls the same two helpers, so LDAP login carried it too. Invisible on Docker
Compose, where core connects as a superuser.

### Fixed — the VM GPU collector never got its SSH key

`workers/workload_tasks.py` imported a name `secret_service` has never
defined, inside a function, inside a blanket `except Exception`. The
ImportError became one log line and a `None`, so every gateway configured with
`vm_gpu_config.ssh_key_secret` collected nothing while reporting success.

### Fixed — three delete previews answered 500

`alert_rules.py`, `providers.py` and `webhooks.py` each named fields their
model does not have, so every delete without `?confirmed=true` raised
AttributeError — under a convention whose whole point is to make a destructive
action safe rather than broken, and the console sends no flag.

### Fixed — the agent dependency graph lost call counts

`record_dependency` incremented `call_count` in Python. Nine recordings of one
edge, eight concurrent, left it at 3. One `INSERT … ON CONFLICT DO UPDATE` now.

### Fixed — vLLM on ROCm was an unknown framework

The image table was written from an NVIDIA deployment's images. `rocm/vllm` and
`rocm/pytorch` are recognised now, with the vLLM version pulled out of AMD's
composite tag.

### Fixed — the rubric delete warning named the lesser consequence

Deleting an eval rubric deletes every evaluation ever scored with it
(`ON DELETE CASCADE`), and the warning mentioned only future ones.

### Fixed — a reachable import of a module that does not exist

`v1/finops.py` imported `app.models.finops_pricing`, which has never existed,
in the reseller-margin branch of the VM chargeback calculation — a 500 for any
reseller customer generating one.

### Added — four guards for the classes of defect above

- `test_every_internal_import_names_a_real_module.py` — every `from app.… import …`
  in `core/app` names a module **and a name** that exists. The second half found
  the SSH-key defect the day it was written.
- `test_every_dry_run_preview_describes_a_real_object.py` — every confirmation
  gate's preview reads only fields its model has. Found the third occurrence on
  its first run.
- `test_every_table_is_cleaned_between_tests.py` — conftest's cleanup list is
  compared against `Base.metadata`. Seven tables were leaking rows between
  tests, found one at a time over a week; this found the last seven at once.
- `test_pre_tenant_lookups_are_scoped.py` extended from `auth.py` to every
  file, and its ordering predicate taught to recognise a service call as a
  query — ADR 0049 had made it blind.

### Changed — the ADR 0049 budgets measure what they claim

Both predicates enumerated the SQLAlchemy methods they knew. `db.get()` was not
among them, so eight queries and two whole files were uncounted; `scalar`,
`scalars`, `stream` and `stream_scalars` had been missing before that. The file
budget rose once, from 17 to 19, to tell the truth about a count that was never
17.

---

## [0.52.9] — 2026-10-06

### Added — ADR 0049 begins: `v1/jobs.py` holds no SQL

Its eight queries moved to `JobService`, `ClusterRateService` and a new
`OrgPolicyService`, and the three helpers four other route modules imported
*from it* moved to `app/policy/`. A route module had been serving as a shared
library, reached through imports written inside function bodies to dodge the
import cycle.

The ratchet in `core/tests/test_the_route_layer_does_not_grow.py` gained a
second budget here. The file count alone cannot see partial progress — a file
losing 25 of its 26 queries does not move it — so the query count is held too.

### Fixed — `portability_check` answered "NVIDIA only" about portable workloads

A tool whose purpose is to say whether a workload can move declined to know.
Measured 06/10/2026: `framework=jax` and `framework=onnxruntime` both returned
`portable_to: ['nvidia']` with a significant migration cost. Both are portable,
and the verdict was wrong in the direction that costs the most — it argues
against moving off NVIDIA, which is the decision the tool exists to inform.

### Fixed — asked to deploy on AMD, the platform wrote `nvidia.com/gpu`

Measured on the OVH gra11 cluster, the same call with `vendor="amd"` produced
`{"limits": {"nvidia.com/gpu": "1"}}`. The scheduler confirms the corrected
form, which asks for `amd.com/gpu`.

### Fixed — `helm_diff` reported "no difference" on a comparison that never ran

It answered `success=True` and reported no differences when helm-diff was not
installed. helm-diff is a plugin, not part of helm, and helm's refusal reads
`Error: unknown command "diff" for "helm"` — which contains no occurrence of the
word the guard was looking for. **An operator runs a diff precisely to learn
what an upgrade will change, and being told "nothing" invites the upgrade.** The
connector now says `No comparison was made: the helm-diff plugin is not
installed.`

The verdict no longer comes off the exit status either: the old comment claimed
exit 1 when differences exist, and exit 0 with differences present was measured
— that convention only applies under `--detailed-exitcode`. The connector now
distinguishes "a comparison was produced" from "the command could not run",
which holds under either.

`helm_get_release` never reported a chart, for any release, on any cluster: it
read `chart.metadata.version` off `helm status -o json`, which does not carry it
at that path.

Both were found by running the connector against a real cluster (OVH gra11,
helm 3.22.0, the version the Connect gateway runs) rather than against mocks.
The nineteen mocked tests passed throughout: a fake subprocess returns whatever
shape the code asks of it.

---

## [0.52.8] — 2026-10-05

### Fixed — the fleet reported neither its GPU model nor its real usage

Measured on a Scaleway Kapsule carrying two NVIDIA L4 while a Whisper workload
held 926 MiB of VRAM on one of them, the console received:

    gpu_total=2   gpu_used=0   gpu_model=''

**`gpu_used` was hard-coded to zero**, with a comment accepting it: computing it
looked like it required the full pod JSON every cycle. GPU usage therefore read
0 % on every real cluster whatever was running on it — while the demo fixtures
showed a figure, so the real card looked like the only idle one. That is the
worst shape a number can take: plausible enough to be read as a measurement,
which is why nobody reported it. It is read with `custom-columns` now, one line
per pod instead of the whole JSON, and summed across all three vendors.

**`gpu_model` was never populated.** Connect counted allocatable cards without
reading the label `gpu-feature-discovery` already places in the same node JSON,
so the console showed "2" and nothing else, while all eighteen reference sites
in the demo set carried a model — an operator could conclude their real fleet
was less well seen than the fixtures.

---

## [0.52.7] — 2026-10-05

### Fixed — GPU memory was read in bytes where DCGM reports MiB

`DCGM_FI_DEV_FB_USED` and `FB_FREE` are MiB. The code divided by 1024³ as
though they were bytes, so 926 MiB became 0.0000009 GB and displayed `0.0GB`.
**A card holding 20 GB announced zero.**

Nothing flagged it, because utilisation, temperature and power were correct
right beside it: a reader saw three credible figures and a fourth at zero,
which reads as "this card has nothing in memory". `nvidia-smi` said 926 MiB,
DCGM said `FB_USED 926`, and the product said 0.0 GB, at the same instant on
the same L4.

`mem_total` was never populated either — DCGM does not emit that field, so
capacity was always `None`. It is derived now, used plus free, giving 22 563 MiB
for an L4. The product displays `0.9GB / 22.03GB` where it wrote `0.0GB`.

No test covered the unit. 6 751 connector tests were green and the figure had
been wrong from the start.

**This release closes a chain of six.** v0.52.2 through v0.52.7 are one
investigation into why GPU measurement did not work on a managed Kubernetes,
each step found by publishing the previous one and testing it against real
hardware. Two of the six were regressions of the fix before them. What made the
chain long is that mocked tests stayed green at every step: the measurement had
to be taken on a cluster to be taken at all.

---

## [0.52.6] — 2026-10-05

### Fixed — a jsonpath carrying a real newline, which kubectl refuses

The multi-node fix in v0.52.5 listed exporters with
`jsonpath={range .items[*]}…{"\n"}{end}` and the escaping was lost on the way,
so the command carried an actual line break inside a quoted string. kubectl
answers `unterminated quoted string`, and **all** GPU measurement fell over —
including what v0.52.5 had just repaired.

The list is read with `-o json` now. JSON has no escaping to lose, and the
per-node filter happens in Python rather than inside an expression that three
layers of quoting have to survive.

The lesson is about the tests, not the jsonpath: the connector mocks recognise
a command by substring, so a malformed command passes them without a word.
`test_no_kubectl_argument_carries_a_raw_newline` reads the source with `ast` and
refuses a literal argument containing a line break.

---

## [0.52.5] — 2026-10-05

### Fixed — DCGM read only every other GPU node, at random

`dcgm-exporter` is a DaemonSet behind a ClusterIP Service: reading the Service
routes to **one** pod, picked by load balancing. Measured on a two-L4 Scaleway
cluster, six calls alternated between the two pods unpredictably.

`accelerator_get_metrics` therefore returned half the fleet, at random and
without saying so, and a per-node filter returned nothing one time in two. A
fleet measurement covering part of the fleet is worse than no measurement: it
looks like an answer.

Each exporter pod is queried individually now, through `pods/proxy` read access
— a distinct RBAC resource granted in the chart's read block. The index key
became `node:gpu`, because `gpu="N"` collapsed one card into the other on
merge: on that cluster both GPUs are `gpu="0"`.

---

## [0.52.4] — 2026-10-05

### Fixed — DCGM is read through the API server's proxy, not a port-forward

The root of the day's chain, found by walking back through three fixes that
were hiding it. On the Scaleway Kapsule, the gateway's own credentials answer
`no` to `create pods/portforward` and `yes` to `get pods`, so the tunnel died
immediately on a permissions refusal.

That right must **not** be granted: the chart documents what it refuses so a
gateway cannot become a pivot, and a tunnel to any pod in the cluster is in
that category. The correct path already existed and was already allowed —
`services/proxy` read access, added on 30/09/2026 for power collection.

---

## [0.52.3] — 2026-10-05

### Fixed — `accelerator_diagnose` neutered its own namespace discovery

Found by verifying v0.52.2 in the field, which required having published it. On
the same cluster in the same minute, DCGM collection reported the operator
present in `kube-system` while `accelerator_diagnose` announced
"GPU Operator Not Installed · CRITICAL".

The cause was in the previous fix. `diagnose` resolved the namespace *before*
calling the health check, with the `gpu-operator` default, and passed it
explicitly — which triggers the "namespace requested" branch, the one that
obeys without looking. **A default resolved too early becomes an order.**

Two messages also named a pre-resolved namespace, including the
`kubectl describe pod -n …` line of the remediation. A remediation naming the
wrong place does not copy-paste, and that is all an operator does with it.

---

## [0.52.2] — 2026-10-05

### Fixed — `dcgm-exporter` is looked for where it runs, not where it is expected

`gpu-operator` is the conventional namespace, the one a manual install of the
NVIDIA chart chooses. A managed Kubernetes installs the operator itself,
wherever it likes: creating an L4 pool on a Scaleway Kapsule puts
`nvidia-gpu-operator` in `kube-system`. Everything ran, and the connector
answered `No Running dcgm-exporter pod found in 'gpu-operator'`.

That is the worst shape an answer can take — wrong, and looking like
information. An operator reads it as "DCGM is not installed" and goes to
install a second one on top of a driver already present, which is a known way
to break a GPU node. The agent attempted exactly that; the install failed on a
CRD the first operator had already created.

`accelerator_get_metrics` and `accelerator_detect_waste` — so all waste
detection — were unusable on any managed Kubernetes that preinstalls the
operator.

### Fixed — the nine accelerator tools could not say which cluster to look at

Measured on the demo host with a real Scaleway L4 in the fleet: the same
question three minutes apart answered "No NVIDIA accelerator devices detected"
when routed to no gateway, and `1 × NVIDIA L4, 22.5 GB` when routed to one.

---

## [0.52.1] — 2026-10-04

### Fixed — every tool call the agent made went unaudited

**44 calls out of 44 to `POST /api/v1/audit/ingest` returned 500**, and not one
row in the table carried `source = 'agent'`. `AuditIngest.org_id` is typed
`uuid.UUID`, so pydantic hands over a UUID object, and the signature is a
`"|".join` of text: `TypeError: sequence item 5: expected str instance, UUID
found`. The agent's client swallows the error so as never to block a user, so
the agent answered perfectly while the audit trail — the product's whole
argument for trust — received nothing from it.

`POST /api/v1/training/exchanges` had returned 500 since 21/09/2026 for the
same class of reason: the agent calls with a service identity carrying no
organisation, and an empty `org_id` reaching a `uuid` column makes the driver
raise.

Found by reading the demo host's logs after a rehearsal. No test called
`/audit/ingest` — the only endpoint through which the agent writes to the trail.

### Fixed — `helm install --wait` never finished on a managed StorageClass

The backup PVC added in v0.52.0 stayed `Pending`. Most managed StorageClasses
bind on `WaitForFirstConsumer`, provisioning the volume only when a pod that
mounts it is scheduled — and the only consumer was the 02:30 CronJob. Helm
waits for every PVC to be `Bound` with no way to exempt one.

### Fixed — the `POST /jobs` throughput gate was a latency SLO in disguise

`SLO Tests (perf)` failed at 22.6 req/s against 25 required, while p50 was
315 ms and p99 907 ms against budgets of 500 and 1 500. The product was meeting
its published SLO and failing on a figure derived from it: at fixed concurrency,
throughput ≈ concurrency ÷ mean latency, so demanding 25 req/s over 10
concurrent requests imposes a 400 ms mean — a harder promise than the
`p50 < 500 ms` written on the same line.

---

## [0.52.0] — 2026-10-04

### Added — backups, on both installation paths (ADR 0048)

The chart deployed a database and nothing dumped it. `postgresql.enabled: true`
is the default and the path Option C of the installation guide walks through:
it brought a StatefulSet, a 20 Gi volume and no backup at all — no CronJob, no
`pg_dump`, nowhere to put one. Nothing failed and no install reported anything.
A customer would have found out on the day they needed a restore.

Both paths now dump nightly, encrypt with AES-256-CBC and PBKDF2 at 600 000
iterations, keep 30 days, and can copy off the host or cluster. Four decisions
are worth naming because each closes a gap the previous step opened:

- **the cleartext dump is never written to a disk.** The first encryption
  commit had one container writing the plain archive to the backup volume and
  the next encrypting it and deleting it. An unlinked file is not an erased
  file: its blocks stay readable until something overwrites them, and a stolen
  disk is precisely the threat the encryption exists for;
- **a failed dump must not expire the good ones.** Retention ran
  unconditionally, so a dump failing every night with a working retention is a
  volume that drains — on the thirty-first day nothing is left, and every step
  did exactly what it was told;
- **the off-host copy came before the encryption**, which made the exposure
  worse before anything closed it — the clear dumps then existed in two places,
  one of them an object store at a provider;
- **the restore procedure was typed out literally, on both paths.** It failed
  four times, each time on a command that cannot run in the context the document
  puts you in — the workstation pod had no key, so `openssl` could reach the
  archive and the database and not decrypt.

### Added — licence issuance is a command with a registry

`make licence CUSTOMER=… PLAN=… DAYS=…` replaces a script named only in a
runbook. Every issuance appends a line to `~/.vibops/licences.csv`, because
nothing anywhere knew who held what or until when: offline verification is the
assumed price of having no licence server, but nothing renews by itself, and an
expiry was discovered when the customer called.

### Fixed — the audit chain forked under concurrency (ADR 0050)

Found by rehearsing the AMD demo, whose closing prompt asks the product to
verify its own audit trail. It answered `"verified": false` at row 181,
`prev_hmac mismatch`. Two rows written 0.9 ms apart carried the **same**
`prev_hmac` — siblings, not a sequence — leaving the first one's signature
orphaned. A second fork followed 0.7 ms later the same day. Of 364 signed rows,
360 distinct predecessors.

**`FOR UPDATE` prevented nothing, and the comment asserting otherwise is what
stopped anyone looking.** It locks the row returned; it does not stop a
concurrent INSERT making the answer false. That is a phantom, which READ
COMMITTED permits by construction. An advisory lock per organisation does stop
it, and costs nothing: two tenants have no reason to wait for each other.

### Fixed — ten background tasks read zero rows and reported success

Under ADR 0047, a transaction that has not set `app.current_org_id` matches no
branch of the policies and reads nothing. For a user request that is the
protection working. For a background task it is a silent defect: the task runs,
processes nothing, and exits successfully.

Ten call sites across seven worker files opened `AsyncSession(engine)` by hand,
outside the helper that sets the scope — `briefing`, `datadog_gpu`,
`discovery`, `job_tasks` (three), `pipeline`, `trigger` and `workload` (two).

### Fixed — eleven subprocesses could wait forever

The connectors launch kubectl, helm, git, nvidia-smi, rocm-smi. If one does not
return — a severed cluster API, a stuck `helm upgrade`, a frozen GPU driver —
`await proc.communicate()` has no reason to come back, and the Celery task
waiting on it is lost in silence until the worker restarts. Two launchers out of
twelve bounded anything — `git`, always, and `kubectl` on two of its four calls.

Eleven sites are bounded now, through a common launcher. **helm derives its
bound from its own `--timeout`**: a `helm upgrade --wait --timeout 5m0s`
legitimately takes five minutes, and a fixed two-minute bound would have killed
it while it was still working. The bounds set by analogy rather than by
measurement were raised from 120 to 600 seconds in the same release — a generous
bound still prevents the hang; a tight one turns slow but valid work into
failure.

---

## [0.51.3] — 2026-10-02

### Added — the client guide is produced by the repository, not by hand

`scripts/declutter.py` and `scripts/build.py` turn `docs/installation.md` into
the document a prospect receives: the archaeology removed, the instructions kept,
rendered as a standalone page with the version `helm/vibops/Chart.yaml` declares.
They lived in a scratch directory until now, which meant the next release would
have had to reinvent them.

Every removal is anchored on an exact passage and fails loudly when the manual
moves under it, rather than silently dropping something else.
`tests/test_client_guide_can_be_produced.py` runs the chain in every suite, so a
broken anchor — or a newly added paragraph naming a test file, a source path or
an ADR — surfaces then instead of on the day of delivery. Both failure modes were
verified against a doctored manual.

The chain reproduces the delivered v0.51.2 document byte for byte.

### Fixed — `Deploy` reported six deployments it never made

Its `Helm Deploy` job guarded every step with
`if: steps.cluster.outputs.available == 'true'`, and that flag was `false`
because no `KUBECONFIG` secret is set. Every step was skipped — and the job
exited **successful**.

So the workflow announced six successful deployments (v0.49.8, v0.49.9, v0.50.0,
v0.51.0, v0.51.1, v0.51.2) while the demonstration host stayed on v0.49.2, with a
`beat` container marked `unhealthy` that v0.51.0 had fixed. Nobody had a reason to
look: the column was green.

The job is now gated on an upstream job's output, so it is **skipped** (grey)
rather than successful, and that job posts a warning annotation and a run summary
saying no deployment took place and that the host is a Docker Compose machine
updated by hand. `tests/test_deploy_does_not_claim_what_it_skipped.py` fails if a
step goes back to guarding itself, or if the absence stops being announced.

`docs/runbooks/update-the-demo-host.md` writes the manual procedure down —
including the host's deliberate differences from the published Compose file, which
a wholesale copy would destroy: the `./static` mount its Caddyfile serves
`/whisper` from, and the separate container that forwards `127.0.0.1:8000`.

The host now runs v0.51.2: served version `0.51.2`, all fourteen containers
`healthy` (`beat` included), 41 gateways / 3 organisations / 4 users unchanged,
and 200 from the internet. The release carried no migration, so the database was
untouched.

### Verified — `install.sh --domain` obtains a real Let's Encrypt certificate

Run on an amd64 host, with the Caddyfile the script generates:

```
served key authentication  challenge=http-01  (four Let's Encrypt validators)
authorization finalized    authz_status=valid
certificate obtained successfully   issuer=acme-v02.api.letsencrypt.org-directory

issuer=C=US, O=Let's Encrypt, CN=YE2     notAfter=Dec 31 12:50:32 2026 GMT
HTTP → 308 to https://<name>/
```

Recreating the container against the same `caddy_data` volume produced **no new
ACME order** and served the same certificate — the reason that volume exists, and
why dropping it would eventually hit Let's Encrypt's five-identical-per-week
limit.

Two things the run taught that the manual did not say:

- **"Ports 80 and 443 reachable" includes the provider's firewall.** On that host
  `ufw` was inactive, `INPUT` was `ACCEPT`, Caddy was listening — and from the
  internet the port timed out, because a cloud firewall in front of the server
  admitted only Cloudflare. ACME then hangs with nothing to read. There is no way
  around inbound 80: TLS-ALPN-01 needs 443 and DNS-01 needs a plugin
  `caddy:2-alpine` does not carry.
- **A Hetzner server's default reverse DNS is a usable name.**
  `static.<reversed-ip>.clients.your-server.de` resolves forward to the server, so
  no DNS change is needed to test HTTPS. The certificate above was issued for one.

### Fixed — `install.sh` adopted a VibOps install that lived elsewhere on the host

The Compose file fixes its container names, so two installations cannot coexist on
one machine whatever `--dir` says — and Compose derives its project name from the
directory name, so a `--dir` ending in `vibops` lands on the same project as an
existing install and **recreates its containers** with the new configuration.

Found by doing it: `--dir /root/essai/vibops` adopted the stack in `/opt/vibops`,
recreated its Caddy, and stopped on `Bind for 127.0.0.1:8000 failed: port is
already allocated`. The repository had anticipated re-runs — an existing
`docker-compose.yml` or `Caddyfile` is kept — but not the neighbour case, which is
the one where something is lost.

The script now reads the existing container's
`com.docker.compose.project.working_dir`, refuses when it differs from the target,
names that directory and the three ways forward, and stops before downloading
anything. Re-running in the same directory stays allowed, because repairing an
install that way is documented.

### Added — `install.sh --domain` is now checked against Caddy itself

The last documented path nobody had exercised. `caddy adapt` is run on the
generated Caddyfile, in the image the deployment uses, and
`tests/test_install_sh_serves_https_for_a_domain.py` fails unless a domain
produces `listen: [":443"]` with a host-matching rule — the pair that turns
Caddy's automatic HTTPS on — unless `:80` produces no 443, and unless the Compose
file publishes both ports and keeps `caddy_data:/data`. Each check was verified
against the broken shape it exists to catch.

That volume matters more than it looks: without it Caddy re-requests a
certificate on every container recreation, and Let's Encrypt allows five
identical certificates per week — so the failure arrives later, on an install
that used to work.

Also documented: "the DNS record points to this machine" excludes a record
proxied through Cloudflare, where the name resolves to Cloudflare and the
certificate a browser sees is Cloudflare's — `--domain` then buys nothing. That
is the configuration `vibops.ai`'s own demo runs, legitimately, on `:80`.

**Not verified**: Caddy obtaining a real certificate. That needs a public name
pointing at a reachable machine and a machine free to take ports 80 and 443. The
equivalent chain was verified end to end on the Kubernetes path on 01/10/2026,
through cert-manager rather than Caddy.

### Fixed — the air-gapped delivery archive could not install anywhere

`scripts/package-delivery.sh` had never been run. It rebuilt three images from
source and named them `ghcr.io/<owner>/<component>:<version>`, while the chart
shipped in the same archive references
`ghcr.io/<owner>/vibops-<component>:v<version>` — neither the name nor the tag
matched. `postgres`, `redis` and the `vibops-connect` chart were absent. The
README told the operator to retag an image that does not exist after
`docker load`. The example values set `core.secret.authUsername` (removed from
the chart on 01/10/2026) and `postgresql.auth.password` (never declared — the
password is generated and preserved), both silently ignored, and asked for a
**bcrypt** hash where the product reads scrypt.

An air-gapped site has no recourse: what is missing is missing for good, and it
surfaces as `ImagePullBackOff` on a cluster that cannot go and fetch the image.

The script now asks the two charts which images they deploy — so the list cannot
drift from what the charts reference — pulls each one for `linux/amd64`, checks
the architecture of every one, and refuses to finish if an image a chart
references is not in the archive. It ships the **published** images rather than
rebuilding, for three reasons and the first settles it: the chart's own Kyverno
policy refuses an unsigned `vibops-*` image, a rebuild is not what CI tested, and
the published images are amd64 only — a rebuild on an arm64 machine produces
tarballs the client's nodes cannot execute.

The archive now carries a generated `load-images.sh` (so no name is ever written
by hand twice), `images.txt`, both charts, `SHA256SUMS`, and example values that
only set keys the charts declare.

Measured on 02/10/2026: 603 MB, six images all verified amd64, checksums verify,
every tarball loads under the name `images.txt` declares, and the packaged chart
rendered with the archive's own values references the internal registry only.

`Install smoke` gained a third job that builds the archive on every tag, verifies
the checksums, loads every image from the archive alone, and fails if the packaged
chart still references anything outside the mirrored registry.

### Verified — an archive installed through an in-cluster registry on amd64

Not only built: installed. On the managed OVH cluster, a `registry:2` bound to the
node's loopback was fed from the archive alone, and the archive's packaged chart
and values file brought up all seven pods with every image reference resolving
through that registry. `login` and `refresh` answered 200, and core announced
`Isolation : connecte en « vibops_app », RLS applicable.`

Then every route out of the cluster was cut — `api.anthropic.com`, `ghcr.io` and
`registry-1.docker.io` unreachable from the pods — and all seven pods were
deleted. They came back Ready, the API answered, the console reached core, and the
licence resolved to its trial limits. The "nothing phones home" claim is now
measured rather than asserted.

Two limits stated rather than glossed: the node already held `postgres` and
`redis` layers with digests identical to the archive's, so containerd resolved
their manifests from the internal registry but reused the cache — the archive's
copies of those two never crossed the wire. And a cold cache with no route out
cannot be arranged on managed Kubernetes, where the nodes are not yours to
configure.

Also fixed: the script used `mapfile`, which does not exist in the bash 3.2 macOS
ships — it exited 127 on the machine that builds the archive.

---

## [0.51.2] — 2026-10-02

### Fixed — a Secret changed by `helm upgrade` did not reach the pods

`helm upgrade` updates the Secret and stops there; a pod keeps the environment it
was created with. So an operator could add `core.secret.smtpHost` to an existing
release, read `STATUS: deployed`, and core would still run without SMTP — the
password reset request then answers `200` and sends nothing, because that is the
intended answer when no server is configured. Nothing anywhere says the setting
did not take.

The same trap as `docker compose restart`, which the manual already documents.

Found by the `Install smoke` step added in 0.51.1: upgrade at 12:28:07, request at
12:28:10, empty mailbox — and the core pod had logged its startup at 12:27:12.

The core, worker, beat and agent pod templates now carry a `checksum/secret`
annotation, so a changed value recreates the pod. The checksum is taken over the
values the operator supplies, not over the rendered Secret: that one contains
`randAlphaNum` fallbacks for generated secrets, and hashing it would recreate
every pod on the first upgrade for no reason.

The smoke step now also reads `SMTP_HOST` back out of the running pod, so it
diagnoses a stale pod instead of only reporting an empty mailbox.

### Verified by HTTP on a Helm install with row level security enforced

The 0.51.1 fixes, confirmed in CI rather than by reasoning:

```
POST /api/v1/auth/refresh HTTP/1.1" 200 OK
{"event": "Isolation : connecte en « %s », RLS applicable.",
 "positional_args": ["vibops_app"], "level": "info"}
```

---

## [0.51.1] — 2026-10-02

### Fixed — three authentication paths that row level security turned off

Measured on 02/10/2026 by installing the chart on a managed OVH Kubernetes
cluster. Two things had to be true at once for any of this to be visible, and no
earlier test had both: the CNI must enforce NetworkPolicies (OVH runs Canal, so
Calico enforces them), and core must connect as a role without `BYPASSRLS` —
which is what a default Helm install does and a Docker Compose install does not.

- **`POST /auth/refresh` returned `401 User not found or inactive.`** for a
  refresh token issued seconds earlier. The token carries only `sub`, so the row
  must be read before the tenant is known; under ADR 0047 a transaction with no
  scope matches no policy branch and reads nothing. **No session could be renewed
  on a Helm install**, and the message blamed the account.
- **`POST /auth/forgot-password` answered `200` and never sent anything.** Same
  cause — and `200` is also the intended answer for an unknown account, so the
  failure was indistinguishable from the normal case.
- **`POST /auth/reset-password` rejected valid codes** with `400 Invalid or
  expired reset code.`, again by failing to find the user.

All three now open `system_scope()` before their first query, as `login`,
`/auth/setup` and gateway authentication already did — the fourth, fifth and
sixth occurrence of the same defect class. `core/tests/test_pre_tenant_lookups_are_scoped.py`
fails if a pre-tenant handler forgets the scope, or opens it after the
transaction has already begun.

### Fixed — core could not reach SMTP or any notification provider under the chart's own policy

Core's egress allowed 5432, 6379 and 53. But core sends notification tests from
the API (Slack, webhook, PagerDuty) and opens its SMTP connection inside the
request handler, so both were dropped on a policy-enforcing CNI. The worker was
unaffected because no policy selects it — which is why scheduled alerts went out
while the "Test" button in the interface timed out silently.

Control, same destination at the same instant: `core -> mailpit:1025` timed out
after 10.1 s, `worker -> mailpit:1025` connected in 0.1 s.

The chart now allows outbound 443, and the port declared in
`core.secret.smtpPort` whenever `core.secret.smtpHost` is set.

**Password reset is now verified end to end** — request, delivery, subject and
reset code read back out of the relay's mailbox. It had never been executed.

### Fixed — the isolation posture core announces was invisible in production

`APP_ENV=production` sets the log level to `WARNING`, and the healthy case is a
`log.info`, so `Isolation : connecte en « vibops_app », RLS applicable.` never
printed where it matters. Only the dangerous case — a role that bypasses RLS —
was a warning and came out. A silent log did not mean "all good"; it meant
nothing, and no functional test tells the two postures apart. Startup facts now
survive production filtering.

### Verified on a managed OVH cluster (Canal / Calico)

Enforcement was confirmed first with a disposable pod — reachable without a
policy, dropped with one — so that a green result would mean something:

- the full chart installs, seven pods Running, three Cinder volumes bound;
- the chart's `grant-app-role` init container really gives core `vibops_app`
  (`rolsuper = f`, `rolbypassrls = f`), so ADR 0047 is active;
- the database egress rule follows where the database lives: with the restricted
  rule a PostgreSQL in another namespace times out after 12 s, with the managed
  branch core completes a real asyncpg handshake in 0.1 s;
- a Connect gateway in **another namespace** registers, pings `200`, polls jobs
  and runs a network scan;
- two consecutive `helm upgrade` runs succeed against a provider whose default
  StorageClass has a real name (`csi-cinder-high-speed-gen2`), not k3d's
  `local-path`.

`Install smoke` now also checks that a session renews and that a password reset
reaches its relay — the two steps that would have caught the defects above.

---

## [0.49.0] — 2026-10-01

Consolidates the 0.48.1 → 0.48.9 releases, which were tagged and published without
a CHANGELOG entry. Three themes, and they are the same thread: a licence nobody
could issue, an installation manual nobody had executed, and a measurement that
rendered as a legitimate absence.

### Added — VibOps can now issue the licences it already knew how to read

`scripts/onboard-client.sh` had pointed at `scripts/gen_licence.py` since it was
written. The file never existed in the history, and the private half of the old
keypair was held by nobody. So the product could verify a licence that no one
could produce, and everything after the 14-day trial was blocked at step one, at
every customer.

- **A new RSA 4096 signing keypair**, and `scripts/gen_licence.py` to sign with it.
  A licence is a self-contained RS256 JWT verified offline against the public key
  embedded in `core/app/licence.py` — no licence server, no telemetry. That is a
  sovereignty argument and also its constraint: **an issued key cannot be revoked**,
  only expire. The generator refuses a world-readable private key, and refuses more
  than 400 days without an explicit override.
- **The generator needs only PyJWT and cryptography.** It first read `PLAN_LIMITS`
  by importing `app.licence`, which pulls in pydantic: an environment with no
  product installed could not issue a licence, and the CI job died on
  `No module named 'pydantic'`. The plans are now parsed out of the *text* of
  `core/app/licence.py`.
- **`docs/runbooks/licence-issuance.md`** — issuing, installing, renewing, and what
  expiry does and does not block.

### Fixed — a licence ceiling was blinding the product instead of bounding it

The ping's error branch returned before `gw.cluster_metrics = new_metrics`. Past
the GPU limit the gateway stayed *online*, `cluster_metrics` and `clusters` were
never written — the console showed "(no cluster)" — and no time-series row was
produced, so no energy was measured either.

The trap inside the trap: `gpu_current`, the counter on the Licence page, is
computed *from* `cluster_metrics` — the field the refusal prevented from being
written. **A 64-GPU fleet on a 10-GPU trial displayed "0 / 10", under the limit,
in green.** The ceiling concealed itself.

A licence bounds actions, and actions were already bounded elsewhere:
`_check_gpu_quota` refuses a GPU deployment with 429, gateway and user creation
return 402. Blinding observation protected nothing and removed the one datum that
cannot be reconstructed afterwards. The overrun is now reported — in the ping
response, in core's log, and by Connect in the customer's own logs — and nothing
is dropped.

### Fixed — a licence did not survive a restart, and neither did the trial anchor

`PATCH /licence` validated the key and replaced the in-memory singleton; nothing
wrote it down, so the next boot read `VIBOPS_LICENCE_KEY` from the environment and
the operator's key was gone, with no message. And `_trial_start` was anchored at
module import, so every restart reopened fourteen days — the trial measured the
container's lifetime, not the time since installation.

`platform_licence` holds one row: the key and the installation date. Precedence is
**database > environment > trial**. A licence installed through Helm also never
reached the product: `core/app/config.py` accepts both `licence_key` and
`vibops_licence_key`, where `extra="ignore"` had been dropping the chart's spelling
in silence.

### Fixed — the installation manual, executed on real hardware for the first time

Three Helm installs (Scaleway Kapsule twice, OVH once) and one Docker Compose
install on an amd64 host. Every defect below stopped a documented command on a
machine that met the stated prerequisites.

**Helm — a fresh install could not start, and could not create its admin.**

- `DO $$ … END $$;` in the role-creation hook: Kubernetes collapses `$$` to `$` in
  container args, so the block reached PostgreSQL malformed and core crash-looped.
  Replaced with psycopg2's `QuotedString`.
- `agent.persistence.storageClassName: standard` — a name no managed Kubernetes
  provider uses. The PVC stayed `Pending` forever. Now empty, so each cluster's
  default class is used; proved by OVH, whose default is `csi-cinder-high-speed-gen2`.
- The bootstrap script was refused by Row Level Security (ADR 0047). Wrapped in
  `system_scope()`.
- **No gateway could authenticate**: a valid token returned 401 with a hash verified
  identical in the database, because the token-authenticated routes ran outside any
  tenant scope. `gateway_scope()` now applies to the four of them.
- The NetworkPolicy admitted no Connect pod from another namespace.
- **And Connect logged `Ping envoyé` on a 401.** The success line did not depend on
  the status code — the clearest instance of this release's recurring failure, in the
  line that had been treated as proof.
- The guide promised SMTP the chart never passed on, and `AUTH_USERNAME` was removed
  everywhere: a setting nothing read.

**Docker Compose — eleven defects across three passes, each one fatal.**

- `make login` does not exist and never did: the first command a prospect typed
  answered `No rule to make target 'login'`, after waiting for a registry token they
  never needed. The images are public.
- `make` was absent from the prerequisites, which listed Docker, Python and curl.
- `REDIS_PASSWORD` was not generated, so `docker compose up` refused to start with
  five interpolation errors.
- **No `Caddyfile` shipped.** The compose bind-mounts `./Caddyfile`; with the source
  missing Docker creates a *directory* and the container dies on "Are you trying to
  mount a directory onto a file?". `install/Caddyfile.example` now ships and is
  installed by `make quickstart` — and creating it no longer sits inside the
  `if [ ! -f .env ]` guard, where any second run or hand-copied `.env` skipped it.
- **Core was published on no port at all**, so step 4 of the guide and `make check`
  both failed on a healthy installation. It now publishes `127.0.0.1:8000`, the same
  treatment postgres, agent, prometheus and grafana already had.
- `make check` looked for the console on port 8080, a number in no compose file.
- `make hash` could not run: the image entrypoint accepts only `api`, `worker` or
  `beat` and answered "Mode inconnu : python" — the step that generates the hash
  without which authentication stays off.
- The guide told readers to open port **8003**, the port the console listens on
  *inside* its container, which nothing maps. Measured: 000. The console is on 80,
  through Caddy — and `make quickstart`'s closing summary said 8003 too.
- The summary announced "2 clusters" for the trial; `PLAN_LIMITS["trial"]` allows 5.
  Two is Starter's. The ceiling is enforced at runtime, so a pilot sized against it
  stops in front of the customer.
- The guide showed `$2b$12$...` as the output of `make hash`. That is bcrypt;
  `hash_password` is scrypt and returns `<salt hex>:<digest hex>`. A reader who cut
  at the colon would store a value `verify_password` rejects, with no message.
- A dead `./static` bind mount on Caddy — a vestige of an experiment removed on
  26/09 — made Docker create an empty directory in every customer's clone.

**The published install repository shipped short, and said nothing.**
`publish-install-repo.sh` carries an allow-list, and a declared-but-absent file was
only a warning before a `continue`: the script exited zero and the repository left
without the file. That is how v0.48.8 published a Makefile that copies
`Caddyfile.example` and no `Caddyfile.example`. It is now fatal, and
`tests/test_install_repo_is_complete.py` checks that every file the shipped Makefile
copies, every script it calls and every compose bind-mount source is published.

**Sizing is now measured, not guessed.** The guide separates a pilot's requirement
from a production recommendation, and states the floor the OVH run established:
2 vCPU / 2 GiB free against chart requests of 1200m / 1280Mi.

### Fixed — only the gateway-token routes may bypass the console

The generated Caddyfile sent every `/api/v1/gateways/*` request straight to core.
That prefix also covers `GET /gateways/{id}`, `POST /{id}/scan` and
`/gateways/gpu-utilization/live`, which authenticate by **user session**: the console
relays those and adds the operator's identity, and sent direct they reached core with
no identity at all. Under `APP_ENV=development` no identity resolves to system scope.

Found on the demo while checking the fleet: the GPU % column read the system
organisation instead of the operator's, so the only cluster with a real GPU showed
"—" and a GPU-less one showed 0%. **The same URL answered from the public internet
with no authentication.** The route now matches exactly the four paths Connect calls,
and the ratchet reads them from Connect's own source.

### Added — GreenOps: the measured path reaches the screen

ADR 0043's collectors existed; nothing carried a measurement to the console.

- `EnergyService` distinguishes **measured** from **declared** per cluster, sums only
  `quality == "measured"`, and states which it used.
- **The console can finally declare what carbon needs**: grid factors (CRUD plus CSV
  import) and the per-cluster energy fields. The GreenOps endpoints had been returning
  404 — they were missing from the console's relay list, and `r.ok ? … : null` rendered
  the 404 as "—".
- **A real measurement rounded to zero.** A gateway on a Scaleway Kapsule with an L4:
  cluster discovered with no kubeconfig, 1 GPU on 2 nodes, 16.44 W from DCGM, four rows
  at `quality=measured` — and the console would have shown **0.0 kWh**, because
  `as_dict` rounded to three decimals and an L4's first hour is 0.0004 kWh. The zero
  this service exists to refuse, produced by the rounding rather than by missing data.
  Precision now follows magnitude. Found fifteen minutes after plugging the gateway in.
- The long `method` sentence moved behind a "?" so it stops stretching the KPI row.

### Fixed — Connect: a cluster name must be choosable, and energy counted once

- Every in-cluster Connect declared itself `in-cluster`, so several sites contested one
  name and `ovh-gra11` displayed "(no cluster)". `gateway.clusterName` now sets it, and
  a refused name is logged rather than swallowed.
- **Energy was under-reported by a factor of two**: it integrated over `POLL_INTERVAL`
  (15 s) while the reading happens in the ping loop every 30 s. It now integrates over
  real monotonic elapsed time.
- The DCGM namespace was assumed, so a working exporter read as absent. It is now read
  from the pod, via the API server's `services/proxy`.
- `rbac.allowWrite` (chart 0.29.5) grants the verbs an action needs and deliberately
  withholds the three that would turn a gateway into a pivot: the cluster's `secrets`,
  the `rbac.authorization.k8s.io` group, and write on `nodes`. Before it, the only way
  to let the agent act was a hand-written ClusterRole outside Helm.

### Fixed — accessibility, and a compliance report that denied a shipped feature

axe-core now runs against a real browser on a seeded instance, which found four
contrast failures that no static check could see. The GDPR report claimed a feature
the product ships, and the console had regions no screen reader could announce.

### Security

- **PyJWT 2.13.0 → 2.14.0** (CVE-2026-102274, CVSS 5.9). From 2.9.0 to 2.14.0,
  `PyJWKSet` does not catch the plain `ValueError` that `RSAAlgorithm.from_jwk` raises
  on a malformed RSA component, so one bad key aborts the whole set — an authentication
  outage caused by a key nobody uses. **This product was not exposed**, and that is
  worth stating rather than only bumping: `sso.py` never builds a `PyJWKSet`; it walks
  `jwks["keys"]` itself and calls `from_jwk` per key inside `try … except: continue`,
  which is exactly the behaviour 2.14.0 adds upstream.

### Documentation

- `docs/poc-oreus.md` — GPU Kubernetes, local install, local LLM, on their own GPUs.
- `docs/poc-tersedia.md` — local prerequisites for a remote or on-premise pilot.
- A commercial two-pager that printed on four pages with broken accents.
- Two figures that would have reached a customer were wrong, and the guard on public
  figures was counting a third of the catalogue.

### Known and not fixed

- Two Connect releases cannot coexist in one cluster: the ClusterRole name derives from
  the release name and they collide.
- `ADMIN_PASSWORD` sits in plaintext in every `.env`.
- `gpu_model` is not collected from DCGM's `modelName`, and `gpu_used` is always 0.
- Option A (`install.sh`) on a fresh machine, the Ingress + TLS path with a real
  certificate, and attaching a **remote** site are still unverified end to end — only
  in-cluster attachment has been proved.
- `E2E Pipeline Tests` fails on the last three tags for a reason outside the code: the
  ten behavioural tests (ADR 0009 L3) call the live Anthropic API and receive
  `400 — credit balance is too low`. That gate is blind until the account is topped up.

---

## [0.48.0] — 2026-09-28

### Added — GreenOps: the product can hold an energy figure, and now measures one

ADR 0043's eight steps, shipped in order and with the collectors **disabled by
default**. A fleet that turns none of them on reads exactly as it did: every figure
declared, and saying so.

- **The measurement-sources page first, before any collector.** DCGM needs the GPU
  Operator; on a cluster without it the collection returns nothing, and nothing renders
  as zero. `GET /greenops/measurement-sources` names, per cluster, which sources are
  present and which are missing — and the absences are not interchangeable: `absent`
  (a prerequisite is missing), `not_applicable` (nothing to measure), `unsupported`
  (no field exists yet).
- **`annual_kwh` and `kwh_source` on `cluster_rates`.** The electricity cost had been
  on file since Sprint 9 as kWh × tariff computed outside the product; only the product
  came in, and the kWh — the one quantity carbon needs — were discarded at input.
- **`grid_factors` and `pue`.** Versioned by year, `source` required, and the table
  **ships empty**: no bundled national average, because a factor is the number a gCO2e
  is multiplied by and the product must not be the one that chose it.
- **Energy in the monthly chargeback and in the console**, beside the dollars — carbon
  is a second unit on the FinOps axis, not a parallel journey.
- **`power_w`, `energy_wh`, `quality`, `source` in `gpu_metrics_history`**, fed by a
  DCGM collector in `connect/worker.py` riding the ping that already runs: no new port,
  no new connection. A cluster with no sensor writes no row rather than a row of zeros.
- **RGESN as the twentieth compliance framework** — 78 criteria in an engine that
  already served nineteen: one word in the agent prompt, no new tool. Not publishable
  as it stands: the titles are summaries, not the official Arcep labels.
- **An SCI export (ISO/IEC 21031:2024) that produces no score.** The standard requires
  four terms and the allocated manufacturing emissions are collected nowhere. Every
  component is exported with its provenance and `sci` is null, naming each missing term.
- **CSV import for both**, with an unknown column now **refused** rather than skipped:
  a file carrying `annual_kwh` for eighteen sites used to report eighteen successes and
  store none of it.

### Added — the audit chain head is witnessed by someone who is not us

ADR 0044 §3. Hourly, each organisation's chain head is published to its own SIEM — a
system the customer already trusts, that already receives the audit exports, needing no
new outbound destination and working air-gapped. An unchanged head is not republished, a
failed push writes no row, and an organisation with no SIEM is skipped rather than
failed. `/audit/verify` now says whether an anchor exists, on a broken chain too.

### Fixed — the console had escaped its own layout box

One `</div>` too many and one unclosed `<template>`, dating from the 15/08/2026 split
into partials. The browser closed the scrolling container at the end of the Dashboard
tab, so every tab after it — and the agent panel — rendered outside the `h-screen` box:
the page grew past the viewport and showed a black band underneath. The templates are
not self-contained, so no single file looked wrong; the new test assembles the document
and walks it.

### Fixed — Connect reported the capacity of each node and no sum

The console reads the cluster-level fields, so an online cluster with a node answering
displayed "0 vCPU / 0 GB / 0 pods". The legacy worker heartbeat had computed those totals
since always; the product path reported less than the path it replaced.

### Fixed — one Celery worker became a new gateway at every restart

Its name defaulted to the container id and its identity file lived in a directory nothing
mounted, so the write failed into `except Exception: pass`. Seven orphan gateway rows had
accumulated on the demo. Both compose files now give it a stable name and a volume, and
the image creates the directory owned by the runtime user — without that last part the
volume arrives owned by root and the fix looks applied while changing nothing.

### Fixed — the demo seed purged a tenant it had not authenticated as

It created its data through the API, in the organisation of the account it logged in as,
and resolved the organisation to purge as "the oldest non-system one". Run against a new
organisation it emptied another: 19 gateways, 120 jobs, 485 rows of GPU metrics.

### Changed — lint covers the platform, and the front end is parsed

Six ruff invocations became nine: `console/app`, `mcp/vibops_mcp`, `connect`, `sdk`,
`llm-proxy`, `scripts`, `core/scripts` and `core/alembic` were looked at by nothing. The
71 findings were all cosmetic. And `node --check` now runs on every file under
`console/static/js` — 6,163 lines that no tool had ever read.

### Fixed — the dev stack refused to start once the referential shipped

`docker-compose.override.yml` bind-mounts `./core:/app` for hot reload, which
replaces the whole directory: the RGESN file the Dockerfile puts in `/app/config`
was erased by the mount, and core raised `FileNotFoundError` at import. Every
developer's `docker compose up` would have failed. The same shape the override
already documents for `/connectors`, and now a test walks every `COPY` into
`/app` and checks the mount brings it back.

### Removed

- `console/templates/base.html` — 906 KB, a full second copy of the console that no route
  rendered, still being edited by style commits.
- Five partials included from nowhere, and `extract_partials.py`, the one-shot split
  script whose own header says it overwrites live templates from frozen line ranges.

---

## [0.47.5] — 2026-09-27

### Fixed — a Connect-managed cluster reported no capacity at all

Connect sent the capacity of each node and no sum. The console reads the
cluster-level fields, so an online cluster with a node answering displayed
"0 vCPU / 0 GB / 0 pods", and the node drawer "0 / 4 vCPU" — the allocatable
figures were never sent either. The legacy worker heartbeat had computed all of
this since always; the product path reported less than the path it replaced.

Connect now sends the totals, the allocatable figures per node, and a running
pod count (via `kubectl get pods -o name`, not the full pod JSON: it runs on
customer clusters). `gpu_used` remains a hardcoded 0 — the same class of defect,
left visible rather than fixed silently, because it needs the pod requests.

### Fixed — one Celery worker became a new gateway at every restart

The worker registers itself as a gateway and keeps its id in `gateway-id.json`
under `VIBOPS_DATA_DIR`. Under Docker both defaults failed at once: the name
defaults to the hostname, which is the container id, and the directory existed
nowhere, so the write raised FileNotFoundError into `except Exception: pass`.
Every `--force-recreate` therefore left a gateway row named after a dead
container, still claiming the cluster names it had reported. Seven had
accumulated on the demo, twenty-two in a development database.

Both compose files now give the worker a stable name and a named volume, and
the image creates `/var/lib/vibops` owned by the runtime user — without that
last part the volume arrives owned by root, the write fails with EACCES, and
the fix looks applied while changing nothing. The code creates the directory
and warns instead of passing silently.

### Fixed — the cluster removal endpoint documented the opposite of its behaviour

`DELETE /gateways/{id}/clusters/{name}` claimed the cluster "will reappear" if a
live gateway re-reports it. It has not been true since `removed_clusters` was
added, and it described the endpoint as useful only for decommissioned clusters
— the one case where it is not needed. Nothing tested the subtraction: removing
it from the ping merge left the whole suite green.

### Fixed — `tests/` was never run as a directory

Every guard in it had to be named by hand in `ci.yml`, and one that was not
never ran. `tests/test_installer_caddyfile.py` — which checks that a default
install can onboard a remote site at all, written after the v0.47.4 failure —
had never executed once. The harness job now runs the directory.

---

## [0.47.4] — 2026-09-26

### Fixed — no default installation could accept a remote site

The Caddyfile `install.sh` generates ended with a catch-all `reverse_proxy
console:8003`, and every console route carries `Depends(get_current_user)`. A
gateway presents a gateway token, not a user JWT, so Connect received 401 —
indistinguishable from a bad token, while the same token worked against the
internal address. Onboarding a remote site, the entire purpose of the component,
was impossible on a stock install.

Found by pointing the demo's own Connect at its public URL. Cloudflare's Bot
Fight Mode challenged it first (403, HTML, `cf-mitigated: challenge`); with that
off, the 401 underneath was this. The generated proxy now routes
`/api/v1/gateways/*` to `core:8000` before the catch-all. Two tests pin it,
including that the route precedes the catch-all that would otherwise swallow it.

### Fixed — the agent could not say whether it had loaded its catalogue

`_refresh_tools` logs "agent tools refreshed: N static + M dynamic" on success,
at INFO, and the agent configured no logging at all — so under uvicorn the line
fell through to `logging.lastResort`, which drops everything below WARNING. The
only way to answer "can this agent act?" was to read *core's* access log. Logging
is now configured, and `GET /health` returns the static/dynamic tool counts, the
number of verifiable actions, and `catalog_loaded`.

### Fixed — a restore onto a fresh cluster produced an unreachable database

The backup service dumped `vibops_db` and nothing else. `pg_dump` exports GRANTs
and never CREATE ROLE, so restoring onto a new cluster failed 57 times on
`role "vibops_app" does not exist` — behind a zero exit code, with every table
and row present and no privileges for the role the application connects as. The
loop now writes `globals_<DATE>.sql.gz` beside the dump, and the healthcheck
requires both. ADR 0048 carries the drill and the corrected procedure.

### Removed

- The `whisper` experiment from the installer: two Caddy routes, one relaying to
  `host.docker.internal:30181`, plus an HTML page downloaded from vibops.ai into
  every customer install.
- `docs/security/responsible-disclosure-policy.md`, which scoped disclosure
  around a SaaS at `app.vibops.ai` that was never built.

### Added

- `nvidia/llama-3.1-nemotron-nano-8b-v1` to the NIM catalogue — the only Nemotron
  that fits a 24 GB card, and so the only one that makes "VibOps runs on NVIDIA
  inference" testable on affordable hardware.
- Nemotron provider tests: where the client points, and that a leftover
  `LLM_API_KEY` is never forwarded to an on-premises NIM endpoint.
- Ratchets on ORM `org_id` comparisons and on figures in `docs/commercial/`.

---

## [0.47.3] — 2026-09-24

### Fixed — the agent started with no dynamic tools and no verification

`GET /api/v1/catalog` compared `ToolPolicyOverride.org_id`, a uuid column, to the
empty string an anonymous caller carries. That does not match nothing: the driver
raises and the endpoint answers 500. The agent calls it once at startup, caught
the failure, and carried on with its static tools. On a cold `docker compose up`:

                          before    after
    static tools            310       310
    dynamic tools             0       141
    verification specs        0        79

Not just 141 missing tools — every Nutanix, Proxmox, vSphere, XO, HPE, Outscale
and Scaleway action. The verification specs come from the same response, so
**post-action verification was off entirely**: any destructive action the agent
could still reach ran unproved.

Nothing announced it. The container reported healthy, the agent answered
normally, one WARNING line in a startup log was the only trace.

The catalogue now skips the override query when there is no organisation, and the
agent retries the load five times before giving up — at ERROR, because serving
310 tools out of 451 with no verification is not a warning.

Found by the release smoke tests, which is the second time today they caught
something that would otherwise have been tagged.

### Added

- **A ratchet on the public figures.** The README claimed 36 connectors in one
  place and 34 in another; there are 33. The MCP server's public README promised
  117 tools in its first line and listed 87, the thirty missing being every
  Proxmox, vSphere and Xen Orchestra tool. The landing page showed three stale
  figures and called the product "MIT open-core" — only `mcp/` and `sdk/` carry
  an MIT licence.

  Nothing checked any of it. `tests/test_public_figures.py` recomputes each
  figure from its source and holds the licence wording to a test asserting which
  components actually carry a LICENSE file. The two checks that read the live
  landing page run under `VIBOPS_CHECK_PUBLIC_SITE=1`, by hand before a tag.

### Fixed

- Thirty of the 117 MCP tools were served and undocumented. The public README now
  documents all of them, and its section counts add up to the number its first
  line promises.
- README figures recounted by collection; `connect` and `sdk` test suites were
  missing from the list entirely.
- Nutanix AHV added where the other hypervisors appear.

### Documented

- **`SECRET_KEY` also signs the audit chain**, which the rotation runbook had not
  said since June. Rotating it makes every existing row fail verification, flips
  the daily SOC 2 CC7.4 control to failing on its own, and — the part that
  matters — makes a real tampering indistinguishable from the rotation for every
  row written before it. The incident-response runbook, whose checklist tells you
  to rotate `SECRET_KEY` when an incident is auth-related, now carries the same
  warning at the point it is triggered.

---

## [0.47.2] — 2026-09-24

### Fixed

- **`get_db` now commits on a clean request and rolls back on any exception.**
  It did neither, which is how eight write handlers came to report success and
  persist nothing (v0.47.0). A refusal — an HTTPException raised for a 404 or a
  409 — rolls back, so it leaves nothing behind.

  The commit is a net, not a floor: `test_write_handlers_persist.py` still
  requires each handler to commit for itself, against a session that does not
  commit on its behalf.

### Added

- **A ratchet on write durability.** 143 write handlers, and until now nothing
  asserted that any of them persisted: the `client` fixture points `get_db` at
  the test's own session, so handler and test share an identity map and a flushed
  row reads back perfectly right up to the rollback nobody observes. No test
  crossed a transaction boundary, which is the only place the defect exists.

  `test_write_handlers_persist.py` closes the class in two halves — a static
  check on the exact signature (flush without commit) and a dynamic one that
  writes through the API with a session per request, then reads back through a
  session opened afterwards. Both were verified by putting the defect back.

---

## [0.47.1] — 2026-09-24

Fixes what CI caught on v0.47.0. Both failures were introduced by that release.

### Fixed

- **The Nutanix connector was classified nowhere in the gateway allowlist**, so
  `connect` would have refused every `nutanix_*` action silently — a connector
  registered, advertised and quietly inert. `test_every_named_connector_exists_
  and_is_classified` caught it; I had run `connect/tests/test_hypervisor.py`
  locally and not the rest of that suite.

- **Nine lines of `docs/installation.md` and one of `docs/technical-architecture.md`
  still named v0.46.6** — copy-pasteable commands installing the previous
  release. `bump-version.sh` updates thirteen places and none of them is prose.

  It does now, and only where it should: the same `ACTIONABLE` filter the docs
  test uses decides which lines are instructions. "Until v0.46.6 the chart pulled
  a Bitnami image" is history and stays; `ghcr.io/…/vibops-core:v0.46.6` is an
  instruction and follows the release. The two patterns must agree, and the
  script says so where it defines its own.

### Not fixed here

- The tagged E2E run reported 10 failures, all of them `test_agent_behavior`
  answering `400 — Your credit balance is too low to access the Anthropic API`.
  The functional suite passed 279. This is an account balance, not the code.

---

## [0.47.0] — 2026-09-24

### Added

- **Nutanix AHV connector**, through Prism Central — 33rd connector, 5th
  hypervisor. Twelve actions: inventory, power, clone, live migration,
  snapshots. Not yet run against a real Prism Central; see below.

- **Post-action verification went from 14 proofs to 79.** A destructive action
  declares how its effect can be proven, and CI forbids the list of unproved ones
  from growing (ADR 0038). That list stood at 69 and stands at 12. Seventeen
  predicates were written, each with its tests.

  What this buys: `helm upgrade --install` returns 0 while a release sits
  `pending-upgrade`; a Proxmox stop returns a UPID, not a stopped VM; `terraform
  apply` returns 0 having applied some resources and not others; a rolling pool
  update that stops halfway leaves a working cluster that can no longer live
  migrate. All of those now read back and say so.

### Changed — breaking for callers

- **`helm_install` and `helm_upgrade` now require `confirmed: true`.** Both were
  flagged non-destructive, and the policy engine reads that flag alone to decide
  whether an action needs a dry-run preview. They installed or upgraded a Helm
  release with no gate at all, against security invariant 3. They now answer HTTP
  409 with a preview until confirmed. The MCP tools `helm_upgrade` and
  `helm_uninstall` take a `confirmed` argument, default `False`.

- **The MCP `helm_uninstall` tool could never succeed** — it sent no `confirmed`
  flag for an action that has always been destructive, so every call was refused.
  Fixed with the above.

- Several actions gained **optional** identifying parameters so their effect can
  be read back: `vm_id` on `xo_delete_snapshot`, `instance_id` on
  `vme_delete_snapshot`, `cluster_id` on the Scaleway pool actions, `tag` on
  `registry_delete_tag`, `repository`/`tag`/`registry_type` on the image pushes.
  Omitting them leaves the action's behaviour unchanged; the proof then reads
  UNKNOWN rather than inventing a verdict.

### Fixed

- **Eight write handlers reported success and persisted nothing.** `get_db`
  yields a session and never commits; these handlers only flushed, so the session
  closed, the transaction rolled back, and the response was built from the
  in-memory object — a 201 describing a row that exists nowhere. Every write in
  `agent_budget.py` and `reselling.py` was lost, plus `PATCH /tenants/orgs/{id}`.
  Found while running the release smoke tests.

- `terraform_plan` runs with `-detailed-exitcode` and reports `has_changes`. The
  return code 2 means "changes pending", not failure.
- `list_ingresses` added to the kubectl connector; `list_deployments` gained no
  duplicate.
- Xen Orchestra host listings carry `version`; Proxmox, VME and Nutanix reads
  expose `power_state` at the root; HPE workloads expose `ready_replicas`.
- Empty snapshot listings return their block instead of nothing — deleting the
  last snapshot was unprovable for want of an empty list.

### Known limitation

- The Nutanix connector has **not been run against a real Prism Central**. Every
  endpoint and response field lives in `connectors/vibops_connectors/nutanix/
  _prism.py`, which states what is uncertain and the order to settle it in. Treat
  it as unfit for a customer site until one `POST /api/nutanix/v3/vms/list` has
  been read against a live cluster.

### Added

- **Nutanix AHV connector**, through Prism Central: VM inventory, power, clone,
  live migration and snapshots — twelve actions, six of them destructive and all
  six shipping with their proof of effect (ADR 0038). The gateway recognises
  `nutanix` as a hypervisor type and reports its VM inventory like any other, and
  the generic `list_vms` / `stop_vm` / `delete_vm` tools route to it.

  **Not yet run against a real Prism Central.** Every endpoint and response field
  lives in `connectors/vibops_connectors/nutanix/_prism.py`, which states what is
  uncertain and the order in which to settle it. Its tests replace the HTTP layer
  with responses written from documentation, not captured from a system, and say
  so. Treat the connector as unfit for a customer site until one `POST
  /api/nutanix/v3/vms/list` has been read against a live cluster.

### Fixed — security

- **`helm_install` and `helm_upgrade` had no confirmation gate.** Both were
  flagged `destructive: False` in the connector catalogue, and the policy engine
  reads that flag — and only it — to require a dry-run preview and
  `confirmed: true`. Installing or upgrading a Helm release, which replaces the
  running workloads, therefore went through with neither. Security invariant 3
  had not held for either action. The same flag is what the post-action
  verification ratchet counts, so both also sat outside it.

  **Breaking for callers.** `helm_install` and `helm_upgrade` now answer HTTP 409
  with a dry-run preview until the payload carries `confirmed: true`. The MCP
  tools `helm_upgrade` and `helm_uninstall` take a `confirmed` argument
  (default `False`, which returns the preview).

- **The MCP `helm_uninstall` tool could never succeed.** It sent no `confirmed`
  flag for an action that has always been destructive, so every call was refused
  with a 409. Found while fixing the above.

- `helm_install` ships with its proof of effect (ADR 0038): `release_deployed`
  reads the release status back, because `helm upgrade --install` returns 0 while
  a release sits `pending-upgrade` or ends `failed` with the old pods still
  serving.

---

## [0.45.11] — 2026-09-21

### Added — the three gaps named in v0.45.10 are closed

**Our own images are pinned by digest in what we distribute.** They were the
last artefacts still referenced by a tag, which made them the least protected in
the chain: a tag is a pointer, and whoever can write to the registry can move
it. The digests exist only after the push, so they are resolved at publish time
and written into the copies that leave — the repository keeps tags so a local
build still runs. A pinned Compose file belongs to one release, so
`install.sh --version vX.Y.Z` now takes that release's own file from the install
repository; keeping one file and swapping a tag would have looked like it worked
while Docker resolved the digest and ignored the tag.

**The published images are scanned**, by digest, after the push. CI already ran
`trivy fs` over the source tree, which sees nothing of the base image: a CVE in
the Python or Debian layer we ship appeared in neither pip-audit nor a
filesystem scan. CRITICAL fails the release; HIGH is reported and does not,
because a gate that blocks every release on an unfixable base-image HIGH is a
gate somebody disables within a month.

**An admission policy enforces the signature** —
`helm/vibops/policies/kyverno-verify-images.yaml`. Verification that an operator
has to remember does not happen, and Kubernetes checks nothing by itself. The
policy refuses any `vibops-*` image without a signature issued to our release
workflow, and rewrites the reference to the verified digest so the pod runs what
was checked. Not installed by the chart — Kyverno is a cluster-wide decision —
and shipped in `Audit` mode.

### Fixed

- **`vibops-beat` and `vibops-gateway` are private, and used by nothing.** The
  mirror list in the installation guide named them, so an air-gapped customer
  following it hit a 403 on two images they did not need. The list now names
  the six that are actually pulled. The two images are still built by the
  release workflow and still referenced by nothing — worth removing, not done
  here.
- **The mirror list still said `bitnamilegacy`.** The v0.45.7 edit that replaced
  it did not match, and I had not asserted the replacement — the kind of silent
  no-op this repository has a test for everywhere else.

---

## [0.45.10] — 2026-09-21

### Added — signed images, and digests instead of tags

Asked whether the images were "secured", the honest answer was no on every
count: pulled by tag, unsigned, no SBOM, no provenance, and the CVE scan looking
at the repository rather than at what we publish. Two of those are fixed here.

**Every VibOps image is signed at its digest**, keyless. cosign exchanges the
workflow's OIDC token for a short-lived Sigstore certificate, signs, throws the
ephemeral key away, and records the signature in the public Rekor log. No
private key exists to store, rotate or lose, and the claim is stronger than a
key's: *this digest was produced by this workflow, in this repository, at this
tag*. The digest is signed, never the tag — a signature on a moving pointer is
worth nothing.

Each image now also carries a **provenance attestation** (`mode=max`) and an
**SBOM**.

**Third-party images are pinned by digest** in the Compose file and the chart:
postgres, redis, caddy, grafana, prometheus and the Docker socket proxy. A tag
is a pointer its publisher can move; a digest is the content. Verified on a
host: the pinned reference pulls, and a wrong digest is refused with `not
found`.

`docs/installation.md` carries the verification commands, including the identity
flags — without them `cosign verify` only checks that *somebody* signed.

### Still open, and named so nobody assumes otherwise

The Helm chart itself is not signed and not published to an OCI registry: it
ships inside the `vibops-install` git repository. The published images are not
scanned — Trivy looks at the repository filesystem. Neither is addressed here.

---

## [0.45.9] — 2026-09-21

### Added — checksums for what we ask you to run as root

`curl -fsSL https://vibops.ai/install.sh | bash` was the documented way in, and
nothing let an operator check what they were about to execute. The script is
ours, on our domain, served by GitHub Pages — the one link in the install chain
we are responsible for, and the only one with no verification.

Each release now publishes `SHA256SUMS` beside `install.sh` and
`docker-compose.yml`, with `SHA256SUMS.version` naming the release. The guide
leads with the verified form and shows it gating the run:

```bash
curl -fsSLO https://vibops.ai/install.sh
curl -fsSL  https://vibops.ai/SHA256SUMS | sha256sum --ignore-missing -c - && bash install.sh
```

The file carries the two checksum lines and nothing else. A first version
included a comment header, and `sha256sum -c` warned `improperly formatted` on
every one of those lines — a verification step that prints warnings when it
passes is a verification step people learn to ignore.

Tested both ways: matching checksums report OK, a single appended line reports
`install.sh: FAILED` and exits non-zero.

---

## [0.45.8] — 2026-09-21

### Fixed — `install.sh` installed Docker the way Docker says not to in production

The script ran `curl -fsSL https://get.docker.com | bash` when Docker was
missing. Docker documents that convenience script as *not for production use* —
and this script configures Let's Encrypt, calls automatic HTTPS "recommended in
production", and is the path the demo runs on. It had no business using it.

It now follows Docker's documented production install: their signed apt
repository, the key placed in `/etc/apt/keyrings` and verified by apt, packages
from the stable channel. It downloads data, not code to execute. Only Ubuntu and
Debian, the distributions this script claims to support; anything else stops
with the link to Docker's instructions rather than guessing.

Verified on a clean `ubuntu:22.04`: Docker Engine 29.8.1 and Compose v5.5.1
installed from `download.docker.com`, signing key fingerprint
`9DC858229FC7DD38854AE2D88D81803C0EBFCD88`.

`docs/installation.md` updates the destination it names: `download.docker.com`
instead of `get.docker.com`, and states that nothing downloaded during an
install is executed as code except `install.sh` itself — which you can read
first.

---

## [0.45.7] — 2026-09-21

### Changed — the chart runs its own PostgreSQL

Bitnami pruned its free Docker Hub catalogue in August 2026 and the tag the
subchart pinned began returning `not found` mid-install. The stopgap was to
point at `bitnamilegacy`, a surviving copy that works and receives nothing —
security updates included. Shipping a product whose database image is frozen is
not a position to hold, and paying for the commercial catalogue to run one
PostgreSQL is not one either.

The chart now owns the database, as it already owned Redis, on
`postgres:16-alpine` — the same image, major version and maintenance as the
Compose deployment. The subchart, its vendored `.tgz` and `Chart.lock` are gone:
the chart has no dependencies left, so packaging it reaches no chart repository
either.

- A NetworkPolicy of its own. The subchart brought one; dropping it with the
  subchart would have left 5432 open to every pod in the namespace, and nothing
  would have reported it. It admits core, the worker and beat, and nothing else.
- Generated password, kept for the life of the release, pinned once written —
  the same rule as every other credential since v0.45.5.
- Every value read through `dig`. An upgrade with `--reuse-values` carries the
  subchart's values shape, which has no `persistence` key at that level: a
  direct read was a nil pointer that stopped the upgrade before the guard could
  explain anything. Fourth time that trap has been paid here.

### Upgrading

**New installations: nothing to do.** **Existing Helm releases: the upgrade
stops and names the volume it found.** The old StatefulSet has a different data
layout and a different uid, so upgrading in place would start an empty database,
core would migrate it, and the release would come up healthy and blank with the
data still on disk. `docs/runbooks/upgrade-migration.md` §v0.45.7 has the dump
and restore, and `postgresql.legacyAcknowledged=true` is the acknowledgement the
procedure uses once the dump is taken.

### Verified on a cluster

Fresh install, zero values: 7/7 Running, `postgres:16-alpine`, health green,
54 tables created. A release installed from the v0.45.6 chart: upgrade refused,
volume named, the running release untouched.

### Documented

`docs/installation.md` now lists every destination an installation reaches —
ghcr.io, Docker Hub, and for the one-line install `vibops.ai` and
`get.docker.com` — with the air-gap mirror procedure, and states what does not
happen: no activation call, no licence server, no telemetry, no version check.

---

## [0.45.6] — 2026-09-21

### Fixed — an Ingress the chart's own NetworkPolicy blocked

First test of the chart on a three-node cluster with a real Ingress controller.
`ingress.enabled=true` publishes three paths — `/` to the console, `/api/v1` to
core, `/api/v1/chat` to the agent. The core policy admitted the agent and the
console; the agent policy admitted the console. A controller runs in its own
namespace and is neither, so two of the three paths timed out while
`kubectl get ingress` showed an address and `helm install` reported deployed.
Measured: `/` 200, the other two no response at all.

Both policies now admit the controller's namespace when ingress is enabled,
matched on `kubernetes.io/metadata.name`, which Kubernetes sets by itself. The
namespace is `ingress.controllerNamespace`, default `ingress-nginx`.

The first version of that fix read the new value directly, and an upgrade run
with `--reuse-values` — which carries the release's old `ingress` map — rendered
`kubernetes.io/metadata.name: ""`, a selector matching no namespace. The upgrade
reported deployed and the routes still timed out. It reads through `dig` with a
default now. Third time that trap has been paid in this chart.

After the fix, on the same cluster: `/` 200, `/api/v1/health` 200 with a live
body, `/api/v1/chat` 405 — the agent rejecting a GET, which is the route
arriving.

### Verified on three nodes

Autoscaling, pod disruption budgets and the Grafana dashboard ConfigMap all
render and behave: HPAs report real CPU and memory figures against
metrics-server, the dashboard ConfigMap carries its key, and `serviceMonitor`
is refused with a clear message when the Prometheus CRD is absent.

### Documented rather than changed

- `podDisruptionBudget.enabled=true` with one replica allows zero disruptions,
  so `kubectl drain` blocks on that node. Arithmetic, surprising at the wrong
  hour, now written in values.yaml.
- Local-path storage pins PostgreSQL to its node: draining it leaves the
  StatefulSet Pending and core in CrashLoopBackOff until the node returns.

### Observed, not reproduced

After that drain, the Celery worker stayed `1/1 Running` with zero restarts,
stopped answering `inspect ping`, and core's health read
`worker: no workers responding` until the deployment was restarted. Deleting
the Redis pod in place, and forcing Redis onto another node, both failed to
reproduce it — the worker kept executing tasks and answered. Recorded in
`docs/harness.md` under known gaps rather than claimed as a defect.

---

## [0.45.5] — 2026-09-21

### Changed — an install needs nothing typed by a human

VibOps exists so that running infrastructure does not mean a person entering
values into a terminal. The chart contradicted that: v0.45.3 made it refuse to
install without eight secrets, which is safer than the placeholders it replaced
and still a form to fill in — eight values to generate, store, and remember on
every upgrade.

The chart now generates each of them on first install and keeps them for the
life of the release: signing keys, the vault key, the internal API key, both
webhook secrets, the Redis password. The database password belongs to the
PostgreSQL subchart, which already preserves it; core, the worker, beat and
both init containers read it from that Secret. The Redis URL is composed in the
pod the same way, and the agent reads core's signing key rather than holding a
copy. No credential is written in two places.

`helm install vibops ./helm/vibops -n vibops --create-namespace` — no values,
no flags — is now the supported path. The only value only you can provide is
the LLM API key.

### Fixed

- **Placeholders are no longer preserved.** Keeping a release's live secrets
  across upgrades, applied to a release installed before v0.45.3, faithfully
  preserved `change-me-in-production` — the exact string core refuses to start
  on. Found by replaying a real upgrade; `helm template` cannot see it, since
  `lookup` returns nothing without a cluster.
- **The v0.45.4 warning about password rotation was wrong.** The subchart's
  `common.secrets.passwords.manage` reads the live Secret before it generates,
  so a password supplied once is not rotated by later upgrades that omit it.
  Verified, and the warning is gone from the runbook.

### Verified on a cluster

| Scenario | Result |
|---|---|
| `helm install` with no values at all | 7/7 Running, 150 s |
| Two upgrades, still no values | every credential unchanged, no pod restarted |
| Chosen PostgreSQL password, upgrade without repeating it | password kept |
| The broken v0.45.2 chart, then `helm upgrade` with no values | 7/7 Running, 90 s |

`tests/test_helm_unsafe_defaults.py` now renders the chart with no values and
pins what comes out — every secret present, strong, distinct, different on two
installs, a usable Fernet key, and each credential read from the one Secret
that owns it.

---

## [0.45.4] — 2026-09-21

### Fixed — one copy of the database password

v0.45.3 made the chart refuse to install without a PostgreSQL password, and
left anyone who had installed the v0.45.2 chart with a manual repair: extract
the password the subchart had generated, pass it back on upgrade. That is a
procedure, not a fix — the defect was that the credential existed twice.

The chart wrote `DATABASE_URL` into its own Secret from
`postgresql.auth.password`; the subchart kept the real password in a Secret of
its own. Nothing reconciled them.

Core, the worker, beat and both init containers now read that password from the
subchart's Secret at start-up, and Kubernetes expands `$(POSTGRES_PASSWORD)`
into the URL. There is one copy, held by the component that owns it.
`postgresql.auth.password` is optional again — the subchart generates one on
install and keeps it on upgrade.

Verified on a cluster: the v0.45.2 chart installed as its guide described it
(core, worker and beat in CrashLoopBackOff), then a plain `helm upgrade` with
no PostgreSQL password and nothing extracted by hand — 7/7 Running, 0
restarts, 90 seconds. The manual procedure has been removed from
`docs/runbooks/upgrade-migration.md`.

`tests/test_helm_unsafe_defaults.py` gains two checks: the chart's own Secret
carries no `DATABASE_URL` when PostgreSQL is bundled, and every container that
connects — core, worker, beat, `alembic-migrate`, `wait-for-migrations` —
takes the password from the same `secretKeyRef`.

---

## [0.45.3] — 2026-09-20

### Fixed — Helm chart (`helm/vibops`)

Found by installing the v0.45.2 chart on a real cluster; all four passed
`helm lint`, `helm template` and `--dry-run=server`.

- **PostgreSQL password**: with `postgresql.auth.password` empty the chart
  rendered `postgresql+asyncpg://vibops:@host` while the Bitnami subchart
  generated a random password of its own. The release installed, every other
  pod reported Ready, and core sat in `Init:Error` forever on
  `fe_sendauth: no password supplied`. The chart now refuses to render.
- **Production secrets**: `APP_ENV` defaults to `production`, where core
  refuses to start without `GITHUB_WEBHOOK_SECRET` and `GRAFANA_WEBHOOK_SECRET`
  — both shipped empty, so a default install gave a core in CrashLoopBackOff.
  Those two, plus `secretKey`, `jwtSecretKey`, `vaultKey` and `internalApiKey`,
  are now required at install time; the `change-me-…` defaults are gone.
- **Agent JWT key**: `agent.secret.jwtSecretKey` defaults to core's. Two
  independent `change-me-jwt-secret` defaults agreed by accident; setting one
  side properly turned every agent→core call into a 401.
- **Worker startup race**: the worker opens its gateway-heartbeat session once
  and never retries. Scheduled before core's migrations it logged
  `relation "gateways" does not exist` and ran Ready with the heartbeat dead. A
  `wait-for-migrations` init container now holds it until the schema exists.

### Changed

- `docs/installation.md`: the Helm values example put `DATABASE_URL` and
  `REDIS_URL` under `core.env`, which the chart never reads; they belong under
  `core.secret`. It also still said the chart bundles no Redis.

### Upgrading

`helm upgrade` now fails with the name of any missing value rather than
installing a release that cannot run — `--reuse-values` from an older release
included. A cluster already running the v0.45.2 chart needs the password its
PostgreSQL subchart generated, not a new one; `docs/runbooks/upgrade-migration.md`
§5 has the two commands. Verified on a cluster: install the v0.45.2 chart as the
guide described it (core, worker and beat all in CrashLoopBackOff), upgrade,
7/7 pods Running with 0 restarts.

### Note on versioning

v0.45.2 shipped the chart with these four defects, and the fixes were published
to the install repo on the main branch under the *same* chart version — two
different charts answering to `0.45.2`. This release exists to give the
corrected chart a version of its own.

---

## [0.45.2] — 2026-09-20

### Fixed
- **Celery beat could not persist its schedule.** `PersistentScheduler` writes to the working
  directory; under the `readOnlyRootFilesystem` the Helm chart sets — correctly — that is
  `[Errno 30]`. Worse, the pod reported **Ready while failing**: Celery survives the error, so it
  schedules and cannot persist what it scheduled, and a restart loses or re-fires it. The
  entrypoint now passes `--schedule=/tmp/celerybeat-schedule`. This release exists to ship that
  image

### Added
- **The Helm chart bundles Redis.** It shipped a PostgreSQL subchart and no broker, while
  `core.secret.redisUrl` said "REQUIRED in production" and defaulted to localhost — where
  nothing listens inside the core pod. The official `redis:7-alpine`, as the compose deployment
  has always used; `redis.enabled: false` remains the path to a managed broker

### Fixed — the Helm chart, found by installing it
- PostgreSQL pinned a Bitnami tag pruned from Docker Hub; repointed at `bitnamilegacy`, which is
  frozen and a stopgap
- core's egress policy selected `component: postgresql`; the Bitnami pod is `component: primary`,
  so the selector matched nothing and the database was unreachable
- Neither webhook secret was exposed, though core refuses to start in production without them
- The console writes SQLite to `/data`; only `/tmp` was mounted. Added, with a PVC, so history
  survives a restart as it does under compose
- The agent's probes pointed at `/health`, which it does not serve — the pod ran forever and was
  never Ready, so its Service had no endpoints
- Adding a value broke `helm upgrade --reuse-values`; the new templates read through `dig`

Seven pods of seven now reach 1/1 on a fresh cluster with nothing but the chart's own values.
Every one of these passes `helm lint`, `helm template` and `--dry-run=server`.

---

## [0.45.1] — 2026-09-20

### Fixed
- **Two secrets carried a published default** in `docker-compose.yml`, which is served at
  vibops.ai and downloaded by `install.sh`: `REDIS_PASSWORD` fell back to `vibops-dev` in five
  places and `GRAFANA_PASSWORD` to `vibops` in three. An operator who downloaded the compose
  file and started it without a `.env` — which the installation guide invites — got a Redis and
  a Grafana admin protected by passwords printed on our own website, with Compose substituting
  the missing variable in silence. Both are now `${VAR:?message}`: Compose refuses to start and
  names what is missing. `install.sh` generates both with `openssl rand`, so the documented path
  was never exposed
- **The production Helm chart named a registry that has never existed** —
  `ghcr.io/vibops/{core,agent,console}` instead of `ghcr.io/<owner>/vibops-<component>`. Helm
  installed the release and the pods sat in ImagePullBackOff. The three images also pinned
  `latest`, so the chart announced one appVersion and delivered whatever was newest
- **The installation guide pointed at a Helm repository that does not resolve**
  (`charts.vibops.io`) and, in another place, at a third spelling of the image owner. The charts
  ship in the public install repository and in the delivery archive; neither needs an outbound flow
- **The main-branch job published the install repository to a copy** rather than to
  `VibOpsai/vibops-install`. The tag workflow had been fixed by overriding an environment
  variable; the script's default was left pointing elsewhere

### Added
- `tests/test_no_weak_defaults.py` — a non-empty default on any variable named PASSWORD, SECRET,
  TOKEN, API_KEY, VAULT_KEY or PRIVATE_KEY fails CI. It found the Grafana default on its first
  run, in a file that had just been read line by line
- `tests/test_sdk_api_parity.py` and `tests/test_sdk_field_parity.py` — the SDK is recognised as
  a sixth interface onto the same data (ADR 0032). Its typed responses carried 3 of 17 budget
  fields and 4 of 22 job fields; `parse()` discarded the rest in silence
- `tests/test_docs_coherence.py` — versions, image references, dead hosts, chart versions and
  stated tool counts, compared against the files that decide them
- Agent behaviour (ADR 0009 layer 3) runs on every tag, on the model a deployment runs
- `sync-sdk.yml` — the public SDK mirror is refreshed on every tag; it had been stale since August

---

## [0.45.0] — 2026-09-19

### Added
- **Deterministic output formatter** (OpContract rule 7) — `agent/app/services/output_format.py`.
  ADR 0032 promised that an on-prem Ollama deployment gets output of the same quality as a
  Claude Sonnet one, through a formatter between the LLM response and the console. That
  formatter did not exist; the rule rested on prompt templates, which work in proportion to how
  good the model is. It strips leaked reasoning tags, inserts missing table separator rows, pads
  ragged rows, normalises status tokens inside table cells, demotes document-level headings. It
  repairs structure and never content: leaked template placeholders are logged, never
  substituted. Idempotent, and it never empties a non-empty reply
- **Prompt prefix caching** on the Anthropic path — the tool catalogue and static rules, about
  60,700 tokens identical on every call, were re-billed in full on every turn of the agent loop.
  The system prompt is now two blocks, the stable one carrying the cache breakpoint.
  `test_prompt_cache_boundary.py` guards the boundary: the cached block must be identical across
  users, clusters, languages and fleet state, or the cache is never read and the 25% write
  premium is paid for nothing
- **Capability-derived tool filtering** — six tool families target one platform each (vSphere,
  Proxmox, Xen Orchestra, HPE VME, Slurm, NVIDIA NIM), 98 of 310 tools and a quarter of the
  catalogue. They are withheld from organisations whose gateways do not report them. Derived
  from `Gateway.capabilities`, never from a guess at the user's intent, and it fails open on
  every path where the answer is unknown. What is withheld is named in the prompt so the model
  says the platform is not connected rather than that the capability does not exist
- **OpContract rules 2, 3 and 6 under test** — numeric coherence across surfaces
  (`test_opcontract_rule2_coherence.py`), collection-failure safety
  (`test_opcontract_rule3_collection_safety.py`), and `validate-seed.sh` wired into
  `e2e-pipeline.yml`. All nine rules of ADR 0032 are now held by an automated check
- **ADR 0043** — GreenOps: carbon as a second unit on the FinOps axis, status Backlog. Plus the
  incoming specification, the 78-criterion RGESN referential and the assumption check in
  `docs/specs/`

### Fixed
- **anyio 4.7.0 → 4.15.1 in the gateway** (CVE-2026-63374, CVE-2026-64847). It was the only
  component still pinned to 4.7.0; core and agent were already on 4.15.1
- `gpu_metric.py` documented a 30 s cadence; the beat schedule says 60 s
- ADR 0032's enforcement table named files that did not exist for three rules

### Changed
- **Documentation language is English by default** — docs, ADRs, specs, docstrings and comments.
  Recorded in `CLAUDE.md`. The five existing French documents are client-facing and stay French

---

## [0.44.0] — 2026-09-18

### Added
- **Backend rate surface** — per-organisation, per-backend LLM pricing in the console and a new
  `llm_backend_rates` table. Rates lived in the proxy's `BACKEND_RATES` environment variable:
  identical for every customer, changed only on redeploy, and a backend absent from the JSON
  fell back to `default_gpu_hour_rate` with `compute_type: "gpu"` — a CPU inference billed at a
  GPU rate. A confident wrong number is worse than a missing one
- **Agent identities panel** wired into the console settings
- **Daily SIEM export** — `push_audit_to_siem` sends the audit trail to Splunk HEC or Datadog,
  with a watermark advanced only after a successful push
- **vSphere collection** in `connect`, several hypervisors per gateway, and hypervisor metrics
  without which no VM alert ever fired
- **`schedulable` field** on the action catalogue, plus the four orphan actions it exposed
- Docker healthchecks on all ten services, chosen per service rather than copied
- Onboarding documentation for Kubernetes, VM and bare metal (`docs/connect-quickstart.md`)

### Fixed
- **The chart's recommended mode collected nothing** — `kubectl` does not implement in-cluster
  configuration (that is client-go), so a pod with only a ServiceAccount fell back to
  `localhost:8080` and reported an empty cluster without an error. Found on a real kind cluster,
  not in nineteen green commits
- **vSphere returned zeros instead of saying it could not read** — `/api/session` (7.0 U2+) and
  `/rest/com/vmware/cis/session` (6.5–7.0) are two dialects; the collector now speaks both and
  marks an unreachable hypervisor unreachable rather than empty
- **A cluster name is a routing address, so it must be unique** — two gateways could claim the
  same name and job routing depended on row order
- 22 console automations proposed actions the policy engine refused; the four orphan actions and
  the four agent aliases that named actions core does not accept
- `scale_node_group` verification accepted the configured count immediately on all three clouds;
  it now requires the node count *and* a settled state
- e2e tests carried an absolute path from a developer's machine

---

## [0.43.0] — 2026-09-18

### Added
- **A local boundary on what a gateway will execute** — `connect/allowlist.py` derives the
  allowed actions from the installed connector library rather than a hand-maintained list
  (ADR 0042 decision 4). Core checks its policy before assigning a job; this is the gate that
  still holds if core is wrong, if a token leaks, or if someone posts to the gateway's queue
- **Network discovery moved into the client the customer actually deploys** (ADR 0042)
- The 29 kubectl actions relayed through the connector library

### Changed
- **One gateway client** (ADR 0042) — the repository had two words for "gateway" and two
  programs answering to it. `gateway/` keeps the OpenAI-compatible façade; the relay is gone

### Fixed
- The two publication paths built different images

---

## [0.42.0] — 2026-09-17

### Added
- **Bare metal, read-only** (ADR 0040) — a `RedfishConnector`, declared inventory, BMC
  recognition in network discovery, four agent read tools, a simulated BMC for developing
  without hardware, and a Bare Metal sub-tab in the console
- **Post-action verification** (ADR 0038) — destructive actions declare how they can be proved,
  the loop enforces the proof, and a failed verification returns the evidence rather than a
  bare refusal
- **External identity to rights** (ADR 0041) — a reconciliation service, a mapping API, and a
  single place where rights are written
- Automatic HTTPS in the installer via `--domain`, with an explicit warning when it is absent
- The three MIG tools restored, with the proof of what they permit

### Changed
- **`agent_service.py` reduced from 6,505 to 110 lines of dispatcher** across ten refactors —
  the tool catalogue, VM operations, the incident family, hypervisor tools, job lifecycle,
  PromQL presets and 37 direct HTTP calls each moved to their own module or routing table.
  Pinned first by characterization tests (`_execute_tool` at 100% of lines, `chat_stream` from
  1% to 99%)

### Fixed
- **Twenty agent tools the PolicyEngine refused**, and the CI invariant that should have caught
  them; every agent scaling path returned 403
- **Six compliance frameworks the agent announced did not exist**; `generate_compliance_report`
  offered two types core refuses; a citation could be written but never withdrawn; CC7.4 cried
  tampering on an intact chain
- Three verification defects found against a real cluster, not in tests
- Twenty-two silent exception swallowers in the agent now log
- `check-tool-parity` read TOOLS from the wrong file, so it had been comparing nothing
- Administrator credentials removed from the seed scripts
- A read failure displayed as an empty inventory; an empty Clusters tab showed a wall of zeros

---

## [0.41.5] — 2026-09-13

### Fixed
- **Morning briefing failed every day at 07:00 UTC** — `briefing_task.py` issued its
  service token with `"teams": ["ops"]`, a list of strings, while the decoder builds a
  `TeamInfo` per entry and reads `t["id"]`. Every call answered 500 with
  `TypeError: string indices must be integers`. It was the last issuer left on the old
  format; d3ae927 had fixed the console and agent ones
- Release images were pushed without the `v` prefix (`vibops-core:0.41.4`) while
  `install/docker-compose.yml` and `install.sh` reference `${VIBOPS_VERSION:-vX.Y.Z}` —
  a fresh install could not resolve its images
- Release notes advertised `docker pull ghcr.io/vibopsai/vibops-*`, a namespace that
  does not exist

### Added
- `vibops.ai` is now published automatically. The site is served by GitHub Pages from
  `VibOpsai/vibopsai.github.io` and no workflow fed it: on 13/09 it still served v0.41.3,
  three days after the images shipped, so every fresh install deployed a stale version

### Changed
- CI spend cut from roughly 2200 to 800 minutes per week: `linux/arm64` dropped from
  release builds (nobody pulled those images — local development on Apple Silicon
  compiles natively), a `concurrency` group added to `ci.yml` (pull requests only, so
  every commit landing on main is still verified), and `deploy.yml` restricted to tags
  (it published `:main` and `:sha-` images that nothing consumes)

---

## [0.41.4] — 2026-09-13

### Fixed
- **Agent unusable with generation-5 models** — `_thinking_params()` only switched to
  adaptive thinking for fable/mythos; every other model got the removed
  `{"type": "enabled", "budget_tokens": N}` form and the API answered
  `400 thinking.type.enabled is not supported`. Adaptive is now the default;
  `budget_tokens` is reserved for Haiku 4.5 and pre-4.6 generations
- Six CVEs in `httpx2` / `httpcore2` (PYSEC-2026-3844 … 3849) — the `anyio==4.7.0` pin
  forced the resolver down to `httpx2 2.6.0`; `anyio` raised to 4.15.1 and
  `httpx2==2.12.0` pinned explicitly
- Five hardcoded versions in Python code, including the FastAPI `version=` that feeds
  `docs/openapi.json` — the published contract announced 0.25.0
- `sync-mcp` and `publish-install` targeted `github.repository_owner` instead of the
  `VibOpsai` org; `sync-mcp` additionally had `actions/checkout` credentials overriding
  the push token. Both public repos had been stale since 06–08/09, `publish-install`
  silently green while publishing to the wrong target
- Orphan `landing` gitlink (mode 160000, no `.gitmodules`, unreachable commit) breaking
  every `git submodule` call
- `anthropic` imported by `core/app/workers/eval_task.py` but never declared — the worker
  raised `ImportError` when used with `provider=claude`

### Added
- `THINKING_EFFORT` (`low` → `max`) exposing `output_config.effort`, the replacement for
  the now-inert `thinking_budget_tokens`
- `scripts/bump-version.sh` — updates the 18 version locations in one command;
  `--check` enforces consistency and gates the CI `lint` job
- CHANGELOG entries for 0.40.0 → 0.41.3, previously undocumented (177 commits)

### Changed
- `anthropic` SDK 0.49.0 → 1.5.0 (HTTP layer moved to `httpx2`)
- Vendor-neutral naming outside the provider layer — audit actor `claude-agent` →
  `vibops-agent` (rows written earlier keep the old value; the console filter accepts
  both), API defaults aligned on the database (`provider="vibops"`), 22 comments reworded
- Default model `claude-sonnet-4-6` → `claude-sonnet-5` (current generation, and cheaper)

---

## [0.41.3] — 2026-09-12

### Added
- HPE VME (Morpheus) connector — inventory, lifecycle, snapshots, migration, waste
  (20 agent tools, 13 MCP tools)
- Xen Orchestra connector enriched — V2V migration, backup/restore, storage, tasks, rolling update
- Full hypervisor context in the agent — V2V migration, XO backup, VME conversion, tool routing
- Multi-framework compliance — 19 regulatory frameworks, `seed_compliance_controls` tool,
  agent rule 22 (auto-seed when a framework has 0 items)
- VibOps Connect job relay — poll, claim, execute, report
- Cold install — install script and production compose, Caddy reverse proxy
  (only ports 80/443 exposed)
- ADR 0035 (Compliance Agent), 0036 (Connect standalone Go binary),
  0037 (Connect security hardening: whitelist, mTLS, token rotation, rate limit)
- `scripts/bump-version.sh` — updates all 13 version locations in one command;
  `--check` enforces consistency (wired into CI)
- Network architecture docs (3 deployment modes: Cloud / Hybrid / Sovereign)
  and Tersedia POC dossier

### Changed
- Counts updated: 36 connectors, 304 agent tools, 117 MCP tools, 242 API routes
- Versions aligned on 0.41.3 across the monorepo — Python packages still declared
  0.25.0 / 0.31.0 / 0.1.0 while images shipped as 0.41.x
- `connectors/build/` is no longer tracked (setuptools output)
- Connect heartbeat uses `httpx.Client` for mTLS certificate support

### Fixed
- `console_data` volume — conversations persist across restarts
- Install wizard: email channel with recipients only, Alpine variable names,
  Next/Skip button state, webhook subscription path
- Secrets written as upsert — no more duplicate key error on wizard retry
- `install.sh` generates `AUTH_PASSWORD_HASH`, `AUTH_USERNAME`, `GITHUB_WEBHOOK_SECRET`
  and `GRAFANA_WEBHOOK_SECRET`
- Caddyfile mounted instead of runtime env var interpolation
- `COMPOSE_URL` points to vibops.ai instead of the private GitHub repo
- VME and XO V2V tool functions lost during a merge, restored
- AI Act update endpoint corrected to `/compliance/ai-act/{id}`

---

## [0.41.2] — 2026-09-08

### Fixed
- `crypto.randomUUID` fallback for non-HTTPS contexts (HTTP deployments)

---

## [0.41.1] — 2026-09-08

### Added
- Agent rule 21 POST-DEPLOY — suggests the service URL after a successful deployment
- `gateway` and `beat` images added to the release-images workflow

### Fixed
- Agent scoped token must carry the admin role for destructive actions
- 409 confirmation handled in `run_job`; `deploy_webapp` added to TOOL_CATALOG
- `get_live_workload_cost` always tried first for workload queries
- K8s gateway excluded from `prometheus_url` — prevents false workload termination

---

## [0.41.0] — 2026-09-06 — Harness Runtime complete

### Added
- Harness Runtime — trigger chaining and agent lifecycle
- Sequential agent execution — steps run in order and stop on failure
- Schedule builder — dropdowns replace raw cron input, existing cron parsed back into the form
- Smart action picker — 24 recommended actions with auto-fill
- Inline trigger editing, step reordering (▲▼), agent creation from the Agents tab
- Harness Integrity CI job — tool parity and i18n checks on every push

### Changed
- OpenAPI spec regenerated (205 routes)
- GHCR push uses `GITHUB_TOKEN` instead of `VIBOPSAI_PAT`

### Fixed
- `/triggers/agents` routes moved before `/triggers/{rule_id}` — fixes 405/404
- Agent routes are `/agents`, not `/triggers/agents` — Core mounts without prefix
- Triggers with null `org_id` honoured in dev mode (list/start/stop, assign)
- The same trigger may now belong to several agents
- Numerous Automations UI fixes — dropdown width and opacity, form layout, tab order

---

## [0.40.0] — 2026-09-06 — Harness OpContract Phase 1

### Added
- Harness OpContract Phase 1 — cross-surface operational integrity (ADR 0032),
  rules 7–10 (output, permission, i18n, gateway version) and agent rule 16
  PERMISSION DENIED (explicit 403 messaging)
- `scripts/seed-dev.sh` — populates the full demo dataset in one command
- `validate-seed.sh` — 12 coherence checks across fleet, finops and alerts
- `check-gateway-compat.sh` — N-1 heartbeat payload replay test
- Endpoint audit — exercises all 254 OpenAPI routes looking for 500s, run on version tags
- E2E pipeline tests — 76 tests across 7 stages
- FinOps infra tools for the agent; budget forecast now includes waste
- CloudSigma demo seed, VibOps Connect guides, *Infrastructure as Agents* product vision
- Automatic `mcp/` → VibOpsai/vibops-mcp sync on version tags

### Changed
- ADRs renumbered — 0032 Harness OpContract, 0033 Topology Graph, 0034 Agentic Graph
  (duplicate 0021/0022 resolved)
- Switched to 30s polling, informers deferred to Level 2b (ADR 0021)
- `core/docker-compose.yml` renamed to `docker-compose.test.yml` — removes compose context confusion
- Nightly Playwright E2E paused; E2E pipeline restricted to version tags

### Fixed
- Budget data coherence — live GPU + VM spend, pro-rated MTD, idempotent seed
- VM spend uses `vm_cost_usd` instead of `customer_cost_usd` — prevents GPU double counting
- Waste computed per cluster via ClusterRate, recommendations generated per idle GPU
- Workload sync keys off `collection_succeeded` instead of a snapshot count
- Migration rewritten for clean installs — idempotent creation, CI drift resolved
- Login accepts username **or** email
- Dev mode counts as an enterprise licence — no GPU/cluster limits
- `vm-usage` crash when `gpu_passthrough` is a bool instead of a list

---

## [0.39.0] — 2026-09-02

### Security
- Fix cross-org data leak in discovery endpoint — org_id filter always applied
- Add rate limiting on LDAP login (10/min) and OIDC callback (10/min)
- Replace Docker socket direct mount with Tecnativa socket proxy
- Remove hardcoded PostgreSQL password in core/docker-compose.yml
- Add Redis authentication in core/docker-compose.yml
- Reject default JWT secret for all non-development environments
- Add kubectl verb allowlist in MCP layer (blocks exec, delete, apply, cp, etc.)
- Add kubeconfig content validation — reject internal/metadata IPs
- Invalidate refresh tokens on password change (phash fingerprint)
- Fix X-Forwarded-For trust to use RFC 1918 ipaddress.is_private
- Fix notification channels query to scope by org_id (cross-tenant leak)
- Fix SSO/LDAP re-login to load actual roles/teams from DB
- Replace blanket is_org_admin on service JWTs with service_account claim
- Sanitize i18n HTML strings through DOMPurify
- Move cursor span inside DOMPurify.sanitize() in chat panel
- Add auth (Depends(verify_token)) to gateway /v1/models endpoint
- Add Slurm script content validation (block curl|sh, rm -rf, etc.)
- Validate LLM proxy backend URLs against configured allowlist
- Fix path traversal in export_dataset via org_id sanitization
- Remove os.environ writes for API keys in agent config endpoint
- Add 10MB body size limit on LLM proxy inference endpoints
- Pin Docker images: Prometheus v3.4.0, Grafana 11.6.0, Ollama 0.9.0
- Bind internal ports to 127.0.0.1 (llm-proxy, prometheus, grafana, gpu-sim, ollama, worker)
- Add kubectl_exec to SHELL_SENSITIVE_TOOLS guardrails
- Refactor Fernet helpers to shared _get_fernet() (SSO, LDAP, SIEM)
- Fix kubeconfig temp file permissions to 0o600

### Changed
- Service-to-service JWTs use `service_account: true` instead of `is_org_admin: true`
- LLMClient accepts override_settings parameter for isolated testing
- Gateway heartbeat temp file moved from /tmp to /var/lib/vibops
- Network discovery uses configurable SSL context (respects VERIFY_SSL)
- MCP tool count comments updated to match actual registrations

### Fixed
- Budget endpoints use db.commit() instead of db.flush() (data persistence)
- Audit export uses output_format parameter (no longer shadows format builtin)
- Alert correlation SQL uses parameterized interval (no string interpolation)
- asyncio.get_running_loop() replaces deprecated get_event_loop()
- Empty kubectl command returns error instead of sending to API
- LLMClient._thinking_params uses self._settings (not global singleton)
- Agent test_config endpoint correctly imports settings instance
- MCP push_to_siem sends filter params as JSON body (not query string)
- MCP version aligned between __init__.py (0.25.0) and pyproject.toml

### Removed
- 14,600 lines of dead code: stale static/index.html, vibops.js.bak
- 31 unregistered MCP ghost functions moved to _unreleased.py
- Hardcoded login_alert_email default removed
- Unused os import in agent config endpoint

---

## [0.38.0] — 2026-08-31

### Added
- **Scheduled triggers (cron)** — cron expressions in trigger rules, evaluated every 60s via croniter
- **LLM Provider config UI** — Settings → Operations → switch Claude/OpenAI-compatible/Ollama with test connection
- **VMs admin sub-tab** — Settings → Infrastructure → connected hypervisors, cluster status, discovered services
- **Dynamic action autocomplete** — trigger form searches 266 actions live
- **Fleet → VMs empty state** — Connect Hypervisor CTA when no VMs connected
- **Network discovery toast** — real-time notifications when gateway discovers Proxmox/vSphere/K8s
- **LLM tab in nav** — Ollama + NIM management exposed in main navigation
- **VM Chargeback UI** — FinOps section with generate button and per-VM breakdown table
- **45 console UI tests** — template + JS module coverage for all new features
- **11 API tests** — scheduled triggers + VM chargeback endpoints
- **`require_org_admin`** dependency in agent auth module

### Changed
- Landing page restructured — 40% shorter, VMs included, 3 clear segments (Cloud Providers, Integrators, Enterprises)
- Automations tab exposed in main nav (was orphaned)
- Network Discovery panel visible when any gateway connected (not only when services found)
- Trigger list shows cron expression for scheduled rules
- "Datadog metric" label → "Metric query" in triggers form (en + fr)
- Agent Tools button removed from Settings Governance (Tool Policy covers it)
- Console `</body>` tag added (was missing)

### Fixed
- **CRITICAL: Trigger jobs missing org_id** — tenant isolation restored for trigger-created jobs
- **CRITICAL: Agent config privilege escalation** — PUT/POST now require org_admin (was any user)
- **HIGH: IDOR via is_org_admin bypass** — removed from triggers, jobs, pipelines (6 locations)
- **HIGH: SSRF on prometheus_url** — block 169.254.*/metadata IPs
- **MEDIUM: Race condition in test_config** — asyncio lock prevents concurrent env var mutation
- LLM tab: `loadOllama()` → `loadLlm()` (was broken)
- Escape handler: dead `showAdminPanel` ref → proper activeTab check
- Fleet state variables: 6 missing Alpine.js reactive vars added to init.js
- i18n: settings_close/settings_title defaults, agents drawer French → t() calls
- i18n: LDAP login + setup form strings internationalized
- Duplicate fleetSearch/kubeContexts declarations removed
- Gateway registration: error toast on failure (was empty catch)
- Console auth: "Token invalide" → "Invalid token"
- KPI bar grid layout in Fleet → VMs restored (x-if instead of x-show)

### Security
- Backend audit: 2 CRITICAL + 3 HIGH + 2 MEDIUM findings fixed
- Front-end audit: 3 CRITICAL + 3 HIGH + 4 MEDIUM findings fixed
- XSS protection verified (DOMPurify on all x-html)
- CSRF token handling verified
- Cookie security verified (httpOnly, secure, sameSite)

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
