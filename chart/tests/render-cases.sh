#!/usr/bin/env bash
# Render-matrix check for the availability defaults (1.4.0): PDB / topologySpread
# auto-gate on replica count, tolerations default to the 60s fast-failover pair.
# Usage: chart/tests/render-cases.sh   (needs helm on PATH; exits non-zero on drift)
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
check() { # name expected-count grep-regex helm-args...
  local name=$1 want=$2 re=$3; shift 3
  local got; got=$(helm template t . "$@" | grep -cE "$re" || true)
  if [[ "$got" == "$want" ]]; then echo "ok   $name ($got)"; else echo "FAIL $name: want $want got $got"; fail=1; fi
}
PDBSPREAD='kind: PodDisruptionBudget|topologySpreadConstraints'
check "replicas=2 default renders PDB+spread"      2 "$PDBSPREAD"
check "replicas=1 renders neither"                 0 "$PDBSPREAD" --set deployment.replicas=1
check "hpa minReplicas=2 renders both"             2 "$PDBSPREAD" --set autoscaling.enabled=true
check "hpa minReplicas=1 renders neither"          0 "$PDBSPREAD" --set autoscaling.enabled=true --set autoscaling.minReplicas=1
check "replicas=1 explicit true forces PDB"        1 'kind: PodDisruptionBudget' --set deployment.replicas=1 --set podDisruptionBudget.enabled=true
check "replicas=2 explicit false suppresses both"  0 "$PDBSPREAD" --set podDisruptionBudget.enabled=false --set topologySpread.enabled=false
check "default tolerations: two 60s entries"       2 'tolerationSeconds: 60'
check "custom tolerations replace default"         0 'tolerationSeconds: 60' --set 'tolerations[0].key=workload,tolerations[0].operator=Exists'
check "custom tolerations rendered"                1 'key: workload' --set 'tolerations[0].key=workload,tolerations[0].operator=Exists'
check "empty tolerations list -> k8s defaults"     0 'tolerationSeconds' --set 'tolerations=[]'
exit $fail
