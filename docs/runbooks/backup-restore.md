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

> **Ce chapitre a ete reecrit le 03/10/2026, et c'est le defaut le plus grave
> trouve pendant le travail sur les sauvegardes.** Il decrivait un produit qui
> n'existe plus, et deux de ses commandes ECHOUAIENT :
>
> * `kubectl exec deployment/vibops-core -- pg_dump …` — l'image core ne
>   contient pas `pg_dump` (mesure le 03/10/2026) ;
> * `pg_restore --format=custom …` — les archives du produit sont du
>   `.sql.gz`, que `pg_restore` ne sait pas lire ; il faut `psql`.
>
> Et il ne mentionnait ni le travail nocturne, ni le volume de sauvegarde, ni
> la copie hors machine, ni le chiffrement — c'est-a-dire aucun des mecanismes
> que le produit possede. Neuf documents pointent ici pour « la procedure »,
> dont le registre des risques. Une sauvegarde dont la procedure de
> restauration est fausse n'est pas une sauvegarde.

### Ce que le produit fait tout seul

| Chemin d'installation | Ce qui tourne | Ou |
|---|---|---|
| Compose (option A et B) | service `backup`, chaque nuit | volume `backups` |
| Helm, base embarquee | CronJob `vibops-backup`, 02h30 UTC | PVC `<release>-backups` |
| Helm, base manageee (`postgresql.enabled=false`) | **rien** | chez le fournisseur |

Deux fichiers par nuit, et **les deux sont necessaires** :

```
vibops_<AAAA-MM-JJ>.sql.gz[.enc]     la base
globals_<AAAA-MM-JJ>.sql.gz[.enc]    les roles et les droits
```

Trente jours de retention, qui ne s'execute **qu'apres** verification du
contenu de l'archive de la nuit — une nuit sans sauvegarde utilisable ne peut
pas perimer la derniere bonne.

Le suffixe `.enc` indique une archive chiffree (AES-256-CBC, PBKDF2 600 000
iterations). La clef :

| | |
|---|---|
| Compose | `BACKUP_PASSPHRASE` dans `.env` |
| Helm | Secret `<release>-backup-key`, clef `BACKUP_PASSPHRASE` |

```bash
# Helm — lire la clef
kubectl -n vibops get secret vibops-backup-key \
  -o jsonpath='{.data.BACKUP_PASSPHRASE}' | base64 -d; echo
```

**Sans cette clef, aucune restauration n'est possible.** Elle ne vit que la ou
le tableau ci-dessus le dit.

### Verifier qu'une sauvegarde existe vraiment

« Un fichier existe » et « une sauvegarde existe » sont deux affirmations
differentes : le service Compose a produit pendant un mois des archives de
371 octets — l'en-tete de `pg_dump` sans une seule table — que tout controle de
presence validait. Les deux healthchecks ouvrent donc l'archive.

```bash
# Compose
docker compose ps backup                 # healthy = archive recente ET lisible
make backup-list

# Helm
kubectl -n vibops get cronjob vibops-backup
kubectl -n vibops get jobs -l app.kubernetes.io/component=backup
kubectl -n vibops logs job/<le dernier> --all-containers
```

### Sauvegarde hors cycle

```bash
# Compose — chiffree comme la boucle nocturne
make backup-now

# Helm
kubectl -n vibops create job --from=cronjob/vibops-backup backup-now
kubectl -n vibops wait --for=condition=complete job/backup-now --timeout=10m
```

### Restauration

**Jamais par-dessus la base vivante.** On restaure dans une base de travail, on
compare, et on promeut ensuite — c'est ce que l'exercice du 25/09/2026 a
etabli (ADR 0048).

> Les trois etapes ci-dessous ont ete deroulees a la lettre le 03/10/2026, sur
> Compose et sur Helm, et la premiere redaction de ce chapitre — ecrite le matin
> du meme jour — en a echoue **trois fois**, toujours de la meme facon : des
> commandes qui ne peuvent pas tourner dans le contexte ou elles vous placent.
>
> * le pod decrit ne montait pas la clef : `openssl` sortait sur « No
>   environment variable BACKUP_PASSPHRASE » ;
> * `psql -U vibops -d postgres` echouait, dans le pod comme dans le conteneur
>   Compose, sur « connection to server on socket … No such file or directory »
>   — il n'y a pas de serveur local la ou l'on se trouve ;
> * « une erreur est attendue » sur les globals : il y en a une PAR ROLE qui
>   existe deja, donc deux quand on restaure sur un serveur qui a tourne.
>
> C'est exactement le reproche fait a la version precedente de ce document. La
> lecon n'est pas « relire » : c'est que tant qu'une procedure n'a pas ete
> executee, elle n'est pas une procedure.

#### 1. Ouvrir un poste de travail

Un conteneur qui voit **l'archive**, **la clef** et **la base**. Les trois, ou
l'etape suivante s'arrete.

```bash
# Helm
kubectl -n vibops run restore --restart=Never --image=postgres:16 \
  --labels='app.kubernetes.io/component=backup' \
  --overrides='{"spec":{"containers":[{"name":"restore","image":"postgres:16",
    "command":["sleep","3600"],
    "env":[{"name":"PGHOST","value":"vibops-db"},
           {"name":"PGUSER","value":"vibops"},
           {"name":"PGPASSWORD","valueFrom":{"secretKeyRef":{"name":"vibops-db","key":"POSTGRES_PASSWORD"}}},
           {"name":"BACKUP_PASSPHRASE","valueFrom":{"secretKeyRef":{"name":"vibops-backup-key","key":"BACKUP_PASSPHRASE"}}}],
    "volumeMounts":[{"name":"b","mountPath":"/backups","readOnly":true}]}],
    "volumes":[{"name":"b","persistentVolumeClaim":{"claimName":"vibops-backups"}}]}}'

kubectl -n vibops exec -it restore -- bash
```

L'etiquette `app.kubernetes.io/component=backup` n'est pas decorative : la
politique reseau de la base n'ouvre 5432 qu'aux pods qui la portent, et un
paquet refuse par une NetworkPolicy n'est pas rejete, il est perdu — `psql`
attendrait la fin de son delai sans un mot.

```bash
# Compose — le conteneur de sauvegarde EST ce poste de travail : il porte la
# clef, le mot de passe de la base, PGHOST et PGUSER.
docker compose exec backup bash
```

Toutes les commandes suivantes s'executent dans ce conteneur, et sont les
memes sur les deux chemins : `PGHOST` et `PGUSER` y sont deja poses, donc
`psql` n'a besoin ni de `-h` ni de `-U`.

```bash
ls -l /backups
```

Pour repartir de la **copie hors machine** plutot que du volume, recuperez-la
d'abord avec le meme Secret rclone que le transport :

```bash
rclone copy "offsite:$BACKUP_REMOTE_PATH" /backups-in \
  --include 'vibops_*' --include 'globals_*'
```

#### 2. Dechiffrer, si `.enc`

```bash
D=2026-10-03   # la date de l'archive choisie

openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 \
  -pass env:BACKUP_PASSPHRASE \
  -in /backups/globals_$D.sql.gz.enc -out /tmp/globals.sql.gz
openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 \
  -pass env:BACKUP_PASSPHRASE \
  -in /backups/vibops_$D.sql.gz.enc -out /tmp/vibops.sql.gz
```

Une mauvaise clef dit `bad decrypt` et non du silence. Un octet altere fait
echouer `gzip` a l'etape suivante : la corruption se voit, la falsification par
quelqu'un qui possede la clef ne se voit pas (`openssl enc` n'a pas de mode
authentifie — ADR 0048).

Sans chiffrement, les archives sont deja en `.sql.gz` : passez a l'etape 3 en
lisant `/backups/globals_$D.sql.gz` directement.

#### 3. Les globals D'ABORD, et sans `ON_ERROR_STOP`

```bash
gzip -dc /tmp/globals.sql.gz | psql -d postgres
```

**Les erreurs `role "…" already exists` sont attendues : une par role qui
existe deja.** Sur un cluster neuf il y en a une — `vibops`, le
superutilisateur que l'image postgres a cree. Sur un serveur qui a deja
tourne, il y en a autant que de roles, donc deux ici.

Ce qui ne doit PAS apparaitre, c'est une autre erreur que celle-la. Et il ne
faut surtout pas `ON_ERROR_STOP` : s'arreter a la premiere sauterait
`vibops_app`, le role non-superuser auquel s'appliquent les politiques RLS
(ADR 0047), et c'est tout l'enjeu de ce fichier.

```bash
psql -d postgres -tAc "SELECT rolname, rolsuper, rolbypassrls FROM pg_roles
  WHERE rolname LIKE 'vibops%'"
```

#### 4. La base dans une copie de travail

Jamais par-dessus la base vivante.

```bash
psql -d postgres -c "CREATE DATABASE vibops_restore"
gzip -dc /tmp/vibops.sql.gz | psql -d vibops_restore 2>&1 | tee /tmp/restore.log
```

#### 5. Lire le journal, pas le code de retour

```bash
grep -c '^ERROR' /tmp/restore.log    # doit valoir 0
```

`psql` sans `ON_ERROR_STOP` sort en 0 apres des centaines d'erreurs. Le premier
exercice en a compte 57 derriere un code de sortie nul.

#### 6. Comparer avant de promouvoir

La structure autant que les lignes. L'etat RLS est la partie qui echoue en
silence : une base revenue sans `FORCE ROW LEVEL SECURITY` sert les lignes de
tous les locataires a la connexion proprietaire, et rien ne le signale.

```bash
for db in vibops vibops_restore; do
  echo "-- $db"
  psql -d $db -c "SELECT relname, relrowsecurity, relforcerowsecurity
    FROM pg_class WHERE relrowsecurity ORDER BY relname"
  psql -d $db -tAc "SELECT count(*) FROM pg_policies"
  psql -d $db -c "SELECT relname, n_live_tup AS lignes
    FROM pg_stat_user_tables ORDER BY n_live_tup DESC LIMIT 20"
done
```

`relname`, et non `tablename` : cette vue n'a pas de colonne `tablename`, et la
requete heritee de la version precedente de ce document echouait sur « column
"tablename" does not exist ». Quatrieme commande de ce chapitre a ne pas
fonctionner, trouvee le 03/10/2026 en le deroulant.

Les deux colonnes RLS, le nombre de politiques et les comptages doivent
coincider. Sur Compose la base vivante s'appelle `vibops_db`, sur Helm
`vibops`.

`n_live_tup` est une estimation du collecteur de statistiques — exacte juste
apres une restauration, puisque le `COPY` vient de l'alimenter, mais elle derive
sur une table qui vit. Pour les tables qui comptent, un `count(*)` tranche.

#### 7. Les migrations, si l'archive est plus ancienne que le code

```bash
kubectl exec -n vibops deployment/vibops-core -- alembic upgrade heads
```

#### 8. Fermer le poste de travail

```bash
kubectl -n vibops delete pod restore     # Helm
```

Le clair dechiffre dans `/tmp` disparait avec le conteneur : sur Helm `/tmp`
est la couche ephemere du pod, sur Compose il part a l'arret du conteneur. Ne
dechiffrez jamais dans `/backups`, qui est monte en lecture seule ici
precisement pour que ce soit impossible.

### Base manageee

`postgresql.enabled=false` : le chart ne deploie aucun travail de sauvegarde,
et c'est voulu — un travail pointe sur la base d'un fournisseur viderait un
serveur qu'on ne nous a pas demande de toucher. **Rien dans le produit ne dira
a l'exploitant si les sauvegardes de son fournisseur sont eteintes.**

```bash
# AWS RDS — retention quotidienne
aws rds modify-db-instance \
  --db-instance-identifier vibops-primary \
  --backup-retention-period 7 \
  --preferred-backup-window "02:00-03:00" \
  --apply-immediately

# Instantane avant une operation risquee
aws rds create-db-snapshot \
  --db-instance-identifier vibops-primary \
  --db-snapshot-identifier "vibops-pre-migration-$(date +%Y%m%d)"

# GCP CloudSQL
gcloud sql backups create --instance=vibops-primary \
  --description="pre-migration-$(date +%Y%m%d)"
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

⚠ `infra/ha/training-pvc.yaml` etait cite ici et n'existe pas dans le depot
(verifie le 03/10/2026). Le chart declare deja ce volume : `agent.persistence`
dans `helm/vibops/values.yaml`. Le manifeste ci-dessous reste une reference
pour un montage hors chart.

```yaml
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

# ⚠ Ce script n'existe pas dans le depot. `scripts/rotate_vault_key.py` etait
# cite ici et n'a jamais ete ecrit — verifie le 03/10/2026. La rotation de
# VAULT_KEY reste un geste manuel : lire chaque secret avec l'ancienne clef, le
# reecrire avec la nouvelle, dans une transaction.
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

**Avant tout : avez-vous la clef de chiffrement des sauvegardes ?** Si les
archives portent `.enc` et que la clef ne vivait que dans le namespace ou le
`.env` detruits, la reprise s'arrete ici. Rien d'autre dans cette checklist
n'aura d'effet.

```bash
# 1. Namespace et secrets
kubectl create namespace vibops

# Le chart genere lui-meme ses secrets, sauf ceux dont la perte casse l'etat
# stocke : VAULT_KEY (dechiffre les secrets en base) et BACKUP_PASSPHRASE
# (dechiffre les archives). Les reposer AVANT l'install, sinon le chart en
# genere de nouveaux et les deux etats deviennent illisibles.
kubectl -n vibops create secret generic vibops-core \
  --from-literal=VAULT_KEY="$(…depuis votre coffre…)"
kubectl -n vibops create secret generic vibops-backup-key \
  --from-literal=BACKUP_PASSPHRASE="$(…depuis votre coffre…)"

# Pas de `helm repo add` : le chart n'a AUCUNE dependance. Le bitnami qui
# figurait ici ajoutait un depot que rien ne lit — la ligne a ete retiree du
# manuel le 01/10/2026 et subsistait encore ici.

# 2. Deployer VibOps
helm install vibops ./helm/vibops -n vibops \
  -f helm/vibops/values.production.yaml \
  -f helm/vibops/values.ha.yaml

# 3. Attendre les pods
kubectl rollout status deployment/vibops-core -n vibops --timeout=5m

# 4. Restaurer PostgreSQL — voir le chapitre PostgreSQL ci-dessus.
#    `pg_restore` ne lit PAS les archives du produit : elles sont du
#    `.sql.gz`, eventuellement chiffre, donc globals puis base via `psql`,
#    dans une base de travail, journal relu, puis promotion.

# 5. Migrations si l'archive precede le code
kubectl exec -n vibops deployment/vibops-core -- alembic upgrade heads

# 6. Donnees d'entrainement
kubectl cp ./training_latest vibops/$(kubectl get pod -n vibops \
  -l app.kubernetes.io/component=agent \
  -o jsonpath='{.items[0].metadata.name}'):/app/data/training

# 7. Verifier
kubectl -n vibops port-forward svc/vibops-core 8000:8000 &
curl -s localhost:8000/health
```

**RTO estime** : 25-40 minutes, la restauration de la base etant l'etape la
plus longue — et seulement si la clef est en main.

---

## Tests de reprise réguliers

Planifier mensuellement :

1. **Snapshot test** : restore du dernier snapshot PostgreSQL dans une DB de staging → vérifier l'intégrité
2. **Failover DNS test** : basculer manuellement le trafic sur la région secondaire → vérifier que l'app fonctionne
3. **Rotation des secrets** : effectuer une rotation de la clé Fernet → vérifier que les secrets existants restent accessibles
