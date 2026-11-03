# Kaggle Ephemeral LLM Runner

Run open-weight frontier LLMs (**DeepSeek-R1 Distill**, **Qwen 2.5**, **Llama 3.1**, **Phi-4**) on Kaggle's free GPU instances (2× T4 / 1× P100) or your local machine with a single-line command.

---

## 📁 Repository Structure

```text
├── notebooks/
│   └── kaggle_runner.ipynb   # Minimal starter notebook ready to paste into Kaggle
├── scripts/
│   ├── install_engine.sh     # Installs Ollama / vLLM based on detected hardware
│   └── start.sh              # Starts background daemon, health checks & pulls model
├── src/
│   ├── __init__.py
│   └── inference.py          # OpenAI-compatible streaming client with speed benchmarking
├── .gitignore
├── PROJECTS.md               # Architecture, design decisions, and roadmap
├── README.md                 # Usage guide
└── requirements.txt          # Python client dependencies
```

---

## ⚡ Quickstart on Kaggle

1. Create a new notebook on [Kaggle](https://www.kaggle.com/).
2. Enable hardware: In the right panel, select **GPU T4 x2** (or **GPU P100**) and toggle **Internet: ON**.
3. Run the following in a cell:
   ```bash
   !git clone https://github.com/<your-username>/<your-repo-name>.git /kaggle/working/llm-runner
   %cd /kaggle/working/llm-runner
   !bash scripts/start.sh --model qwen2.5:7b --engine ollama
   ```
4. Query the model in the next cell:
   ```bash
   !python src/inference.py --model qwen2.5:7b --prompt "Explain the theory of relativity simply."
   ```

---

## 💻 Local Usage

You can also run this locally on Linux/macOS:

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Start the runner (downloads Ollama if needed and starts model)
bash scripts/start.sh --model qwen2.5:7b

# 3. Interactive chat in terminal
python src/inference.py --model qwen2.5:7b
```

---

## ⚙️ Options for `scripts/start.sh`

| Option | Default | Description |
| :--- | :--- | :--- |
| `--model <name>` | `qwen2.5:7b` | Model tag (e.g. `deepseek-r1:7b`, `qwen2.5-coder:14b`, `llama3.1:8b`) |
| `--engine <name>` | `ollama` | Backend engine: `ollama` or `vllm` |
| `--port <port>` | `11434` / `8000` | Custom port to bind the server daemon |
| `--help` | - | Display help documentation |
