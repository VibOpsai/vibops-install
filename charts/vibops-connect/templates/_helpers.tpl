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
{{- /* Un tag vide retombe sur appVersion, de sorte que le chart et l'image ne
       divergent pas en silence. Sans ce defaut, image.tag="" produisait
       « repository: » — un deux-points final que YAML refuse, et le rendu
       echouait avec une erreur qui ne nommait ni le tag ni l'image. */ -}}
{{- /* Le prefixe « v » n'est pas decoratif : release-images.yml publie sous
       ${GITHUB_REF_NAME}, c'est-a-dire v0.43.0. Chart.yaml porte 0.43.0, la
       convention Helm pour appVersion. Sans ce printf, le chart rendait
       :0.43.0 — une etiquette qui n'a jamais existe dans le registre, et
       qu'aucun test ne comparait a ce que la CI publie.

       Constate en deployant le chart sur un cluster kind le 18/09 :
       ErrImagePull, « ghcr.io/.../vibops-connect:0.43.0: not found ».
       Une etiquette explicite dans values.yaml est prise telle quelle. */ -}}
{{- $tag := .Values.image.tag | default (printf "v%s" .Chart.AppVersion) }}
{{- $registry := .Values.global.imageRegistry | default "" }}
{{- if $registry }}
{{- printf "%s/%s:%s" (trimSuffix "/" $registry) .Values.image.repository $tag }}
{{- else }}
{{- printf "%s:%s" .Values.image.repository $tag }}
{{- end }}
{{- end }}
