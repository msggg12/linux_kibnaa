# ELK Stack Secure + Monitoring

This repository contains a production-ready ELK (Elasticsearch, Logstash, Kibana) stack integrated with Prometheus and Grafana for observability, including Beats for log and metric collection.

## Quick start

1) Copy env and review secrets:

```bash
cp .env.example .env
sed -i 's/changeme-strong/el@st1c-Strong-P@ss/g' .env
```

2) Start and initialize:

```bash
./scripts/setup.sh
```

3) Access:
- Kibana: http://localhost:5601 (login: elastic / $ELASTIC_PASSWORD)
- Grafana: http://localhost:3000 (admin / admin)
- Prometheus: http://localhost:9090

## Data
- Elasticsearch data in Docker volume `es-data`
- Snapshots in volume `es-snapshots` (repo: `local_snapshots`)

## Backups

```bash
./scripts/backup.sh
PRUNE_DAYS=14 ./scripts/backup.sh  # optional prune
```

## Monitoring

```bash
./scripts/monitoring.sh
```

## Performance
- ES JVM heap: 16g (for 32GB RAM host)
- Shards per daily index: 1 shard, 0 replicas (single node)
- Refresh interval: 10s
- Logstash workers: 4, batch size 125

## Security
- xpack security enabled
- Change all default passwords and keys in `.env` and `config/kibana.yml`
- For TLS, terminate at a reverse proxy or enable ES/Kibana TLS

## Compose commands

```bash
docker compose up -d
docker compose ps
docker compose logs -f elasticsearch | cat
```

## Structure

See repository tree in the root README of this project.