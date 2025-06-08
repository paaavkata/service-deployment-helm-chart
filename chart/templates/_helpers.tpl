{{/*
Expand the name of the chart.
*/}}
{{- define "service-deployment-helm-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "service-deployment-helm-chart.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "service-deployment-helm-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "service-deployment-helm-chart.labels" -}}
helm.sh/chart: {{ include "service-deployment-helm-chart.chart" . }}
{{ include "service-deployment-helm-chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "service-deployment-helm-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "service-deployment-helm-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common logging fields
*/}}
{{- define "service-deployment-helm-chart.loggingFields" -}}
app: {{ .Values.app.name }}
environment: {{ .Values.global.environment }}
version: {{ .Values.app.version }}
{{- end }}

{{/*
Log aggregation index name
*/}}
{{- define "service-deployment-helm-chart.logIndex" -}}
app-logs-{{ .Values.global.environment }}
{{- end }}

{{/*
Common metrics labels
*/}}
{{- define "service-deployment-helm-chart.metricsLabels" -}}
app: {{ .Values.app.name }}
environment: {{ .Values.global.environment }}
{{- end }}

{{/*
Common metrics annotations
*/}}
{{- define "service-deployment-helm-chart.metricsAnnotations" -}}
prometheus.io/scrape: "true"
prometheus.io/port: {{ .Values.metrics.port | quote }}
prometheus.io/path: {{ .Values.metrics.path | quote }}
{{- end }} 