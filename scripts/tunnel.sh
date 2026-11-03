#!/usr/bin/env bash
set -euo pipefail

# scripts/tunnel.sh: Installs and launches Ngrok with a permanent static domain
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
PID_FILE="${PROJECT_ROOT}/.tunnel.pid"
LOG_FILE="${PROJECT_ROOT}/ngrok.log"

PORT="${1:-11434}"
TOKEN="${2:-${NGROK_AUTHTOKEN:-}}"
DOMAIN="${3:-${NGROK_DOMAIN:-}}"

echo "=========================================="
echo "🌐 Starting Ngrok Static Tunnel"
echo "=========================================="

if [[ -z "${TOKEN}" ]]; then
    echo "❌ Error: Ngrok authtoken is required."
    echo "Provide it via: bash scripts/tunnel.sh <PORT> <AUTHTOKEN> [STATIC_DOMAIN]"
    echo "            or: export NGROK_AUTHTOKEN=<TOKEN> and NGROK_DOMAIN=<DOMAIN>"
    exit 1
fi

# 1. Stop old tunnel if already running
if [[ -f "${PID_FILE}" ]]; then
    OLD_PID="$(cat "${PID_FILE}")"
    if kill -0 "${OLD_PID}" 2>/dev/null; then
        echo "--> Stopping previous ngrok process (PID: ${OLD_PID})..."
        kill -15 "${OLD_PID}" 2>/dev/null || true
        sleep 1
    fi
    rm -f "${PID_FILE}"
fi

# 2. Install ngrok binary if not found
if ! command -v ngrok &> /dev/null; then
    echo "--> Installing ngrok (Linux x86_64)..."
    mkdir -p "${PROJECT_ROOT}/bin"
    curl -fsSL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz | tar -xz -C "${PROJECT_ROOT}/bin"
    export PATH="${PROJECT_ROOT}/bin:${PATH}"
fi

NGROK_BIN="$(command -v ngrok || echo "${PROJECT_ROOT}/bin/ngrok")"

# 3. Configure Authtoken
"${NGROK_BIN}" config add-authtoken "${TOKEN}" > /dev/null 2>&1

# 4. Build command with optional static domain
DOMAIN_FLAG=""
if [[ -n "${DOMAIN}" ]]; then
    DOMAIN_FLAG="--domain=${DOMAIN}"
    echo "✔ Configured Static Domain: https://${DOMAIN}"
fi

# 5. Launch in background
echo "--> Starting ngrok daemon on port ${PORT}..."
nohup "${NGROK_BIN}" http ${DOMAIN_FLAG} "${PORT}" > "${LOG_FILE}" 2>&1 &
TUNNEL_PID=$!
echo "${TUNNEL_PID}" > "${PID_FILE}"
sleep 3

if kill -0 "${TUNNEL_PID}" 2>/dev/null; then
    echo "✔ Ngrok tunnel is RUNNING (PID: ${TUNNEL_PID})."
    if [[ -n "${DOMAIN}" ]]; then
        echo "=========================================="
        echo "🎉 Static Endpoint : https://${DOMAIN}/v1"
        echo "=========================================="
    else
        echo "Logs: ${LOG_FILE}"
    fi
else
    echo "❌ Ngrok failed to start. Logs:"
    cat "${LOG_FILE}"
    exit 1
fi
