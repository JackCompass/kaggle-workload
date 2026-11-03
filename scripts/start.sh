#!/usr/bin/env bash
set -euo pipefail

# Default configuration
DEFAULT_MODEL="qwen2.5:7b"
DEFAULT_ENGINE="ollama"
MODEL="${DEFAULT_MODEL}"
ENGINE="${DEFAULT_ENGINE}"
PORT=""
HELP=false

show_help() {
    cat << EOF
Usage: bash scripts/start.sh [OPTIONS]

Options:
  --model <name>     Name of the model to pull and serve (default: ${DEFAULT_MODEL})
                     Examples: qwen2.5:7b, deepseek-r1:7b, qwen2.5-coder:14b, llama3.1:8b
  --engine <name>    Inference engine to use: 'ollama' or 'vllm' (default: ${DEFAULT_ENGINE})
  --port <port>      Custom port to bind the server (default: 11434 for Ollama, 8000 for vLLM)
  --help             Show this help message and exit
EOF
}

# Parse command line flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)
            MODEL="$2"
            shift 2
            ;;
        --engine)
            ENGINE="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "❌ Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

echo "=========================================="
echo "Kaggle Ephemeral LLM Runner"
echo "=========================================="
echo "Engine : ${ENGINE}"
echo "Model  : ${MODEL}"
echo "Root   : ${PROJECT_ROOT}"
echo "=========================================="

# 1. Install python client dependencies
echo "--> Installing Python requirements..."
pip install -q -r "${PROJECT_ROOT}/requirements.txt"

# 2. Run engine installer
bash "${SCRIPT_DIR}/install_engine.sh" "${ENGINE}"

# 3. Launch background service based on engine
if [[ "${ENGINE}" == "ollama" ]]; then
    PORT="${PORT:-11434}"
    export OLLAMA_HOST="0.0.0.0:${PORT}"

    echo "--> Starting Ollama daemon in background on port ${PORT}..."
    nohup ollama serve > "${PROJECT_ROOT}/ollama.log" 2>&1 &
    DAEMON_PID=$!
    echo "✔ Ollama started (PID: ${DAEMON_PID}). Waiting for health check..."

    # Wait for Ollama service to become responsive
    MAX_RETRIES=20
    COUNT=0
    until curl -s "http://127.0.0.1:${PORT}/api/tags" > /dev/null 2>&1; do
        sleep 1
        COUNT=$((COUNT + 1))
        if [[ $COUNT -ge $MAX_RETRIES ]]; then
            echo "❌ Ollama daemon failed to start within ${MAX_RETRIES} seconds. Logs:"
            cat "${PROJECT_ROOT}/ollama.log"
            exit 1
        fi
    done
    echo "✔ Ollama daemon is ready and responding on port ${PORT}."

    # 4. Pull the requested model
    echo "--> Pulling model '${MODEL}' (this may take a few minutes)..."
    ollama pull "${MODEL}"
    echo "✔ Model '${MODEL}' is ready!"

elif [[ "${ENGINE}" == "vllm" ]]; then
    PORT="${PORT:-8000}"
    echo "--> Starting vLLM OpenAI-compatible server on port ${PORT} for model '${MODEL}'..."
    nohup python -m vllm.entrypoints.openai.api_server \
        --model "${MODEL}" \
        --port "${PORT}" \
        --host 0.0.0.0 > "${PROJECT_ROOT}/vllm.log" 2>&1 &
    DAEMON_PID=$!
    echo "✔ vLLM launched (PID: ${DAEMON_PID}). Logs: ${PROJECT_ROOT}/vllm.log"
fi

echo "=========================================="
echo "🚀 Ready for Inference!"
echo "Endpoint: http://127.0.0.1:${PORT}/v1"
echo "Model   : ${MODEL}"
echo "=========================================="
