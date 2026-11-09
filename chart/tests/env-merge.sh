#!/usr/bin/env bash
# Env map merge checks for 1.7.0 (spec deployment-configuration-model):
#   1. an Application layer setting one key of `env` keeps every chart key
#   2. a name in both the legacy list and the map renders once, map value
#   3. secretEnv keys from two layers are both present
#   4. list field-ref entries (POD_NAME) render before map values using them
#   5. image.digest renders <tag>@<digest>, empty digest renders <tag>
# Usage: chart/tests/env-merge.sh   (needs helm and yq on PATH)
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
envof() { # values-file... -> container env as "NAME=VALUE|secret:NAME/KEY|ref" lines
  local args=(); for f in "$@"; do args+=(-f "$f"); done
  helm template t . "${args[@]}" -s templates/deployment.yaml \
    | yq -r '.spec.template.spec.containers[0].env[] | .name + "=" + (.value // (.valueFrom.secretKeyRef | select(.) | "secret:" + .name + "/" + .key) // "ref")'
}

# Scenario 1: chart defines ten keys, prod sets NATS_URL only.
{ echo "env:"; for i in $(seq 1 9); do echo "  K$i: \"v$i\""; done; echo "  NATS_URL: nats://dev"; } > "$tmp/chart.yaml"
printf 'env:\n  NATS_URL: nats://prod\n' > "$tmp/prod.yaml"
out=$(envof "$tmp/chart.yaml" "$tmp/prod.yaml")
n=$(grep -cE '^(K[1-9]|NATS_URL)=' <<<"$out")
if [[ $n == 10 ]] && grep -qx 'NATS_URL=nats://prod' <<<"$out"; then ok "prod sets one key, all ten present"; else bad "prod sets one key: got $n keys"; echo "$out"; fi

# Scenario 2: LOG_LEVEL in the list and in the map.
printf 'envVars:\n  - name: LOG_LEVEL\n    value: debug\nenv:\n  LOG_LEVEL: info\n' > "$tmp/both.yaml"
out=$(envof "$tmp/both.yaml")
if [[ $(grep -c '^LOG_LEVEL=' <<<"$out") == 1 ]] && grep -qx 'LOG_LEVEL=info' <<<"$out"; then ok "list+map renders once with the map value"; else bad "list+map"; echo "$out"; fi

# Scenario 3: secret map merges across layers.
printf 'secretEnv:\n  DB_URI:\n    secretName: svc-db\n    secretKey: uri\n' > "$tmp/s1.yaml"
printf 'secretEnv:\n  IP_HASH_SALT:\n    secretName: svc-secrets\n    secretKey: ip-hash-salt\n' > "$tmp/s2.yaml"
out=$(envof "$tmp/s1.yaml" "$tmp/s2.yaml")
if grep -qx 'DB_URI=secret:svc-db/uri' <<<"$out" && grep -qx 'IP_HASH_SALT=secret:svc-secrets/ip-hash-salt' <<<"$out"; then ok "secretEnv merges across layers"; else bad "secretEnv merge"; echo "$out"; fi

# secretEnv optional flag (1.7.1)
printf 'secretEnv:\n  NATS_PASSWORD:\n    secretName: nats-credentials\n    secretKey: svc\n    optional: true\n' > "$tmp/opt.yaml"
o=$(helm template t . -f "$tmp/opt.yaml" -s templates/deployment.yaml | yq -r '.spec.template.spec.containers[0].env[] | select(.name=="NATS_PASSWORD") | .valueFrom.secretKeyRef.optional')
[[ $o == true ]] && ok "secretEnv optional renders optional: true" || bad "secretEnv optional ($o)"

# envVars valueFrom entry superseded by a secretEnv key renders once (1.7.2)
printf 'envVars:\n  - name: NATS_PASSWORD\n    valueFrom:\n      secretKeyRef:\n        name: old\n        key: k\n' > "$tmp/old.yaml"
n=$(helm template t . -f "$tmp/old.yaml" -f "$tmp/opt.yaml" -s templates/deployment.yaml | yq -r '[.spec.template.spec.containers[0].env[] | select(.name=="NATS_PASSWORD")] | length')
[[ $n == 1 ]] && ok "envVars entry superseded by secretEnv renders once" || bad "secretEnv supersede ($n)"

# Scenario 4: POD_NAME (list, field ref) precedes NATS_CLIENT_ID (map).
printf 'envVars:\n  - name: POD_NAME\n    valueFrom:\n      fieldRef:\n        fieldPath: metadata.name\nenv:\n  NATS_CLIENT_ID: $(POD_NAME)\n' > "$tmp/ref.yaml"
out=$(envof "$tmp/ref.yaml")
a=$(grep -n '^POD_NAME=' <<<"$out" | cut -d: -f1); b=$(grep -n '^NATS_CLIENT_ID=' <<<"$out" | cut -d: -f1)
if [[ -n $a && -n $b && $a -lt $b ]]; then ok "POD_NAME renders before the map value expanding it"; else bad "ordering ($a, $b)"; echo "$out"; fi

# Scenario 5: null in a later layer removes a chart key.
printf 'env:\n  NATS_URL: null\n' > "$tmp/del.yaml"
out=$(envof "$tmp/chart.yaml" "$tmp/del.yaml")
if ! grep -q '^NATS_URL=' <<<"$out"; then ok "null removes a key"; else bad "null removal"; fi

# image.digest
img() { helm template t . "$@" -s templates/deployment.yaml | yq -r '.spec.template.spec.containers[0].image'; }
[[ $(img --set image.tag=abc1234) == *":abc1234" ]] && ok "no digest renders the tag" || bad "no digest"
[[ $(img --set image.tag=abc1234 --set image.digest=sha256:0123) == *":abc1234@sha256:0123" ]] && ok "digest renders tag@digest" || bad "digest"
exit $fail
