{{/*
Common helpers for the shared service-deployment chart.
Selector labels intentionally stay `app` + `version: v1` for backward
compatibility — spec.selector.matchLabels is immutable on existing releases.
*/}}

{{- define "service-deployment.name" -}}
{{- .Release.Name -}}
{{- end -}}

{{/* Immutable selector labels — DO NOT change on existing releases. */}}
{{- define "service-deployment.selectorLabels" -}}
app: {{ .Release.Name }}
version: v1
{{- end -}}

{{/* Recommended metadata labels (safe to change). */}}
{{- define "service-deployment.labels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
kubernetes.infra.app: {{ .Release.Name }}
{{- end -}}

{{/*
Platform attribution label (SERVICEMONITOR.md §4): stable across envs,
propagated to Prometheus (kube-state-metrics allowlist) and Loki (Promtail
relabels the pod label). RFC1123 value; defaults to the release name.
*/}}
{{- define "service-deployment.appId" -}}
{{- .Values.appId | default .Release.Name -}}
{{- end -}}
