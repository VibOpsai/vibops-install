#!/usr/bin/env bash
# connect-setup.sh — Enregistre un gateway local et démarre le worker Connect.
#
# Usage :
#   ./scripts/connect-setup.sh [--name mon-gw] [--cluster vibops-dev] [--start]
#
# Options :
#   --name    Nom du gateway  (défaut : local-dev)
#   --cluster Cluster cible   (défaut : vibops-dev)
#   --start   Lance le worker via docker compose après l'enregistrement
#
# Le script sauvegarde les credentials dans .connect-env (gitignored) et
# les réutilise si le gateway est déjà enregistré.

set -euo pipefail

CORE_URL="${VIBOPS_CORE_URL:-http://localhost:8000}"
GW_NAME="local-dev"
CLUSTER="vibops-dev"
DO_START=false
ENV_FILE=".connect-env"

# ─── Parse args ───────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case $1 in
    --name)    GW_NAME="$2"; shift 2 ;;
    --cluster) CLUSTER="$2"; shift 2 ;;
    --start)   DO_START=true; shift ;;
    *) echo "Option inconnue : $1"; exit 1 ;;
  esac
done

# ─── Réutilise les creds existants si disponibles ─────────────────────────────

if [[ -f "$ENV_FILE" ]]; then
  echo "→ Credentials trouvés dans $ENV_FILE — réutilisation."
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  echo "  Gateway ID : $CONNECT_GATEWAY_ID"
  echo "  Gateway    : $GW_NAME"
else
  # ─── Enregistrement via l'API ────────────────────────────────────────────────

  echo "→ Enregistrement du gateway '$GW_NAME' sur $CORE_URL..."

  RESPONSE=$(curl -sf -X POST "$CORE_URL/api/v1/gateways" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$GW_NAME\", \"description\": \"Gateway local (dev)\", \"clusters\": [\"$CLUSTER\"]}" \
  )

  if [[ -z "$RESPONSE" ]]; then
    echo "✗ Impossible de joindre le Core. Vérifiez que le service core tourne sur $CORE_URL."
    exit 1
  fi

  CONNECT_GATEWAY_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
  CONNECT_TOKEN=$(echo "$RESPONSE"      | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

  if [[ -z "$CONNECT_GATEWAY_ID" || -z "$CONNECT_TOKEN" ]]; then
    echo "✗ Réponse inattendue du Core :"
    echo "$RESPONSE"
    exit 1
  fi

  # Sauvegarde dans .connect-env (gitignored)
  cat > "$ENV_FILE" <<EOF
CONNECT_GATEWAY_ID=$CONNECT_GATEWAY_ID
CONNECT_TOKEN=$CONNECT_TOKEN
EOF

  echo "✓ Gateway enregistré."
  echo "  ID    : $CONNECT_GATEWAY_ID"
  echo "  Token : (sauvegardé dans $ENV_FILE)"
fi

# ─── Démarrage du worker ──────────────────────────────────────────────────────

if $DO_START; then
  echo ""
  echo "→ Démarrage du worker Connect (docker compose --profile connect)..."
  CONNECT_GATEWAY_ID="$CONNECT_GATEWAY_ID" \
  CONNECT_TOKEN="$CONNECT_TOKEN" \
  docker compose --profile connect up connect --build -d

  echo ""
  echo "✓ Worker démarré. Logs :"
  docker compose logs -f connect
else
  echo ""
  echo "Pour démarrer le worker :"
  echo ""
  echo "  source $ENV_FILE && docker compose --profile connect up connect --build"
  echo ""
  echo "  ou directement :"
  echo ""
  echo "  CONNECT_GATEWAY_ID=$CONNECT_GATEWAY_ID CONNECT_TOKEN=<token> python connect/worker.py"
fi
