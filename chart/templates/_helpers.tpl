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

{{/*
multiReplica: "true" when the workload runs >= 2 replicas (deployment.replicas,
or autoscaling.minReplicas when the HPA owns the replica count), else "".
*/}}
{{- define "service-deployment.multiReplica" -}}
{{- if .Values.autoscaling.enabled -}}
{{- if ge (int .Values.autoscaling.minReplicas) 2 }}true{{ end -}}
{{- else -}}
{{- if ge (int .Values.deployment.replicas) 2 }}true{{ end -}}
{{- end -}}
{{- end -}}

{{/*
gate: tri-state enabled flag -> "true" or "".
  true  -> always; false -> never; auto -> only when multiReplica.
usage: include "service-deployment.gate" (dict "enabled" .Values.x.enabled "root" $)
*/}}
{{- define "service-deployment.gate" -}}
{{- $e := toString .enabled -}}
{{- if eq $e "true" -}}true
{{- else if and (eq $e "auto") (include "service-deployment.multiReplica" .root) -}}true
{{- end -}}
{{- end -}}

{{/*
priorityClassName: "auto" -> services-<environment> for prod/dev, nothing for
other environments; a literal string renders as given; "" renders nothing.
*/}}
{{- define "service-deployment.priorityClassName" -}}
{{- $p := toString (default "" .Values.priorityClassName) -}}
{{- if eq $p "auto" -}}
{{- if has .Values.environment (list "prod" "dev") -}}services-{{ .Values.environment }}{{- end -}}
{{- else -}}{{ $p }}{{- end -}}
{{- end -}}
