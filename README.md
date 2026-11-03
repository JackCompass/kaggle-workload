# Kaggle Ephemeral LLM Runner

Run open-weight frontier LLMs (**DeepSeek-R1 Distill**, **Qwen 2.5**, **Llama 3.1**, **Phi-4**) on Kaggle's free GPU instances (2× T4 / 1× P100) and access them remotely via a **free permanent static domain using Ngrok** (no credit card required).

---

## 📁 Repository Structure

```text
├── notebooks/
│   └── kaggle_runner.ipynb   # Minimal starter notebook ready to paste into Kaggle
├── scripts/
│   ├── install_engine.sh     # Installs Ollama / vLLM based on detected hardware
│   ├── start.sh              # Starts background daemon, health checks & pulls model
│   ├── status.sh             # Inspects running service, loaded models & GPU usage
│   ├── stop.sh               # Gracefully terminates running background daemons
│   └── tunnel.sh             # Starts Ngrok background daemon with static domain
├── src/
│   ├── __init__.py
│   ├── inference.py          # OpenAI-compatible streaming client with speed benchmarking
│   └── models.py             # Model registry, alias resolver, and VRAM validator
├── .gitignore
├── README.md                 # Usage guide
└── requirements.txt          # Python client dependencies
```

---

## 🌐 Permanent Static URL via Ngrok (100% Free, No Credit Card)

1. **Sign up on Ngrok:**
   * Create a free account at [ngrok.com](https://ngrok.com/) (sign in via Google or GitHub—no credit card required).
2. **Claim your Free Static Domain:**
   * Go to **Domains** in the left sidebar and claim your free static domain (e.g. `your-domain.ngrok-free.app`).
3. **Get your Authtoken:**
   * In the sidebar, click **Your Authtoken** and copy it.
4. **In Kaggle:**
   * Open top menu: **Add-ons** ➔ **Secrets** and add:
     * `NGROK_AUTHTOKEN`: `<your-authtoken>`
     * `NGROK_DOMAIN`: `your-domain.ngrok-free.app`
   * Run the notebook cell:
     ```bash
     !bash scripts/start.sh --model r1 --tunnel
     ```
5. **In VS Code / Local Apps:**
   * Point your OpenAI-compatible client to your permanent static URL:
     ```text
     https://your-domain.ngrok-free.app/v1
     ```

---

## ⚡ Quickstart on Kaggle

```bash
# 1. Clone repository
!git clone https://github.com/<your-username>/retrieval-aug-gen.git /kaggle/working/llm-runner
%cd /kaggle/working/llm-runner

# 2. Start model with Ngrok tunnel
!bash scripts/start.sh --model r1 --tunnel

# 3. Test prompt
!python3 src/inference.py --model deepseek-r1:7b --prompt "Explain quantum computing in 3 sentences."
```

---

## ⚙️ Options for `scripts/start.sh`

| Option | Default | Description |
| :--- | :--- | :--- |
| `--model <name\|alias>` | `qwen2.5:7b` | Model alias (e.g. `r1`, `r1-14b`, `coder-14b`, `dolphin`, `llama-3b`) |
| `--engine <name>` | `ollama` | Backend engine: `ollama` or `vllm` |
| `--port <port>` | `11434` / `8000` | Custom port to bind the server daemon |
| `--tensor-parallel <n>` | Auto | Tensor parallel GPUs (vLLM multi-GPU) |
| `--tunnel` | `false` | Enable Ngrok remote tunnel |
| `--ngrok-token <token>` | `$NGROK_AUTHTOKEN` | Ngrok authtoken |
| `--ngrok-domain <domain>`| `$NGROK_DOMAIN` | Static Ngrok domain (e.g. `cricket.ngrok-free.app`) |
| `--list` | - | Display curated model registry with VRAM requirements |
| `--help` | - | Display help documentation |
