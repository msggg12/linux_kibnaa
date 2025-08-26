#!/usr/bin/env bash
set -euo pipefail

AGENT_DIR=${AGENT_DIR:-/opt/elk-stack-secure/ops_agent}
REPO_DIR=${REPO_DIR:-/opt/elk-stack-secure}
AGENT_PORT=${AGENT_PORT:-8088}
AGENT_TOKEN=${AGENT_TOKEN:-}
PYTHON_BIN=${PYTHON_BIN:-python3}

if [ -z "$AGENT_TOKEN" ]; then
  echo "Please set AGENT_TOKEN to a strong secret (e.g., openssl rand -hex 24)" >&2
  exit 1
fi

sudo mkdir -p "$AGENT_DIR"
sudo rsync -a ./ "$AGENT_DIR"/

cd "$AGENT_DIR"
$PYTHON_BIN -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo "Writing systemd unit..."
UNIT_FILE=/etc/systemd/system/elk-ops-agent.service
sudo bash -c "cat > $UNIT_FILE" <<EOF
[Unit]
Description=ELK Ops Agent (FastAPI)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SUDO_USER:-$USER}
WorkingDirectory=$AGENT_DIR
Environment=AGENT_TOKEN=$AGENT_TOKEN
Environment=AGENT_PORT=$AGENT_PORT
Environment=REPO_DIR=$REPO_DIR
ExecStart=$AGENT_DIR/.venv/bin/uvicorn ops_agent.agent:app --host 127.0.0.1 --port $AGENT_PORT --workers 1
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now elk-ops-agent.service

sleep 1
systemctl --no-pager status elk-ops-agent.service | cat

echo "Agent running on 127.0.0.1:$AGENT_PORT"
echo "Test: curl -H 'Authorization: Bearer $AGENT_TOKEN' http://127.0.0.1:$AGENT_PORT/health"