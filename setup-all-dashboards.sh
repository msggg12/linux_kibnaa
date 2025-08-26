#!/bin/bash

# Setup Essential Dashboards Only
# ეს script მხოლოდ საჭირო dashboard-ებს ქმნის

set -e

KIBANA_URL="http://localhost:5601"
ELASTIC_USER="elastic"
ELASTIC_PASSWORD="${ELASTIC_PASSWORD:-Madafaka13!}"

echo "🚀 საჭირო Dashboard-ების დაყენება..."

# Wait for Kibana to be ready
echo "⏳ Kibana-ს მზადობის მოლოდინი..."
until curl -s -u "$ELASTIC_USER:$ELASTIC_PASSWORD" "$KIBANA_URL/api/status" | grep -q '"level":"available"'; do
    echo "Kibana-ს ელოდება..."
    sleep 5
done

echo "✅ Kibana მზადაა!"

# 1. System Overview Dashboard
echo "📊 System Overview Dashboard-ის შექმნა..."
curl -X POST "$KIBANA_URL/api/saved_objects/dashboard/system-overview" \
  -H "Content-Type: application/json" \
  -H "kbn-xsrf: true" \
  -u "$ELASTIC_USER:$ELASTIC_PASSWORD" \
  -d '{
    "attributes": {
      "title": "System Overview",
      "description": "სისტემის ზოგადი მონიტორინგი - CPU, Memory, Disk",
      "panelsJSON": "[]",
      "optionsJSON": "{\"useMargins\":true,\"syncColors\":false,\"hidePanelTitles\":false}",
      "version": 1,
      "timeRestore": false,
      "kibanaSavedObjectMeta": {
        "searchSourceJSON": "{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[]}"
      }
    }
  }' || echo "System Overview Dashboard უკვე არსებობს"

# 2. Docker Containers Dashboard
echo "🐳 Docker Containers Dashboard-ის შექმნა..."
curl -X POST "$KIBANA_URL/api/saved_objects/dashboard/docker-containers" \
  -H "Content-Type: application/json" \
  -H "kbn-xsrf: true" \
  -u "$ELASTIC_USER:$ELASTIC_PASSWORD" \
  -d '{
    "attributes": {
      "title": "Docker Containers",
      "description": "Docker კონტეინერების მონიტორინგი",
      "panelsJSON": "[]",
      "optionsJSON": "{\"useMargins\":true,\"syncColors\":false,\"hidePanelTitles\":false}",
      "version": 1,
      "timeRestore": false,
      "kibanaSavedObjectMeta": {
        "searchSourceJSON": "{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[]}"
      }
    }
  }' || echo "Docker Containers Dashboard უკვე არსებობს"

# 3. CloudFront Analytics Dashboard
echo "☁️ CloudFront Analytics Dashboard-ის შექმნა..."
curl -X POST "$KIBANA_URL/api/saved_objects/dashboard/cloudfront-analytics" \
  -H "Content-Type: application/json" \
  -H "kbn-xsrf: true" \
  -u "$ELASTIC_USER:$ELASTIC_PASSWORD" \
  -d '{
    "attributes": {
      "title": "CloudFront Analytics",
      "description": "CloudFront logs-ების ანალიზი",
      "panelsJSON": "[]",
      "optionsJSON": "{\"useMargins\":true,\"syncColors\":false,\"hidePanelTitles\":false}",
      "version": 1,
      "timeRestore": false,
      "kibanaSavedObjectMeta": {
        "searchSourceJSON": "{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[]}"
      }
    }
  }' || echo "CloudFront Analytics Dashboard უკვე არსებობს"

# 4. Elasticsearch Health Dashboard
echo "🔍 Elasticsearch Health Dashboard-ის შექმნა..."
curl -X POST "$KIBANA_URL/api/saved_objects/dashboard/elasticsearch-health" \
  -H "Content-Type: application/json" \
  -H "kbn-xsrf: true" \
  -u "$ELASTIC_USER:$ELASTIC_PASSWORD" \
  -d '{
    "attributes": {
      "title": "Elasticsearch Health",
      "description": "Elasticsearch cluster-ის ჯანმრთელობა",
      "panelsJSON": "[]",
      "optionsJSON": "{\"useMargins\":true,\"syncColors\":false,\"hidePanelTitles\":false}",
      "version": 1,
      "timeRestore": false,
      "kibanaSavedObjectMeta": {
        "searchSourceJSON": "{\"query\":{\"query\":\"\",\"language\":\"kuery\"},\"filter\":[]}"
      }
    }
  }' || echo "Elasticsearch Health Dashboard უკვე არსებობს"

# Create Index Patterns if they don't exist
echo "📋 Index Pattern-ების შექმნა..."

# Metricbeat index pattern
curl -X POST "$KIBANA_URL/api/saved_objects/index-pattern/metricbeat-*" \
  -H "Content-Type: application/json" \
  -H "kbn-xsrf: true" \
  -u "$ELASTIC_USER:$ELASTIC_PASSWORD" \
  -d '{
    "attributes": {
      "title": "metricbeat-*",
      "timeFieldName": "@timestamp"
    }
  }' || echo "Metricbeat index pattern უკვე არსებობს"

# CloudFront enriched index pattern
curl -X POST "$KIBANA_URL/api/saved_objects/index-pattern/cloudfront-logs-enriched-*" \
  -H "Content-Type: application/json" \
  -H "kbn-xsrf: true" \
  -u "$ELASTIC_USER:$ELASTIC_PASSWORD" \
  -d '{
    "attributes": {
      "title": "cloudfront-logs-enriched-*",
      "timeFieldName": "@timestamp"
    }
  }' || echo "CloudFront enriched index pattern უკვე არსებობს"

echo ""
echo "✅ საჭირო Dashboard-ები შექმნილია!"
echo ""
echo "📊 შექმნილი Dashboard-ები:"
echo "   • System Overview - სისტემის მონიტორინგი"
echo "   • Docker Containers - კონტეინერების მონიტორინგი"  
echo "   • CloudFront Analytics - CloudFront logs ანალიზი"
echo "   • Elasticsearch Health - Elasticsearch cluster ჯანმრთელობა"
echo ""
echo "🌐 Kibana: http://localhost:5601"
echo "👤 Username: elastic"
echo "🔑 Password: $ELASTIC_PASSWORD"
echo ""
echo "💡 Dashboard-ები ცარიელია - თქვენ შეგიძლიათ დაამატოთ visualizations Analytics > Visualize Library-დან"
