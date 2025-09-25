#!/usr/bin/env bash
set -euo pipefail
NS="${1:?namespace required}"
list=$(kubectl get sa -n "$NS" -o jsonpath='{.items[*].metadata.name}')
arr=$(jq -Rn 'inputs|split(" ")' <<< "$list")
echo "{"workloads_json": "$(jq -c <<< "$arr")"}"
