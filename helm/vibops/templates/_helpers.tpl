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

{{/* Database URL — utilise le sub-chart PostgreSQL si activé */}}
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

{{- define "vibops.databaseUrl" -}}
{{- if .Values.postgresql.enabled }}
{{- /* No default. An empty password renders `postgresql+asyncpg://vibops:@host`
       while the Bitnami subchart generates a random one of its own: the release
       installs, every pod reports Ready, and core sits in Init:Error forever on
       `fe_sendauth: no password supplied`. values.yaml said REQUIRED; nothing
       enforced it. Same guard as redis.auth.password. `dig` so that an upgrade
       run with --reuse-values, whose values predate this key, fails with this
       message instead of a nil pointer. */ -}}
{{- $pw := required "postgresql.auth.password is required — generate one with `openssl rand -hex 24`, or set postgresql.enabled=false and point core.secret.databaseUrl at your own server" (dig "auth" "password" "" .Values.postgresql) }}
{{- printf "postgresql+asyncpg://%s:%s@%s-postgresql:5432/%s" .Values.postgresql.auth.username $pw .Release.Name .Values.postgresql.auth.database }}
{{- else }}
{{- required "core.secret.databaseUrl is required when postgresql.enabled=false" (dig "secret" "databaseUrl" "" .Values.core) }}
{{- end }}
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
