{{/*
VibOps Connect — helpers
*/}}

{{- define "vibops-connect.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "vibops-connect.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "vibops-connect.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "vibops-connect.labels" -}}
helm.sh/chart: {{ include "vibops-connect.chart" . }}
app.kubernetes.io/name: {{ include "vibops-connect.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "vibops-connect.selectorLabels" -}}
app.kubernetes.io/name: {{ include "vibops-connect.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "vibops-connect.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "vibops-connect.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "vibops-connect.secretName" -}}
{{- if .Values.vibops.existingSecret }}
{{- .Values.vibops.existingSecret }}
{{- else }}
{{- printf "%s-token" (include "vibops-connect.fullname" .) }}
{{- end }}
{{- end }}

{{- define "vibops-connect.image" -}}
{{- $registry := .Values.global.imageRegistry | default "" }}
{{- if $registry }}
{{- printf "%s/%s:%s" (trimSuffix "/" $registry) .Values.image.repository .Values.image.tag }}
{{- else }}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag }}
{{- end }}
{{- end }}
