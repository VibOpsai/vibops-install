# Pilot Runbook — VibOps

**Audience :** opérateur VibOps qui onboarde un client pilot.  
**Prérequis :** Docker + Docker Compose installés, repo cloné, fichier `.env` configuré.

---

## 1. Démarrer la stack

```bash
make up
# ou : docker compose up -d
```

Vérifier que tous les services sont healthy :

```bash
docker compose ps
curl http://localhost:8000/api/v1/health
```

Réponse attendue :

```json
{
  "status": "ok",
  "checks": {
    "postgres": "ok",
    "redis": "ok",
    "worker": "ok (1 online)"
  }
}
```

Si `worker` renvoie `"no workers responding"` : `docker compose logs worker` pour diagnostiquer.

---

## 2. Créer le premier client pilot

```bash
make pilot-create-client \
  ORG="Acme Corp" \
  EMAIL=admin@acme.com \
  PASSWORD=changeme123 \
  BUDGET=5000
```

Le script est **idempotent** — relancer sans danger si quelque chose a mal tourné.

**Paramètres disponibles :**

| Paramètre | Requis | Description | Exemple |
|-----------|--------|-------------|---------|
| `ORG`     | oui    | Nom de l'organisation | `"Acme Corp"` |
| `EMAIL`   | oui    | Email de l'admin | `admin@acme.com` |
| `PASSWORD`| oui    | Mot de passe admin | `changeme123` |
| `SLUG`    | non    | Identifiant URL (dérivé de ORG si absent) | `acme` |
| `BUDGET`  | non    | Plafond mensuel USD | `5000` |
| `SOFT_CAP`| non    | Seuil alerte % (défaut: 80) | `75` |
| `HARD_CAP`| non    | Seuil blocage % (défaut: 100) | `95` |

**Sortie attendue :**

```
── VibOps Pilot Provisioning ───────────────────────────
  Organisation  [+ créée]   : Acme Corp  (id: ...)
  Utilisateur   [+ créé]    : acme-admin
  Budget        [+ créé]    : $5,000/mois  (soft 80% / hard 100%)

── Credentials ─────────────────────────────────────────
  Org slug  : acme
  Username  : acme-admin
  Password  : changeme123

── JWT Token (valide 2h) ────────────────────────────────
  eyJ...
```

Le username généré suit le pattern `{slug}-admin`. Transmettre au client :
- URL console : `http://<host>:8003`
- Username : `{slug}-admin`
- Password : valeur de `PASSWORD`

---

## 3. Connecter le cluster GPU du client

Dans la console → onglet **Fleet** → sous-onglet **Gateways** → **New Gateway** (ou **⚙ Admin → Gateways → New Gateway**) :

1. Nommer le gateway (ex: `acme-gpu-cluster-1`)
2. Copier le token généré
3. Sur le cluster GPU du client, déployer `vibops-connect` :

```bash
helm upgrade --install vibops-connect vibops/vibops-connect \
  --namespace vibops-connect --create-namespace \
  --set gateway.name="acme-gpu-cluster-1" \
  --set vibops.coreUrl="http://<vibops-host>:8000" \
  --set vibops.token="<token-depuis-console>"
```

Vérifier la connexion : dans la console, le gateway doit passer à l'état **Online** (heartbeat < 30s).

---

## 4. Inviter des membres de l'équipe client

Via l'API (avec le JWT token obtenu à l'étape 2) :

```bash
TOKEN="eyJ..."
ORG_ID="<uuid-de-l-org>"

# Créer un lien d'invitation (valable 48h)
curl -X POST http://localhost:8000/api/v1/orgs/$ORG_ID/invites \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"email": "engineer@acme.com", "is_org_admin": false}'
```

Réponse : `invite_url` à transmettre à l'invité. Il définit son propre mot de passe.

---

## 5. Configurer les équipes et permissions

Créer une équipe avec des accès restreints :

```bash
curl -X POST http://localhost:8000/api/v1/orgs/$ORG_ID/teams \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ML Engineers",
    "allowed_namespaces": ["default", "prod"],
    "allowed_clusters": ["acme-gpu-cluster-1"],
    "allowed_actions": ["deploy_model", "scale_cluster", "get_cluster_deployments"],
    "gpu_quota": 8
  }'
```

---

## 6. Vérifier l'observabilité

- **Grafana** : `http://localhost:3000` — admin / `${GRAFANA_PASSWORD:-vibops}`
  - Dashboard `VibOps` : jobs, GPU utilisation, coûts
  - Dashboard `VibOps GPU` : métriques GPU temps réel
- **Prometheus** : `http://localhost:9090`
  - Alertes actives : `http://localhost:9090/alerts`

---

## 7. Vérifier les backups

```bash
# Lister les backups existants
make backup-list

# Lancer un backup manuel
make backup-now
```

Les backups automatiques tournent toutes les 24h (02:00 UTC). Rétention : 30 jours.

### Restaurer un backup

```bash
# 1. Identifier le fichier
make backup-list

# 2. Restaurer (arrêter l'API d'abord)
docker compose stop core worker beat agent console

# 3. Écraser la DB
BACKUP=vibops_2026-05-02.sql.gz
docker compose exec backup sh -c \
  "gunzip -c /backups/$BACKUP | psql -h postgres -U vibops -d vibops_db"

# 4. Redémarrer
docker compose start core worker beat agent console
```

---

## 8. Checklist go-live

Avant de livrer l'accès au client :

- [ ] `make up` + `curl /health` → `"status": "ok"` sur tous les checks
- [ ] Gateway connecté et Online dans la console
- [ ] Premier job de test exécuté avec succès (`list_cluster_deployments`)
- [ ] Budget configuré et visible dans l'onglet FinOps → Budget
- [ ] Admin client peut se connecter sur la console
- [ ] Grafana accessible et dashboards chargés
- [ ] Backup de J0 présent : `make backup-list`
- [ ] Alertes Prometheus visibles sur `:9090/alerts`

---

## 9. Dépannage rapide

| Symptôme | Commande de diagnostic |
|----------|------------------------|
| Core API ne répond pas | `docker compose logs core` |
| Worker inactif | `docker compose logs worker` |
| Connexion DB échouée | `docker compose exec postgres psql -U vibops -c "SELECT 1"` |
| Gateway offline | `docker compose logs worker \| grep heartbeat` |
| Job bloqué en PENDING | `docker compose exec core celery -A app.workers.celery_app inspect active` |
| Erreur de chiffrement (VAULT_KEY) | Vérifier `VAULT_KEY` dans `.env` (doit être une clé Fernet valide) |

---

## 10. Créer plusieurs clients

Le script `pilot_provision` est idempotent et peut être appelé plusieurs fois :

```bash
make pilot-create-client ORG="Acme Corp"   EMAIL=admin@acme.com   PASSWORD=secret1 BUDGET=5000
make pilot-create-client ORG="BioTech AI"  EMAIL=cto@biotech.io   PASSWORD=secret2 BUDGET=12000
make pilot-create-client ORG="NvidiaLabs"  EMAIL=ops@nvlabs.com   PASSWORD=secret3
```

Chaque organisation est **isolée** : ses secrets, budgets, jobs et rapports chargeback sont strictement cloisonnés.
