#!/bin/bash

# ELK Stack Quick Optimization Script
# 🚀 პერფორმანსის სწრაფი გაუმჯობესება

set -e

echo "🔧 ELK Stack-ის სწრაფი ოპტიმიზაცია..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Check if running as root or with sudo
if [[ $EUID -eq 0 ]]; then
   print_warning "არ გაუშვა root-ად! გამოიყენე sudo მხოლოდ საჭიროებისას."
fi

# System optimization
print_info "🔧 სისტემის ოპტიმიზაცია..."

# Increase vm.max_map_count for Elasticsearch
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

print_status "vm.max_map_count გაზრდილია 262144-მდე"

# Set optimal swappiness
echo "vm.swappiness=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl vm.swappiness=1

print_status "swappiness დაყენებულია 1-ზე"

# Increase file descriptor limits
cat <<EOF | sudo tee -a /etc/security/limits.conf
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF

print_status "File descriptor limits გაზრდილია"

# Docker optimization
print_info "🐳 Docker-ის ოპტიმიზაცია..."

# Create docker daemon configuration
sudo mkdir -p /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  }
}
EOF

print_status "Docker daemon კონფიგურაცია ოპტიმიზებულია"

# Backup current configuration
print_info "📁 ძველი კონფიგურაციის Backup..."

BACKUP_DIR="./backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup existing files
cp docker-compose.yml "$BACKUP_DIR/" 2>/dev/null || true
cp .env "$BACKUP_DIR/" 2>/dev/null || true
cp -r elasticsearch/config "$BACKUP_DIR/elasticsearch-config" 2>/dev/null || true
cp -r kibana/config "$BACKUP_DIR/kibana-config" 2>/dev/null || true
cp -r logstash/config "$BACKUP_DIR/logstash-config" 2>/dev/null || true

print_status "Backup შენახულია: $BACKUP_DIR"

# Apply optimized configurations
print_info "🔄 ოპტიმიზებული კონფიგურაციების გამოყენება..."

# Use optimized environment
if [ -f ".env.optimized" ]; then
    cp .env.optimized .env
    print_status "Environment variables განახლებულია"
else
    print_warning ".env.optimized ფაილი ვერ მოიძებნა"
fi

# Use optimized docker-compose
if [ -f "docker-compose-optimized.yml" ]; then
    cp docker-compose-optimized.yml docker-compose.yml
    print_status "Docker Compose კონფიგურაცია განახლებულია"
else
    print_warning "docker-compose-optimized.yml ფაილი ვერ მოიძებნა"
fi

# Stop existing services
print_info "🛑 არსებული სერვისების გაჩერება..."
docker-compose down 2>/dev/null || true

# Clean up old containers and volumes if needed
print_info "🧹 Docker cleanup..."
docker system prune -f
docker volume prune -f

# Create necessary directories
print_info "📁 საჭირო დირექტორიების შექმნა..."
mkdir -p logs/{elasticsearch,kibana,logstash,metricbeat,filebeat}
mkdir -p logstash/{pipeline-fast-optimized,pipeline-enrich-optimized}

# Set proper permissions
sudo chown -R 1000:1000 logs/elasticsearch
sudo chown -R 1000:1000 logstash/
sudo chmod -R 755 logs/
sudo chmod +x scripts/*.sh

print_status "Permissions დაყენებულია"

# Start optimized services
print_info "🚀 ოპტიმიზებული სერვისების გაშვება..."

# Pull latest images
docker-compose pull

# Start services in order
docker-compose up -d elasticsearch redis
print_info "⏳ Elasticsearch და Redis ელოდება startup-ს..."
sleep 30

docker-compose up -d kibana logstash-fast
print_info "⏳ Kibana და Logstash-Fast ელოდება startup-ს..."
sleep 20

docker-compose up -d logstash-enrich metricbeat filebeat
print_info "⏳ დანარჩენი სერვისები იწყება..."
sleep 10

# Health check
print_info "🏥 Health Check..."

# Wait for Elasticsearch
echo "Elasticsearch-ის მოლოდინი..."
for i in {1..30}; do
    if curl -s -u "elastic:${ELASTIC_PASSWORD:-ElasticSecure2024!@#$%}" "http://localhost:9200/_cluster/health" | grep -q "yellow\|green"; then
        print_status "Elasticsearch მუშაობს!"
        break
    fi
    echo "მცდელობა $i/30..."
    sleep 5
done

# Wait for Kibana
echo "Kibana-ს მოლოდინი..."
for i in {1..20}; do
    if curl -s "http://localhost:5601/api/status" | grep -q "available"; then
        print_status "Kibana მუშაობს!"
        break
    fi
    echo "მცდელობა $i/20..."
    sleep 5
done

# Show status
print_info "📊 სერვისების სტატუსი:"
docker-compose ps

# Performance recommendations
print_info "🎯 შემდგომი რეკომენდაციები:"
echo ""
echo "1. მონიტორინგი: http://localhost:5601"
echo "2. Elasticsearch API: http://localhost:9200"
echo "3. Logstash API: http://localhost:9600"
echo ""
echo "📈 რეალ-ტაიმ მონიტორინგისთვის:"
echo "   docker-compose logs -f"
echo ""
echo "💾 მეხსიერების გამოყენება:"
echo "   docker stats"
echo ""

print_status "ოპტიმიზაცია დასრულებულია! 🎉"

# Optional: System monitoring commands
print_info "📊 სისტემის მონიტორინგის ბრძანებები:"
echo "• CPU გამოყენება: htop"
echo "• მეხსიერება: free -h"
echo "• Disk I/O: iostat -x 1"
echo "• Network: iftop"
echo "• Elasticsearch მდგომარეობა: curl -u elastic:password http://localhost:9200/_cluster/health?pretty"

print_status "სკრიპტი წარმატებით დასრულდა!"