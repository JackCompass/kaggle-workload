# 🚀 Kaggle Ephemeral LLM Runner

Run open-weight frontier LLMs (**DeepSeek-R1 Distill**, **Qwen 2.5**, **Llama 3.1**, **Phi-4**, **Dolphin**) on Kaggle's free GPUs (2× NVIDIA T4 / 1× P100) and access them remotely via a **free permanent static domain using Ngrok** (no credit card required).

---

## ⚡ Quickstart on Kaggle (Copy & Paste)

### 1. Kaggle Notebook Settings
* In the right panel, set **Accelerator: GPU T4 x2** (or **GPU P100**).
* Set **Internet: ON** (required to download models and dependencies).
* *(Optional for remote access)* In top menu: **Add-ons** ➔ **Secrets**:
  * `NGROK_AUTHTOKEN`: *(From your free account on [ngrok.com](https://ngrok.com/))*
  * `NGROK_DOMAIN`: *(Your free static domain, e.g. `your-domain.ngrok-free.app`)*

---

### 2. Start the LLM Server (Kaggle Cell 1)

```bash
# Clone or pull latest updates
!git -C /kaggle/working/llm-runner pull || git clone https://github.com/JackCompass/kaggle-workload.git /kaggle/working/llm-runner
%cd /kaggle/working/llm-runner

# Start DeepSeek-R1 7B with Ngrok tunnel
!bash scripts/start.sh --model r1 --tunnel
```

---

### 3. Run Inference inside Kaggle (Kaggle Cell 2)

#### Option A: Quick CLI Prompt
```bash
!python3 src/inference.py --model deepseek-r1:7b --prompt "Explain quantum computing in 3 simple sentences."
```

#### Option B: Python Streaming in Notebook
```python
from src.inference import get_client, stream_completion

# Connect to local runner
client = get_client("http://127.0.0.1:11434/v1")

prompt = "Write a clean Python script to perform binary search."
print(f"Prompt: {prompt}\n")

gen = stream_completion(client, model="deepseek-r1:7b", prompt=prompt)
for chunk in gen:
    print(chunk, end="", flush=True)
```

---

### 4. Query from Local VS Code or Terminal (via Ngrok Static URL)

Once the runner is active, you can send prompts from your local machine:

```bash
# Using our client
python3 src/inference.py \
  --url https://your-domain.ngrok-free.app/v1 \
  --model deepseek-r1:7b \
  --prompt "Hello from VS Code!"
```

Or using `curl`:
```bash
curl https://your-domain.ngrok-free.app/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-r1:7b",
    "messages": [{"role": "user", "content": "Hello!"}],
    "stream": false
  }'
```

---

## 🎯 Commands to Run Different Models

Pass any model name or short alias to `--model`:

### 🧠 Reasoning & "Thinking" Models
```bash
# DeepSeek-R1 Distill on Qwen 7B (Default, shows internal thinking)
!bash scripts/start.sh --model r1 --tunnel

# DeepSeek-R1 Distill on Qwen 14B (Heavy logic and math)
!bash scripts/start.sh --model r1-14b --tunnel

# DeepSeek-R1 Distill on Llama 8B
!bash scripts/start.sh --model r1-8b --tunnel

# Microsoft Phi-4 14B (STEM & Analytical Reasoning)
!bash scripts/start.sh --model phi4 --tunnel
```

### 💻 Coding Specialists
```bash
# Qwen 2.5 Coder 7B
!bash scripts/start.sh --model coder --tunnel

# Qwen 2.5 Coder 14B (Near-frontier coding benchmarks)
!bash scripts/start.sh --model coder-14b --tunnel
```

### 🌐 General Purpose & Multilingual
```bash
# Qwen 2.5 7B (128k context, great JSON formatting)
!bash scripts/start.sh --model qwen --tunnel

# Qwen 2.5 14B (High intelligence & fast speed)
!bash scripts/start.sh --model qwen-14b --tunnel

# Meta Llama 3.1 8B (Conversational & natural tone)
!bash scripts/start.sh --model llama --tunnel
```

### 🔓 Uncensored & Unfiltered (Personal Tasks)
```bash
# Dolphin 2.9.4 Llama 3 8B (No corporate guardrails/refusals)
!bash scripts/start.sh --model dolphin --tunnel
```

### ⚡ Ultra-Lightweight (Fastest Execution)
```bash
# Meta Llama 3.2 3B (Runs with minimal VRAM and very high tokens/sec)
!bash scripts/start.sh --model llama-3b --tunnel
```

---

## ⚙️ Commands to Run Different Engines

### 1. Ollama (Default - Recommended for GGUF & Simplicity)
Fastest cold start, automatic memory offloading, zero complex setup:
```bash
!bash scripts/start.sh --model r1 --engine ollama --tunnel
```

### 2. vLLM (High Throughput & Multi-GPU Tensor Parallelism)
Uses Kaggle's 2× T4 GPUs simultaneously with tensor parallelism (`--tensor-parallel-size 2`):
```bash
!bash scripts/start.sh --model Qwen/Qwen2.5-7B-Instruct --engine vllm --tunnel
```

---

## 🛠️ Management & Inspection Commands

```bash
# Check service status, active port, loaded models & GPU usage
!bash scripts/status.sh

# List all models in the curated catalog with VRAM requirements
!bash scripts/start.sh --list

# Stop all background daemons (Ollama, vLLM, Ngrok)
!bash scripts/stop.sh
```

---

## 📁 Repository Structure

```text
├── notebooks/
│   └── kaggle_runner.ipynb   # Minimal starter notebook ready to paste into Kaggle
├── scripts/
│   ├── install_engine.sh     # Installs Ollama / vLLM (with auto zstd dependency)
│   ├── start.sh              # Starts background daemon, health checks & pulls model
│   ├── status.sh             # Inspects running service, loaded models & GPU usage
│   ├── stop.sh               # Gracefully terminates running background daemons
│   └── tunnel.sh             # Starts Ngrok background daemon with static domain
├── src/
│   ├── __init__.py
│   ├── inference.py          # OpenAI-compatible streaming client with speed benchmarking
│   └── models.py             # Model registry, alias resolver, and VRAM validator
├── .gitignore
├── README.md                 # Usage guide & copy-paste commands
└── requirements.txt          # Python client dependencies
```
