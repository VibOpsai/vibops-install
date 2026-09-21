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
{{- define "vibops.databaseEnv" -}}
{{- if .Values.postgresql.enabled }}
- name: POSTGRES_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ dig "auth" "existingSecret" "" .Values.postgresql | default (printf "%s-postgresql" .Release.Name) }}
      key: {{ dig "auth" "secretKeys" "userPasswordKey" "password" .Values.postgresql }}
- name: DATABASE_URL
  value: {{ printf "postgresql+asyncpg://%s:$(POSTGRES_PASSWORD)@%s-postgresql:5432/%s" .Values.postgresql.auth.username .Release.Name .Values.postgresql.auth.database | quote }}
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
{{- $tag := $img.tag | default (printf "v%s" .ctx.Chart.AppVersion) -}}
{{- printf "%s:%s" $img.repository $tag -}}
{{- end -}}
