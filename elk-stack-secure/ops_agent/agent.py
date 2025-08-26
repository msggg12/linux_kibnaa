#!/usr/bin/env python3
import os
import subprocess
import shlex
import json
from pathlib import Path
from typing import List, Optional, Dict, Any

from fastapi import FastAPI, HTTPException, Header, Depends, Query
from pydantic import BaseModel, Field

APP_TOKEN = os.environ.get("AGENT_TOKEN", "")
APP_PORT = int(os.environ.get("AGENT_PORT", "8088"))

REPO_ROOT = Path(os.environ.get("REPO_DIR", Path(__file__).resolve().parents[1]))
ALLOWED_WRITE_DIRS = [REPO_ROOT / "config", REPO_ROOT / "scripts", REPO_ROOT / "dashboards"]
COMPOSE_FILE = REPO_ROOT / "docker-compose.yml"

app = FastAPI(title="ELK Ops Agent", version="1.0.0")


def require_token(authorization: Optional[str] = Header(None)):
    if not APP_TOKEN:
        raise HTTPException(status_code=500, detail="AGENT_TOKEN not set")
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Bearer token")
    token = authorization.split(" ", 1)[1]
    if token != APP_TOKEN:
        raise HTTPException(status_code=403, detail="Invalid token")
    return True


def run_cmd(cmd: List[str], cwd: Optional[Path] = None, timeout: int = 120) -> subprocess.CompletedProcess:
    try:
        proc = subprocess.run(cmd, cwd=str(cwd) if cwd else None, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout, text=True)
        return proc
    except subprocess.TimeoutExpired as exc:
        raise HTTPException(status_code=504, detail=f"Command timed out: {' '.join(cmd)}") from exc


def is_subpath(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except Exception:
        return False


class FileWriteRequest(BaseModel):
    path: str = Field(..., description="Relative path within repo, e.g., config/filebeat.yml")
    content: str = Field(..., description="Full file content to write")
    backup: bool = Field(True, description="Save .bak before overwrite")


class ComposeServicesRequest(BaseModel):
    services: Optional[List[str]] = Field(None, description="Specific services to act on; default all")


class BackupRequest(BaseModel):
    prune_days: Optional[int] = Field(None, description="Delete snapshots older than N days")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/info", dependencies=[Depends(require_token)])
def info():
    return {
        "repo_root": str(REPO_ROOT),
        "compose_file": str(COMPOSE_FILE),
        "allowed_write_dirs": [str(p) for p in ALLOWED_WRITE_DIRS],
    }


@app.get("/files/tree", dependencies=[Depends(require_token)])
def files_tree(dir: str = Query("", description="Subdir under repo (blank for root)"), depth: int = Query(2, ge=1, le=6)):
    base = (REPO_ROOT / dir).resolve()
    if not is_subpath(base, REPO_ROOT) or not base.exists():
        raise HTTPException(status_code=400, detail="Invalid directory")

    def walk(p: Path, d: int) -> Dict[str, Any]:
        node: Dict[str, Any] = {"name": p.name, "path": str(p.relative_to(REPO_ROOT)), "type": "dir" if p.is_dir() else "file"}
        if p.is_dir() and d > 0:
            children = []
            for child in sorted(p.iterdir()):
                if child.name.startswith('.'):
                    continue
                if child.is_dir():
                    children.append(walk(child, d - 1))
                else:
                    children.append({"name": child.name, "path": str(child.relative_to(REPO_ROOT)), "type": "file", "size": child.stat().st_size})
            node["children"] = children
        return node

    return walk(base, depth)


@app.get("/files/read", dependencies=[Depends(require_token)])
def files_read(path: str):
    fpath = (REPO_ROOT / path).resolve()
    if not is_subpath(fpath, REPO_ROOT) or not fpath.is_file():
        raise HTTPException(status_code=400, detail="Invalid file path")
    content = fpath.read_text(encoding="utf-8")
    return {"path": str(fpath.relative_to(REPO_ROOT)), "size": len(content.encode("utf-8")), "content": content}


@app.post("/files/write", dependencies=[Depends(require_token)])
def files_write(req: FileWriteRequest):
    fpath = (REPO_ROOT / req.path).resolve()
    # Restrict to allowed dirs
    if not any(is_subpath(fpath, allowed) for allowed in ALLOWED_WRITE_DIRS):
        raise HTTPException(status_code=403, detail="Writes are restricted to config/, scripts/, dashboards/")
    fpath.parent.mkdir(parents=True, exist_ok=True)
    if fpath.exists() and req.backup:
        backup_path = fpath.with_suffix(fpath.suffix + ".bak")
        backup_path.write_text(fpath.read_text(encoding="utf-8"), encoding="utf-8")
    fpath.write_text(req.content, encoding="utf-8")
    return {"status": "written", "path": str(fpath.relative_to(REPO_ROOT))}


def compose_cmd() -> List[str]:
    return ["docker", "compose", "-f", str(COMPOSE_FILE)]


def validate_services(services: Optional[List[str]]) -> List[str]:
    if services is None or len(services) == 0:
        return []
    safe: List[str] = []
    for s in services:
        if not s or any(c in s for c in [';', '&', '|', '>', '<', '$', ' ']):
            raise HTTPException(status_code=400, detail=f"Invalid service name: {s}")
        safe.append(s)
    return safe


@app.get("/compose/ps", dependencies=[Depends(require_token)])
def compose_ps():
    cmd = compose_cmd() + ["ps", "--format", "json"]
    proc = run_cmd(cmd, cwd=REPO_ROOT)
    if proc.returncode != 0:
        raise HTTPException(status_code=500, detail=proc.stderr)
    try:
        data = json.loads(proc.stdout)
    except Exception:
        data = proc.stdout
    return {"result": data}


@app.post("/compose/up", dependencies=[Depends(require_token)])
def compose_up(req: ComposeServicesRequest):
    services = validate_services(req.services)
    cmd = compose_cmd() + ["up", "-d"] + services
    proc = run_cmd(cmd, cwd=REPO_ROOT, timeout=600)
    if proc.returncode != 0:
        raise HTTPException(status_code=500, detail=proc.stderr)
    return {"stdout": proc.stdout}


@app.post("/compose/down", dependencies=[Depends(require_token)])
def compose_down(req: ComposeServicesRequest):
    services = validate_services(req.services)
    cmd = compose_cmd() + ["down"] + services
    proc = run_cmd(cmd, cwd=REPO_ROOT, timeout=600)
    if proc.returncode != 0:
        raise HTTPException(status_code=500, detail=proc.stderr)
    return {"stdout": proc.stdout}


@app.post("/compose/restart", dependencies=[Depends(require_token)])
def compose_restart(req: ComposeServicesRequest):
    services = validate_services(req.services)
    cmd = compose_cmd() + ["restart"] + services
    proc = run_cmd(cmd, cwd=REPO_ROOT)
    if proc.returncode != 0:
        raise HTTPException(status_code=500, detail=proc.stderr)
    return {"stdout": proc.stdout}


@app.get("/status", dependencies=[Depends(require_token)])
def status():
    script = REPO_ROOT / "scripts" / "monitoring.sh"
    if not script.exists():
        raise HTTPException(status_code=500, detail="monitoring.sh not found")
    proc = run_cmd(["bash", str(script)], cwd=REPO_ROOT)
    if proc.returncode != 0:
        raise HTTPException(status_code=500, detail=proc.stderr)
    return {"output": proc.stdout}


@app.post("/setup", dependencies=[Depends(require_token)])
def setup():
    script = REPO_ROOT / "scripts" / "setup.sh"
    if not script.exists():
        raise HTTPException(status_code=500, detail="setup.sh not found")
    proc = run_cmd(["bash", str(script)], cwd=REPO_ROOT, timeout=1200)
    if proc.returncode != 0:
        raise HTTPException(status_code=500, detail=proc.stderr)
    return {"output": proc.stdout}


@app.post("/backup", dependencies=[Depends(require_token)])
def backup(req: BackupRequest):
    env = os.environ.copy()
    if req.prune_days:
        env["PRUNE_DAYS"] = str(req.prune_days)
    script = REPO_ROOT / "scripts" / "backup.sh"
    if not script.exists():
        raise HTTPException(status_code=500, detail="backup.sh not found")
    proc = subprocess.run(["bash", str(script)], cwd=str(REPO_ROOT), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env)
    if proc.returncode != 0:
        raise HTTPException(status_code=500, detail=proc.stderr)
    return {"output": proc.stdout}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("ops_agent.agent:app", host="127.0.0.1", port=APP_PORT, reload=False)