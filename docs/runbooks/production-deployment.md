# VibOps — Production Deployment Runbook

Version cible : **v0.20.0** | Durée estimée : 45–90 min

---

## Prérequis

| Outil | Version min | Vérification |
|-------|-------------|--------------|
| kubectl | 1.28 | `kubectl version --client` |
| helm | 3.14 | `helm version` |
| cert-manager | 1.14 | `kubectl get pods -n cert-manager` |
| ingress-nginx | 1.10 | `kubectl get pods -n ingress-nginx` |

Base de données et cache managés requis (ne pas utiliser le sub-chart PostgreSQL en prod) :

- **PostgreSQL** ≥ 15 — RDS, CloudSQL, AlloyDB, Supabase, ou on-prem
- **Redis** ≥ 7 — ElastiCache, Memorystore, ou on-prem

---

## Étape 1 — Générer les secrets

```bash
# SECRET_KEY (Fernet — chiffrement vault)
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"

# JWT_SECRET_KEY et SECRET_KEY (HMAC — signatures)
python3 -c "import secrets; print(secrets.token_hex(32))"

# AUTH_PASSWORD_HASH (admin password)
python3 -c "from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt']).hash('CHANGE_ME'))"
```

Créer `my-secrets.yaml` (ne jamais commiter ce fichier) :

```yaml
core:
  env:
    DATABASE_URL: "postgresql+asyncpg://vibops:<password>@<host>:5432/vibops"
    REDIS_URL: "redis://<host>:6379/0"
  secret:
    secretKey: "<fernet key>"
    jwtSecretKey: "<hex 64>"
    authPasswordHash: "<bcrypt hash>"
    vaultKey: "<fernet key>"
    licenceKey: "<jwt licence — contacter david@vibops.ai>"

agent:
  secret:
    llmApiKey: "sk-ant-..."
    jwtSecretKey: "<même que core.secret.jwtSecretKey>"
```

---

## Étape 2 — Préparer la base de données

```bash
# Créer la base et l'utilisateur (PostgreSQL)
psql -h <host> -U postgres <<EOF
CREATE USER vibops WITH PASSWORD '<password>';
CREATE DATABASE vibops OWNER vibops;
GRANT ALL PRIVILEGES ON DATABASE vibops TO vibops;
EOF
```

Les migrations Alembic s'exécutent automatiquement via l'init container au démarrage.

---

## Étape 3 — Configurer le domaine

Pointer `vibops.yourcompany.com` vers l'IP externe de l'ingress-nginx :

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
# → noter l'EXTERNAL-IP
```

Créer un enregistrement DNS `A` : `vibops.yourcompany.com → <EXTERNAL-IP>`

Vérifier la propagation : `dig vibops.yourcompany.com +short`

---

## Étape 4 — Déployer VibOps

```bash
# Namespace
kubectl create namespace vibops

# GHCR pull secret (PAT avec permission read:packages)
kubectl create secret docker-registry ghcr-vibops \
  --docker-server=ghcr.io \
  --docker-username=vibops-deploy \
  --docker-password=<ghcr-pat> \
  -n vibops

# Helm deploy
helm upgrade --install vibops ./helm/vibops \
  -n vibops \
  -f helm/vibops/values.production.yaml \
  -f my-secrets.yaml \
  --set images.core.tag=v0.20.0 \
  --set images.agent.tag=v0.20.0 \
  --set images.console.tag=v0.20.0 \
  --set ingress.host=vibops.yourcompany.com \
  --set "ingress.tls[0].hosts[0]=vibops.yourcompany.com" \
  --atomic --timeout 10m --wait

# Vérifier
kubectl get pods -n vibops
kubectl get ingress -n vibops
```

Attendre que tous les pods soient `Running` (2–5 min, init container migrations inclus).

---

## Étape 5 — Premier login

```bash
# URL console
open https://vibops.yourcompany.com

# Credentials : admin / <mot de passe du AUTH_PASSWORD_HASH>
```

Vérifier dans Admin → Licence que la clé est reconnue.

---

## Étape 6 — Connecter le premier cluster GPU

### Option A — Depuis la console VibOps (recommandé)

Une fois VibOps déployé, tout le reste se pilote **depuis la console elle-même** via les pipeline templates.

Dans le chat :
```
Connect the GPU cluster gpu-prod to this VibOps instance using API key vbops_xyz
```

VibOps déclenche automatiquement le pipeline `connect_gpu_cluster` :
- Step 1 : `helm_upgrade` → déploie le gateway `vibops-connect` sur le cluster cible
- Step 2 : `run_kubectl` → vérifie que le pod est `Running`

Pour voir les templates disponibles :
```
GET /api/v1/pipelines/templates
```

Pour déployer une mise à jour de VibOps lui-même depuis la console :
```
Deploy VibOps v0.21.0 on context prod-k8s
```
→ pipeline `deploy_vibops` : `git_clone` → `helm_upgrade` → `rollout status`

### Option B — Cluster distant (CLI)

Sur le **cluster GPU client**, déployer le gateway VibOps Connect :

```bash
helm upgrade --install vibops-connect ./charts/vibops-connect \
  --set vibops.url=https://vibops.yourcompany.com \
  --set vibops.apiKey=<api-key-généré-dans-admin> \
  --set gateway.name=gpu-prod \
  -n vibops-connect --create-namespace
```

### Option C — Cluster local (même cluster que VibOps)

```bash
# Créer une API key dans Admin → API Tokens
# Puis enregistrer le gateway via l'agent :
# "Register a local gateway named gpu-prod"
```

Vérifier dans **Admin → Gateways** que le gateway apparaît `online`.

---

## Étape 7 — Vérifications post-déploiement

```bash
# Health check
curl -s https://vibops.yourcompany.com/health | jq .

# API
curl -s https://vibops.yourcompany.com/api/v1/clusters \
  -H "Authorization: Bearer <jwt>" | jq .

# Audit log (vérifie que la DB est opérationnelle)
curl -s https://vibops.yourcompany.com/api/v1/audit?limit=5 \
  -H "Authorization: Bearer <jwt>" | jq .
```

```bash
# Test agent
curl -s -X POST https://vibops.yourcompany.com/api/v1/agent/chat \
  -H "Authorization: Bearer <jwt>" \
  -H "Content-Type: application/json" \
  -d '{"message": "List connected clusters"}' | jq .
```

---

## Étape 8 — Configurer les prix cloud (optionnel)

```bash
# Synchroniser le taux GPU depuis AWS
curl -s -X POST https://vibops.yourcompany.com/api/v1/clusters/gpu-prod/rate/sync \
  -H "Authorization: Bearer <jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "provider": "aws",
    "instance_type": "p5.48xlarge",
    "region": "us-east-1",
    "pricing_tier": "on_demand",
    "markup_pct": 0
  }' | jq .
```

---

## Mise à jour (rolling update sans downtime)

```bash
helm upgrade vibops ./helm/vibops \
  -n vibops \
  -f helm/vibops/values.production.yaml \
  -f my-secrets.yaml \
  --set images.core.tag=v0.21.0 \
  --set images.agent.tag=v0.21.0 \
  --set images.console.tag=v0.21.0 \
  --atomic --timeout 10m --wait
```

Les migrations Alembic s'exécutent automatiquement via l'init container avant chaque déploiement.

---

## Rollback

```bash
# Voir l'historique
helm history vibops -n vibops

# Rollback à la revision précédente
helm rollback vibops -n vibops

# Rollback à une revision spécifique
helm rollback vibops 3 -n vibops
```

---

## Checklist pré-go-live

- [ ] DB externe configurée (pas le sub-chart Bitnami)
- [ ] `SECRET_KEY` et `JWT_SECRET_KEY` ≠ valeurs par défaut
- [ ] `AUTH_PASSWORD_HASH` configuré (password admin fort)
- [ ] `VAULT_KEY` configuré (chiffrement des secrets vault)
- [ ] Licence VibOps activée
- [ ] TLS actif (cert-manager + Let's Encrypt)
- [ ] Au moins un cluster GPU connecté et `online`
- [ ] `GET /health` retourne `{"status": "ok"}`
- [ ] Premier chat agent fonctionnel
- [ ] Canal de notification configuré (Slack ou email)
- [ ] Budget mensuel configuré dans FinOps → Budget
