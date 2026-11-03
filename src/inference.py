#!/usr/bin/env python3
"""
src/inference.py: Client for querying local OpenAI-compatible endpoints (Ollama / vLLM).
Provides streaming output, tokens/sec benchmarking, and interactive chat.
"""

import argparse
import sys
import time
from typing import Generator

try:
    from openai import OpenAI
    from rich.console import Console
    from rich.markdown import Markdown
    from rich.panel import Panel
except ImportError:
    print("Error: Missing dependencies. Run: pip install -r requirements.txt")
    sys.exit(1)

console = Console()


def get_client(base_url: str, api_key: str = "ollama") -> OpenAI:
    """Initialize OpenAI client configured for local endpoint."""
    return OpenAI(base_url=base_url, api_key=api_key)


def stream_completion(
    client: OpenAI,
    model: str,
    prompt: str,
    system_prompt: str = "You are a helpful, concise AI assistant.",
    temperature: float = 0.7,
) -> Generator[str, None, dict]:
    """
    Stream model completion tokens while calculating latency & generation speed.
    """
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": prompt},
    ]

    start_time = time.perf_counter()
    first_token_time = None
    token_count = 0

    response = client.chat.completions.create(
        model=model,
        messages=messages,
        temperature=temperature,
        stream=True,
    )

    for chunk in response:
        delta = chunk.choices[0].delta.content or ""
        if delta:
            if first_token_time is None:
                first_token_time = time.perf_counter()
            token_count += 1
            yield delta

    end_time = time.perf_counter()
    gen_time = end_time - (first_token_time or start_time)
    tok_per_sec = (token_count / gen_time) if gen_time > 0 else 0.0

    return {
        "token_count": token_count,
        "total_time": end_time - start_time,
        "tokens_per_second": tok_per_sec,
    }


def run_interactive(client: OpenAI, model: str, system_prompt: str) -> None:
    """Run interactive REPL in the terminal."""
    console.print(
        Panel(
            f"[bold green]Interactive Session Started[/bold green]\n"
            f"Model: [cyan]{model}[/cyan]\n"
            f"Type [yellow]exit[/yellow] or [yellow]quit[/yellow] to end.",
            title="Kaggle LLM Runner",
        )
    )

    messages = [{"role": "system", "content": system_prompt}]

    while True:
        try:
            user_input = console.input("\n[bold blue]User > [/bold blue]").strip()
            if not user_input:
                continue
            if user_input.lower() in ("exit", "quit"):
                console.print("[dim]Goodbye![/dim]")
                break

            messages.append({"role": "user", "content": user_input})
            console.print(f"[bold cyan]{model} > [/bold cyan]", end="")

            start_time = time.perf_counter()
            full_reply = ""
            tokens = 0

            response = client.chat.completions.create(
                model=model,
                messages=messages,
                stream=True,
            )

            for chunk in response:
                content = chunk.choices[0].delta.content or ""
                if content:
                    tokens += 1
                    full_reply += content
                    console.print(content, end="")

            elapsed = time.perf_counter() - start_time
            speed = (tokens / elapsed) if elapsed > 0 else 0
            console.print(f"\n[dim]({tokens} tokens | {speed:.1f} tok/s)[/dim]")
            messages.append({"role": "assistant", "content": full_reply})

        except KeyboardInterrupt:
            console.print("\n[dim]Session interrupted.[/dim]")
            break


def main():
    parser = argparse.ArgumentParser(description="Query local LLM inference server.")
    parser.add_argument(
        "--model",
        type=str,
        default="qwen2.5:7b",
        help="Model name (e.g., qwen2.5:7b, deepseek-r1:7b)",
    )
    parser.add_argument(
        "--url",
        type=str,
        default="http://127.0.0.1:11434/v1",
        help="OpenAI-compatible base URL",
    )
    parser.add_argument(
        "--prompt",
        type=str,
        default=None,
        help="One-off prompt to send to the model",
    )
    parser.add_argument(
        "--system",
        type=str,
        default="You are an expert AI assistant. Provide concise and accurate answers.",
        help="System prompt instruction",
    )
    parser.add_argument(
        "--temperature",
        type=float,
        default=0.7,
        help="Sampling temperature",
    )

    args = parser.parse_args()
    client = get_client(base_url=args.url)

    if args.prompt:
        console.print(f"[dim]Connecting to {args.url} (Model: {args.model})...[/dim]\n")
        console.print(f"[bold blue]Prompt:[/bold blue] {args.prompt}\n")
        console.print(f"[bold cyan]{args.model}:[/bold cyan] ", end="")

        generator = stream_completion(
            client=client,
            model=args.model,
            prompt=args.prompt,
            system_prompt=args.system,
            temperature=args.temperature,
        )

        try:
            while True:
                token = next(generator)
                console.print(token, end="")
        except StopIteration as e:
            stats = e.value or {}
            tok_s = stats.get("tokens_per_second", 0.0)
            tok_count = stats.get("token_count", 0)
            console.print(f"\n\n[dim]Speed: {tok_s:.1f} tok/s | Total tokens: {tok_count}[/dim]")
    else:
        run_interactive(client=client, model=args.model, system_prompt=args.system)


if __name__ == "__main__":
    main()
