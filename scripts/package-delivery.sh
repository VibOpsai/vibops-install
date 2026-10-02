#!/usr/bin/env bash
# package-delivery.sh — build the offline delivery archive for a client site.
#
# Usage: ./scripts/package-delivery.sh <client-slug> <version>
#    ex: ./scripts/package-delivery.sh acme-corp v0.51.2
#
# The archive carries the PUBLISHED images, pulled by name, and never rebuilds
# them. Three reasons, and the first one alone settles it:
#
#   1. The chart ships `policies/kyverno-verify-images.yaml` in Enforce mode,
#      which refuses an unsigned `ghcr.io/davidmacamara-boop/vibops-*` image.
#      Images rebuilt on a laptop are not signed: the policy inside the archive
#      would reject the images inside the same archive.
#   2. A rebuild is not the artefact CI tested. The client would run bits that
#      passed no suite and no smoke test.
#   3. Published images are amd64 only — the arm64 variant was withdrawn. A
#      rebuild on an Apple Silicon machine silently produces arm64 tarballs, and
#      the client's pods fail with `exec format error`.
#
# The image list is asked of the charts themselves rather than written here, so
# it cannot drift away from what the charts actually deploy. Until 02/10/2026
# this script built three images named `ghcr.io/<owner>/<component>` while the
# chart referenced `ghcr.io/<owner>/vibops-<component>:v<version>` — neither the
# name nor the tag matched, `postgres`, `redis` and `vibops-connect` were absent
# altogether, and the README told the operator to retag an image that does not
# exist after `docker load`. The archive could not install anywhere.

set -euo pipefail

CLIENT="${1:?Usage: $0 <client-slug> <version>}"
RAW_VERSION="${2:?Usage: $0 <client-slug> <version>}"

# Les deux formes circulent : le tag git porte le v, la version du chart non.
VERSION="${RAW_VERSION#v}"
TAG="v${VERSION}"
PLATFORM="${VIBOPS_PLATFORM:-linux/amd64}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="${REPO_ROOT}/dist/vibops-${CLIENT}-${TAG}"

for outil in docker helm; do
  command -v "$outil" >/dev/null || { echo "✗ $outil est requis"; exit 1; }
done

echo "→ Archive de livraison VibOps"
echo "  client    : ${CLIENT}"
echo "  version   : ${TAG}"
echo "  plateforme: ${PLATFORM}"
echo "  sortie    : ${DIST}/"
echo ""

rm -rf "${DIST}"
mkdir -p "${DIST}/images" "${DIST}/helm"

# ── 1. Demander aux charts quelles images ils deploient ──────────────────────
echo "  ── images declarees par les charts…"
rendu=$(
  helm template vibops "${REPO_ROOT}/helm/vibops" \
    --set agent.secret.llmApiKey=placeholder 2>/dev/null
  helm template vibops-connect "${REPO_ROOT}/charts/vibops-connect" \
    --set gateway.id=placeholder --set vibops.coreUrl=http://placeholder \
    --set vibops.token=placeholder 2>/dev/null
)
# Une boucle `read` plutot que `mapfile` : macOS livre bash 3.2, ou mapfile
# n'existe pas — le script sortait en 127 sur la machine qui construit l'archive.
IMAGES=()
while IFS= read -r ligne; do
  [[ -n "$ligne" ]] && IMAGES+=("$ligne")
done < <(printf '%s\n' "$rendu" \
  | sed -n 's/^[[:space:]]*image:[[:space:]]*//p' | tr -d '"' | sort -u)

[[ ${#IMAGES[@]} -gt 0 ]] || { echo "✗ aucune image rendue par les charts"; exit 1; }

# Un chart qui annonce une autre version que celle demandee produirait une
# archive dont les images ne sont pas celles du nom du dossier.
for image in "${IMAGES[@]}"; do
  case "$image" in
    *vibops-*:v*)
      [[ "$image" == *":${TAG}" ]] || {
        echo "✗ le chart deploie ${image}, pas ${TAG} — lancez scripts/bump-version.sh ${VERSION}"
        exit 1; }
      ;;
  esac
done
printf '     %s\n' "${IMAGES[@]}"

# ── 2. Tirer et exporter ─────────────────────────────────────────────────────
# Un nom de fichier derive de l'image, et une table qui relie les deux : c'est
# elle que lit le script de chargement, donc aucun nom n'est reecrit a la main.
slug() {
  local ref="$1"
  ref="${ref%@*}"            # le digest ne va pas dans un nom de fichier
  ref="${ref##*/}"           # basename
  echo "${ref//:/-}"
}

: > "${DIST}/images.txt"
for image in "${IMAGES[@]}"; do
  # Une image epinglee par digest est tiree par digest — c'est le contenu — puis
  # retaguee sous `depot:tag` pour que `docker load` rende un nom utilisable.
  cible="${image%@*}"
  tarball="images/$(slug "$image").tar.gz"

  echo "  ── ${image}"
  attendue="${PLATFORM##*/}"

  # On tire le digest de la plateforme, pas celui de l'index.
  #
  # `docker pull --platform` choisit bien la bonne variante, mais retaguer
  # ensuite depuis une reference portant le digest de l'index est ambigu sur une
  # machine qui a deja une autre plateforme en cache : le tag se posait sur
  # l'image arm64 locale, et c'est elle qui partait dans l'archive. Un digest de
  # manifeste ne nomme qu'une plateforme, donc il n'y a plus de choix a faire.
  manifeste=$(docker buildx imagetools inspect "$image" --format \
    '{{range .Manifest.Manifests}}{{if and (eq .Platform.OS "linux") (eq .Platform.Architecture "'"${attendue}"'")}}{{println .Digest}}{{end}}{{end}}' \
    2>/dev/null | head -1)
  if [[ -n "$manifeste" ]]; then
    source_ref="${cible}@${manifeste}"
  else
    # Image a manifeste unique : il n'y a rien a choisir.
    source_ref="$image"
  fi

  docker pull --platform "${PLATFORM}" "$source_ref" >/dev/null || {
    echo "✗ ${image} introuvable. Les images de ${TAG} sont-elles publiees ?"; exit 1; }
  docker tag "$source_ref" "$cible"

  arch=$(docker image inspect "$cible" --format '{{.Architecture}}')
  [[ "$arch" == "$attendue" ]] || {
    echo "✗ ${cible} est en ${arch}, pas ${attendue}"; exit 1; }

  docker save "$cible" | gzip > "${DIST}/${tarball}"
  printf '%s\t%s\n' "$cible" "$tarball" >> "${DIST}/images.txt"
  echo "     ✓ ${arch}  $(du -h "${DIST}/${tarball}" | cut -f1)  ${tarball}"
done

# ── 3. Le chargement, genere avec les vrais noms ─────────────────────────────
# Le README decrivait la boucle a la main, avec un nom d'image qui n'existait
# pas apres `docker load`. Un script genere depuis images.txt ne peut pas se
# tromper de nom.
cat > "${DIST}/load-images.sh" <<'LOADER'
#!/usr/bin/env bash
# Charge les images de l'archive et les pousse dans votre registre.
#   REGISTRY=registry.interne.example ./load-images.sh
#
# Sans REGISTRY, les images sont seulement chargees dans le dockerd local.
set -euo pipefail
cd "$(dirname "$0")"
REGISTRY="${REGISTRY:-}"

while IFS=$'\t' read -r image tarball; do
  [[ -n "$image" ]] || continue
  echo "→ ${tarball}"
  gunzip -c "$tarball" | docker load
  if [[ -n "$REGISTRY" ]]; then
    destination="${REGISTRY}/${image##*/}"
    docker tag "$image" "$destination"
    docker push "$destination"
    echo "  ✓ ${destination}"
  else
    echo "  ✓ ${image} (chargee localement)"
  fi
done < images.txt

echo ""
echo "Images chargees. Les depots a declarer dans vos valeurs :"
while IFS=$'\t' read -r image _; do
  [[ -n "$image" ]] || continue
  nom="${image##*/}"; nom="${nom%%:*}"
  echo "  ${REGISTRY:-<VOTRE_REGISTRE>}/${nom}"
done < images.txt
LOADER
chmod +x "${DIST}/load-images.sh"
echo "  ✓ load-images.sh"

# ── 4. Les deux charts ───────────────────────────────────────────────────────
helm package "${REPO_ROOT}/helm/vibops" --destination "${DIST}/helm" >/dev/null
helm package "${REPO_ROOT}/charts/vibops-connect" --destination "${DIST}/helm" >/dev/null
echo "  ✓ helm/$(cd "${DIST}/helm" && ls | tr '\n' ' ')"

# ── 5. Valeurs d'exemple — uniquement des cles que les charts declarent ──────
# L'ancien fichier posait `core.secret.authUsername` (retire du chart le
# 01/10/2026) et `postgresql.auth.password` (qui n'existe pas : le mot de passe
# est genere et conserve). pydantic et Helm ignorent une cle inconnue sans un
# mot, donc l'operateur reglait trois choses dont deux sans effet.
cat > "${DIST}/values.example.yaml" <<EOF
# VibOps ${TAG} — valeurs d'exemple pour ${CLIENT}
# Remplacez chaque CHANGEZ_MOI. Gardez ce fichier dans votre coffre : il porte
# des secrets.

# ── Registre interne ─────────────────────────────────────────────────────────
# Les noms que load-images.sh affiche a la fin. Le digest d'origine n'est pas
# repris : pousser dans un autre registre produit un autre digest. L'integrite
# de ce que vous installez est verifiee autrement — par SHA256SUMS, a cote.
images:
  core:
    repository: VOTRE_REGISTRE/vibops-core
    tag: "${TAG}"
  agent:
    repository: VOTRE_REGISTRE/vibops-agent
    tag: "${TAG}"
  console:
    repository: VOTRE_REGISTRE/vibops-console
    tag: "${TAG}"

postgresql:
  image:
    repository: VOTRE_REGISTRE/postgres
    tag: "16-alpine"
redis:
  image:
    repository: VOTRE_REGISTRE/redis
    tag: "7-alpine"

# Le chart cree un Secret de pull vers ghcr par defaut : inutile ici.
imageCredentials:
  enabled: false

# ── Ce que vous seul fournissez ──────────────────────────────────────────────
core:
  secret:
    # scrypt, au format sel:empreinte — PAS bcrypt. Genere par l'image elle-meme :
    #   docker run --rm --entrypoint python VOTRE_REGISTRE/vibops-core:${TAG} \\
    #     -c "from app.auth import hash_password; print(hash_password('motdepasse'))"
    authPasswordHash: "CHANGEZ_MOI"
    # Licence hors ligne (RS256, verifiee sans aucun appel sortant). Vide =
    # essai de 14 jours, apres quoi les plafonds de l'essai s'appliquent.
    licenceKey: ""
    # Tout le reste — cles de signature, cle de coffre, mots de passe de la base
    # et du broker — est genere a l'installation et conserve pour la vie de la
    # release. Ne posez une valeur que pour imposer la votre.

agent:
  secret:
    # Vide si vous servez un modele sur place : voir LLM_BASE_URL dans le manuel.
    llmApiKey: "CHANGEZ_MOI"

ingress:
  enabled: true
  className: "nginx"
  host: vibops.${CLIENT}.internal
  annotations: {}
  tls:
    - secretName: vibops-tls
      hosts: [vibops.${CLIENT}.internal]
EOF
echo "  ✓ values.example.yaml"

# ── 6. README ────────────────────────────────────────────────────────────────
cat > "${DIST}/README-delivery.md" <<EOF
# VibOps ${TAG} — livraison hors ligne pour ${CLIENT}

Tout ce qui suit s'execute sans acces a Internet, une fois l'archive copiee sur
site. Les images sont celles publiees pour ${TAG}, en ${PLATFORM} : ce sont les
memes octets que ceux passes par la CI, pas une reconstruction.

## Contenu

\`\`\`
images/           une archive par image, voir images.txt
images.txt        image → fichier (lu par load-images.sh)
load-images.sh    charge et pousse dans votre registre
helm/             les deux charts : vibops et vibops-connect
values.example.yaml
SHA256SUMS
\`\`\`

## 0 — Verifier l'archive

\`\`\`bash
shasum -a 256 -c SHA256SUMS      # ou sha256sum -c SHA256SUMS
\`\`\`

## 1 — Charger les images dans votre registre

\`\`\`bash
REGISTRY=registry.${CLIENT}.internal ./load-images.sh
\`\`\`

Le script affiche a la fin les depots a reprendre dans vos valeurs.

## 2 — Preparer les valeurs

\`\`\`bash
cp values.example.yaml my-values.yaml
\`\`\`

Trois choses a fournir, et rien d'autre : l'empreinte du mot de passe admin, la
cle de votre fournisseur LLM (ou rien si le modele est sur place), et le nom DNS
de l'ingress. Le reste est genere a l'installation.

L'empreinte est en **scrypt**, au format \`sel:empreinte\` :

\`\`\`bash
docker run --rm --entrypoint python registry.${CLIENT}.internal/vibops-core:${TAG} \\
  -c "from app.auth import hash_password; print(hash_password('votre-mot-de-passe'))"
\`\`\`

## 3 — Installer

\`\`\`bash
helm install vibops helm/vibops-${VERSION}.tgz \\
  -n vibops --create-namespace -f my-values.yaml --wait --timeout 10m
\`\`\`

Le chart reclame une **StorageClass par defaut** (20 Gi pour la base, 10 Gi pour
les donnees d'entrainement, 1 Gi pour la console) : sans elle les pods restent
\`Pending\` et rien ne dit pourquoi.

\`\`\`bash
kubectl get storageclass          # une ligne doit porter (default)
\`\`\`

## 4 — Creer le premier compte

\`\`\`bash
kubectl exec -n vibops deploy/vibops-core -- python -m scripts.bootstrap \\
  --org "${CLIENT}" --slug ${CLIENT} \\
  --username admin --email admin@${CLIENT}.internal \\
  --password 'votre-mot-de-passe'
\`\`\`

Core annonce a chaque demarrage avec quel role il parle a la base :

\`\`\`bash
kubectl -n vibops logs deploy/vibops-core | grep Isolation
# Isolation : connecte en « vibops_app », RLS applicable.
\`\`\`

C'est la ligne a lire : l'isolation entre organisations est appliquee par
PostgreSQL, et elle ne vaut que pour un role sans BYPASSRLS.

## 5 — Les passerelles GPU

\`vibops-connect\` est le second chart. Une passerelle s'enregistre d'abord dans
la console (Fleet → Connect Infrastructure), qui donne l'identifiant et le
jeton ; le chart les consomme. Une passerelle dans ce meme cluster joint core
directement, une passerelle distante passe par l'ingress.

## A savoir pour un site coupe du reseau

- **La politique Kyverno du chart ne s'applique plus.** Elle verifie les
  signatures de \`ghcr.io/davidmacamara-boop/vibops-*\` : sous un nom de registre
  interne elle ne correspond a rien, et elle a besoin de Rekor. Ne l'appliquez
  pas telle quelle — adaptez \`imageReferences\` et miroitez Rekor, ou laissez-la
  de cote. Elle est dans le chart, sous \`policies/\`.
- **Rien n'appelle l'extérieur.** La licence est un JWT RS256 verifie avec une
  cle publique embarquee : pas de serveur de licence, pas de telemetrie, pas de
  verification de version. Seules sorties possibles, et seulement si vous les
  configurez : votre fournisseur LLM et vos passerelles — qui joignent votre
  serveur, pas le notre.

## Support

david@vibops.ai

---

*VibOps ${TAG} — logiciel propriétaire. Conditions d'usage : voir le contrat.*
EOF
echo "  ✓ README-delivery.md"

# ── 7. Empreintes ────────────────────────────────────────────────────────────
( cd "${DIST}" && find . -type f ! -name SHA256SUMS -print0 \
    | sort -z | xargs -0 shasum -a 256 > SHA256SUMS )
echo "  ✓ SHA256SUMS"

# ── 8. L'archive doit contenir ce que les charts reclament ───────────────────
# Le controle qui manquait. Il echoue au moment de la construction plutot que
# chez le client, ou l'absence se presente en ImagePullBackOff sur un site qui
# n'a justement aucun moyen d'aller chercher l'image manquante.
manquantes=()
for image in "${IMAGES[@]}"; do
  cible="${image%@*}"
  grep -qF "${cible}"$'\t' "${DIST}/images.txt" || manquantes+=("$cible")
done
if [[ ${#manquantes[@]} -gt 0 ]]; then
  echo "✗ images reclamees par les charts et absentes de l'archive :"
  printf '    %s\n' "${manquantes[@]}"
  exit 1
fi

echo ""
echo "✓ Archive prete — $(du -sh "${DIST}" | cut -f1), ${#IMAGES[@]} images"
find "${DIST}" -type f | sort | sed "s|${DIST}/|  |"
echo ""
echo "  Livrez le dossier, ou : tar czf vibops-${CLIENT}-${TAG}.tar.gz -C $(dirname "${DIST}") $(basename "${DIST}")"
