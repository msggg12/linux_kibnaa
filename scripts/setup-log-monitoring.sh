#!/bin/bash

echo "📋 ლოგების მონიტორინგის კონფიგურაცია..."
echo "======================================"

# Load environment variables
source .env

# Create log directories if they don't exist
echo "📁 ლოგების დირექტორიების შექმნა..."
sudo mkdir -p logs/{elasticsearch,kibana,metricbeat,filebeat}

# Set proper permissions
echo "🔐 Permissions-ების დაყენება..."
sudo chown -R 1000:1000 logs/elasticsearch
sudo chown -R 1000:1000 logs/kibana
sudo chown -R root:root logs/metricbeat
sudo chown -R root:root logs/filebeat
sudo chmod -R 755 logs/

#  Fixed docker-compose command to use docker compose (space instead of hyphen)
# Restart filebeat to apply new configuration
echo "🔄 Filebeat-ის restart..."
docker compose restart filebeat

# Wait for filebeat to start
echo "⏳ Filebeat-ის ჩართვის მოლოდინი..."
sleep 10

# Create index patterns for log monitoring
echo "📊 Index Patterns-ების შექმნა..."

# Container logs index pattern
curl -X POST "http://localhost:5601/api/saved_objects/index-pattern/container-logs-*" \
  -H "Content-Type: application/json" \
  -H "kbn-xsrf: true" \
  -u "elastic:${ELASTIC_PASSWORD}" \
  -d '{
    "attributes": {
      "title": "container-logs-*",
      "timeFieldName": "@timestamp"
    }
  }' 2>/dev/null

# Elasticsearch logs index pattern
curl -X POST "http://localhost:5601/api/saved_objects/index-pattern/elasticsearch-logs-*" \
  -H "Content-Type: application/json" \
  -H "kbn-xsrf: true" \
  -u "elastic:${ELASTIC_PASSWORD}" \
  -d '{
    "attributes": {
      "title": "elasticsearch-logs-*",
      "timeFieldName": "@timestamp"
    }
  }' 2>/dev/null

# Kibana logs index pattern
curl -X POST "http://localhost:5601/api/saved_objects/index-pattern/kibana-logs-*" \
  -H "Content-Type: application/json" \
  -H "kbn-xsrf: true" \
  -u "elastic:${ELASTIC_PASSWORD}" \
  -d '{
    "attributes": {
      "title": "kibana-logs-*",
      "timeFieldName": "@timestamp"
    }
  }' 2>/dev/null

echo ""
echo "✅ ლოგების მონიტორინგი კონფიგურირებულია!"
echo ""
echo "📋 ხელმისაწვდომი Index Patterns:"
echo "  • container-logs-* - ყველა კონტეინერის ლოგები"
echo "  • elasticsearch-logs-* - Elasticsearch ლოგები"
echo "  • kibana-logs-* - Kibana ლოგები"
echo "  • metricbeat-logs-* - Metricbeat ლოგები"
echo ""
echo "🔍 ლოგების სანახავად:"
echo "  1. გადადი Kibana > Analytics > Discover"
echo "  2. აირჩიე შესაბამისი Index Pattern"
echo "  3. გაფილტრე container.name ველით კონკრეტული კონტეინერისთვის"

