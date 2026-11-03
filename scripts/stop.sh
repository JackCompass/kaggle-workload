#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
PID_FILE="${PROJECT_ROOT}/.runner.pid"
TUNNEL_PID_FILE="${PROJECT_ROOT}/.tunnel.pid"
STATE_FILE="${PROJECT_ROOT}/.runner.state"


echo "=========================================="
echo "Stopping LLM Runner Daemons..."
echo "=========================================="

STOPPED=false

# Stop PID if file exists
if [[ -f "${PID_FILE}" ]]; then
    PID="$(cat "${PID_FILE}")"
    if kill -0 "${PID}" 2>/dev/null; then
        echo "--> Terminating daemon process (PID: ${PID})..."
        kill -15 "${PID}" 2>/dev/null || true
        sleep 2
        if kill -0 "${PID}" 2>/dev/null; then
            echo "--> Force killing process ${PID}..."
            kill -9 "${PID}" 2>/dev/null || true
        fi
        STOPPED=true
    fi
    rm -f "${PID_FILE}"
fi

# Fallback cleanups for ollama or vllm
if pgrep -f "ollama serve" > /dev/null 2>&1; then
    echo "--> Stopping remaining 'ollama serve' processes..."
    pkill -15 -f "ollama serve" || true
    STOPPED=true
fi

if pgrep -f "vllm.entrypoints.openai" > /dev/null 2>&1; then
    echo "--> Stopping remaining vLLM processes..."
    pkill -15 -f "vllm.entrypoints.openai" || true
    STOPPED=true
fi

# Stop Ngrok tunnel process
if [[ -f "${TUNNEL_PID_FILE}" ]]; then
    TPID="$(cat "${TUNNEL_PID_FILE}")"
    if kill -0 "${TPID}" 2>/dev/null; then
        echo "--> Terminating ngrok tunnel (PID: ${TPID})..."
        kill -15 "${TPID}" 2>/dev/null || true
        STOPPED=true
    fi
    rm -f "${TUNNEL_PID_FILE}"
fi

if pgrep -f "ngrok http" > /dev/null 2>&1; then
    echo "--> Stopping remaining ngrok processes..."
    pkill -15 -f "ngrok http" || true
    STOPPED=true
fi




if [[ -f "${STATE_FILE}" ]]; then
    rm -f "${STATE_FILE}"
fi

if [[ "${STOPPED}" == true ]]; then
    echo "✔ LLM services stopped successfully."
else
    echo "ℹ No active LLM processes were found."
fi
echo "=========================================="
