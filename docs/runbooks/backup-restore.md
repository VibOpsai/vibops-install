# VibOps — Runbook Backup & Restore

## Ce qu'il faut sauvegarder

| Donnée | Emplacement | Criticité | RTO cible |
|--------|-------------|-----------|-----------|
| PostgreSQL (jobs, pipelines, secrets, memories) | DB externe | Critique | < 30 min |
| Training JSONL (échanges agent) | `/app/data/training/` (agent pod) | Important | < 2h |
| Secrets Vault (clés Fernet chiffrées) | PostgreSQL table `secrets` | Critique | Inclus DB |
| Configuration Helm | Git | Faible | Immédiat |

---

## PostgreSQL

### Backup automatique (recommandé)

Activer les backups automatiques sur votre DB managée :

```bash
# AWS RDS — backup quotidien à 02h00 UTC, rétention 7 jours
aws rds modify-db-instance \
  --db-instance-identifier vibops-primary \
  --backup-retention-period 7 \
  --preferred-backup-window "02:00-03:00" \
  --apply-immediately

# Snapshot manuel avant une opération risquée
aws rds create-db-snapshot \
  --db-instance-identifier vibops-primary \
  --db-snapshot-identifier "vibops-pre-migration-$(date +%Y%m%d)"
```

```bash
# GCP CloudSQL
gcloud sql backups create \
  --instance=vibops-primary \
  --description="pre-migration-$(date +%Y%m%d)"
```

### Backup manuel (pg_dump)

```bash
# Depuis l'extérieur (nécessite accès réseau à la DB)
pg_dump \
  --host=YOUR_DB_HOST \
  --port=5432 \
  --username=vibops \
  --dbname=vibops \
  --format=custom \
  --compress=9 \
  --file="vibops_$(date +%Y%m%d_%H%M%S).dump"

# Depuis un pod core (accès réseau interne)
kubectl exec -n vibops deployment/vibops-core -- \
  pg_dump "$DATABASE_URL" \
  --format=custom \
  --compress=9 \
  > "vibops_$(date +%Y%m%d_%H%M%S).dump"
```

### Restore PostgreSQL

```bash
# 1. Créer la DB cible si elle n'existe pas
psql --host=NEW_HOST -U vibops -c "CREATE DATABASE vibops;"

# 2. Restore
pg_restore \
  --host=NEW_HOST \
  --port=5432 \
  --username=vibops \
  --dbname=vibops \
  --no-owner \
  --no-privileges \
  --verbose \
  vibops_20260410_140000.dump

# 3. Vérifier les tables clés
psql --host=NEW_HOST -U vibops -d vibops -c "
SELECT tablename, n_live_tup AS rows
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;
"

# 4. Lancer les migrations alembic si le dump est d'une version plus ancienne
kubectl exec -n vibops deployment/vibops-core -- alembic upgrade head
```

---

## Training Data (JSONL)

Les fichiers JSONL sont stockés dans le pod agent — ils ne sont pas dans PostgreSQL.

### Backup

```bash
# Copier les fichiers hors du pod
POD=$(kubectl get pod -n vibops -l app.kubernetes.io/component=agent \
      -o jsonpath='{.items[0].metadata.name}')

kubectl cp \
  "vibops/${POD}:/app/data/training" \
  "./backup/training_$(date +%Y%m%d)"

# Compresser et archiver sur S3
tar -czf "training_$(date +%Y%m%d).tar.gz" \
  "./backup/training_$(date +%Y%m%d)"

aws s3 cp "training_$(date +%Y%m%d).tar.gz" \
  "s3://vibops-backups/training/" \
  --storage-class STANDARD_IA
```

### Restore Training Data

```bash
# 1. Télécharger depuis S3
aws s3 cp "s3://vibops-backups/training/training_20260410.tar.gz" .
tar -xzf training_20260410.tar.gz

# 2. Copier dans le pod
POD=$(kubectl get pod -n vibops -l app.kubernetes.io/component=agent \
      -o jsonpath='{.items[0].metadata.name}')

kubectl cp \
  "./training_20260410" \
  "vibops/${POD}:/app/data/training"

# 3. Vérifier
kubectl exec -n vibops "$POD" -- \
  find /app/data/training -name "*.jsonl" | wc -l
```

> **Pour la production** : monter un PersistentVolume (EFS/GCS Filestore) partagé entre les pods agent au lieu du filesystem local — évite la perte de données en cas de redémarrage du pod.

### PersistentVolume pour les données training

```yaml
# infra/ha/training-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: vibops-training-data
  namespace: vibops
spec:
  accessModes:
    - ReadWriteMany    # plusieurs pods agent accèdent en simultané
  storageClassName: efs-sc   # AWS EFS / sur GCP : nfs-client
  resources:
    requests:
      storage: 50Gi
```

```bash
kubectl apply -f infra/ha/training-pvc.yaml

# Monter dans le deployment agent (ajouter dans values.yaml) :
# agent:
#   extraVolumes:
#     - name: training-data
#       persistentVolumeClaim:
#         claimName: vibops-training-data
#   extraVolumeMounts:
#     - name: training-data
#       mountPath: /app/data/training
```

---

## Secrets Vault (clés Fernet)

Les secrets chiffrés sont en DB (table `secrets`), couverts par le backup PostgreSQL. La **clé Fernet** (`VAULT_KEY`) est le seul secret hors DB — la perdre = perdre l'accès à tous les secrets chiffrés.

### Sauvegarder la clé Fernet

```bash
# Extraire depuis le secret Kubernetes
kubectl get secret -n vibops vibops-core \
  -o jsonpath='{.data.VAULT_KEY}' | base64 -d > vault_key_backup.txt

# Stocker dans un coffre-fort externe (AWS Secrets Manager, Vault, 1Password)
aws secretsmanager put-secret-value \
  --secret-id "vibops/vault-key" \
  --secret-string "$(cat vault_key_backup.txt)"

# SUPPRIMER le fichier local
rm vault_key_backup.txt
```

### Rotation de la clé Fernet

```bash
# 1. Générer une nouvelle clé
NEW_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")

# 2. Re-chiffrer tous les secrets avec la nouvelle clé
kubectl exec -n vibops deployment/vibops-core -- python3 -c "
from app.services.secret_service import SecretService
from app.database import get_sync_db
import asyncio

# Ce script re-chiffre tous les secrets avec NEW_VAULT_KEY
# Voir scripts/rotate_vault_key.py pour l'implémentation complète
print('Lancer: python scripts/rotate_vault_key.py --new-key \$NEW_KEY')
"

# 3. Mettre à jour le secret Kubernetes
kubectl patch secret -n vibops vibops-core \
  --type merge \
  -p "{\"stringData\":{\"VAULT_KEY\":\"$NEW_KEY\"}}"

kubectl rollout restart deployment/vibops-core -n vibops
```

---

## Checklist de reprise après sinistre

Ordre d'exécution en cas de reprise totale depuis zéro :

```bash
# 1. Infrastructure
helm repo add bitnami https://charts.bitnami.com/bitnami  # si Redis local
helm repo update

# 2. Namespace et secrets
kubectl create namespace vibops
kubectl create secret generic vibops-secrets \
  --from-literal=VAULT_KEY="$(aws secretsmanager get-secret-value \
    --secret-id vibops/vault-key --query SecretString --output text)" \
  -n vibops

# 3. Déployer VibOps
helm install vibops ./helm/vibops \
  -n vibops \
  -f helm/vibops/values.production.yaml \
  -f helm/vibops/values.ha.yaml \
  -f secrets/production.yaml

# 4. Attendre que les pods soient prêts
kubectl rollout status deployment/vibops-core -n vibops --timeout=5m

# 5. Restore PostgreSQL (si nouvelle DB)
pg_restore --host=NEW_DB_HOST -U vibops -d vibops vibops_latest.dump

# 6. Lancer les migrations
kubectl exec -n vibops deployment/vibops-core -- alembic upgrade head

# 7. Restore training data
kubectl cp ./training_latest vibops/$(kubectl get pod -n vibops \
  -l app.kubernetes.io/component=agent \
  -o jsonpath='{.items[0].metadata.name}'):/app/data/training

# 8. Vérifier l'état
curl https://vibops.yourcompany.com/api/health
```

**RTO estimé** : 25-40 minutes (DB restore = étape la plus longue).

---

## Tests de reprise réguliers

Planifier mensuellement :

1. **Snapshot test** : restore du dernier snapshot PostgreSQL dans une DB de staging → vérifier l'intégrité
2. **Failover DNS test** : basculer manuellement le trafic sur la région secondaire → vérifier que l'app fonctionne
3. **Rotation des secrets** : effectuer une rotation de la clé Fernet → vérifier que les secrets existants restent accessibles
