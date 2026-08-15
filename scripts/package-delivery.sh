#!/usr/bin/env bash
# package-delivery.sh — build the VibOps POC delivery package for a CSP/client
# Usage: ./scripts/package-delivery.sh <client-slug> <version>
# Example: ./scripts/package-delivery.sh acme-corp 0.8.0
#
# Output: dist/vibops-<client-slug>-<version>/
#   ├── images/
#   │   ├── vibops-core-<version>.tar.gz
#   │   ├── vibops-agent-<version>.tar.gz
#   │   └── vibops-console-<version>.tar.gz
#   ├── helm/
#   │   └── vibops-<version>.tgz
#   ├── values.example.yaml
#   └── README-delivery.md

set -euo pipefail

CLIENT="${1:?Usage: $0 <client-slug> <version>}"
VERSION="${2:?Usage: $0 <client-slug> <version>}"
REGISTRY="${VIBOPS_REGISTRY:-ghcr.io/vibops}"
DIST="dist/vibops-${CLIENT}-${VERSION}"

echo "→ Building VibOps delivery package"
echo "  client:  ${CLIENT}"
echo "  version: ${VERSION}"
echo "  output:  ${DIST}/"
echo ""

mkdir -p "${DIST}/images" "${DIST}/helm"

# ── 1. Build Docker images ────────────────────────────────────────────────────
for COMPONENT in core agent console; do
  IMAGE="${REGISTRY}/${COMPONENT}:${VERSION}"
  TARBALL="${DIST}/images/vibops-${COMPONENT}-${VERSION}.tar.gz"

  echo "  ── building ${COMPONENT}…"
  # Use --platform linux/amd64 only in CI (set VIBOPS_PLATFORM=linux/amd64)
  PLATFORM_ARG=""
  [[ -n "${VIBOPS_PLATFORM:-}" ]] && PLATFORM_ARG="--platform ${VIBOPS_PLATFORM}"
  docker build \
    ${PLATFORM_ARG} \
    --label "org.opencontainers.image.version=${VERSION}" \
    --label "org.opencontainers.image.title=vibops-${COMPONENT}" \
    -f "${COMPONENT}/Dockerfile" \
    -t "${IMAGE}" \
    .

  echo "  ── exporting ${COMPONENT} → ${TARBALL}"
  docker save "${IMAGE}" | gzip > "${TARBALL}"
  echo "  ✓ $(du -sh "${TARBALL}" | cut -f1)  ${TARBALL}"
done

# ── 2. Package Helm chart ─────────────────────────────────────────────────────
echo ""
echo "  ── packaging Helm chart…"
if command -v helm &>/dev/null; then
  helm repo add bitnami https://charts.bitnami.com/bitnami --force-update 2>/dev/null || true
  helm dependency update helm/vibops 2>/dev/null || true
  helm package helm/vibops --version "${VERSION}" --destination "${DIST}/helm"
  echo "  ✓ $(ls "${DIST}/helm/")"
else
  echo "  ⚠ helm not found — skipping chart packaging"
  echo "    Install: brew install helm"
  echo "    Then re-run to add the chart to the package"
  # Copy chart source as fallback
  cp -r helm/vibops "${DIST}/helm/vibops-chart-source"
  echo "  ✓ chart source copied to ${DIST}/helm/vibops-chart-source/"
fi

# ── 3. Generate example values ───────────────────────────────────────────────
cat > "${DIST}/values.example.yaml" <<EOF
# VibOps ${VERSION} — example values for ${CLIENT}
# Replace all CHANGE_ME placeholders before deploying.
# Store this file in your secrets manager — do not commit secrets to git.

images:
  core:
    repository: <YOUR_REGISTRY>/vibops/core
    tag: "${VERSION}"
  agent:
    repository: <YOUR_REGISTRY>/vibops/agent
    tag: "${VERSION}"
  console:
    repository: <YOUR_REGISTRY>/vibops/console
    tag: "${VERSION}"

# Disable auto-created registry secret — use your own registry
imageCredentials:
  enabled: false

core:
  secret:
    secretKey: "CHANGE_ME_32_CHAR_RANDOM_STRING__"
    jwtSecretKey: "CHANGE_ME_JWT_32_CHAR_SECRET_KEY_"
    authUsername: "admin"
    authPasswordHash: ""   # bcrypt hash of admin password
    # databaseUrl: only if postgresql.enabled=false

agent:
  secret:
    # Your LLM API key — required for LLM_PROVIDER=claude or openai, leave empty for ollama
    # Claude: get a key at https://console.anthropic.com/settings/keys
    # Anthropic token costs are billed directly to your Anthropic account.
    # VibOps licence fees are invoiced separately by VibOps SAS.
    llmApiKey: "CHANGE_ME_LLM_API_KEY"
    jwtSecretKey: "CHANGE_ME_JWT_32_CHAR_SECRET_KEY_"   # must match core

postgresql:
  enabled: true
  auth:
    username: vibops
    password: "CHANGE_ME_PG_PASSWORD"
    database: vibops

ingress:
  enabled: true
  className: "nginx"
  host: vibops.${CLIENT}.internal
  tls:
    - secretName: vibops-tls
      hosts: [vibops.${CLIENT}.internal]
EOF
echo "  ✓ values.example.yaml"

# ── 4. Generate delivery README ───────────────────────────────────────────────
cat > "${DIST}/README-delivery.md" <<EOF
# VibOps ${VERSION} — Delivery Package for ${CLIENT}

## Contents

\`\`\`
images/
  vibops-core-${VERSION}.tar.gz      Core Execution Engine
  vibops-agent-${VERSION}.tar.gz     Claude AI Agent
  vibops-console-${VERSION}.tar.gz   Web Console
helm/
  vibops-${VERSION}.tgz              Helm chart
values.example.yaml                  Configuration template
\`\`\`

## Prerequisites

- Kubernetes 1.27+
- Helm 3.12+
- PostgreSQL 14+ (or use the bundled Bitnami sub-chart)
- Anthropic API key

## Step 1 — Load images into your registry

\`\`\`bash
REGISTRY=registry.${CLIENT}.internal

for COMPONENT in core agent console; do
  docker load < images/vibops-\${COMPONENT}-${VERSION}.tar.gz
  docker tag ghcr.io/vibops/\${COMPONENT}:${VERSION} \${REGISTRY}/vibops/\${COMPONENT}:${VERSION}
  docker push \${REGISTRY}/vibops/\${COMPONENT}:${VERSION}
done
\`\`\`

## Step 2 — Prepare your values file

\`\`\`bash
cp values.example.yaml my-values.yaml
# Edit my-values.yaml:
#   - Set images.*.repository to your internal registry
#   - Set core.secret.secretKey and jwtSecretKey (32-char random strings)
#   - Set agent.secret.llmApiKey
#   - Set postgresql.auth.password
#   - Set ingress.host
#   Store secrets in your Vault / Secrets Manager — do not commit to git
\`\`\`

Generate random secret keys:
\`\`\`bash
openssl rand -hex 32   # run twice — once for secretKey, once for jwtSecretKey
\`\`\`

Generate admin password hash:
\`\`\`bash
python3 -c "import bcrypt; print(bcrypt.hashpw(b'YOUR_PASSWORD', bcrypt.gensalt()).decode())"
\`\`\`

## Step 3 — Install

\`\`\`bash
helm install vibops helm/vibops-${VERSION}.tgz \\
  -n vibops --create-namespace \\
  -f my-values.yaml
\`\`\`

Watch rollout:
\`\`\`bash
kubectl -n vibops get pods -w
\`\`\`

## Step 4 — Bootstrap admin account

\`\`\`bash
kubectl exec -n vibops deploy/vibops-core -- \\
  python -m scripts.bootstrap \\
    --org "${CLIENT}" \\
    --slug ${CLIENT} \\
    --username admin \\
    --email admin@${CLIENT}.com \\
    --password "YOUR_PASSWORD"
\`\`\`

Copy the JWT token printed — use it to log into the console.

## Step 5 — Access the console

Open https://vibops.${CLIENT}.internal in your browser.

## Support

Contact: david@vibops.ai
Documentation: https://docs.vibops.io

---

*VibOps ${VERSION} — Proprietary software. See NDA for terms of use.*
EOF
echo "  ✓ README-delivery.md"

# ── 5. Summary ────────────────────────────────────────────────────────────────
echo ""
echo "✓ Delivery package ready:"
du -sh "${DIST}"
echo ""
find "${DIST}" -type f | sort | sed "s|${DIST}/|  |"
echo ""
echo "  Deliver the '${DIST}/' folder to ${CLIENT}."
echo "  Zip it with: zip -r vibops-${CLIENT}-${VERSION}.zip ${DIST}/"
