#!/usr/bin/env bash
set -euo pipefail

# install_engine.sh: Installs the selected inference engine (Ollama or vLLM)
ENGINE="${1:-ollama}"

echo "=========================================="
echo "Installing Inference Engine: ${ENGINE}"
echo "=========================================="

# Check for NVIDIA GPU
if command -v nvidia-smi &> /dev/null; then
    echo "✔ NVIDIA GPU detected:"
    nvidia-smi --query-gpu=gpu_name,memory.total --format=csv,noheader
else
    echo "⚠ No NVIDIA GPU detected. Running in CPU mode."
fi

case "${ENGINE}" in
    ollama)
        if command -v ollama &> /dev/null; then
            echo "✔ Ollama is already installed: $(ollama --version)"
        else
            # Ensure zstd is installed (required by the official Ollama installer)
            if ! command -v zstd &> /dev/null; then
                echo "--> Installing missing dependency 'zstd'..."
                SUDO=""
                if [ "$(id -u)" -ne 0 ] && command -v sudo &> /dev/null; then
                    SUDO="sudo"
                fi
                if command -v apt-get &> /dev/null; then
                    ${SUDO} apt-get update -qq && ${SUDO} apt-get install -y -qq zstd
                elif command -v dnf &> /dev/null; then
                    ${SUDO} dnf install -y -q zstd
                fi
            fi

            echo "--> Downloading and installing Ollama..."
            curl -fsSL https://ollama.com/install.sh | sh
            echo "✔ Ollama installed successfully: $(ollama --version)"
        fi
        ;;

    vllm)
        echo "--> Installing vLLM via pip..."
        pip install --upgrade vllm
        echo "✔ vLLM installed successfully."
        ;;
    *)
        echo "❌ Unknown engine: '${ENGINE}'. Supported engines: 'ollama', 'vllm'"
        exit 1
        ;;
esac

echo "✔ Engine installation step complete."
