#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
PID_FILE="${PROJECT_ROOT}/.runner.pid"
STATE_FILE="${PROJECT_ROOT}/.runner.state"

DEFAULT_MODEL="qwen2.5:7b"
DEFAULT_ENGINE="ollama"
INPUT_MODEL="${DEFAULT_MODEL}"
ENGINE="${DEFAULT_ENGINE}"
PORT=""
TENSOR_PARALLEL=""

show_help() {
    cat << EOF
Usage: bash scripts/start.sh [OPTIONS]

Options:
  --model <name|alias>   Model name or alias to pull and serve (default: ${DEFAULT_MODEL})
                         Examples: r1, r1-14b, qwen-7b, coder-7b, coder-14b, dolphin, llama-3b
  --engine <name>        Inference engine: 'ollama' or 'vllm' (default: ${DEFAULT_ENGINE})
  --port <port>          Custom port to bind (default: 11434 for Ollama, 8000 for vLLM)
  --tensor-parallel <n>  Number of GPUs for tensor parallelism (vLLM only, auto-detected)
  --list                 List all models in the curated catalog and exit
  --help|-h              Show this help message and exit
EOF
}

# Parse command line flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)
            INPUT_MODEL="$2"
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
        --tensor-parallel)
            TENSOR_PARALLEL="$2"
            shift 2
            ;;
        --list)
            python3 "${PROJECT_ROOT}/src/models.py" --list
            exit 0
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

# 1. Resolve model alias and check hardware
MODEL="$(python3 "${PROJECT_ROOT}/src/models.py" --resolve "${INPUT_MODEL}")"

echo "=========================================="
echo "🚀 Kaggle Ephemeral LLM Runner"
echo "=========================================="
echo "Engine   : ${ENGINE}"
echo "Requested: ${INPUT_MODEL}"
echo "Resolved : ${MODEL}"
echo "Root     : ${PROJECT_ROOT}"
echo "------------------------------------------"

# Hardware inspection & VRAM check
python3 "${PROJECT_ROOT}/src/models.py" --hardware
python3 "${PROJECT_ROOT}/src/models.py" --check "${MODEL}"
echo "=========================================="

# 2. Install requirements if missing
if ! python3 -c "import openai, rich" > /dev/null 2>&1; then
    echo "--> Installing Python requirements..."
    pip install -q -r "${PROJECT_ROOT}/requirements.txt"
fi

# 3. Install the engine if not present
bash "${SCRIPT_DIR}/install_engine.sh" "${ENGINE}"

# 4. Engine Daemon Lifecycle & Model Serving
if [[ "${ENGINE}" == "ollama" ]]; then
    PORT="${PORT:-11434}"
    export OLLAMA_HOST="0.0.0.0:${PORT}"

    # Check if Ollama is already active on this port
    if curl -s "http://127.0.0.1:${PORT}/api/tags" > /dev/null 2>&1; then
        echo "✔ Ollama daemon is already running on port ${PORT}."
    else
        echo "--> Starting Ollama daemon in background on port ${PORT}..."
        nohup ollama serve > "${PROJECT_ROOT}/ollama.log" 2>&1 &
        DAEMON_PID=$!
        echo "${DAEMON_PID}" > "${PID_FILE}"
        echo "✔ Ollama started (PID: ${DAEMON_PID}). Waiting for health check..."

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
        echo "✔ Ollama daemon health-check passed."
    fi

    # Record state
    cat << EOF > "${STATE_FILE}"
Engine: ollama
Model: ${MODEL}
Port: ${PORT}
Endpoint: http://127.0.0.1:${PORT}/v1
StartedAt: $(date)
EOF

    # Pull the requested model
    echo "--> Pulling model '${MODEL}'..."
    ollama pull "${MODEL}"
    echo "✔ Model '${MODEL}' is ready!"

elif [[ "${ENGINE}" == "vllm" ]]; then
    PORT="${PORT:-8000}"

    # Auto-detect GPU count for tensor parallelism if not specified
    if [[ -z "${TENSOR_PARALLEL}" ]]; then
        GPU_COUNT="$(python3 -c "import src.models as m; print(m.get_hardware_info()['gpu_count'] or 1)")"
        TENSOR_PARALLEL="${GPU_COUNT}"
    fi

    echo "--> Starting vLLM OpenAI-compatible server on port ${PORT}..."
    echo "    Model: ${MODEL} | Tensor Parallel GPUs: ${TENSOR_PARALLEL}"

    nohup python3 -m vllm.entrypoints.openai.api_server \
        --model "${MODEL}" \
        --port "${PORT}" \
        --host 0.0.0.0 \
        --tensor-parallel-size "${TENSOR_PARALLEL}" > "${PROJECT_ROOT}/vllm.log" 2>&1 &
    DAEMON_PID=$!
    echo "${DAEMON_PID}" > "${PID_FILE}"

    cat << EOF > "${STATE_FILE}"
Engine: vllm
Model: ${MODEL}
Port: ${PORT}
Endpoint: http://127.0.0.1:${PORT}/v1
TensorParallel: ${TENSOR_PARALLEL}
StartedAt: $(date)
EOF
    echo "✔ vLLM launched (PID: ${DAEMON_PID}). Logs: ${PROJECT_ROOT}/vllm.log"
fi

echo "=========================================="
echo "🎉 Server is online and ready!"
echo "Endpoint : http://127.0.0.1:${PORT}/v1"
echo "Model    : ${MODEL}"
echo "Try it   : python3 src/inference.py --model ${MODEL} --prompt \"Hello!\""
echo "=========================================="
