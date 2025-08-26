#!/bin/bash

echo "🔍 Setting up Kibana Audit Dashboard..."

# Wait for Kibana to be ready
echo "⏳ Waiting for Kibana to be ready..."
until curl -s -u "elastic:${ELASTIC_PASSWORD}" "http://localhost:5601/api/status" | grep -q "available"; do
  echo "Waiting for Kibana..."
  sleep 5
done

# Create index pattern for audit logs
echo "📊 Creating audit logs index pattern..."
curl -X POST "http://localhost:5601/api/saved_objects/index-pattern/security-audit" \
  -H "Content-Type: application/json" \
  -H "kbn-xsrf: true" \
  -u "elastic:${ELASTIC_PASSWORD}" \
  -d '{
    "attributes": {
      "title": ".security-audit-*",
      "timeFieldName": "@timestamp"
    }
  }'

# Import audit dashboard
echo "📈 Importing audit dashboard..."
curl -X POST "http://localhost:5601/api/saved_objects/_import" \
  -H "kbn-xsrf: true" \
  -u "elastic:${ELASTIC_PASSWORD}" \
  -F "file=@kibana/dashboards/audit-dashboard.json"

echo "✅ Audit dashboard setup complete!"
echo ""
echo "🎯 როგორ ნახოთ user activity:"
echo "1. Kibana-ში გადადით Analytics > Discover"
echo "2. აირჩიეთ '.security-audit-*' index pattern"
echo "3. ან გადადით Analytics > Dashboard > 'Kibana User Activity Audit'"
echo ""
echo "📋 რას ნახავთ:"
echo "- ვინ რა search გააკეთა (event.action: search)"
echo "- ვინ შევიდა სისტემაში (event.action: authentication_success)"
echo "- რა dashboards ნახა (event.action: access_granted)"
echo "- Failed login attempts (event.action: authentication_failed)"
