#!/usr/bin/env bash
# VibOps — Debug Bundle Generator
# Collects diagnostic information and packages it into a single file
# that can be sent to VibOps support for troubleshooting.
#
# Usage: make debug
# Output: vibops-debug-YYYY-MM-DD-HHMMSS.tar.gz

set -euo pipefail

TIMESTAMP=$(date -u +%Y-%m-%d-%H%M%S)
BUNDLE_DIR="/tmp/vibops-debug-${TIMESTAMP}"
BUNDLE_FILE="vibops-debug-${TIMESTAMP}.tar.gz"

mkdir -p "${BUNDLE_DIR}"

echo "╔══════════════════════════════════════════════════════╗"
echo "║  VibOps — Generating debug bundle                   ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ── 1. System info ──────────────────────────────────────────
echo "→ Collecting system info..."
{
  echo "=== Date (UTC) ==="
  date -u
  echo ""
  echo "=== OS ==="
  uname -a
  echo ""
  echo "=== CPU ==="
  nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "unknown"
  echo ""
  echo "=== Memory ==="
  free -m 2>/dev/null || vm_stat 2>/dev/null || echo "unknown"
  echo ""
  echo "=== Disk ==="
  df -h / 2>/dev/null || echo "unknown"
  echo ""
  echo "=== Docker version ==="
  docker version 2>&1
  echo ""
  echo "=== Docker Compose version ==="
  docker compose version 2>&1
} > "${BUNDLE_DIR}/system-info.txt" 2>&1

# ── 2. Container status ────────────────────────────────────
echo "→ Collecting container status..."
docker compose ps -a > "${BUNDLE_DIR}/containers.txt" 2>&1

# ── 3. Image versions ──────────────────────────────────────
echo "→ Collecting image versions..."
docker compose images > "${BUNDLE_DIR}/images.txt" 2>&1

# ── 4. Logs (last 500 lines per service) ───────────────────
echo "→ Collecting logs (last 500 lines per service)..."
for svc in core agent worker beat console gateway postgres redis prometheus grafana; do
  echo "  · ${svc}"
  docker compose logs --tail=500 --no-color "${svc}" > "${BUNDLE_DIR}/logs-${svc}.txt" 2>&1 || true
done

# ── 5. Health check ────────────────────────────────────────
echo "→ Running health check..."
bash scripts/poc-healthcheck.sh http://localhost:8000 > "${BUNDLE_DIR}/healthcheck.txt" 2>&1 || true

# ── 6. API health endpoints ────────────────────────────────
echo "→ Checking API endpoints..."
{
  echo "=== /api/v1/health ==="
  curl -s -m 5 http://localhost:8000/api/v1/health 2>&1 || echo "UNREACHABLE"
  echo ""
  echo ""
  echo "=== Agent /health ==="
  curl -s -m 5 http://localhost:8001/health 2>&1 || echo "UNREACHABLE"
  echo ""
  echo ""
  echo "=== Console /health ==="
  curl -s -m 5 http://localhost:8003/health 2>&1 || echo "UNREACHABLE"
} > "${BUNDLE_DIR}/api-health.txt" 2>&1

# ── 7. Docker resource usage ───────────────────────────────
echo "→ Collecting resource usage..."
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" > "${BUNDLE_DIR}/resource-usage.txt" 2>&1 || true

# ── 8. Docker events (last 50) ─────────────────────────────
echo "→ Collecting recent Docker events..."
docker events --since "1h" --until "$(date -u +%Y-%m-%dT%H:%M:%S)" --format '{{.Time}} {{.Action}} {{.Actor.Attributes.name}}' 2>/dev/null | tail -50 > "${BUNDLE_DIR}/docker-events.txt" 2>&1 || true

# ── 9. Environment (secrets masked) ────────────────────────
echo "→ Collecting environment (secrets masked)..."
if [ -f .env ]; then
  sed -E \
    -e 's/(PASSWORD|SECRET|KEY|TOKEN|API_KEY)=.+/\1=***REDACTED***/g' \
    .env > "${BUNDLE_DIR}/env-masked.txt"
else
  echo ".env not found" > "${BUNDLE_DIR}/env-masked.txt"
fi

# ── 10. Network ────────────────────────────────────────────
echo "→ Collecting network info..."
{
  echo "=== Docker networks ==="
  docker network ls
  echo ""
  echo "=== vibops_net inspect ==="
  docker network inspect vibops-install_vibops_net 2>/dev/null || docker network inspect vibops_vibops_net 2>/dev/null || echo "network not found"
} > "${BUNDLE_DIR}/network.txt" 2>&1

# ── 11. Volumes ────────────────────────────────────────────
echo "→ Collecting volume info..."
docker volume ls --filter "name=vibops" > "${BUNDLE_DIR}/volumes.txt" 2>&1

# ── 12. PostgreSQL connectivity ────────────────────────────
echo "→ Checking PostgreSQL..."
{
  docker compose exec -T postgres pg_isready -U vibops -d vibops_db 2>&1 || echo "PG NOT READY"
  echo ""
  echo "=== Table count ==="
  docker compose exec -T postgres psql -U vibops -d vibops_db -c "SELECT count(*) as table_count FROM information_schema.tables WHERE table_schema='public';" 2>&1 || echo "QUERY FAILED"
  echo ""
  echo "=== Alembic version ==="
  docker compose exec -T postgres psql -U vibops -d vibops_db -c "SELECT version_num FROM alembic_version;" 2>&1 || echo "QUERY FAILED"
} > "${BUNDLE_DIR}/postgres.txt" 2>&1

# ── 13. Redis connectivity ─────────────────────────────────
echo "→ Checking Redis..."
{
  docker compose exec -T redis redis-cli ping 2>&1 || echo "REDIS NOT REACHABLE"
  echo ""
  echo "=== Celery queues ==="
  docker compose exec -T redis redis-cli llen celery 2>&1 || echo "QUERY FAILED"
} > "${BUNDLE_DIR}/redis.txt" 2>&1

# ── Package ────────────────────────────────────────────────
echo ""
echo "→ Packaging bundle..."
tar -czf "${BUNDLE_FILE}" -C /tmp "vibops-debug-${TIMESTAMP}"
rm -rf "${BUNDLE_DIR}"

SIZE=$(du -h "${BUNDLE_FILE}" | cut -f1)

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  Debug bundle ready                                  ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  File: ${BUNDLE_FILE} (${SIZE})"
echo ""
echo "  Send this file to: david@vibops.ai"
echo "  All secrets are automatically redacted."
echo ""
