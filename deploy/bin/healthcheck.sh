#!/usr/bin/env bash
set -euo pipefail

[[ "${EXPECTED_CHAIN_ID:-}" =~ ^[0-9a-f]{64}$ ]] || {
  echo "EXPECTED_CHAIN_ID must be a 64-character lowercase chain ID" >&2
  exit 1
}

info=$(curl -fsS -X POST -H 'Content-Type: application/json' -d '{}' \
  http://127.0.0.1:8888/v1/chain/get_info)

printf '%s' "${info}" | grep -Eq \
  '"chain_id"[[:space:]]*:[[:space:]]*"'"${EXPECTED_CHAIN_ID}"'"'
