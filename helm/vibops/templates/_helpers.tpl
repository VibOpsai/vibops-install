{{/*
VibOps Helm helpers
*/}}

{{- define "vibops.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "vibops.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "vibops.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "vibops.labels" -}}
helm.sh/chart: {{ include "vibops.chart" . }}
app.kubernetes.io/name: {{ include "vibops.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "vibops.selectorLabels" -}}
app.kubernetes.io/name: {{ include "vibops.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
imagePullSecrets — merges global.imagePullSecrets with the auto-created registry secret
*/}}
{{- define "vibops.imagePullSecrets" -}}
{{- $secrets := list }}
{{- range .Values.global.imagePullSecrets }}
  {{- $secrets = append $secrets (dict "name" .) }}
{{- end }}
{{- if and .Values.imageCredentials.enabled .Values.imageCredentials.password }}
  {{- $secrets = append $secrets (dict "name" (printf "%s-registry" (include "vibops.fullname" .))) }}
{{- end }}
{{- if $secrets }}
imagePullSecrets:
  {{- toYaml $secrets | nindent 2 }}
{{- end }}
{{- end }}

{{/* vibops.databaseEnv — the database connection, composed in the pod rather
     than baked into a Secret at render time.

     The chart used to write DATABASE_URL into its own Secret from
     postgresql.auth.password, while the PostgreSQL subchart kept the real
     password in a Secret of its own. Two copies of one credential: when the
     value was left empty the subchart generated a password, core was given an
     empty one, and nothing reconciled them — the database was unreachable and
     no upgrade could repair it, because the server had been initialised with a
     password no values file contained.

     There is now one copy. The pod reads the subchart's Secret at start-up and
     Kubernetes expands $(POSTGRES_PASSWORD) in the URL, so whatever password
     that Secret holds — supplied or generated, on install or after an upgrade
     — is the password core connects with. Divergence is no longer expressible.

     `env` wins over `envFrom`, so this overrides the Secret's DATABASE_URL. */}}
{{/* vibops.preserved — a secret the chart generates once and then never
     changes on its own.

     VibOps exists so that operating infrastructure needs no human typing
     values into a terminal. A chart that demands eight passwords before it
     will install contradicts that, and every one of them typed by hand is a
     value that can be lost, weakened, or forgotten on the next upgrade.

     So: if the value is already live in the cluster, it is used. Otherwise the
     operator's value if they supplied one. Otherwise a fresh random one. The
     live value comes first for anything whose change breaks stored state — a
     database initialised with a password, a vault that encrypts with a key, an
     audit chain signed with one (`pinned`); for the rest the operator's value
     wins, so a deliberate rotation is still a `--set` away.

     `legacySecret` lets a value be adopted from wherever it used to live, so
     an upgrade inherits the running credential instead of generating a new one
     the server has never heard of.

     `lookup` returns nothing under `helm template` and `--dry-run`: renders
     without a cluster show a fresh random value, and nothing is applied. */}}
{{- define "vibops.preserved" -}}
{{- $ns := .ctx.Release.Namespace -}}
{{- $live := "" -}}
{{- $s := lookup "v1" "Secret" $ns .secret -}}
{{- if $s -}}{{- $live = (index $s.data .key | default "" | b64dec) -}}{{- end -}}
{{- /* A placeholder is not a value worth keeping. Releases up to v0.45.2
       shipped `change-me-in-production` and friends; preserving them faithfully
       is how an upgraded release reached core with the exact string core
       refuses to start on — verified on a cluster, 21/09/2026. */ -}}
{{- if hasPrefix "change-me" $live -}}{{- $live = "" -}}{{- end -}}
{{- $legacy := "" -}}
{{- if and (not $live) .legacySecret -}}
  {{- $l := lookup "v1" "Secret" $ns .legacySecret -}}
  {{- if $l -}}{{- $legacy = (index $l.data (.legacyKey | default .key) | default "" | b64dec) -}}{{- end -}}
{{- end -}}
{{- if hasPrefix "change-me" $legacy -}}{{- $legacy = "" -}}{{- end -}}
{{- if and .value (not .pinned) -}}{{- .value -}}
{{- else if $live -}}{{- $live -}}
{{- else if $legacy -}}{{- $legacy -}}
{{- else if .value -}}{{- .value -}}
{{- else -}}{{- .generate -}}
{{- end -}}
{{- end }}

{{/* vibops.redisEnv — the broker connection, composed in the pod from the
     Secret that owns the password. Same reason as vibops.databaseEnv: the URL
     used to be assembled at render time with the password inlined, which is a
     second copy of a credential. */}}
{{- define "vibops.redisEnv" -}}
{{- if .Values.redis.enabled }}
- name: REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "vibops.fullname" . }}-redis
      key: REDIS_PASSWORD
- name: REDIS_URL
  value: {{ printf "redis://:$(REDIS_PASSWORD)@%s-redis:6379/0" (include "vibops.fullname" .) | quote }}
{{- end }}
{{- end }}

{{- define "vibops.databaseEnv" -}}
{{- if .Values.postgresql.enabled }}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "vibops.fullname" . }}-db
      key: POSTGRES_PASSWORD
- name: DATABASE_URL
  value: {{ printf "postgresql+asyncpg://%s:$(POSTGRES_PASSWORD)@%s-db:5432/%s" (dig "auth" "username" "vibops" .Values.postgresql) (include "vibops.fullname" .) (dig "auth" "database" "vibops" .Values.postgresql) | quote }}
{{- end }}
{{- end }}

{{/* vibops.appDatabaseEnv — the connection the application uses.

     The owner role is a superuser, and a superuser bypasses row level security
     unconditionally: the forty-six policies of ADR 0047 enforce nothing while
     the application connects as it. `vibops_app` is a plain role, created
     NOLOGIN by migration f5a6b7c8d9e0 and given a password by the
     `grant-app-role` init container, which runs after the migrations that
     create it.

     Migrations keep the owner connection (`vibops.databaseEnv`): a data
     migration has to reach every tenant, and DDL needs privileges this role
     does not have.

     `postgresql.appRole.enabled: false` puts the application back on the owner
     — the rollback if an isolation bug ever locks a legitimate read out. It
     does not remove the policies; it removes their effect. */}}
{{- define "vibops.appDatabaseEnv" -}}
{{- if and .Values.postgresql.enabled (dig "appRole" "enabled" true .Values.postgresql) }}
- name: APP_ROLE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "vibops.fullname" . }}-db
      key: APP_ROLE_PASSWORD
- name: DATABASE_URL
  value: {{ printf "postgresql+asyncpg://vibops_app:$(APP_ROLE_PASSWORD)@%s-db:5432/%s" (include "vibops.fullname" .) (dig "auth" "database" "vibops" .Values.postgresql) | quote }}
{{- else }}
{{- include "vibops.databaseEnv" . }}
{{- end }}
{{- end }}

{{/* vibops.grantAppRole — an init container that gives `vibops_app` its
     password, after the migrations that create the role and before any
     application container starts.

     The password is never interpolated into SQL. `ALTER ROLE … PASSWORD` takes
     no bind parameter, so it goes through a session setting and `format(%L)`,
     which quotes it correctly whatever it contains. */}}
{{- define "vibops.grantAppRole" -}}
{{- if and .Values.postgresql.enabled (dig "appRole" "enabled" true .Values.postgresql) }}
- name: grant-app-role
  image: {{ include "vibops.image" (dict "ctx" . "component" "core") | quote }}
  imagePullPolicy: {{ .Values.images.core.pullPolicy }}
  securityContext:
    {{- toYaml .Values.containerSecurityContext | nindent 4 }}
  env:
    - name: APP_ROLE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ include "vibops.fullname" . }}-db
          key: APP_ROLE_PASSWORD
    {{- include "vibops.databaseEnv" . | nindent 4 }}
  command:
    - python
    - -c
    - |
      import os
      from sqlalchemy import create_engine, text

      url = os.environ["DATABASE_URL"].replace("postgresql+asyncpg", "postgresql+psycopg2")
      engine = create_engine(url, isolation_level="AUTOCOMMIT")
      with engine.connect() as conn:
          conn.execute(
              text("SELECT set_config('vibops.app_pw', :pw, false)"),
              {"pw": os.environ["APP_ROLE_PASSWORD"]},
          )
          conn.execute(text(
              "DO $$ BEGIN EXECUTE format("
              "'ALTER ROLE vibops_app WITH LOGIN PASSWORD %L',"
              " current_setting('vibops.app_pw')); END $$;"
          ))
          row = conn.execute(text(
              "SELECT rolsuper, rolbypassrls, rolcanlogin FROM pg_roles"
              " WHERE rolname = 'vibops_app'"
          )).first()
      if row is None:
          raise SystemExit("vibops_app does not exist — migrations did not run")
      if row[0] or row[1]:
          raise SystemExit("vibops_app is exempt from row level security; refusing to continue")
      if not row[2]:
          raise SystemExit("vibops_app cannot log in")
      print("vibops_app ready: no superuser, no bypassrls, login granted")
  resources:
    {{- toYaml .Values.alembicInit.resources | nindent 4 }}
  volumeMounts:
    - name: tmp
      mountPath: /tmp
{{- end }}
{{- end }}

{{/* vibops.prodSecret — a value core refuses to start without when
     APP_ENV=production (see core/app/main.py `_check_security`).

     The chart shipped these empty, or as "change-me-...", with APP_ENV
     defaulting to production. A `helm install` following the guide therefore
     produced a core in CrashLoopBackOff on `GITHUB_WEBHOOK_SECRET empty` — the
     release reported deployed and every other pod reported Ready. The runtime
     refusal is correct; what was missing was refusing at install time, where
     the message can still name the value to set.

     Call: {{ include "vibops.prodSecret" (dict "ctx" . "value" .Values.x "message" "...") }} */}}
{{- define "vibops.prodSecret" -}}
{{- if eq (dig "env" "APP_ENV" "production" .ctx.Values.core) "production" -}}
{{- required .message .value -}}
{{- else -}}
{{- .value -}}
{{- end -}}
{{- end }}

{{/* vibops.databaseUrl — a database the operator runs. The bundled one does
     not come through here: see vibops.databaseEnv. */}}
{{- define "vibops.databaseUrl" -}}
{{- required "core.secret.databaseUrl is required when postgresql.enabled=false" (dig "secret" "databaseUrl" "" .Values.core) -}}
{{- end }}

{{/* vibops.image — une reference d'image complete pour un composant.

     Appel : {{ include "vibops.image" (dict "ctx" . "component" "core") }}

     L'etiquette vient de values si elle est posee, sinon de l'appVersion du
     chart, prefixee d'un v — c'est le format que publie
     .github/workflows/release-images.yml (`:v0.45.0`, pas `:0.45.0`).

     Le chart posait "latest" pour les trois composants. Une version applicative
     annoncee par le chart et une image `latest` tiree a l'installation sont
     deux choses differentes, et rien ne signalait l'ecart. Meme forme que
     charts/vibops-connect, ou le meme defaut avait ete corrige le 18/09. */}}
{{- define "vibops.image" -}}
{{- $img := index .ctx.Values.images .component -}}
{{- $digest := dig "digest" "" $img -}}
{{- if $digest -}}
{{- /* A digest is the content; a tag is a pointer its owner can move — ours
       included. The published chart carries digests, written at release time
       once the images exist; the repository keeps tags so that a local build
       still runs. */ -}}
{{- printf "%s@%s" $img.repository $digest -}}
{{- else -}}
{{- $tag := $img.tag | default (printf "v%s" .ctx.Chart.AppVersion) -}}
{{- printf "%s:%s" $img.repository $tag -}}
{{- end -}}
{{- end -}}
