# service-deployment-helm-chart
Helm chart that will be used as a template for all services that run in K8S.

**Current chart version: 1.7.2** (`chart/Chart.yaml`). Every service chart should pin the parent
at 1.7.2 in its `helm/Chart.yaml` (the pin sweep of platform-architecture-improvements-8).

Environment variables: set them with the `parent.env` and `parent.secretEnv` maps
(`secretEnv` entries are `{secretName, secretKey, optional}`); see 1.7.0 to 1.7.2 below. The
`envVars` / `secretEnvVars` lists are legacy: they still render first, and an entry is skipped when
`env` or `secretEnv` has the same name.

## Version 1.7.2 — env list entry superseded by `secretEnv`

An `envVars` list entry is also skipped when `secretEnv` has the same name, so a `valueFrom`
secret ref that moved from the list to `secretEnv` never renders twice.

## Version 1.7.1 — `secretEnv` optional

A `secretEnv` entry may set `optional: true` (renders `secretKeyRef.optional`), so the optional
per-service credentials (`NATS_PASSWORD`, `INTERNAL_TOKEN*`, `GATEWAY_IDENTITY_KEYS*`) move to the
map too and no Application needs a list override for them.

## Version 1.7.0 — `env` / `secretEnv` maps, `image.digest`

Environment variables are now MAPS that Helm merges key by key across values layers (parent
defaults, the service chart's `helm/values.yaml`, the Argo CD Application's `valuesObject`):

```yaml
parent:
  env:
    NATS_URL: nats://nats.data-dev:4222
    LOG_LEVEL: info
  secretEnv:
    DB_URI: {secretName: usage-service-db, secretKey: uri}
```

An Application sets only the keys that differ for its environment; every other key from the
service chart stays in effect. A key set to `null` in a later layer removes it. Map entries render
sorted by name, after the legacy lists.

Legacy lists (`envVars`, `secretEnvVars`) still render, first, for one minor (removal in 1.8.0 at
the earliest, after `infra/infra-gitops/scripts/check-envvars-override.sh` reports zero list
overrides). A list REPLACES the whole list of a lower layer, which is how chart entries were
silently dropped in prod; keep in the list only entries that must render before the maps,
i.e. `valueFrom` field refs such as `POD_NAME` that a map value expands with `$(POD_NAME)`.
A list entry whose name is also a key of the corresponding map is skipped (the map wins, the
name renders once). The parent's default `envVars` list is now empty: `ENV` and `HOST` were
already rendered from `environment` and `host`, and the stale `EMAIL_SERVICE_URL` default is gone
(no service relied on it; every service overrode the list).

Migration of an Application from lists to maps: `infra/infra-gitops/scripts/migrate-env-to-map.sh`
(refuses unless the Application's chart depends on parent >= 1.7.0).

`image.digest` (default empty): when set, the image renders as `<tag>@<digest>`. service-ci and
promote-to-prod record the pushed manifest digest in the Application.

Checks: `chart/tests/env-merge.sh` (merge, list+map, secret merge, ordering, null removal,
digest) and `chart/tests/render-cases.sh`.

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

## Version 1.6.0 — `ingress.extraHosts`

`ingress.extraHosts: []` lists additional application hosts a service answers on. Each
entry renders one more `Host(<host>) && PathPrefix(<ingress.path>)` route on the same
entrypoints with the same middleware chain (gateway plugin + strip-prefix) as the primary
host. This is how a shared platform service serves several applications
(e.g. `usage-service` on `file-convert.online` and `scantinel.ai`): the gateway plugin
resolves `X-App-Id` from the host, nothing else changes. Empty list renders exactly the
1.5.0 output.

## Version 1.5.0 — priorityClassName from environment

`priorityClassName` defaults to `auto`: the Deployment renders `services-prod` for
`environment: prod` and `services-dev` for `dev` (PriorityClasses from infra-gitops
`infra/priority-classes/services.yaml`; prod preempts dev on the shared services pool,
dev never preempts). Any other environment renders nothing. A literal value is rendered
as given; `""` disables it.

| Value | Default | Effect |
|---|---|---|
| `priorityClassName` | `auto` | `services-<environment>` for prod/dev, literal otherwise, `""` = none |

## Version 1.4.0 — availability on by default

`podDisruptionBudget.enabled` and `topologySpread.enabled` are now tri-state
`auto | true | false`, default **`auto`**: rendered whenever the workload has
>= 2 replicas (`deployment.replicas`, or `autoscaling.minReplicas` with HPA on),
never for a singleton (a `minAvailable: 1` PDB on one replica blocks drains and
the descheduler). `tolerations` now defaults to the 60s fast-failover pair
(`node.kubernetes.io/unreachable` + `not-ready`, NoExecute); a service-supplied
list replaces it, an explicit `[]` restores the k8s 300s defaults.

| Flag | Default | Effect |
|---|---|---|
| `podDisruptionBudget.enabled` | `auto` | PDB `minAvailable: 1` when replicas >= 2 |
| `topologySpread.enabled` | `auto` | hostname spread, `maxSkew: 1`, `ScheduleAnyway`, when replicas >= 2 |
| `tolerations` | 60s unreachable/not-ready pair | fast eviction off dead nodes |

Render matrix: `chart/tests/render-cases.sh` (run before bumping the chart).
Existing explicit `true`/`false` values keep their meaning.

## Version 1.3.0 — hardening on by default

`probes.enabled` and `securityContext.enabled` now default **true** (all
services serve the go-server health endpoints on `metrics`; the cluster
enforces PodSecurity). Opt out per-service only if genuinely incompatible.
Also: default `image.registry` is the internal zot registry (ECR retired).
Published by chart-ci from this repo's main branch — do not push manually.

## `envVars` / `secretEnvVars` are lists — Argo CD overrides REPLACE, not merge

(Historical, before 1.7.0; the maps above replace this.) `envVars` and `secretEnvVars` in `chart/values.yaml` are plain YAML **lists** of
`{name, value|valueFrom}` / `{name, secretName, secretKey}` entries, rendered by a
straight `{{- range $env := .Values.envVars }}` loop in `chart/templates/deployment.yaml`
(no per-name keying, no merge logic). Helm has no concept of merging two lists by a `name`
field — when a service's Argo CD Application (`<svc>-dev.yaml` / `-prod.yaml` in infra-gitops) sets
`helm.valuesObject.parent.envVars` to override even one entry, it **replaces the entire
list wholesale**; every chart-level `helm/values.yaml` entry not repeated there is silently
dropped from the running pod. This is a live footgun, not a theoretical one: as of this
writing, `job-status-service/helm/values.yaml` declares 8 `envVars` (including
`KUBERNETES_NAMESPACE` and `HTTP_PORT`) but the `job-status-service-dev` Application
overrides `parent.envVars` with only 6 entries — `KUBERNETES_NAMESPACE` and `HTTP_PORT` never
reach the pod. `conversion-status-service` shows the same pattern (11 chart-level entries vs.
6 in its dev Application override). **Anyone editing a service's `envVars` or
`secretEnvVars` in `helm/values.yaml` must also check whether the matching
Application in infra-gitops overrides that same array, and if so, copy the full intended list
into the override rather than adding only the new/changed entry.**
