#!/bin/bash

# Fix file permissions for ELK Stack components
echo "Fixing file permissions for ELK Stack..."

# Fix metricbeat.yml ownership (must be owned by root for metricbeat container)
echo "Setting metricbeat.yml ownership to root..."
sudo chown root:root metricbeat/metricbeat.yml
sudo chmod 644 metricbeat/metricbeat.yml

# Fix filebeat.yml ownership (must be owned by root for filebeat container)
echo "Setting filebeat.yml ownership to root..."
sudo chown root:root filebeat/filebeat.yml
sudo chmod 644 filebeat/filebeat.yml

# Fix elasticsearch config permissions
echo "Setting elasticsearch config permissions..."
sudo chown -R 1000:1000 elasticsearch/
sudo chmod -R 644 elasticsearch/config/

# Fix kibana config permissions  
echo "Setting kibana config permissions..."
sudo chown -R 1000:1000 kibana/
sudo chmod -R 644 kibana/config/

echo "Setting logstash config permissions..."
sudo chown -R 1000:1000 logstash/
sudo chmod -R 755 logstash/config/
sudo chmod -R 644 logstash/config/*.yml
sudo chmod -R 755 logstash/pipeline-fast/
sudo chmod -R 644 logstash/pipeline-fast/*.conf
sudo chmod -R 755 logstash/pipeline-enrich/
sudo chmod -R 644 logstash/pipeline-enrich/*.conf

# Fix redis config permissions
echo "Setting redis config permissions..."
sudo chown -R 999:999 redis/
sudo chmod 644 redis/config/redis.conf

echo "Creating log directories..."
sudo mkdir -p logs/elasticsearch logs/kibana logs/metricbeat logs/filebeat
sudo chown -R 1000:1000 logs/elasticsearch
sudo chown -R 1000:1000 logs/kibana  
sudo chown -R root:root logs/metricbeat
sudo chown -R root:root logs/filebeat
sudo chmod -R 755 logs/

echo "File permissions fixed successfully!"
echo "You can now run: docker-compose up -d"
