# service-deployment-helm-chart
Helm chart that will be used as a template for all services that run in K8S.

## Version 1.1.0 — Kubernetes hardening

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
