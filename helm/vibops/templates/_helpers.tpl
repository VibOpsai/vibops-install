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
