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
VERSION="${VIBOPS_VERSION:-0.52.5}"
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

# Un essai a blanc doit rendre un verdict, pas un echo.
#
# `--dry-run` se contentait d'afficher la commande helm, puis le script annoncait
# « VibOps deploye avec succes ! ». C'etait un succes qui ne prouvait rien : la
# commande affichee, passee a helm, echouait. Un essai a blanc passe maintenant
# `--dry-run` a helm, qui rend les gabarits et applique les garde-fous du chart.
run_helm() {
  if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${YELLOW}[dry-run]${NC} $*"
    "$@" --dry-run >/dev/null || die "le chart refuse ces valeurs — voir ci-dessus"
    success "Le chart accepte ces valeurs (essai a blanc)"
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

# Le hash est calcule par le produit, pas reimplemente ici.
#
# Ce bloc faisait un bcrypt. `verify_password` fait un scrypt et decoupe sur un
# deux-points qu'un hash bcrypt n'a pas : il rend donc toujours False, et
# l'administrateur ainsi cree ne pouvait jamais se connecter. Sur le chemin
# d'onboarding des clients CSP et entreprise. Constate le 02/10/2026.
info "Hash du mot de passe admin (scrypt, par l'image du produit)..."
AUTH_HASH=$(docker run --rm --entrypoint python \
  "ghcr.io/davidmacamara-boop/vibops-core:${VERSION}" -c \
  "from app.auth import hash_password; print(hash_password('${ADMIN_PASSWORD}'))" 2>/dev/null | tail -1)
if [[ -z "$AUTH_HASH" ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    warn "image indisponible — hash fictif en dry-run"
    AUTH_HASH="0000000000000000000000000000000f:placeholder"
  else
    die "Impossible de calculer le hash : l'image ${VERSION} est-elle tirable ?"
  fi
fi

# ── 3. Secrets ────────────────────────────────────────────────────────────────
#
# Plus de Secret `vibops-secrets` fabrique a cote.
#
# Il portait le JWT, le hash admin, la licence et la cle LLM, et il etait passe au
# chart par `secrets.existingSecret` — une valeur que le chart ne declare nulle
# part. Rien ne le lisait donc : le deploiement partait avec des secrets generes
# par le chart, et ceux-ci dormaient dans le cluster sans emploi. Les valeurs
# passent desormais par celles que le chart lit vraiment, plus bas.

# ── 5. Helm install vibops ────────────────────────────────────────────────────
info "Déploiement VibOps ${VERSION}..."

# Les valeurs que le chart lit reellement.
#
# Cette liste a ete ecrite contre une forme de chart qui n'existe pas :
#   * `secrets.existingSecret` n'est declare nulle part — le Secret Kubernetes
#     fabrique plus haut n'etait donc lu par personne, et le JWT comme le hash
#     admin n'atteignaient jamais les pods ;
#   * `ingress.tls` est une LISTE, pas un objet : `ingress.tls.enabled` faisait
#     « destination for vibops.ingress.tls is a table. Ignoring non-table value »
#     et le bloc TLS demande disparaissait en silence ;
#   * `--db-url` et `--redis` etaient exiges en entree et passes a rien, alors
#     que `postgresql.enabled=false` desactivait la base embarquee. L'installation
#     s'arretait sur « core.secret.databaseUrl is required when
#     postgresql.enabled=false » — le chart se defendait, le script ne le savait
#     pas. Mesure le 02/10/2026 contre un vrai cluster.
#   * `--version` ne s'applique qu'a un chart tire d'un depot, pas a un chemin.
HELM_ARGS=(
  # Aucun depot Helm public n'est servi : le chart est celui du paquet.
  helm upgrade --install vibops ./helm/vibops
  --namespace "$NAMESPACE"
  --set "postgresql.enabled=false"
  --set "redis.enabled=false"
  --set "core.secret.databaseUrl=${DB_URL}"
  --set "core.secret.redisUrl=${REDIS_URL}"
  --set "core.secret.jwtSecretKey=${JWT_SECRET}"
  --set "core.secret.authPasswordHash=${AUTH_HASH}"
  --set "agent.secret.jwtSecretKey=${JWT_SECRET}"
  --set "ingress.enabled=true"
  --set "ingress.host=${HOST}"
  --set-json "ingress.tls=[{\"secretName\":\"vibops-tls\",\"hosts\":[\"${HOST}\"]}]"
  --set "images.core.tag=${VERSION}"
  --set "images.agent.tag=${VERSION}"
  --set "images.console.tag=${VERSION}"
  --wait
  --timeout 10m
)

[[ -n "$ANTHROPIC_KEY" ]] && HELM_ARGS+=("--set" "agent.secret.llmApiKey=${ANTHROPIC_KEY}")

[[ -n "$LICENCE_KEY" ]] && HELM_ARGS+=("--set" "core.secret.licenceKey=${LICENCE_KEY}")
[[ -z "$ANTHROPIC_KEY" ]] && warn "Pas de clé Anthropic — configurer LLM_PROVIDER manuellement"

run_helm "${HELM_ARGS[@]}"
[[ "$DRY_RUN" == false ]] && success "Stack VibOps déployée"

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
  # https://${HOST} → onglet Fleet → "+ Connect Infrastructure" → Kubernetes

  kubectl create namespace vibops-connect
  kubectl create secret generic vibops-connect-token \\
    --namespace vibops-connect --from-literal=token="<jeton-depuis-console>"

  helm upgrade --install vibops-connect ./charts/vibops-connect \\
    --namespace vibops-connect \\
    --set gateway.id="<id-depuis-console>" \\
    --set gateway.clusterName="<nom-du-cluster>" \\
    --set vibops.coreUrl="https://${HOST}" \\
    --set vibops.existingSecret=vibops-connect-token
CONNECT

else
  echo -e "${YELLOW}Pour connecter vos clusters GPU internes (vibops-connect) :${NC}"
  echo ""
  echo -e "  1. Créer un gateway : ${CYAN}https://${HOST}${NC} → onglet Fleet → '+ Connect Infrastructure' → Kubernetes"
  echo -e "     La console affiche l'id, le jeton et la commande prête à coller."
  echo -e "  2. Déployer sur chaque cluster GPU :"
  echo ""
  # La commande ci-dessous est celle qui fonctionne, verifiee contre un cluster.
  #
  # Celle qui etait imprimee ici ne pouvait pas marcher : `gateway.name` n'existe
  # pas dans le chart — les cles sont `gateway.id` et `gateway.clusterName` — donc
  # l'identifiant n'etait jamais pose et connect s'arretait a sa premiere ligne.
  # Et `prometheus.url` n'est declare nulle part : aucun template ne le rend, la
  # valeur partait dans le vide. Prometheus se saisit sur la passerelle, dans la
  # console.
  cat <<ENTERPRISE_CONNECT
  kubectl create namespace vibops-connect
  kubectl create secret generic vibops-connect-token \\
    --namespace vibops-connect --from-literal=token="<jeton-depuis-console>"

  helm upgrade --install vibops-connect ./charts/vibops-connect \\
    --namespace vibops-connect \\
    --set gateway.id="<id-depuis-console>" \\
    --set gateway.clusterName="<nom-du-cluster-gpu>" \\
    --set vibops.coreUrl="https://${HOST}" \\
    --set vibops.existingSecret=vibops-connect-token
ENTERPRISE_CONNECT
fi

echo ""
