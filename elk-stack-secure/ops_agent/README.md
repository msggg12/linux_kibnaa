# ELK Ops Agent (Local API)

FastAPI-based local agent to inspect and manage the stack. List files, read/write configs, run compose, invoke setup/backup — all over a localhost-only, token-protected HTTP API.

## Install

On the server (Ubuntu):
```bash
sudo apt-get update && sudo apt-get install -y python3-venv rsync
cd /opt/elk-stack-secure/ops_agent
AGENT_TOKEN=$(openssl rand -hex 24) \
AGENT_PORT=8088 \
REPO_DIR=/opt/elk-stack-secure \
./install.sh
```

Test:
```bash
curl -H "Authorization: Bearer $AGENT_TOKEN" http://127.0.0.1:8088/health
```

## API examples

- Inspect tree:
```bash
curl -s -H "Authorization: Bearer $AGENT_TOKEN" \
  "http://127.0.0.1:8088/files/tree?dir=config&depth=2" | jq
```

- Read file:
```bash
curl -s -H "Authorization: Bearer $AGENT_TOKEN" \
  "http://127.0.0.1:8088/files/read?path=config/filebeat.yml" | jq -r .content
```

- Write file (auto .bak backup):
```bash
curl -s -X POST -H "Authorization: Bearer $AGENT_TOKEN" -H 'Content-Type: application/json' \
  -d @- http://127.0.0.1:8088/files/write <<'JSON'
{
  "path": "config/filebeat.yml",
  "content": "# new content here\n",
  "backup": true
}
JSON
```

- Compose up/down/restart:
```bash
curl -s -X POST -H "Authorization: Bearer $AGENT_TOKEN" -H 'Content-Type: application/json' \
  -d '{"services":[]}' http://127.0.0.1:8088/compose/up | jq
```

- Run setup and backup:
```bash
curl -s -X POST -H "Authorization: Bearer $AGENT_TOKEN" http://127.0.0.1:8088/setup | jq
curl -s -X POST -H "Authorization: Bearer $AGENT_TOKEN" -H 'Content-Type: application/json' \
  -d '{"prune_days":14}' http://127.0.0.1:8088/backup | jq
```

- Status snapshot (wraps scripts/monitoring.sh):
```bash
curl -s -H "Authorization: Bearer $AGENT_TOKEN" http://127.0.0.1:8088/status | jq -r .output
```

## Security
- Listens on 127.0.0.1 only; protect with token
- Rotate `AGENT_TOKEN` by editing the systemd unit and restarting service
- Writes are restricted to `config/`, `scripts/`, `dashboards/`
- For remote control, expose via SSH tunnel only: `ssh -L 8088:127.0.0.1:8088 user@server`