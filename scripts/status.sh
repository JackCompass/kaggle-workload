#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
PID_FILE="${PROJECT_ROOT}/.runner.pid"
TUNNEL_PID_FILE="${PROJECT_ROOT}/.tunnel.pid"
STATE_FILE="${PROJECT_ROOT}/.runner.state"


echo "=========================================="
echo "Kaggle LLM Runner - Service Status"
echo "=========================================="

# Check state file
if [[ -f "${STATE_FILE}" ]]; then
    cat "${STATE_FILE}"
    echo "------------------------------------------"
fi

# Check PID
RUNNING=false
if [[ -f "${PID_FILE}" ]]; then
    PID="$(cat "${PID_FILE}")"
    if kill -0 "${PID}" 2>/dev/null; then
        echo "✔ Background process is RUNNING (PID: ${PID})"
        RUNNING=true
    else
        echo "⚠ Stale PID file found (Process ${PID} is not running)."
    fi
fi

# Check network ports
OLLAMA_UP=false
VLLM_UP=false

if curl -s "http://127.0.0.1:11434/api/tags" > /dev/null 2>&1; then
    OLLAMA_UP=true
    echo "✔ Ollama endpoint is active on http://127.0.0.1:11434"
    echo "Installed models:"
    curl -s "http://127.0.0.1:11434/api/tags" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | sed 's/^/  - /' || echo "  (None)"
fi

if curl -s "http://127.0.0.1:8000/v1/models" > /dev/null 2>&1; then
    VLLM_UP=true
    echo "✔ vLLM endpoint is active on http://127.0.0.1:8000"
fi

# Check Ngrok Tunnel
if [[ -f "${TUNNEL_PID_FILE}" ]]; then
    TPID="$(cat "${TUNNEL_PID_FILE}")"
    if kill -0 "${TPID}" 2>/dev/null; then
        echo "✔ Ngrok tunnel is ACTIVE (PID: ${TPID})"
    else
        echo "⚠ Tunnel PID file found, but process ${TPID} is dead."
    fi
elif pgrep -f "ngrok http" > /dev/null 2>&1; then
    echo "✔ Ngrok tunnel process is ACTIVE"
fi




if [[ "$OLLAMA_UP" == false && "$VLLM_UP" == false && "$RUNNING" == false ]]; then
    echo "❌ No LLM daemon is currently running."
fi

# GPU utilization
echo "------------------------------------------"
if command -v nvidia-smi &> /dev/null; then
    echo "GPU Status:"
    nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu --format=csv,noheader
else
    echo "No NVIDIA GPU detected."
fi
echo "=========================================="
