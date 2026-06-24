#!/usr/bin/env bash
# poc-healthcheck.sh — verify a VibOps instance is fully operational
# Usage: ./scripts/poc-healthcheck.sh [BASE_URL] [TOKEN]
# Example:
#   ./scripts/poc-healthcheck.sh http://localhost:8000 eyJ...
#   ./scripts/poc-healthcheck.sh                        # defaults: localhost, no auth

set -euo pipefail

BASE_URL="${1:-http://localhost:8000}"
TOKEN="${2:-}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $*"; }
fail() { echo -e "  ${RED}✗${NC} $*"; FAILURES=$((FAILURES+1)); }
warn() { echo -e "  ${YELLOW}⚠${NC} $*"; }
info() { echo -e "  ${CYAN}→${NC} $*"; }

FAILURES=0

echo ""
echo -e "${BOLD}VibOps POC Health Check${NC}"
echo -e "Target: ${CYAN}${BASE_URL}${NC}"
echo ""

AUTH_HEADER=""
[[ -n "$TOKEN" ]] && AUTH_HEADER="Authorization: Bearer ${TOKEN}"

_get() {
  local url="${BASE_URL}${1}"
  if [[ -n "$AUTH_HEADER" ]]; then
    curl -sf -H "$AUTH_HEADER" --max-time 5 "$url" 2>/dev/null
  else
    curl -sf --max-time 5 "$url" 2>/dev/null
  fi
}

# ── 1. Core API reachable ─────────────────────────────────────────────────────
echo -e "${BOLD}1. Core API${NC}"
if HEALTH=$(_get /api/v1/health 2>/dev/null); then
  ok "GET /api/v1/health → 200"
else
  fail "GET /api/v1/health — unreachable. Is the stack running? (make up)"
  echo ""
  echo -e "${RED}Cannot proceed — core API is down.${NC}"
  exit 1
fi

# ── 2. Worker status ──────────────────────────────────────────────────────────
WORKER_RAW=$(echo "$HEALTH" | python3 -c "import sys,json; h=json.load(sys.stdin); print(h.get('checks',{}).get('worker','unknown'))" 2>/dev/null || echo "unknown")

if [[ "$WORKER_RAW" == unknown ]]; then
  fail "Worker status: unknown — run: docker compose restart worker beat"
elif [[ "$WORKER_RAW" == ok* ]]; then
  ok "Worker status: ${WORKER_RAW}"
else
  fail "Worker status: ${WORKER_RAW} — run: docker compose restart worker beat"
fi

# ── 3. Database ───────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}2. Database${NC}"
DB_STATUS=$(echo "$HEALTH" | python3 -c "import sys,json; h=json.load(sys.stdin); print(h.get('checks',{}).get('postgres','unknown'))" 2>/dev/null || echo "unknown")
if [[ "$DB_STATUS" == "ok" ]]; then
  ok "PostgreSQL connected"
else
  fail "PostgreSQL: ${DB_STATUS} — check: docker compose logs postgres"
fi

# ── 4. Auth ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}3. Authentication${NC}"
if [[ -n "$TOKEN" ]]; then
  if _get /api/v1/auth/me &>/dev/null; then
    ok "Token valid"
  else
    fail "Token rejected by /api/v1/auth/me — check JWT_SECRET_KEY or token expiry"
  fi
else
  warn "No token provided — skipping auth check. Pass a token as second argument."
  info "Get a token: POST ${BASE_URL}/api/v1/auth/login"
fi

# ── 5. Gateways ───────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}4. Gateways${NC}"
if [[ -n "$TOKEN" ]]; then
  if GW_RESP=$(_get /api/v1/gateways); then
    GW_COUNT=$(echo "$GW_RESP" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
    GW_ONLINE=$(echo "$GW_RESP" | python3 -c "import sys,json; print(sum(1 for g in json.load(sys.stdin) if g.get('online')))" 2>/dev/null || echo "?")
    if [[ "$GW_COUNT" == "0" ]]; then
      warn "No gateways registered yet — connect a cluster to start running jobs"
    elif [[ "$GW_ONLINE" == "0" ]]; then
      fail "${GW_COUNT} gateway(s) registered but none online — check gateway heartbeat"
    else
      ok "${GW_ONLINE}/${GW_COUNT} gateway(s) online"
    fi
  else
    fail "Could not reach /api/v1/gateways"
  fi
else
  warn "No token — skipping gateway check"
fi

# ── 6. Agent reachable ────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}5. Agent${NC}"
AGENT_URL="${BASE_URL%:8000}:8001"
# In docker-compose the agent is on 8001; via console proxy it may differ
if curl -sf --max-time 5 "${AGENT_URL}/health" &>/dev/null; then
  ok "Agent API reachable at ${AGENT_URL}"
else
  warn "Agent not reachable at ${AGENT_URL}/health — may be proxied through console"
fi

# ── 7. Console ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}6. Console${NC}"
CONSOLE_URL="${BASE_URL%:8000}:8080"
if curl -sf --max-time 5 "${CONSOLE_URL}/" &>/dev/null; then
  ok "Console reachable at ${CONSOLE_URL}"
else
  warn "Console not reachable at ${CONSOLE_URL} — check docker compose ps console"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────"
if [[ "$FAILURES" -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}All checks passed.${NC} VibOps is operational."
else
  echo -e "${RED}${BOLD}${FAILURES} check(s) failed.${NC} See above for details."
  exit 1
fi
echo ""
