# VibOps — Guide déploiement Multi-Region & HA

## Vue d'ensemble

VibOps est architecturé autour de composants **stateless** (core, agent, console, gateway) et d'un état centralisé en PostgreSQL + Redis. Cela le rend naturellement adapté à une topologie multi-region.

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Global Load Balancer                           │
│              (Route53 / Cloud DNS / Cloudflare)                     │
└──────────────┬────────────────────────────────┬────────────────────-┘
               │                                │
    ┌──────────▼──────────┐          ┌──────────▼──────────┐
    │    Region EU-WEST   │          │   Region US-EAST     │
    │  ┌───────────────┐  │          │  ┌───────────────┐   │
    │  │  Gateway ×2   │  │          │  │  Gateway ×2   │   │
    │  │  Core    ×3   │  │          │  │  Core    ×3   │   │
    │  │  Agent   ×2   │  │          │  │  Agent   ×2   │   │
    │  │  Console ×2   │  │          │  │  Console ×2   │   │
    │  └───────────────┘  │          │  └───────────────┘   │
    │                     │          │                       │
    │  ┌───────────────┐  │          │  ┌───────────────┐   │
    │  │ PostgreSQL     │◄─┼──────────┼─►│ Read Replica  │   │
    │  │ (Primary)      │  │  répl.   │  │ (Read-only)   │   │
    │  └───────────────┘  │          │  └───────────────┘   │
    │  ┌───────────────┐  │          │  ┌───────────────┐   │
    │  │ Redis Primary  │◄─┼──────────┼─►│ Redis Replica │   │
    │  └───────────────┘  │          │  └───────────────┘   │
    └─────────────────────┘          └───────────────────────┘
```

---

## Stratégie Active-Passive vs Active-Active

### Recommandation : Active-Passive dans un premier temps

| Critère | Active-Passive | Active-Active |
|---------|---------------|---------------|
| Complexité | Faible | Élevée |
| RPO (perte données) | < 30s (réplication) | ~0 (multi-master) |
| RTO (reprise) | 1-5 min (DNS failover) | < 1 min |
| Conflits DB | Aucun | Gestion nécessaire |
| Coût | ×1.5 | ×2 |

**Active-Passive** : région primaire gère tout le trafic, région secondaire est en standby chaud avec réplication PostgreSQL. Failover DNS en cas de panne.

---

## Déploiement

### Prérequis

```bash
# Clusters Kubernetes (un par région)
kubectl config get-contexts
# vibops-eu-west
# vibops-us-east

# Tools
helm version    # ≥ 3.12
kubectl version # ≥ 1.28
```

### 1. Région primaire (EU-WEST)

```bash
helm install vibops ./helm/vibops \
  --kube-context vibops-eu-west \
  --namespace vibops \
  --create-namespace \
  -f helm/vibops/values.production.yaml \
  -f helm/vibops/values.ha.yaml \
  -f secrets/eu-west.yaml   # voir section Secrets ci-dessous
```

**`secrets/eu-west.yaml`** (ne pas commiter) :
```yaml
core:
  env:
    DATABASE_URL: "postgresql+asyncpg://vibops:PASSWORD@rds-primary.eu-west-1.rds.amazonaws.com:5432/vibops"
    REDIS_URL: "redis://elasticache-primary.eu-west-1.cache.amazonaws.com:6379/0"
    APP_ENV: "production"
  secret:
    jwtSecretKey: "SHARED_SECRET_SAME_IN_ALL_REGIONS"   # identique partout !
    authPasswordHash: "BCRYPT_HASH"
    vaultKey: "FERNET_KEY_32_BYTES_BASE64"

agent:
  secret:
    llmApiKey: "sk-ant-..."
    jwtSecretKey: "SHARED_SECRET_SAME_IN_ALL_REGIONS"
```

> **Critique** : `jwtSecretKey` doit être identique dans toutes les régions — un token émis en EU doit être valide en US lors d'un failover.

### 2. Région secondaire (US-EAST)

```bash
helm install vibops ./helm/vibops \
  --kube-context vibops-us-east \
  --namespace vibops \
  --create-namespace \
  -f helm/vibops/values.production.yaml \
  -f helm/vibops/values.ha.yaml \
  -f secrets/us-east.yaml
```

**`secrets/us-east.yaml`** — pointe vers la **read replica** PostgreSQL :
```yaml
core:
  env:
    DATABASE_URL: "postgresql+asyncpg://vibops:PASSWORD@rds-replica.us-east-1.rds.amazonaws.com:5432/vibops"
    REDIS_URL: "redis://elasticache-replica.us-east-1.cache.amazonaws.com:6379/0"
    APP_ENV: "production"
    VIBOPS_READ_ONLY: "true"   # désactive les writes côté app si lecture seule
```

### 3. Global Load Balancing

#### AWS Route53

```bash
# Health check sur chaque région
aws route53 create-health-check \
  --caller-reference eu-$(date +%s) \
  --health-check-config '{
    "Type": "HTTPS",
    "FullyQualifiedDomainName": "vibops.eu-west.yourcompany.com",
    "ResourcePath": "/api/health",
    "RequestInterval": 10,
    "FailureThreshold": 2
  }'

# DNS failover
aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_ZONE_ID \
  --change-batch file://dns-failover.json
```

**`dns-failover.json`** :
```json
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "vibops.yourcompany.com",
        "Type": "A",
        "SetIdentifier": "eu-primary",
        "Failover": "PRIMARY",
        "HealthCheckId": "EU_HEALTH_CHECK_ID",
        "AliasTarget": {
          "DNSName": "vibops-eu.elb.eu-west-1.amazonaws.com",
          "EvaluateTargetHealth": true,
          "HostedZoneId": "EU_ELB_ZONE_ID"
        }
      }
    },
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "vibops.yourcompany.com",
        "Type": "A",
        "SetIdentifier": "us-secondary",
        "Failover": "SECONDARY",
        "AliasTarget": {
          "DNSName": "vibops-us.elb.us-east-1.amazonaws.com",
          "EvaluateTargetHealth": true,
          "HostedZoneId": "US_ELB_ZONE_ID"
        }
      }
    }
  ]
}
```

---

## Base de données

### RDS Multi-AZ (recommandé pour AWS)

```bash
aws rds create-db-instance \
  --db-instance-identifier vibops-primary \
  --db-instance-class db.t3.medium \
  --engine postgres \
  --engine-version 16 \
  --master-username vibops \
  --master-user-password SECRET \
  --db-name vibops \
  --multi-az \                        # failover automatique intra-région
  --storage-type gp3 \
  --allocated-storage 100 \
  --backup-retention-period 7 \
  --enable-performance-insights \
  --region eu-west-1

# Read replica inter-région
aws rds create-db-instance-read-replica \
  --db-instance-identifier vibops-replica-us \
  --source-db-instance-identifier vibops-primary \
  --db-instance-class db.t3.medium \
  --source-region eu-west-1 \
  --region us-east-1
```

### CloudSQL (GCP)

```bash
gcloud sql instances create vibops-primary \
  --database-version=POSTGRES_16 \
  --tier=db-n1-standard-2 \
  --region=europe-west1 \
  --availability-type=REGIONAL \    # HA intra-région
  --backup-start-time=02:00 \
  --retained-backups-count=7 \
  --enable-bin-log

gcloud sql instances create vibops-replica-us \
  --master-instance-name=vibops-primary \
  --region=us-central1
```

---

## Failover manuel

En cas de panne de la région primaire :

```bash
# 1. Promouvoir la replica en primary
aws rds promote-read-replica \
  --db-instance-identifier vibops-replica-us \
  --region us-east-1

# 2. Attendre que la promotion soit terminée (~2 min)
aws rds wait db-instance-available \
  --db-instance-identifier vibops-replica-us \
  --region us-east-1

# 3. Mettre à jour la config de la région US pour pointer sur le nouveau primary
kubectl patch secret vibops-core \
  --kube-context vibops-us-east \
  -n vibops \
  --type merge \
  -p '{"stringData":{"DATABASE_URL":"postgresql+asyncpg://vibops:PWD@new-primary.us-east-1.rds.amazonaws.com:5432/vibops"}}'

# 4. Rolling restart pour prendre en compte
kubectl rollout restart deployment/vibops-core \
  --kube-context vibops-us-east \
  -n vibops

# 5. Pointer le DNS global sur la région US (retirer le health check EU)
# Route53 bascule automatiquement si health check défaille
```

---

## Monitoring

Points à surveiller pour chaque région :

| Métrique | Seuil alerte | Outil |
|----------|-------------|-------|
| `/api/health` response time | > 500ms | Datadog / CloudWatch |
| PostgreSQL replication lag | > 30s | RDS Enhanced Monitoring |
| Redis memory usage | > 80% | ElastiCache Metrics |
| Pod restart count | > 3 / 5min | Kubernetes Events |
| HPA scale events | Chaque event | Alertmanager |

```bash
# Vérifier le lag de réplication
kubectl exec -n vibops deployment/vibops-core -- \
  python -c "
import asyncio, asyncpg
async def check():
    conn = await asyncpg.connect(DATABASE_URL)
    lag = await conn.fetchval('SELECT EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))')
    print(f'Replication lag: {lag:.1f}s')
asyncio.run(check())
"
```
