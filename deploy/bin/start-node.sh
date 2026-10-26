#!/usr/bin/env bash
set -euo pipefail

args=(--config-dir /etc/funod --data-dir /var/lib/funod)
[[ -z "${P2P_PEER:-}" ]] || args+=(--p2p-peer-address "${P2P_PEER}")

if [[ ! -e /var/lib/funod/state/shared_memory.bin ]]; then
  if [[ -n "${SNAPSHOT_FILE:-}" ]]; then
    snapshot="/snapshots/${SNAPSHOT_FILE}"
    [[ -f "${snapshot}" ]] || { echo "snapshot not found: ${snapshot}" >&2; exit 1; }
    args+=(--snapshot "${snapshot}")
  else
    [[ -f /etc/funod/genesis.json ]] || { echo "missing /etc/funod/genesis.json" >&2; exit 1; }
    args+=(--genesis-json /etc/funod/genesis.json)
  fi
fi

exec funod "${args[@]}"
