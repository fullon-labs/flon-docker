#!/usr/bin/env bash
set -euo pipefail

args=(--config-dir /etc/funod --data-dir /var/lib/funod)
[[ -z "${P2P_PEER:-}" ]] || args+=(--p2p-peer-address "${P2P_PEER}")

case "${FLON_NETWORK:-}" in
  mainnet) expected_genesis_sha256=d4aae059868a50401a6169c2a8261f0b9d1d12ab0638eaaf96f22d467b84bddb ;;
  testnet) expected_genesis_sha256=4df875d57f88fe244c21a5d9906a171af95a5bc208e5ea817be8e8089cc42311 ;;
  *) echo "FLON_NETWORK must be mainnet or testnet" >&2; exit 1 ;;
esac

[[ -f /etc/funod/genesis.json ]] || { echo "missing ${FLON_NETWORK} genesis.json" >&2; exit 1; }
actual_genesis_sha256=$(sha256sum /etc/funod/genesis.json | awk '{print $1}')
[[ "${actual_genesis_sha256}" == "${expected_genesis_sha256}" ]] || {
  echo "genesis checksum mismatch for ${FLON_NETWORK}" >&2
  exit 1
}

if [[ ! -e /var/lib/funod/state/shared_memory.bin ]]; then
  if [[ -n "${SNAPSHOT_FILE:-}" ]]; then
    snapshot="/snapshots/${SNAPSHOT_FILE}"
    [[ -f "${snapshot}" ]] || { echo "snapshot not found: ${snapshot}" >&2; exit 1; }
    args+=(--snapshot "${snapshot}")
  else
    args+=(--genesis-json /etc/funod/genesis.json)
  fi
fi

exec funod "${args[@]}"
