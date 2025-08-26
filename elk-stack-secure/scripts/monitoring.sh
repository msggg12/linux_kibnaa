#!/usr/bin/env bash
set -euo pipefail

ES_HEALTH=$(curl -s -u "elastic:${ELASTIC_PASSWORD:-changeme}" http://localhost:9200/_cluster/health)
LOGSTASH_STATS=$(curl -s http://localhost:9600/_node/pipelines/main?pretty)
KIBANA_STATUS=$(curl -s -u "elastic:${ELASTIC_PASSWORD:-changeme}" -H 'kbn-xsrf: true' http://localhost:5601/api/status || true)
PROM_TARGETS=$(curl -s http://localhost:9090/api/v1/targets)

printf "Elasticsearch health: %s\n" "$ES_HEALTH"
printf "Logstash main pipeline: %s\n" "$LOGSTASH_STATS"
printf "Kibana status: %s\n" "$KIBANA_STATUS"
printf "Prometheus targets: %s\n" "$PROM_TARGETS"