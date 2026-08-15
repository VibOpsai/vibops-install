# VibOps — Security Incident Response Runbook

_Last updated: 2026-06-19 · v0.18.0_

> **Scope:** This runbook covers security incidents only. For operational incidents (API down, job failures, budget breaches) see `incident-response.md`.

---

## Severity Classification

| Severity | Definition | Response SLA |
|----------|-----------|-------------|
| **P0** | Active breach, confirmed data exfiltration, credentials compromised, ransomware | Immediate — wake everyone |
| **P1** | Suspected intrusion, anomalous access patterns, CVE actively exploited in production, unauthorized privilege escalation | < 30 min |
| **P2** | Failed attack attempt, vulnerability discovered but not yet exploited, suspicious but inconclusive activity | < 4 h |
| **P3** | Security policy violation, misconfiguration found, dependency with known CVE (unexploited) | Next business day |

---

## Notification Matrix

| Severity | Who to notify | How | Within |
|----------|--------------|-----|--------|
| P0 | On-call + CTO + Legal + all org admins of affected tenants | Phone + `#vibops-security` Slack + email | 15 min |
| P1 | On-call + engineering lead + affected org admins | `#vibops-security` Slack + phone | 30 min |
| P2 | On-call + engineering lead | `#vibops-security` Slack | 4 h |
| P3 | On-call engineer | `#vibops-incidents` Slack ticket | Next business day |

---

## First 15 Minutes — All Severities

### 1. Declare and assign

```
IC (Incident Commander): ______________
Scribe (takes timestamped notes): ______________
Start time (UTC): ______________
```

Announce in `#vibops-security`: `@here SEC-INCIDENT P[X] declared — IC is @name — bridge: [link]`

### 2. Preserve evidence before touching anything

```bash
# Snapshot current audit log (last 500 entries) to a file before any state changes
TOKEN="<admin-jwt>"
curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/audit?limit=500" \
  > /tmp/incident-audit-$(date +%Y%m%dT%H%M%S).json

# Verify audit chain integrity FIRST — confirms logs haven't been tampered with
curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/audit/verify?limit=1000" \
  > /tmp/incident-audit-verify-$(date +%Y%m%dT%H%M%S).json

# Capture container logs before any restart
docker compose logs --no-color > /tmp/incident-docker-$(date +%Y%m%dT%H%M%S).log 2>&1

# Save current DB snapshot (non-destructive)
make backup-now   # or: docker compose exec postgres pg_dump -U vibops vibops_db > /tmp/incident-db-snapshot.sql
```

### 3. Contain (P0/P1 only)

- If active breach is confirmed: **revoke JWT signing key immediately** (see "Rotate JWT_SECRET_KEY" below) — this logs out every active session.
- If a specific account is compromised: force-lock the account (see "Manual Account Lockout" below).
- If a gateway is compromised: delete it via API — this cancels all its pending/running jobs and disconnects it.

```bash
# Delete a compromised gateway
curl -X DELETE -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/gateways/<gateway_id>"
```

---

## Investigation Steps — VibOps Specific

### Pull Audit Logs

```bash
TOKEN="<admin-jwt>"

# Full audit log (most recent first)
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/audit?limit=500"

# Filter by user
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/audit?actor=<username>&limit=200"

# Filter by action type (e.g., secrets, policy changes)
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/audit?action=secret.read&limit=200"

# Filter by time window
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/audit?since=2026-06-19T00:00:00Z&limit=500"
```

### Verify Audit Chain Integrity

```bash
# Verify HMAC chain of the 1000 most recent signed audit entries
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/audit/verify?limit=1000"

# Response: {"ok": true, "verified": 1000} or {"ok": false, "first_broken_at": <index>, ...}
# A broken chain means audit logs have been tampered with — escalate to P0 immediately.
```

### Check Active Sessions / Who Is Logged In

VibOps does not maintain a server-side session table — JWTs are stateless (2h TTL). To invalidate all active sessions:

```bash
# Option 1: Rotate JWT_SECRET_KEY (invalidates ALL sessions immediately)
# See secret-rotation.md → JWT_SECRET_KEY section

# Option 2: Check recent logins in the audit log
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/audit?action=auth.login&limit=100"

# Option 3: Check for agent machine identities (long-lived keys)
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/agent-identities"
# Revoke any suspicious agent identity immediately
curl -X DELETE -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/agent-identities/<identity_id>"
```

### Manual Account Lockout

```bash
# Lock an account immediately via direct DB (emergency only — bypasses API)
docker compose exec postgres psql -U vibops -c \
  "UPDATE users SET locked_until = NOW() + INTERVAL '999 days', \
   failed_login_attempts = 99 \
   WHERE username = '<username>';"

# Verify lockout
docker compose exec postgres psql -U vibops -c \
  "SELECT username, locked_until, failed_login_attempts FROM users WHERE username = '<username>';"

# Unlock when safe
docker compose exec postgres psql -U vibops -c \
  "UPDATE users SET locked_until = NULL, failed_login_attempts = 0 \
   WHERE username = '<username>';"
```

Note: Normal lockout is automatic after 5 failed login attempts → 15-minute lock (`core/app/api/v1/auth.py` line 184).

### Check Docker Container Logs

```bash
# All services, last 200 lines
docker compose logs --tail=200

# Specific service
docker compose logs --tail=200 core
docker compose logs --tail=200 worker
docker compose logs --tail=200 gateway

# Follow in real time
docker compose logs -f core

# Search for specific patterns
docker compose logs core 2>&1 | grep -i "403\|401\|unauthorized\|forbidden\|secret\|error"
```

### Check for Unusual API Activity

```bash
# Unusual secret reads
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/audit?action=secret.read&limit=100"

# Policy changes
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/audit?action=policy.update&limit=50"

# User creation / role changes
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/audit?action=user.create&limit=50"

# Check current policy state (detect unauthorized policy relaxation)
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/policy"
```

### Check for Anomalies (AI-Detected)

```bash
# Open anomalies in the fleet
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/anomalies?status=open"
```

---

## P0 — Active Breach

### Immediate Actions (first 15 min)

1. Declare P0, assign IC and scribe.
2. Preserve evidence (see above).
3. Rotate `JWT_SECRET_KEY` → all sessions invalidated immediately.
4. Rotate `INTERNAL_API_KEY` → service-to-service calls drop until restarted.
5. Lock any confirmed-compromised accounts (DB direct).
6. Disconnect compromised gateways (API delete).
7. Notify Legal and affected tenant org admins.

### Investigation

- Pull full audit log; look for exfiltration patterns (bulk `secret.read`, unusual `kubectl exec`, large data downloads).
- Verify audit chain — a broken chain is itself a major finding.
- Check for new agent identities created without authorization.
- Review all policy changes in the last 30 days.
- Check container logs for outbound connections.

### Recovery

1. Once containment is confirmed, rotate all secrets per `secret-rotation.md`.
2. Review and tighten policy (`GET /api/v1/policy` → `PUT /api/v1/policy`).
3. Re-enable services one by one, verifying health at each step.
4. Issue new credentials to legitimate users.

### Post-Incident Report (required within 72 h for P0)

- Timeline of events (UTC timestamps)
- Root cause
- Data accessed / exfiltrated (scope)
- Containment actions taken
- Recovery actions taken
- Regulatory notification requirements (GDPR: 72h if personal data involved)
- Remediation plan with owners and dates

---

## P1 — Suspected Intrusion / Exploited CVE

### First 30 Minutes

1. Preserve evidence.
2. Identify the specific CVE or anomalous accounts.
3. If CVE: check if exploit is confirmed in logs vs. attempted.
4. Restrict access to the affected component if possible without full outage.
5. Begin investigation (audit log, container logs).

### Investigation

- Correlate audit log entries with anomalous times.
- Check CVE details: which endpoint/library? Search logs for exploit signatures.
- Review all actions taken by suspicious user/IP in audit log.

### Recovery

- Patch the CVE (update dependency, redeploy).
- Rotate credentials for any secrets that may have been exposed.
- Monitor closely for 48 h post-remediation.

### Post-Incident Report (required within 24 h)

- Same template as P0, shorter — focus on whether data was accessed.

---

## P2 — Failed Attack / Unexploited Vulnerability

### Actions (within 4 h)

1. Log the attempt in `#vibops-security` with details.
2. If vulnerability: open a private issue, assign patch SLA per security policy.
3. Check audit log for any other attempts from the same source.
4. Consider rate-limit or block the source IP at the load balancer.

### Post-Incident Report (within 48 h)

- Brief summary: what was attempted, why it failed, what was found.
- Remediation ticket reference.

---

## P3 — Policy Violation / Misconfiguration

### Actions (next business day)

1. Document the misconfiguration.
2. Correct it and verify.
3. Determine if any data was exposed as a result.
4. Add a check to CI or deployment scripts to prevent recurrence.

---

## Communication Templates

### Initial Notification (P0/P1)

```
Subject: [SECURITY INCIDENT P0/P1] VibOps — <brief description>

We are responding to a security incident affecting VibOps infrastructure.

Status: ACTIVE INVESTIGATION
Incident Commander: <name>
Started: <UTC timestamp>

What we know: <1-2 sentences>
Actions taken: <list>
Next update: in <30/60> minutes

Do NOT discuss details outside this thread.
```

### Tenant Notification (P0 — data may be affected)

```
Subject: Security Incident Notification — VibOps

Dear <Org Name> team,

We are writing to inform you of a security incident that may have affected your VibOps environment.

Details of what occurred: <description>
Data potentially involved: <scope>
Actions we have taken: <list>
Actions you should take: [change passwords, rotate API keys, etc.]

We will provide a full incident report within 72 hours.

Contact: security@vibops.ai
```

### All-Clear Notification

```
Subject: [RESOLVED] Security Incident — VibOps

The security incident declared at <timestamp> has been resolved.

Root cause: <summary>
Duration: <start> to <end> UTC
Impact: <scope>
Remediation: <actions taken>

Full post-incident report: <link>
```

---

## Contact List Template

> Fill this in before you need it.

| Role | Name | Phone | Slack |
|------|------|-------|-------|
| On-call engineer | | | |
| Engineering lead | | | |
| CTO | | | |
| Legal / DPO | | | |
| Cloud provider security | | | |

---

_See also: `backup-restore.md`, `secret-rotation.md`, `../security-policy.md`_
