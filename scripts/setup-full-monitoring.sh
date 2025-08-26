#!/bin/bash

# 🚀 Full Monitoring Stack Setup Script
# ELK + Grafana + Prometheus ინტეგრირებული Setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_header() {
    echo -e "${PURPLE}🎯 $1${NC}"
}

echo "🚀 სრული მონიტორინგის Setup-ის დაწყება..."

# ==========================================
# PRE-FLIGHT CHECKS
# ==========================================
print_header "Pre-flight Checks"

# Check Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker არ არის დაინსტალირებული"
    exit 1
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose არ არის დაინსტალირებული"
    exit 1
fi

print_status "Docker და Docker Compose მზადაა"

# ==========================================
# BACKUP EXISTING CONTAINERS
# ==========================================
print_header "არსებული კონტეინერების Backup"

BACKUP_DIR="./monitoring-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Export existing Grafana data
print_info "Grafana მონაცემების Export..."
if docker ps | grep -q "grafana"; then
    docker exec grafana grafana-cli admin export-dashboard > "$BACKUP_DIR/grafana-dashboards.json" 2>/dev/null || true
    print_status "Grafana Dashboards exported"
fi

# Export Prometheus data (optional)
print_info "Prometheus კონფიგურაციის Backup..."
if docker ps | grep -q "prometheus"; then
    docker cp prometheus:/etc/prometheus/prometheus.yml "$BACKUP_DIR/" 2>/dev/null || true
    print_status "Prometheus config backed up"
fi

# ==========================================
# SYSTEM OPTIMIZATION
# ==========================================
print_header "სისტემის ოპტიმიზაცია"

# vm.max_map_count for Elasticsearch
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# File descriptor limits
cat <<EOF | sudo tee -a /etc/security/limits.conf
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF

print_status "სისტემური პარამეტრები ოპტიმიზებულია"

# ==========================================
# STOP EXISTING SERVICES
# ==========================================
print_header "არსებული სერვისების გაჩერება"

# Stop existing containers gracefully
existing_containers=("grafana" "prometheus" "node-exporter")
for container in "${existing_containers[@]}"; do
    if docker ps -q -f name="$container" | grep -q .; then
        print_info "$container-ის გაჩერება..."
        docker stop "$container" || true
        docker rm "$container" || true
        print_status "$container გაჩერებულია"
    fi
done

# Stop any existing ELK services
if [ -f "docker-compose.yml" ]; then
    print_info "ELK Stack-ის გაჩერება..."
    docker-compose down || true
fi

print_status "ყველა არსებული სერვისი გაჩერებულია"

# ==========================================
# CONFIGURATION SETUP
# ==========================================
print_header "კონფიგურაციების Setup"

# Use optimized environment
if [ -f ".env.optimized" ]; then
    cp .env.optimized .env
    print_status "Environment variables განახლებულია"
else
    print_warning ".env.optimized ფაილი ვერ მოიძებნა"
fi

# Create necessary directories
print_info "საჭირო დირექტორიების შექმნა..."
mkdir -p logs/{elasticsearch,kibana,logstash,metricbeat,filebeat,grafana,prometheus}
mkdir -p logstash/{pipeline-fast-optimized,pipeline-enrich-optimized}
mkdir -p prometheus grafana/{provisioning/{datasources,dashboards},dashboards}

# Set proper permissions
sudo chown -R 1000:1000 logs/elasticsearch logs/kibana logs/logstash
sudo chown -R 472:472 logs/grafana
sudo chown -R 65534:65534 logs/prometheus
sudo chmod -R 755 logs/
sudo chmod +x scripts/*.sh

print_status "Permissions დაყენებულია"

# ==========================================
# GRAFANA DATASOURCES CONFIGURATION
# ==========================================
print_info "Grafana DataSources-ის კონფიგურაცია..."

cat > grafana/provisioning/datasources/datasources.yml << EOF
apiVersion: 1

datasources:
  # Prometheus DataSource
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true

  # Elasticsearch DataSource
  - name: Elasticsearch
    type: elasticsearch
    access: proxy
    url: http://elasticsearch:9200
    database: "[filebeat-]*"
    basicAuth: true
    basicAuthUser: elastic
    basicAuthPassword: \${ELASTIC_PASSWORD}
    timeField: "@timestamp"
    editable: true

  # Kibana DataSource (for embedding)
  - name: Kibana
    type: grafana-simple-json-datasource
    access: proxy
    url: http://kibana:5601
    basicAuth: true
    basicAuthUser: elastic
    basicAuthPassword: \${ELASTIC_PASSWORD}
    editable: true
EOF

print_status "Grafana DataSources კონფიგურირებულია"

# ==========================================
# START INTEGRATED SERVICES
# ==========================================
print_header "ინტეგრირებული სერვისების გაშვება"

# Use the full monitoring docker-compose
if [ -f "docker-compose-full-monitoring.yml" ]; then
    cp docker-compose-full-monitoring.yml docker-compose.yml
    print_status "Full Monitoring Docker Compose გამოყენებულია"
else
    print_error "docker-compose-full-monitoring.yml ფაილი ვერ მოიძებნა"
    exit 1
fi

# Pull latest images
print_info "Images-ების გადმოწერა..."
docker-compose pull

# Start services in phases
print_info "Phase 1: Infrastructure Services..."
docker-compose up -d elasticsearch redis
sleep 30

print_info "Phase 2: ELK Core Services..."
docker-compose up -d kibana logstash-fast
sleep 20

print_info "Phase 3: Processing Services..."
docker-compose up -d logstash-enrich metricbeat filebeat
sleep 15

print_info "Phase 4: Monitoring Services..."
docker-compose up -d prometheus node-exporter elasticsearch-exporter
sleep 10

print_info "Phase 5: Visualization Services..."
docker-compose up -d grafana
sleep 10

print_status "ყველა სერვისი გაშვებულია"

# ==========================================
# HEALTH CHECKS
# ==========================================
print_header "Health Checks"

# Function to check service health
check_service() {
    local service_name=$1
    local url=$2
    local max_attempts=30
    local attempt=1

    print_info "$service_name-ის მოლოდინი..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$url" > /dev/null 2>&1; then
            print_status "$service_name მუშაობს!"
            return 0
        fi
        echo "მცდელობა $attempt/$max_attempts..."
        sleep 5
        ((attempt++))
    done
    
    print_warning "$service_name მოლოდინის დრო ამოიწურა"
    return 1
}

# Check all services
check_service "Elasticsearch" "http://localhost:9200"
check_service "Kibana" "http://localhost:5601"
check_service "Grafana" "http://localhost:3000"
check_service "Prometheus" "http://localhost:9090"

# ==========================================
# POST-SETUP CONFIGURATION
# ==========================================
print_header "Post-Setup კონფიგურაცია"

# Setup Kibana index patterns
print_info "Kibana Index Patterns-ის შექმნა..."
sleep 30  # Wait for data to be indexed

# Create index patterns for different log types
index_patterns=(
    "filebeat-grafana-*"
    "filebeat-prometheus-*"
    "filebeat-elasticsearch-*"
    "filebeat-docker-*"
    "metricbeat-*"
    "cloudfront-logs-*"
)

for pattern in "${index_patterns[@]}"; do
    curl -X POST "localhost:5601/api/saved_objects/index-pattern/$pattern" \
        -H "Content-Type: application/json" \
        -H "kbn-xsrf: true" \
        -u "elastic:${ELASTIC_PASSWORD:-ElasticSecure2024!@#\$%}" \
        -d "{
            \"attributes\": {
                \"title\": \"$pattern\",
                \"timeFieldName\": \"@timestamp\"
            }
        }" 2>/dev/null || true
done

print_status "Kibana Index Patterns შექმნილია"

# Import Metricbeat dashboards
print_info "Metricbeat Dashboards-ების იმპორტი..."
docker exec metricbeat metricbeat setup --dashboards -E setup.kibana.host=kibana:5601 -E setup.kibana.username=elastic -E setup.kibana.password="${ELASTIC_PASSWORD:-ElasticSecure2024!@#\$%}" || true

print_status "Dashboards იმპორტირებულია"

# ==========================================
# SHOW STATUS
# ==========================================
print_header "სერვისების სტატუსი"
docker-compose ps

print_header "Service URLs"
echo ""
echo "🔍 Kibana (Logs & Analytics):     http://localhost:5601"
echo "📊 Grafana (Dashboards):          http://localhost:3000"
echo "📈 Prometheus (Metrics):          http://localhost:9090"
echo "🔧 Elasticsearch API:             http://localhost:9200"
echo "⚙️  Logstash Fast API:            http://localhost:9600"
echo "⚙️  Logstash Enrich API:          http://localhost:9601"
echo ""

print_header "Default Credentials"
echo ""
echo "Kibana/Elasticsearch:"
echo "  Username: elastic"
echo "  Password: ${ELASTIC_PASSWORD:-ElasticSecure2024!@#\$%}"
echo ""
echo "Grafana:"
echo "  Username: admin"
echo "  Password: ${GRAFANA_PASSWORD:-GrafanaSecure2024!@#\$%}"
echo ""

print_header "რეალ-ტაიმ მონიტორინგი"
echo ""
echo "📊 სერვისების logs: docker-compose logs -f"
echo "💾 რესურსების გამოყენება: docker stats"
echo "🔍 Elasticsearch cluster: curl -u elastic:password http://localhost:9200/_cluster/health?pretty"
echo ""

print_status "Setup წარმატებით დასრულდა! 🎉"

print_info "🎯 შემდეგი ნაბიჯები:"
echo "1. შედი Kibana-ში (http://localhost:5601) და შექმენი Dashboards"
echo "2. შედი Grafana-ში (http://localhost:3000) და დააკონფიგურირე Alerts"
echo "3. გამოიყენე Prometheus (http://localhost:9090) მეტრიკების ანალიზისთვის"
echo "4. მონიტორინგი docker-compose logs -f ბრძანებით"

print_header "Backup მდებარეობა: $BACKUP_DIR"