# VibOps — Environnement de secours local

Un hôte distant peut tomber le matin d'une démonstration. Ce runbook décrit la
pile **publiée** tenue prête sur un poste de travail, pour que le repli coûte
une commande et non un après-midi.

```bash
scripts/local-standby.sh up        # monter, initialiser, semer
scripts/local-standby.sh update    # passer à la version publiée courante
scripts/local-standby.sh status    # ce qui tourne, et à quelle version
scripts/local-standby.sh down      # arrêter, garder les données
```

Après `up` :

| | |
|---|---|
| console | <https://localhost> — `admin` / `vibops2026` |
| core | <http://127.0.0.1:8000> |
| base | `postgresql://vibops@127.0.0.1:15432/vibops_db` |

**En `https`, et sur `localhost` — pas sur `127.0.0.1`.** Un certificat se valide
sur un nom ; l'autorité interne de Caddy n'en émet pas pour une IP nue, et son
journal le dit (`domains: [localhost]`). L'adresse IP n'est donc pas une
variante, c'est une impasse.

**Le navigateur avertira** qu'il ne connaît pas l'autorité. Sur une pile liée à
la boucle locale c'est exact et sans conséquence — mais **l'avertissement n'est
pas toujours contournable** : la console envoie un HSTS d'un an dès
`APP_ENV=production`, et sous épinglage le bouton « continuer quand même »
disparaît. Déclarez l'autorité une fois, sans sudo :

```bash
security add-trusted-cert -d -r trustRoot \
  -k ~/Library/Keychains/login.keychain-db \
  ~/.vibops/standby/caddy-local-ca.crt
```

Pour l'annuler : `security delete-certificate -c "Caddy Local Authority" …`.

Le TLS n'est pas un ornement. La console pose ses cookies de session avec
l'attribut `Secure` dès que `APP_ENV=production`, ce que le secours est par
construction. Un navigateur ne renvoie jamais un cookie `Secure` sur `http://` :
servi en clair, le secours répond **200 au login puis 401 à l'appel suivant**, et
la console reboucle sur l'écran de connexion sans un mot. Passer en
`APP_ENV=development` l'aurait évité, et aurait aussi ouvert l'accès anonyme —
un secours qui ne se comporte pas comme ce qu'un client installe ne prouve rien
sur ce qu'un client installe.

## Ce que cet environnement porte, et ce qu'il ne porte pas

Il porte **les images publiées**, celles qu'un client installe, et des **données
de démonstration semées** par les fixtures du dépôt.

Il ne porte **aucune donnée réelle**. Restaurer ici une sauvegarde de l'hôte de
démonstration mettrait des données client et `BACKUP_PASSPHRASE` sur un
portable : c'est une décision sur les données, pas sur l'outillage, et elle n'a
pas été prise. `docs/runbooks/backup-restore.md` porte la procédure si elle
l'est un jour.

Conséquence à connaître avant d'en avoir besoin : **ce n'est pas une reprise
d'activité.** Si l'hôte distant tombe, vous avez une instance qui fonctionne et
qui se démontre, pas l'état d'un client. Le secours couvre la démonstration, pas
la continuité de service.

## Pourquoi `install.sh` n'est pas utilisé

Il exige root, installe Docker depuis un dépôt apt Debian, et refuse de
cohabiter avec une autre installation sur l'hôte. C'est un installateur de
production pour un serveur Linux, et s'en servir ici serait l'utiliser pour ce
qu'il dit ne pas être.

Ce qui est repris de lui l'est à l'identique : le compose publié, la forme du
`.env`, et **le hash du mot de passe calculé par l'image du produit** plutôt que
réimplémenté — install.sh note pourquoi, un PBKDF2-SHA512 local produisait un
hash de même forme que le scrypt du produit ne pouvait pas vérifier.

## Les deux seules différences avec une installation client

`install/docker-compose.standby.yml` ne change **que** la publication des ports,
et `core/tests/test_the_local_standby_runs_what_a_client_receives.py` refuse
qu'il change autre chose — une pile de secours qui a dérivé ne prouve rien sur
celle qui est publiée.

Les deux listes portent `ports: !override`, et ce n'est pas décoratif : **Compose
fusionne les listes en les concaténant.** Sans cette étiquette, l'overlay
*ajoute* sa publication à celle du fichier publié au lieu de la remplacer —
postgres se retrouve avec 5432 **et** 15432, caddy avec `0.0.0.0:80` **et**
`127.0.0.1:8080` — et la pile meurt sur `bind: address already in use` après
avoir démarré la moitié de ses conteneurs. Un overlay sans l'étiquette a l'air
correct dans les deux fichiers ; il ne devient faux qu'une fois fusionné, ce qui
est pourquoi le test lit `docker compose config` et non ce qui est écrit.

1. **postgres passe de 5432 à 15432.** 5432 est occupé par le PostgreSQL du
   poste, dont la suite de tests de `core/` a besoin. La pile n'en souffre pas :
   en interne tout parle à `postgres:5432`.

2. **caddy n'écoute plus que sur la boucle locale**, en 8080/8443 au lieu de
   `0.0.0.0:80/443`. Sur un serveur avec un domaine et un certificat, écouter
   partout est correct ; sur un portable dans un café, cela sert la pile au
   réseau — et le mot de passe administrateur de cet environnement est connu et
   écrit dans ce document.

   Huit caractères minimum : `/auth/setup` refuse moins, avec un 422 qui le dit.
   Les seeds Python codent `admin`/`admin` en dur, mais `seed-dev.sh` réécrit
   ces identifiants depuis `VIBOPS_ADMIN_*` avant de les lancer.

## Une seule pile VibOps à la fois

Le compose publié fixe les noms de conteneurs (`container_name: vibops_core`),
donc la pile de secours et la pile de développement du dépôt ne peuvent pas
tourner ensemble, quels que soient leurs répertoires. Le script refuse et nomme
celle qui occupe la place — `install.sh` a rencontré exactement cela le
02/10/2026 et porte le même garde.

En pratique cela gêne peu : le travail sur le code passe par les services natifs
(brew), pas par la pile Docker de développement.

## Architectures

Les images sont publiées en `linux/amd64` **et** `linux/arm64`. L'arm64 avait
été retiré le 13/09/2026 au motif que personne ne les tirait ; il est revenu le
08/10/2026, parce que ce secours est quelqu'un qui les tire. Sans lui, sur un
portable Apple Silicon, `up` s'arrête sur :

```
no matching manifest for linux/arm64/v8 in the manifest list entries
```

Le test ci-dessus exige les deux architectures, pour que le motif du retrait
soit réexaminé plutôt que reproduit.
