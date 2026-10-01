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
# Un avertissement compte. `warn` n'incrementait rien, et le resume ne regardait
# que FAILURES : ce script a affiche « All checks passed. VibOps is operational. »
# juste apres avoir declare la console ET l'agent injoignables. Mesure le
# 01/10/2026 sur la demo, apres `make update`. Deux lignes jaunes au-dessus d'une
# ligne verte, et c'est la verte qu'on retient.
warn() { echo -e "  ${YELLOW}⚠${NC} $*"; WARNINGS=$((WARNINGS+1)); }
# Une verification qu'on ne peut pas faire n'est pas un probleme : sans jeton, le
# script ne peut pas lire les passerelles, et ce n'est pas un symptome. A
# distinguer d'un service qui ne repond pas.
skip() { echo -e "  ${CYAN}–${NC} $*"; SKIPS=$((SKIPS+1)); }
info() { echo -e "  ${CYAN}→${NC} $*"; }

FAILURES=0
WARNINGS=0
SKIPS=0

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
  skip "No token provided — auth check not attempted. Pass a token as second argument."
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
  skip "No token — gateway check not attempted"
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
# La console n'est pas publiee sur un port : Caddy la sert sur :80, et c'est la
# seule facon de l'atteindre dans une installation par defaut. Ce script
# cherchait le port 8080, qui n'apparait dans aucun fichier compose du produit —
# donc l'avertissement « Console not reachable » tombait sur chaque installation
# saine. Constate le 01/10/2026 en deroulant Option B sur un hote amd64.
CONSOLE_URL="${BASE_URL%:8000}"
if curl -sf --max-time 5 "${CONSOLE_URL}/" &>/dev/null; then
  ok "Console reachable at ${CONSOLE_URL} (through the reverse proxy)"
else
  # Pas un avertissement : dans une installation par defaut, Caddy sur :80 est
  # la seule facon d'atteindre quoi que ce soit. Une installation dont la
  # console ne repond pas n'est pas « operationnelle ».
  fail "Console not reachable at ${CONSOLE_URL} — is caddy running? (docker compose ps caddy)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────"
SUFFIX=""
[[ "$SKIPS" -gt 0 ]] && SUFFIX=" ${SKIPS} check(s) not attempted."
if [[ "$FAILURES" -gt 0 ]]; then
  echo -e "${RED}${BOLD}${FAILURES} check(s) failed.${NC} See above for details.${SUFFIX}"
  exit 1
elif [[ "$WARNINGS" -gt 0 ]]; then
  echo -e "${YELLOW}${BOLD}${WARNINGS} warning(s).${NC} VibOps is running, but read them above.${SUFFIX}"
else
  echo -e "${GREEN}${BOLD}All checks passed.${NC} VibOps is operational.${SUFFIX}"
fi
echo ""
