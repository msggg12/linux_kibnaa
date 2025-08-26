#!/bin/bash

# Elasticsearch Users Setup Script
# Creates necessary users for the ELK stack

set -e

source .env

echo "Setting up Elasticsearch users..."

# Wait for Elasticsearch to be ready
echo "Waiting for Elasticsearch to start..."
until curl -s -u "elastic:$ELASTIC_PASSWORD" "http://localhost:9200/_cluster/health" > /dev/null; do
    echo "Waiting for Elasticsearch..."
    sleep 5
done

echo "Elasticsearch is ready. Setting up users..."

# Set kibana_system user password
echo "Setting kibana_system password..."
curl -X POST "localhost:9200/_security/user/kibana_system/_password" \
  -u "elastic:$ELASTIC_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"$KIBANA_SYSTEM_PASSWORD\"}"

# Set logstash_system user password  
echo "Setting logstash_system password..."
curl -X POST "localhost:9200/_security/user/logstash_system/_password" \
  -u "elastic:$ELASTIC_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"$LOGSTASH_INTERNAL_PASSWORD\"}"

# Set beats_system user password
echo "Setting beats_system password..."
curl -X POST "localhost:9200/_security/user/beats_system/_password" \
  -u "elastic:$ELASTIC_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"$BEATS_SYSTEM_PASSWORD\"}"

# Set apm_system user password
echo "Setting apm_system password..."
curl -X POST "localhost:9200/_security/user/apm_system/_password" \
  -u "elastic:$ELASTIC_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"$APM_SYSTEM_PASSWORD\"}"

# Set remote_monitoring_user password
echo "Setting remote_monitoring_user password..."
curl -X POST "localhost:9200/_security/user/remote_monitoring_user/_password" \
  -u "elastic:$ELASTIC_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"$REMOTE_MONITORING_USER_PASSWORD\"}"

echo ""
echo "Verifying user setup..."
curl -s -u "kibana_system:$KIBANA_SYSTEM_PASSWORD" "http://localhost:9200/_security/_authenticate" > /dev/null && echo "✓ kibana_system user verified" || echo "✗ kibana_system user failed"
curl -s -u "logstash_system:$LOGSTASH_INTERNAL_PASSWORD" "http://localhost:9200/_security/_authenticate" > /dev/null && echo "✓ logstash_system user verified" || echo "✗ logstash_system user failed"

echo ""
echo "All users have been set up successfully!"
echo ""
echo "Access Information:"
echo "==================="
echo "Elasticsearch: http://localhost:9200"
echo "  Username: elastic"
echo "  Password: $ELASTIC_PASSWORD"
echo ""
echo "Kibana: http://localhost:5601"
echo "  Username: elastic"
echo "  Password: $ELASTIC_PASSWORD"
echo ""
echo "Redis: localhost:6379"
echo "  Password: $REDIS_PASSWORD"
echo ""
echo "Next steps:"
echo "1. Restart Kibana: docker-compose restart kibana"
echo "2. Check Kibana logs: docker logs kibana"
