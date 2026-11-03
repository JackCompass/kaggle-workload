#!/usr/bin/env python3
"""
src/models.py: Model Registry, Alias Resolver, and Hardware Detection.
Maintains curated models, required VRAM, categories, and hardware validation.
"""

import argparse
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from typing import Dict, List, Optional


@dataclass
class ModelInfo:
    name: str
    aliases: List[str]
    category: str
    params: str
    min_vram_gb: float
    description: str
    recommended_engine: str = "ollama"



# Curated Model Catalog
MODEL_CATALOG: Dict[str, ModelInfo] = {
    # Reasoning Models
    "deepseek-r1:7b": ModelInfo(
        name="deepseek-r1:7b",
        aliases=["r1-7b", "r1", "deepseek-7b", "reasoning-7b"],
        category="Reasoning",
        params="7B",
        min_vram_gb=5.0,
        description="DeepSeek-R1 distilled on Qwen 2.5 7B. Shows full thinking process.",
    ),
    "deepseek-r1:14b": ModelInfo(
        name="deepseek-r1:14b",
        aliases=["r1-14b", "deepseek-14b", "reasoning-14b"],
        category="Reasoning",
        params="14B",
        min_vram_gb=9.0,
        description="DeepSeek-R1 distilled on Qwen 2.5 14B. Heavy mathematical & logic reasoning.",
    ),
    "deepseek-r1:8b": ModelInfo(
        name="deepseek-r1:8b",
        aliases=["r1-8b", "deepseek-8b"],
        category="Reasoning",
        params="8B",
        min_vram_gb=5.5,
        description="DeepSeek-R1 distilled on Llama 3.1 8B. Strong chain-of-thought logic.",
    ),
    "phi4:14b": ModelInfo(
        name="phi4:14b",
        aliases=["phi-4", "phi4"],
        category="Reasoning",
        params="14B",
        min_vram_gb=9.5,
        description="Microsoft Phi-4. Exceptional synthetic-data trained reasoning and STEM.",
    ),
    # General / Instruction
    "qwen2.5:7b": ModelInfo(
        name="qwen2.5:7b",
        aliases=["qwen", "qwen-7b", "default"],
        category="General",
        params="7B",
        min_vram_gb=4.8,
        description="Top-tier 7B model. 128k context, great multilingual & structured outputs.",
    ),
    "qwen2.5:14b": ModelInfo(
        name="qwen2.5:14b",
        aliases=["qwen-14b"],
        category="General",
        params="14B",
        min_vram_gb=9.0,
        description="Outstanding 14B model balancing high intelligence with speed.",
    ),
    "llama3.1:8b": ModelInfo(
        name="llama3.1:8b",
        aliases=["llama", "llama-8b", "llama3"],
        category="General",
        params="8B",
        min_vram_gb=5.0,
        description="Meta Llama 3.1 8B. 128k context, natural conversational tone.",
    ),
    # Coding
    "qwen2.5-coder:7b": ModelInfo(
        name="qwen2.5-coder:7b",
        aliases=["coder", "coder-7b", "qwen-coder-7b"],
        category="Coding",
        params="7B",
        min_vram_gb=4.8,
        description="State-of-the-art 7B code generation, refactoring, and debugging model.",
    ),
    "qwen2.5-coder:14b": ModelInfo(
        name="qwen2.5-coder:14b",
        aliases=["coder-14b", "qwen-coder-14b"],
        category="Coding",
        params="14B",
        min_vram_gb=9.0,
        description="Competitive with proprietary frontier models on programming benchmarks.",
    ),
    # Uncensored / Unfiltered
    "dolphin-llama3:8b": ModelInfo(
        name="dolphin-llama3:8b",
        aliases=["dolphin", "uncensored", "dolphin-8b"],
        category="Uncensored",
        params="8B",
        min_vram_gb=5.2,
        description="Eric Hartford's Dolphin fine-tune of Llama 3. Unfiltered, compliant personal tasks.",
    ),
    "mistral-nemo:12b": ModelInfo(
        name="mistral-nemo:12b",
        aliases=["mistral-nemo", "nemo", "mistral-12b"],
        category="General",
        params="12B",
        min_vram_gb=8.0,
        description="Mistral & NVIDIA 12B model with 128k context and balanced personality.",
    ),
    # Lightweight
    "llama3.2:3b": ModelInfo(
        name="llama3.2:3b",
        aliases=["llama-3b", "small", "fast"],
        category="Lightweight",
        params="3B",
        min_vram_gb=2.5,
        description="Ultra-fast, low memory footprint. Runs easily on laptop CPU / low-tier GPU.",
    ),
}


def resolve_model(name_or_alias: str) -> str:
    """Resolve an alias or model name to its canonical identifier."""
    target = name_or_alias.strip().lower()

    # Exact key match
    if target in MODEL_CATALOG:
        return MODEL_CATALOG[target].name

    # Check aliases
    for model_name, info in MODEL_CATALOG.items():
        if target in [a.lower() for a in info.aliases]:
            return model_name

    # If not found in catalog, return as-is (allows user to pass any custom Ollama/HF model)
    return name_or_alias


def get_hardware_info() -> dict:
    """Detect GPU hardware and VRAM availability."""
    info = {
        "has_gpu": False,
        "gpu_count": 0,
        "gpus": [],
        "total_vram_gb": 0.0,
    }

    if not shutil.which("nvidia-smi"):
        return info

    try:
        cmd = [
            "nvidia-smi",
            "--query-gpu=name,memory.total,memory.free",
            "--format=csv,noheader,nounits",
        ]
        output = subprocess.check_output(cmd, text=True).strip()
        lines = [line.strip() for line in output.split("\n") if line.strip()]

        total_vram = 0.0
        gpus = []
        for line in lines:
            parts = [p.strip() for p in line.split(",")]
            if len(parts) >= 3:
                name = parts[0]
                tot_mb = float(parts[1])
                free_mb = float(parts[2])
                tot_gb = round(tot_mb / 1024.0, 2)
                free_gb = round(free_mb / 1024.0, 2)
                total_vram += tot_gb
                gpus.append({"name": name, "total_gb": tot_gb, "free_gb": free_gb})

        info["has_gpu"] = len(gpus) > 0
        info["gpu_count"] = len(gpus)
        info["gpus"] = gpus
        info["total_vram_gb"] = round(total_vram, 2)
    except Exception as e:
        info["error"] = str(e)

    return info


def check_model_fits(model_name: str) -> tuple[bool, str]:
    """Check if the given model is likely to fit in available VRAM."""
    canonical = resolve_model(model_name)
    model_info = MODEL_CATALOG.get(canonical)
    hw = get_hardware_info()

    if not hw["has_gpu"]:
        return True, "No GPU detected; model will run on CPU/RAM."

    if not model_info:
        return True, f"Custom model '{model_name}' (not in catalog, unable to pre-check VRAM)."

    required = model_info.min_vram_gb
    available = hw["total_vram_gb"]

    if available >= required:
        return True, f"Model '{canonical}' requires ~{required}GB VRAM. Available: {available}GB."
    else:
        return False, (
            f"Model '{canonical}' requires ~{required}GB VRAM, but only "
            f"{available}GB total VRAM is available. It may offload to CPU or OOM."
        )


def print_catalog():
    """Print formatted catalog using rich table or fallback."""
    try:
        from rich.console import Console
        from rich.table import Table

        console = Console()
        table = Table(title="🤖 Kaggle LLM Runner - Model Registry", show_header=True)
        table.add_column("Canonical Name", style="cyan", no_wrap=True)
        table.add_column("Aliases", style="yellow")
        table.add_column("Category", style="magenta")
        table.add_column("Params", justify="right", style="green")
        table.add_column("Min VRAM", justify="right", style="blue")
        table.add_column("Description", style="white")

        for name, m in MODEL_CATALOG.items():
            aliases_str = ", ".join(m.aliases[:3])
            table.add_row(
                m.name,
                aliases_str,
                m.category,
                m.params,
                f"{m.min_vram_gb} GB",
                m.description,
            )

        console.print(table)
    except ImportError:
        print(f"{'Model Name':<22} | {'Params':<6} | {'VRAM':<7} | {'Category':<12} | Aliases")
        print("-" * 75)
        for name, m in MODEL_CATALOG.items():
            print(
                f"{m.name:<22} | {m.params:<6} | {m.min_vram_gb} GB | {m.category:<12} | {', '.join(m.aliases)}"
            )


def print_hardware():
    """Print detected GPU hardware."""
    hw = get_hardware_info()
    if not hw["has_gpu"]:
        print("Hardware: No NVIDIA GPU detected (Running in CPU mode).")
        return

    print(f"GPUs Detected: {hw['gpu_count']} | Total VRAM: {hw['total_vram_gb']} GB")
    for i, g in enumerate(hw["gpus"]):
        print(f"  [{i}] {g['name']} - Total: {g['total_gb']} GB (Free: {g['free_gb']} GB)")


def main():
    parser = argparse.ArgumentParser(description="Model Registry and Hardware Checker.")
    parser.add_argument("--list", action="store_true", help="List all curated models.")
    parser.add_argument("--resolve", type=str, help="Resolve alias to canonical model name.")
    parser.add_argument("--hardware", action="store_true", help="Display GPU hardware and VRAM.")
    parser.add_argument("--check", type=str, help="Check if a model fits in available VRAM.")

    args = parser.parse_args()

    if args.list:
        print_catalog()
    elif args.resolve:
        resolved = resolve_model(args.resolve)
        print(resolved)
    elif args.hardware:
        print_hardware()
    elif args.check:
        fits, msg = check_model_fits(args.check)
        status = "✔ PASS" if fits else "⚠ WARNING"
        print(f"{status}: {msg}")
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
