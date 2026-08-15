# VibOps — Incident Response Runbook

_Last updated: 2026-08-07 · v0.28.0_

---

## Overview

This runbook covers diagnosis and resolution of the most common VibOps production incidents. It complements the alerting rules in `alerting_rules.yml` and the backup/restore procedures in `backup-restore.md`.

**Escalation path:** on-call operator → platform team → `#vibops-incidents` Slack channel

---

## Alerting Rules Reference

| Alert | Condition | Severity |
|-------|-----------|---------|
| `VibOpsCoreDown` | Core API unreachable for >1min | Critical |
| `VibOpsHighJobFailureRate` | >10% job failures over 5min | Warning |
| `VibOpsBudgetHardCapBreached` | HTTP 429 on `/jobs` (budget cap hit) | Warning |

---

## 1. Core API Down (`VibOpsCoreDown`)

### Symptoms
- Console shows "Impossible de joindre le Core"
- `GET /api/v1/health` returns non-200 or times out
- All agent tool calls fail

### Diagnosis

```bash
# Check service status
docker compose ps core

# Check recent logs
docker compose logs --tail=50 core

# Check database connectivity
docker compose exec core python -c "from app.database import engine; import asyncio; asyncio.run(engine.connect())"

# Check Redis connectivity
docker compose exec core python -c "import redis; r=redis.from_url('redis://redis:6379'); r.ping()"
```

### Resolution

```bash
# Restart core service
docker compose restart core

# If DB migration issue (table missing / constraint error in logs)
docker compose exec core alembic upgrade heads

# If Redis connection pool exhausted
docker compose restart redis

# Full stack restart (last resort)
docker compose down && docker compose up -d
```

---

## 2. High Job Failure Rate (`VibOpsHighJobFailureRate`)

### Symptoms
- Grafana API SLO dashboard shows failure spike
- Users report jobs stuck in FAILED state
- Alert fires: >10% failures over 5 minutes

### Diagnosis

```bash
# List recent failed jobs (replace with your org_id)
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/jobs?status=failed&limit=20"

# Check Celery worker status
docker compose exec worker celery -A app.workers.celery_app inspect active
docker compose exec worker celery -A app.workers.celery_app inspect reserved

# Check worker logs
docker compose logs --tail=100 worker

# Check if workers are alive
docker compose exec core curl -s http://localhost:8000/api/v1/health | jq .worker
```

### Common causes and fixes

**Connector CLI missing (kubectl, helm…)**
```bash
# Verify CLI in gateway
docker compose exec gateway kubectl version --client
```

**Worker memory drift (restart after max_tasks_per_child)**
```bash
docker compose restart worker
```

**Gateway offline (jobs routing to unreachable cluster)**
```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/v1/gateways
# Check last_ping_at — if >5min, gateway is offline
```

**Secret resolution failure (credentials missing or rotated)**
```bash
# Check audit log for secret errors
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/audit?limit=20"
```

---

## 3. Budget Hard Cap Breached (`VibOpsBudgetHardCapBreached`)

### Symptoms
- HTTP 429 on `POST /jobs`
- Users report "budget exceeded" errors
- Alert fires on repeated 429s

### Diagnosis

```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/v1/finops/budget
# Check: spend_forecast_eom_usd vs budget amount, is_hard_cap_exceeded
```

### Resolution

**Option 1 — Increase budget (org_admin required)**
```bash
curl -X PUT -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"amount_usd": 5000, "soft_cap_pct": 80, "hard_cap_pct": 100}' \
  http://localhost:8000/api/v1/finops/budget
```

**Option 2 — Generate chargeback report then reset**
```bash
YEAR=$(date +%Y); MONTH=$(date +%m)
curl -X POST -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/finops/chargeback/$YEAR/$MONTH/generate"
```

---

## 4. Worker Down / No Active Workers

### Symptoms
- `GET /api/v1/health` returns `{"worker": {"status": "offline", "active_workers": 0}}`
- Jobs stay in `pending` state indefinitely

### Resolution

```bash
docker compose restart worker beat

# Verify
curl http://localhost:8000/api/v1/health | jq .worker
```

---

## 5. Database Issues

### PostgreSQL connection refused

```bash
docker compose ps postgres
docker compose logs postgres --tail=30

# If disk full — check backup volume
df -h

# Restart
docker compose restart postgres
# Wait 10s for readiness
sleep 10 && docker compose restart core worker beat
```

### Migration failure at startup

```bash
# Check which migration failed
docker compose exec core alembic current
docker compose exec core alembic history --verbose | head -20

# Apply manually
docker compose exec core alembic upgrade heads
```

### Table locked / deadlock

```bash
# Check active queries
docker compose exec postgres psql -U vibops -c \
  "SELECT pid, state, query, wait_event_type, wait_event FROM pg_stat_activity WHERE state != 'idle';"

# Terminate stuck query (replace PID)
docker compose exec postgres psql -U vibops -c "SELECT pg_terminate_backend(PID);"
```

---

## 6. Agent / LLM Issues

### Agent not responding (tool calls timing out)

```bash
docker compose logs agent --tail=50

# Check LLM provider connectivity
docker compose exec agent python -c "
import asyncio, httpx
async def check():
    async with httpx.AsyncClient(timeout=10) as c:
        r = await c.get('http://ollama:11434/api/tags')
        print(r.status_code, r.text[:200])
asyncio.run(check())
"
```

### Memory context corrupted

```bash
# Clear agent memories for org (org_admin)
curl -X DELETE -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/memories/KEY_NAME"
```

---

## 7. Gateway Connectivity Issues

### Gateway offline (last_ping_at stale)

```bash
# On the gateway host
docker compose -f docker-compose.gateway.yml logs gateway --tail=50

# Check connectivity from gateway to core
curl -k https://CORE_URL/api/v1/health

# Re-register gateway (if token lost)
bash scripts/connect-setup.sh
```

### Gateway cancels all jobs on delete

This is expected behavior — deleting a gateway cancels all PENDING/RUNNING jobs targeting it. Use `POST /gateways` to register a replacement.

---

## 8. Redis Issues

### Connection pool exhausted

```bash
docker compose logs redis --tail=30
docker compose restart redis
sleep 5
docker compose restart core worker beat
```

### Celery tasks stuck in queue

```bash
# Inspect queue length
docker compose exec redis redis-cli llen celery

# Purge stuck tasks (CAUTION: data loss)
docker compose exec worker celery -A app.workers.celery_app purge
```

---

## Post-Incident Checklist

- [ ] Root cause identified and documented
- [ ] Affected jobs rerun or cancelled explicitly
- [ ] Alerting rule confirmed firing and resolved
- [ ] Incident timeline noted in `#vibops-incidents`
- [ ] If data integrity concern: trigger backup (`make backup-now`) and verify restore
- [ ] If auth-related: rotate `SECRET_KEY` and `INTERNAL_API_KEY`, restart all services
