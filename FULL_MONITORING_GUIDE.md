# 🚀 სრული ინტეგრირებული მონიტორინგის Guide

## 📊 **არსებული → ინტეგრირებული Setup**

თქვენ გაქვთ:
- ✅ Grafana (3000 port)
- ✅ Prometheus (9090 port) 
- ✅ Node Exporter (9100 port)

ახლა მოვამზადებთ:
- 🎯 **ELK Stack** (Elasticsearch, Logstash, Kibana)
- 🎯 **ინტეგრირებული Grafana + Prometheus**
- 🎯 **ყველა ლოგის ცენტრალიზაცია Kibana-ში**

---

## 🔥 **სწრაფი Migration (5 წუთი)**

```bash
# 1. Repository Clone/Update
cd ~/elk-stack-secure
git pull origin main

# 2. Full Setup-ის გაშვება (ავტომატური migration)
chmod +x scripts/setup-full-monitoring.sh
./scripts/setup-full-monitoring.sh
```

---

## 📋 **სერვისების რუკა**

### **🎯 ახალი Ports რუკა:**
| სერვისი | Port | URL | აღწერა |
|---------|------|-----|--------|
| **Kibana** | 5601 | http://localhost:5601 | ლოგების ანალიზი და Dashboard |
| **Grafana** | 3000 | http://localhost:3000 | მეტრიკების Dashboard |
| **Prometheus** | 9090 | http://localhost:9090 | მეტრიკების შეგროვება |
| **Elasticsearch** | 9200 | http://localhost:9200 | ძიების ძრავა |
| **Node Exporter** | 9100 | http://localhost:9100 | სისტემური მეტრიკები |
| **ES Exporter** | 9114 | http://localhost:9114 | Elasticsearch მეტრიკები |

### **🔍 ლოგების კატეგორიები Kibana-ში:**
- `filebeat-grafana-*` - Grafana ლოგები
- `filebeat-prometheus-*` - Prometheus ლოგები  
- `filebeat-elasticsearch-*` - Elasticsearch ლოგები
- `filebeat-docker-*` - ყველა Docker კონტეინერი
- `metricbeat-*` - სისტემური მეტრიკები
- `cloudfront-logs-*` - თქვენი მთავარი აპლიკაციის ლოგები

---

## 🎛️ **Manual Setup (თუ ავტომატური არ იმუშავა)**

### **1. არსებული კონტეინერების Backup**

```bash
# Grafana Dashboards Export
mkdir -p backup-$(date +%Y%m%d)
docker exec grafana grafana-cli admin export-dashboard > backup-$(date +%Y%m%d)/dashboards.json

# Prometheus Config Backup
docker cp prometheus:/etc/prometheus/prometheus.yml backup-$(date +%Y%m%d)/
```

### **2. არსებული კონტეინერების გაჩერება**

```bash
# გაჩერება (მონაცემები შენარჩუნდება Docker volumes-ში)
docker stop grafana prometheus node-exporter
docker rm grafana prometheus node-exporter
```

### **3. ინტეგრირებული კონფიგურაციების გამოყენება**

```bash
# Environment და Docker Compose განახლება
cp .env.optimized .env
cp docker-compose-full-monitoring.yml docker-compose.yml

# სერვისების გაშვება
docker-compose up -d
```

---

## 🎯 **სერვისების Integration**

### **Grafana Integration:**
- **DataSources:** ავტომატურად კონფიგურირებული Prometheus + Elasticsearch
- **Dashboards:** ძველი dashboards იმპორტირდება
- **Alerts:** ძველი alert rules შენარჩუნდება

### **Prometheus Integration:**
- **Targets:** ყველა ELK კომპონენტი მონიტორინგში
- **Elasticsearch Exporter:** ELK მეტრიკების მონიტორინგი
- **Enhanced Scraping:** Node, Docker, Application მეტრიკები

### **Kibana Integration:**
- **Log Aggregation:** ყველა სერვისის ლოგები ერთ ადგილზე
- **Index Patterns:** ავტომატურად შექმნილი
- **Dashboards:** Metricbeat dashboards ავტომატურად იმპორტირებული

---

## 🔧 **Performance Improvements**

### **Memory Allocation:**
| სერვისი | ძველი | ახალი | Improvement |
|---------|-------|-------|-------------|
| Elasticsearch | - | **16GB** | **ახალი** |
| Logstash | - | **6GB** | **ახალი** |
| Grafana | 512MB | **2GB** | **300% ↑** |
| Prometheus | 1GB | **2GB** | **100% ↑** |
| Redis Buffer | - | **3GB** | **ახალი** |

### **Network Optimization:**
- ყველა სერვისი **ერთ network-ში**
- **Internal Communication** optimized
- **Service Discovery** ავტომატური

---

## 📊 **მონიტორინგის სტრატეგია**

### **Grafana (მეტრიკები):**
- System Performance (CPU, Memory, Disk)
- Application Metrics (Response Time, Error Rate)
- Infrastructure Health (Network, Storage)
- Custom Business Metrics

### **Kibana (ლოგები):**
- Application Logs Analysis
- Error Tracking და Debugging
- Security Events
- User Activity Logs
- Performance Troubleshooting

### **ერთობლივი დანახვა:**
```bash
# Real-time monitoring
docker stats

# Services health
docker-compose ps

# Logs monitoring
docker-compose logs -f
```

---

## 🚨 **Alert Rules**

### **Grafana Alerts:**
```yaml
# High CPU Usage
- alert: HighCPUUsage
  expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
  for: 5m

# Elasticsearch Cluster Health
- alert: ElasticsearchClusterRed
  expr: elasticsearch_cluster_health_status{color="red"} == 1
  for: 1m

# High Memory Usage
- alert: HighMemoryUsage
  expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.85
  for: 5m
```

### **Kibana Alerts:**
```json
{
  "name": "High Error Rate",
  "rule_type_id": ".index-threshold",
  "schedule": { "interval": "1m" },
  "params": {
    "index": ["filebeat-*"],
    "timeField": "@timestamp",
    "aggType": "count",
    "threshold": [100]
  }
}
```

---

## 🎯 **გამოყენების სცენარები**

### **1. Application Debugging:**
```bash
# Kibana-ში შედი და ძებნა:
service: "your-app" AND level: "ERROR"
```

### **2. Performance Analysis:**
```bash
# Grafana Dashboard-ზე ნახე:
- CPU/Memory trends
- Response time metrics
- Database query performance
```

### **3. Infrastructure Monitoring:**
```bash
# Prometheus Queries:
node_cpu_seconds_total
elasticsearch_cluster_health_status
docker_container_memory_usage_bytes
```

---

## 🔍 **Dashboard Examples**

### **Kibana Dashboard:**
1. **Application Overview:**
   - Log volume trends
   - Error rate by service
   - Top error messages
   - User activity patterns

2. **Infrastructure Overview:**
   - Container resource usage
   - Network traffic
   - Storage utilization
   - Service availability

### **Grafana Dashboard:**
1. **System Overview:**
   - CPU, Memory, Disk metrics
   - Network throughput
   - Process monitoring
   - Docker container stats

2. **ELK Stack Health:**
   - Elasticsearch cluster metrics
   - Logstash pipeline performance
   - Kibana response times
   - Index growth rates

---

## 🚀 **გაშვების ინსტრუქციები**

### **სწრაფი გაშვება:**
```bash
# ყველაფერი ერთად
./scripts/setup-full-monitoring.sh
```

### **ნაბიჯ-ნაბიჯ:**
```bash
# 1. Environment setup
cp .env.optimized .env

# 2. Docker compose
cp docker-compose-full-monitoring.yml docker-compose.yml

# 3. Start services
docker-compose up -d

# 4. Health check
curl -u elastic:password http://localhost:9200/_cluster/health
```

### **მონაცემების შემოწმება:**
```bash
# Kibana Index Patterns
curl -u elastic:password http://localhost:5601/api/saved_objects/index-pattern

# Grafana DataSources
curl -u admin:password http://localhost:3000/api/datasources

# Prometheus Targets
curl http://localhost:9090/api/v1/targets
```

---

## 🎉 **წარმატების ინდიკატორები**

✅ **ყველა სერვისი გაშვებული:**
```bash
docker-compose ps | grep "Up"
```

✅ **ლოგები ჩანს Kibana-ში:**
- http://localhost:5601 → Discover

✅ **მეტრიკები ჩანს Grafana-ში:**  
- http://localhost:3000 → Dashboards

✅ **Prometheus targets healthy:**
- http://localhost:9090 → Targets

✅ **Elasticsearch cluster green:**
```bash
curl -u elastic:password http://localhost:9200/_cluster/health
```

---

## 🔧 **Troubleshooting**

### **რასაც უნდა შეამოწმო:**
```bash
# Services status
docker-compose ps

# Services logs
docker-compose logs elasticsearch
docker-compose logs kibana
docker-compose logs grafana

# Disk space
df -h

# Memory usage
free -h

# Network connectivity
docker network ls
docker network inspect elk-stack-secure_monitoring
```

### **ხშირი პრობლემები:**
1. **Elasticsearch yellow/red:** → Check disk space
2. **Kibana not loading:** → Check Elasticsearch connection
3. **Grafana no data:** → Check Prometheus datasource
4. **Memory issues:** → Check swap and available RAM

---

## 💻 **მოკლე Commands**

```bash
# სერვისების restart
docker-compose restart

# ლოგების monitoring
docker-compose logs -f

# რესურსების monitoring  
docker stats

# cleanup
docker system prune -f

# backup
./scripts/backup-monitoring.sh
```

**🎉 ყველაფერი მზადაა! ახლა გაქვთ სრული ინტეგრირებული მონიტორინგი!** 🚀