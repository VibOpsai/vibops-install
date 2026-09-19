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
{{- define "vibops.databaseUrl" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "postgresql+asyncpg://%s:%s@%s-postgresql:5432/%s" .Values.postgresql.auth.username .Values.postgresql.auth.password .Release.Name .Values.postgresql.auth.database }}
{{- else }}
{{- .Values.core.secret.databaseUrl }}
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
