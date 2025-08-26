#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck disable=SC1091
source .env

SNAPSHOT_NAME="snapshot-$(date +%Y%m%d-%H%M%S)"
REPO="local_snapshots"

curl -s -X PUT -u "elastic:${ELASTIC_PASSWORD}" \
  -H 'Content-Type: application/json' \
  "http://localhost:9200/_snapshot/${REPO}/${SNAPSHOT_NAME}?wait_for_completion=true" \
  -d '{"indices": "logs-*", "include_global_state": false}' | jq .

echo "Snapshot ${SNAPSHOT_NAME} created in repo ${REPO}."

# Optional prune: delete snapshots older than N days
if [ "${PRUNE_DAYS:-}" != "" ]; then
  echo "Pruning snapshots older than ${PRUNE_DAYS} days..."
  cutoff=$(date -d "-${PRUNE_DAYS} days" +%s)
  snapshots=$(curl -s -u "elastic:${ELASTIC_PASSWORD}" http://localhost:9200/_snapshot/${REPO}/_all | jq -r '.snapshots[].snapshot')
  for s in $snapshots; do
    # parse time from snapshot name if it matches our pattern
    ts=$(echo "$s" | sed -n 's/snapshot-\([0-9]\{8\}-[0-9]\{6\}\)/\1/p' | sed 's/-//')
    if [ -n "$ts" ]; then
      s_epoch=$(date -d "${ts:0:8} ${ts:8:6}" +%s)
      if [ "$s_epoch" -lt "$cutoff" ]; then
        echo "Deleting snapshot $s"
        curl -s -X DELETE -u "elastic:${ELASTIC_PASSWORD}" http://localhost:9200/_snapshot/${REPO}/$s | jq .
      fi
    fi
  done
fi