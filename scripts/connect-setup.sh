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

# Deux adresses, pas une.
#
# `CORE_URL` est celle que CE script appelle pour enregistrer la passerelle,
# depuis l'hote : le compose publie core sur la boucle locale, donc
# `http://localhost:8000`. Le conteneur, lui, vit dans le reseau docker et doit
# appeler `http://core:8000` — ces deux adresses ne coincident presque jamais.
#
# Elles etaient la meme variable : le conteneur heritait de `localhost:8000`,
# ou rien n'ecoute dans son propre espace reseau, et repetait « Core injoignable »
# sans que l'adresse affichee paraisse fausse. Constate le 02/10/2026.
#
# Regle : un enregistrement local implique un core local au reseau docker. Pour
# un site distant, les deux adresses sont la meme URL publique, et
# `CONNECT_CORE_URL` permet de l'imposer.
if [[ -n "${CONNECT_CORE_URL:-}" ]]; then
  CONTAINER_CORE_URL="$CONNECT_CORE_URL"
elif [[ "$CORE_URL" =~ ^https?://(localhost|127\.0\.0\.1)(:[0-9]+)?$ ]]; then
  CONTAINER_CORE_URL="http://core:8000"
else
  CONTAINER_CORE_URL="$CORE_URL"
fi
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

  # `-f` retire, et le code HTTP lu separement.
  #
  # Avec `curl -sf`, un refus faisait sortir le script par `set -e` avant son
  # propre message : l'operateur voyait « Enregistrement... » puis plus rien, sans
  # un mot. Et le message prevu aurait eu tort de toute facon — il annoncait un
  # core injoignable, alors que le cas le plus courant est une instance qui
  # demande une authentification. Constate le 02/10/2026 en enregistrant contre
  # une instance publique.
  HTTP_BODY_AND_CODE=$(curl -s -w $'\n%{http_code}' -X POST "$CORE_URL/api/v1/gateways" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"$GW_NAME\", \"description\": \"Gateway local (dev)\", \"clusters\": [\"$CLUSTER\"]}" \
    || true)
  HTTP_CODE="${HTTP_BODY_AND_CODE##*$'\n'}"
  RESPONSE="${HTTP_BODY_AND_CODE%$'\n'*}"

  case "$HTTP_CODE" in
    2??) : ;;
    000|"")
      echo "✗ Core injoignable sur $CORE_URL."
      echo "  Verifiez que la pile tourne : docker compose ps core"
      exit 1 ;;
    401|403)
      echo "✗ $CORE_URL demande une authentification (HTTP $HTTP_CODE)."
      echo "  Cette instance a l'authentification activee : enregistrez la"
      echo "  passerelle depuis la console (Fleet → + Connect Infrastructure),"
      echo "  ou appelez ce script sur une URL locale non authentifiee."
      exit 1 ;;
    *)
      echo "✗ $CORE_URL a refuse l'enregistrement (HTTP $HTTP_CODE) :"
      echo "  ${RESPONSE:0:300}"
      exit 1 ;;
  esac

  CONNECT_GATEWAY_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
  CONNECT_TOKEN=$(echo "$RESPONSE"      | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

  if [[ -z "$CONNECT_GATEWAY_ID" || -z "$CONNECT_TOKEN" ]]; then
    echo "✗ Réponse inattendue du Core :"
    echo "$RESPONSE"
    exit 1
  fi

  # Sauvegarde dans .connect-env (gitignored)
  # Le nom du cluster voyage avec les identifiants, sinon il est perdu.
  #
  # Il etait envoye a l'enregistrement puis oublie : le conteneur demarrait sans
  # VIBOPS_CLUSTER_NAME et la passerelle se declarait sous le contexte de son
  # kubeconfig. Le `--cluster` demande n'avait donc aucun effet sur ce que la
  # flotte affichait, et deux sites pouvaient se disputer un meme nom.
  cat > "$ENV_FILE" <<EOF
CONNECT_GATEWAY_ID=$CONNECT_GATEWAY_ID
CONNECT_TOKEN=$CONNECT_TOKEN
CONNECT_CLUSTER_NAME=$CLUSTER
CONNECT_CORE_URL=$CONTAINER_CORE_URL
EOF

  echo "✓ Gateway enregistré."
  echo "  ID    : $CONNECT_GATEWAY_ID"
  echo "  Token : (sauvegardé dans $ENV_FILE)"
fi

# ─── Démarrage du worker ──────────────────────────────────────────────────────

if $DO_START; then
  echo ""
  echo "→ Démarrage du worker Connect (docker compose --profile connect)..."
  # Sans `--build` : le compose d'installation part d'une image publiee, et ce
  # depot ne contient aucun contexte de construction.
  CONNECT_GATEWAY_ID="$CONNECT_GATEWAY_ID" \
  CONNECT_TOKEN="$CONNECT_TOKEN" \
  CONNECT_CLUSTER_NAME="$CLUSTER" \
  VIBOPS_CORE_URL="$CONTAINER_CORE_URL" \
  docker compose --profile connect up connect -d
  echo "  (le conteneur appelle $CONTAINER_CORE_URL)"

  echo ""
  echo "✓ Worker démarré. Dernières lignes :"
  # `logs -f` bloquait le script indefiniment — commode a l'ecran, piegeux des
  # qu'on enchaine des commandes.
  docker compose logs --tail=15 connect
  echo ""
  echo "  Pour suivre : docker compose logs -f connect"
else
  echo ""
  echo "Pour démarrer le worker :"
  echo ""
  echo "  source $ENV_FILE && docker compose --profile connect up connect -d"
  echo ""
  echo "  ou directement :"
  echo ""
  echo "  CONNECT_GATEWAY_ID=$CONNECT_GATEWAY_ID CONNECT_TOKEN=<token> python connect/worker.py"
fi
