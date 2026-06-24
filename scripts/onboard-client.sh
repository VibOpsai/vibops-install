#!/usr/bin/env bash
# onboard-client.sh — déploiement VibOps complet pour un nouveau client
#
# Supports deux segments :
#   --segment csp        → CSP qui déploie VibOps pour ses clients GPU
#   --segment enterprise → Grande entreprise gérant sa propre infra AI
#
# Usage CSP :
#   ./scripts/onboard-client.sh \
#     --segment      csp \
#     --org          acme \
#     --host         vibops.acme.com \
#     --db-url       "postgresql+asyncpg://vibops:pass@db.acme.com:5432/vibops_db" \
#     --redis        "redis://cache.acme.com:6379/0" \
#     --anthropic-key sk-ant-... \
#     --licence-key  "eyJ..."
#
# Usage Enterprise :
#   ./scripts/onboard-client.sh \
#     --segment      enterprise \
#     --org          mycompany \
#     --host         vibops.internal.mycompany.com \
#     --db-url       "postgresql+asyncpg://vibops:pass@db.internal:5432/vibops_db" \
#     --redis        "redis://redis.internal:6379/0" \
#     --anthropic-key sk-ant-... \
#     --licence-key  "eyJ..."
#
# La clé de licence est générée par VibOps (vendor) via scripts/gen_licence.py.
# Le client reçoit uniquement VIBOPS_LICENCE_KEY — il ne peut pas en forger de nouvelle.
#
# Prérequis :
#   - kubectl configuré sur le cluster cible
#   - helm >= 3.14
#   - openssl, python3
#   - pip3 install bcrypt

set -euo pipefail

# ── Couleurs ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${CYAN}→${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠${NC} $*"; }
die()     { echo -e "${RED}✗${NC} $*" >&2; exit 1; }
section() { echo ""; echo -e "${BOLD}── $* ──${NC}"; }

# ── Paramètres ────────────────────────────────────────────────────────────────
SEGMENT="enterprise"
ORG=""
HOST=""
DB_URL=""
REDIS_URL=""
ANTHROPIC_KEY=""
ADMIN_PASSWORD="vibops-admin"
SLACK_WEBHOOK=""
VERSION="${VIBOPS_VERSION:-0.17.6}"
NAMESPACE="vibops"
CHART_REPO="https://davidmacamara-boop.github.io/vibops"
LICENCE_KEY=""    # JWT RS256 fourni par VibOps — omit pour trial 14j
DRY_RUN=false

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Required:
  --org          <name>     Identifiant client (ex: acme, mycompany)
  --host         <fqdn>     Hostname public (ex: vibops.acme.com)
  --db-url       <url>      URL PostgreSQL asyncpg complète
  --redis        <url>      URL Redis (ex: redis://host:6379/0)
  --anthropic-key <key>     Clé API Anthropic (laisser vide pour LLM on-prem)

Optional:
  --segment       <seg>     Segment: csp | enterprise (défaut: enterprise)
  --licence-key   <jwt>     Clé de licence VibOps RS256 (omit = trial 14j)
  --admin-password <pass>   Mot de passe admin console (défaut: vibops-admin)
  --slack-webhook  <url>    Webhook Slack pour alertes système
  --version        <ver>    Version à déployer (défaut: ${VERSION})
  --namespace      <ns>     Namespace K8s (défaut: ${NAMESPACE})
  --dry-run                 Affiche sans exécuter les helm install
  -h, --help
EOF
  exit 0
}

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --segment)        SEGMENT="$2"; shift 2 ;;
    --org)            ORG="$2"; shift 2 ;;
    --host)           HOST="$2"; shift 2 ;;
    --db-url)         DB_URL="$2"; shift 2 ;;
    --redis)          REDIS_URL="$2"; shift 2 ;;
    --anthropic-key)  ANTHROPIC_KEY="$2"; shift 2 ;;
    --admin-password) ADMIN_PASSWORD="$2"; shift 2 ;;
    --slack-webhook)  SLACK_WEBHOOK="$2"; shift 2 ;;
    --licence-key)    LICENCE_KEY="$2"; shift 2 ;;
    --version)        VERSION="$2"; shift 2 ;;
    --namespace)      NAMESPACE="$2"; shift 2 ;;
    --dry-run)        DRY_RUN=true; shift ;;
    -h|--help)        usage ;;
    *) die "Option inconnue: $1" ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────
[[ -z "$ORG"      ]] && die "--org est requis"
[[ -z "$HOST"     ]] && die "--host est requis"
[[ -z "$DB_URL"   ]] && die "--db-url est requis"
[[ -z "$REDIS_URL" ]] && die "--redis est requis"
[[ "$SEGMENT" =~ ^(csp|enterprise)$ ]] || die "--segment doit être 'csp' ou 'enterprise'"

command -v kubectl >/dev/null || die "kubectl non trouvé"
command -v helm    >/dev/null || die "helm non trouvé (>= 3.14)"
command -v openssl >/dev/null || die "openssl non trouvé"
command -v python3 >/dev/null || die "python3 non trouvé"

SEGMENT_LABEL="Enterprise"
[[ "$SEGMENT" == "csp" ]] && SEGMENT_LABEL="CSP"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     VibOps — Onboarding ${SEGMENT_LABEL}$(printf '%*s' $((26 - ${#SEGMENT_LABEL})) '')║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
info "Organisation : ${ORG}"
info "Segment      : ${SEGMENT_LABEL}"
info "Host         : ${HOST}"
info "Licence      : ${LICENCE_KEY:+fournie}${LICENCE_KEY:-trial 14 jours}"
info "Version      : ${VERSION}"
info "Namespace    : ${NAMESPACE}"
[[ "$DRY_RUN" == true ]] && warn "Mode DRY-RUN activé — aucune ressource ne sera créée"
echo ""

run() {
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${YELLOW}[dry-run]${NC} $*"
  else
    "$@"
  fi
}

# ── 1. Namespace ──────────────────────────────────────────────────────────────
section "Namespace"
run kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | \
  { [[ "$DRY_RUN" == true ]] && cat || kubectl apply -f -; }
success "Namespace ${NAMESPACE} prêt"

# ── 2. Génération des secrets ─────────────────────────────────────────────────
section "Génération des secrets"

info "JWT secret..."
JWT_SECRET=$(openssl rand -hex 32)

info "Hash bcrypt du mot de passe admin..."
AUTH_HASH=$(python3 -c \
  "import bcrypt; print(bcrypt.hashpw('${ADMIN_PASSWORD}'.encode(), bcrypt.gensalt()).decode())" \
  2>/dev/null || true)
if [[ -z "$AUTH_HASH" ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    warn "bcrypt non disponible — hash placeholder utilisé en dry-run"
    AUTH_HASH='$2b$12$PLACEHOLDER_INSTALL_BCRYPT'
  else
    die "bcrypt non disponible — installer: pip3 install bcrypt"
  fi
fi

# ── 3. Secret K8s ─────────────────────────────────────────────────────────────
section "Secret Kubernetes"

SECRET_ARGS=(
  kubectl create secret generic vibops-secrets
  -n "$NAMESPACE"
  "--from-literal=jwt-secret=${JWT_SECRET}"
  "--from-literal=auth-password-hash=${AUTH_HASH}"
)
[[ -n "$LICENCE_KEY"   ]] && SECRET_ARGS+=("--from-literal=licence-key=${LICENCE_KEY}")
[[ -n "$ANTHROPIC_KEY" ]] && SECRET_ARGS+=("--from-literal=anthropic-api-key=${ANTHROPIC_KEY}")
[[ -n "$SLACK_WEBHOOK" ]] && SECRET_ARGS+=("--from-literal=slack-webhook-url=${SLACK_WEBHOOK}")

if [[ "$DRY_RUN" == false ]]; then
  if kubectl get secret vibops-secrets -n "$NAMESPACE" &>/dev/null; then
    warn "Secret vibops-secrets existe déjà — mise à jour..."
    kubectl delete secret vibops-secrets -n "$NAMESPACE"
  fi
fi
run "${SECRET_ARGS[@]}" --dry-run=client -o yaml | \
  { [[ "$DRY_RUN" == true ]] && cat || kubectl apply -f -; }
success "Secret vibops-secrets créé"

# ── 4. Helm repo ──────────────────────────────────────────────────────────────
section "Helm"
info "Ajout du repo VibOps..."
run helm repo add vibops "$CHART_REPO" || true
run helm repo update vibops

# ── 5. Helm install vibops ────────────────────────────────────────────────────
info "Déploiement VibOps ${VERSION}..."

HELM_ARGS=(
  helm upgrade --install vibops vibops/vibops
  --namespace "$NAMESPACE"
  --version "$VERSION"
  --set "secrets.existingSecret=vibops-secrets"
  --set "postgresql.enabled=false"
  --set "ingress.enabled=true"
  --set "ingress.host=${HOST}"
  --set "ingress.tls.enabled=true"
  --set "ingress.tls.secretName=vibops-tls"
  --set "images.core.tag=${VERSION}"
  --set "images.agent.tag=${VERSION}"
  --set "images.console.tag=${VERSION}"
  --wait
  --timeout 10m
)

[[ -n "$LICENCE_KEY" ]] && HELM_ARGS+=("--set" "core.secret.licenceKey=${LICENCE_KEY}")
[[ -z "$ANTHROPIC_KEY" ]] && warn "Pas de clé Anthropic — configurer LLM_PROVIDER manuellement"

run "${HELM_ARGS[@]}"
success "Stack VibOps déployée"

# ── 6. Vérification ───────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == false ]]; then
  section "Vérification des pods"
  kubectl rollout status deployment/vibops-core    -n "$NAMESPACE" --timeout=5m
  kubectl rollout status deployment/vibops-agent   -n "$NAMESPACE" --timeout=5m
  kubectl rollout status deployment/vibops-console -n "$NAMESPACE" --timeout=5m
  success "Tous les pods sont Running"
fi

# ── 7. Résumé ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     VibOps déployé avec succès !                        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Console  : ${CYAN}https://${HOST}${NC}"
echo -e "  Login    : ${CYAN}admin${NC} / ${CYAN}${ADMIN_PASSWORD}${NC}"
echo -e "  Segment  : ${CYAN}${SEGMENT_LABEL}${NC}"
if [[ -n "$LICENCE_KEY" ]]; then
  echo -e "  Licence  : ${GREEN}active${NC}"
else
  echo -e "  Licence  : ${YELLOW}trial 14 jours${NC} — contacter david@vibops.ai pour une clé"
fi
echo ""

# ── 8. Instructions vibops-connect ────────────────────────────────────────────
if [[ "$SEGMENT" == "csp" ]]; then
  echo -e "${YELLOW}Pour connecter un cluster GPU client (vibops-connect) :${NC}"
  echo ""
  cat <<CONNECT
  # Sur le cluster GPU du client final — utiliser le token généré dans la console :
  # https://${HOST} → Fleet tab → "Add a gateway"  (ou ⚙ Admin → Gateways → New Gateway)

  helm upgrade --install vibops-connect vibops/vibops-connect \\
    --namespace vibops-connect --create-namespace \\
    --set gateway.name="<nom-cluster>" \\
    --set vibops.coreUrl="https://${HOST}" \\
    --set vibops.token="<token-depuis-console>" \\
    --set prometheus.url="http://prometheus-operated.monitoring.svc.cluster.local:9090"
CONNECT

else
  echo -e "${YELLOW}Pour connecter vos clusters GPU internes (vibops-connect) :${NC}"
  echo ""
  echo -e "  1. Créer un gateway : ${CYAN}https://${HOST}${NC} → Fleet tab → 'Add a gateway'  (ou ⚙ Admin → Gateways → New Gateway)"
  echo -e "  2. Déployer sur chaque cluster GPU :"
  echo ""
  cat <<ENTERPRISE_CONNECT
  helm upgrade --install vibops-connect vibops/vibops-connect \\
    --namespace vibops-connect --create-namespace \\
    --set gateway.name="<nom-cluster-gpu>" \\
    --set vibops.coreUrl="https://${HOST}" \\
    --set vibops.token="<token-depuis-console>" \\
    --set prometheus.url="http://prometheus-operated.monitoring.svc.cluster.local:9090"
ENTERPRISE_CONNECT
fi

echo ""
