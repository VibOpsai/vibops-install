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
| console | <http://127.0.0.1:8080> — `admin` / `admin` |
| core | <http://127.0.0.1:8000> |
| base | `postgresql://vibops@127.0.0.1:15432/vibops_db` |

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

1. **postgres passe de 5432 à 15432.** 5432 est occupé par le PostgreSQL du
   poste, dont la suite de tests de `core/` a besoin. La pile n'en souffre pas :
   en interne tout parle à `postgres:5432`.

2. **caddy n'écoute plus que sur la boucle locale**, en 8080/8443 au lieu de
   `0.0.0.0:80/443`. Sur un serveur avec un domaine et un certificat, écouter
   partout est correct ; sur un portable dans un café, cela sert la pile au
   réseau — et le compte administrateur de cet environnement est `admin`/`admin`,
   parce que c'est ce avec quoi les scripts de seed s'authentifient.

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
