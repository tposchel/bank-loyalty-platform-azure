#!/usr/bin/env bash
set -euo pipefail
STORE="${1:-}"; KEY="${2:-}"; LABEL="${3:-}"
if [[ -z "$STORE" || -z "$KEY" ]]; then echo "Usage: $0 <appconfig-name> <key> <label>" >&2; exit 1; fi
ARGS=(--name "$STORE" --key "$KEY" --resolve-keyvault true -o json)
if [[ -n "$LABEL" ]]; then ARGS+=(--label "$LABEL"); fi
JSON=$(az appconfig kv show "${ARGS[@]}")
VAL=$(echo "$JSON" | jq -r '.value // .content.value // empty')
echo "{"audience": "${VAL:-}"}"
