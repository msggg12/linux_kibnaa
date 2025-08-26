#!/bin/bash

echo "🔍 ELK Stack სერვისების ჯანმრთელობის შემოწმება..."
echo "=================================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check service health
check_service() {
    local service_name=$1
    local health_status=$(docker inspect --format='{{.State.Health.Status}}' $service_name 2>/dev/null)
    local running_status=$(docker inspect --format='{{.State.Running}}' $service_name 2>/dev/null)
    
    if [ "$running_status" = "true" ]; then
        if [ "$health_status" = "healthy" ] || [ -z "$health_status" ]; then
            echo -e "${GREEN}✅ $service_name: ცოცხალი და ჯანსაღი${NC}"
        elif [ "$health_status" = "unhealthy" ]; then
            echo -e "${RED}❌ $service_name: ცოცხალი მაგრამ არაჯანსაღი${NC}"
        else
            echo -e "${YELLOW}⏳ $service_name: ცოცხალი, ჯანმრთელობა შემოწმდება...${NC}"
        fi
    else
        echo -e "${RED}💀 $service_name: გამორთული${NC}"
    fi
}

# Check all services
echo "📊 კონტეინერების სტატუსი:"
echo "------------------------"
check_service "elasticsearch"
check_service "kibana"
check_service "logstash-fast"
check_service "logstash-enrich"
check_service "redis"
check_service "metricbeat"
check_service "filebeat"

echo ""
echo "📈 Logstash Performance მეტრიკები:"
echo "--------------------------------"

# Check Logstash Fast performance
echo "🚀 Logstash-Fast Pipeline Stats:"
curl -s "http://localhost:9600/_node/stats/pipelines" | jq -r '
.pipelines.main.events | 
"  📥 შემოსული: \(.in) ჩანაწერი",
"  📤 გამოსული: \(.out) ჩანაწერი", 
"  ⚡ სიჩქარე: \((.out / 60) | floor) ჩანაწერი/წუთი"
' 2>/dev/null || echo "  ❌ Logstash-Fast API მიუწვდომელია"

echo ""
echo "🔄 Logstash-Enrich Pipeline Stats:"
curl -s "http://localhost:9601/_node/stats/pipelines" | jq -r '
.pipelines.main.events | 
"  📥 შემოსული: \(.in) ჩანაწერი",
"  📤 გამოსული: \(.out) ჩანაწერი",
"  ⚡ სიჩქარე: \((.out / 60) | floor) ჩანაწერი/წუთი"
' 2>/dev/null || echo "  ❌ Logstash-Enrich API მიუწვდომელია"

echo ""
echo "🗄️ Elasticsearch Cluster ჯანმრთელობა:"
echo "------------------------------------"
curl -s -u "elastic:${ELASTIC_PASSWORD}" "http://localhost:9200/_cluster/health?pretty" | jq -r '
"  🟢 სტატუსი: \(.status)",
"  📊 ნოდები: \(.number_of_nodes)",
"  📁 ინდექსები: \(.number_of_data_nodes)",
"  🔄 აქტიური shards: \(.active_shards)"
' 2>/dev/null || echo "  ❌ Elasticsearch API მიუწვდომელია"

echo ""
echo "📋 Docker კონტეინერების რესურსები:"
echo "--------------------------------"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

echo ""
echo "🔍 შემოწმება დასრულდა!"
