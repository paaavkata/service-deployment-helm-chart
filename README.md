# service-deployment-helm-chart
Helm chart that will be used as a template for all services that run in K8S.

**Current chart version: 1.3.1** (`chart/Chart.yaml`). Most consuming services still pin the
parent chart at `1.2.0` in their own `helm/Chart.yaml` dependency block — that is a deliberate,
unbumped pin, not a doc error; don't "fix" a service's pin without checking with its owner first.

## Version 1.1.0 — Kubernetes hardening

> **SUPERSEDED as of 1.3.0.** The table below documents the historical 1.1.0 behavior
> (hardening opt-in, defaults `false`). As of 1.3.0, `probes.enabled` and
> `securityContext.enabled` default to **`true`** in `chart/values.yaml` — see the
> "Version 1.3.0" section below. Kept here for history; do not read this table as current.

All hardening is **gated behind values flags, default OFF**, so bumping 1.0.0 → 1.1.0
with unchanged values is a near no-op. The only always-on changes: both container
ports (`http` + `metrics`) render regardless of `ingress.enabled`, and `APP_PORT` /
`METRICS_PORT` env are injected for `go-server`.

| Flag | Default | Effect when true |
|---|---|---|
| `probes.enabled` | `false` | startup/liveness/readiness probes on the `metrics` port (9090) |
| `securityContext.enabled` | `false` | non-root, ro-rootfs, drop ALL caps, seccomp RuntimeDefault; `/tmp` emptyDir |
| `podDisruptionBudget.enabled` | `false` | PDB with `minAvailable` (use with `replicas >= 2`) |
| `autoscaling.enabled` | `false` | HPA on CPU+memory; Deployment omits `replicas` |
| `topologySpread.enabled` | `false` | spread replicas across `topologyKey` |
| `serviceMonitor.enabled` | `false` | Prometheus Operator ServiceMonitor scraping `metrics` |

Other defaults: `deployment.replicas: 2`; `resources` sets CPU+memory **requests** and a
**memory limit only** (no CPU limit, anti-throttle); `terminationGracePeriodSeconds: 30`;
`lifecycle.preStopMode: none` (drain in-process via go-server; use `nativeSleep` on k8s ≥1.30).
Migrate a service by setting `probes.enabled`, `securityContext.enabled`, `serviceMonitor.enabled: true`
in its `helm/values.yaml` under `parent:` (see `K8S_HARDENING_PLAN/03-per-service-plans.md`).

## Version 1.3.0 — hardening on by default

`probes.enabled` and `securityContext.enabled` now default **true** (all
services serve the go-server health endpoints on `metrics`; the cluster
enforces PodSecurity). Opt out per-service only if genuinely incompatible.
Also: default `image.registry` is the internal zot registry (ECR retired).
Published by chart-ci from this repo's main branch — do not push manually.

## `envVars` / `secretEnvVars` are lists — Argo CD overrides REPLACE, not merge

`envVars` and `secretEnvVars` in `chart/values.yaml` are plain YAML **lists** of
`{name, value|valueFrom}` / `{name, secretName, secretKey}` entries, rendered by a
straight `{{- range $env := .Values.envVars }}` loop in `chart/templates/deployment.yaml`
(no per-name keying, no merge logic). Helm has no concept of merging two lists by a `name`
field — when a service's `gitops/application-dev.yaml` (or `-prod.yaml`) sets
`helm.valuesObject.parent.envVars` to override even one entry, it **replaces the entire
list wholesale**; every chart-level `helm/values.yaml` entry not repeated there is silently
dropped from the running pod. This is a live footgun, not a theoretical one: as of this
writing, `job-status-service/helm/values.yaml` declares 8 `envVars` (including
`KUBERNETES_NAMESPACE` and `HTTP_PORT`) but `job-status-service/gitops/application-dev.yaml`
overrides `parent.envVars` with only 6 entries — `KUBERNETES_NAMESPACE` and `HTTP_PORT` never
reach the pod. `conversion-status-service` shows the same pattern (11 chart-level entries vs.
6 in its `gitops/application-dev.yaml` override). **Anyone editing a service's `envVars` or
`secretEnvVars` in `helm/values.yaml` must also check whether the matching
`gitops/application-*.yaml` overrides that same array, and if so, copy the full intended list
into the override rather than adding only the new/changed entry.**
