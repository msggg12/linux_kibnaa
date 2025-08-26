#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  cp .env.example .env
fi

# shellcheck disable=SC1091
source .env

export ELASTIC_PASSWORD KIBANA_SYSTEM_PASSWORD

COMPOSE="docker compose"
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required" >&2
  exit 1
fi

$COMPOSE up -d elasticsearch

echo "Waiting for Elasticsearch to become healthy..."
for i in {1..60}; do
  if curl -s -u "elastic:${ELASTIC_PASSWORD}" http://localhost:9200/_cluster/health?wait_for_status=yellow | grep -q '"status"'; then
    echo "Elasticsearch is up."
    break
  fi
  sleep 5
  if [ "$i" -eq 60 ]; then
    echo "Elasticsearch did not become healthy in time" >&2
    exit 1
  fi
done

# Set kibana_system password
curl -s -X POST -u "elastic:${ELASTIC_PASSWORD}" \
  -H 'Content-Type: application/json' \
  http://localhost:9200/_security/user/kibana_system/_password \
  -d "{\"password\": \"${KIBANA_SYSTEM_PASSWORD}\"}" | jq . >/dev/null 2>&1 || true

echo "Creating ILM policy (90d delete) and index template for logs-*"
# ILM policy
curl -s -X PUT -u "elastic:${ELASTIC_PASSWORD}" \
  -H 'Content-Type: application/json' \
  http://localhost:9200/_ilm/policy/logs-90d-policy \
  -d '{
    "policy": {
      "phases": {
        "hot": {"actions": {}},
        "delete": {
          "min_age": "90d",
          "actions": {"delete": {}}
        }
      }
    }
  }' | jq . >/dev/null 2>&1 || true

# Index template
curl -s -X PUT -u "elastic:${ELASTIC_PASSWORD}" \
  -H 'Content-Type: application/json' \
  http://localhost:9200/_index_template/logs-template \
  -d '{
    "index_patterns": ["logs-*"] ,
    "template": {
      "settings": {
        "number_of_shards": 1,
        "number_of_replicas": 0,
        "index.lifecycle.name": "logs-90d-policy",
        "refresh_interval": "10s"
      },
      "mappings": {
        "dynamic": true
      }
    },
    "priority": 500
  }' | jq . >/dev/null 2>&1 || true

# Register snapshot repository
curl -s -X PUT -u "elastic:${ELASTIC_PASSWORD}" \
  -H 'Content-Type: application/json' \
  http://localhost:9200/_snapshot/local_snapshots \
  -d '{
    "type": "fs",
    "settings": {"location": "/usr/share/elasticsearch/snapshots", "compress": true}
  }' | jq . >/dev/null 2>&1 || true

# Start the rest of the stack
$COMPOSE up -d

echo "Setup complete. Access Kibana at http://localhost:5601 and Grafana at http://localhost:3000"