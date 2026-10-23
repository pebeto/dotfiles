# Local LLM server

The workstation runs a local LLM server from `.config/llm`. `run.sh` starts a model from its config in `configs/`, and the `llm` function in `.zshrc` wraps it:

```sh
llm --list             # list configured models
llm qwen3.8-27b        # main: research, general reasoning, tools (NVFP4)
llm gpt-oss-20b        # lighter reasoning + tools (MXFP4)
```

Models run in the official vLLM OpenAI server in Docker, one at a time, on port 8000. Each config is flat YAML where `flag: value` becomes `vllm serve --flag value`, plus three special keys: `image:`, `model:` and `env-NAME:`. Weights download to `~/.cache/huggingface`, which `run.sh` mounts into the container.

The bar's [LLM panel](quickshell.md#llm-panel) does the same as `llm <model>`, but runs it as a systemd user unit, `llm-<model>`, so it keeps going without a terminal.

| Model | Quant | Use |
|-------|-------|-----|
| `qwen3.8-27b` | NVFP4 | The main model: research, reasoning, coding and tools. Text and images, 128K context, no video. |
| `gpt-oss-20b` | MXFP4 | Faster and lighter (a 21B MoE with 3.6B active). Text only, 131K context, and `reasoning_effort` sets how hard it thinks per request. |

Both are 4-bit formats that Blackwell runs natively, and the checkpoints declare them, so neither config sets `--quantization`. gpt-oss comes from OpenAI's own repo because the mirrors ship a `generation_config.json` without the `</call>` stop token, which breaks tool calling.

## The Qwen config

Each setting in `configs/qwen3.8-27b.yaml` has a comment with the measurements behind it. In short:

- It uses unsloth's NVFP4 build instead of NVIDIA's ModelOpt one. NVIDIA's falls back to the Marlin kernel, which prefills at half the speed and crashes on Blackwell.
- Every client asks for `reasoning_effort: medium`. The template defaults to `xhigh`, which used about five times the tokens on six coding tasks without passing more of them, and once thought until it ran out of output budget. omp maps its `high` level to medium for this model, so only `:xhigh` asks for more; opencode sends it in `chat_template_kwargs`.
- Speculative decoding (the checkpoint's MTP layer) is off. It roughly doubles decode speed, but it caps the context at 81920 tokens, and omp then had to compact about twice as often. The config comment lists what to change to turn it back on.
- The KV cache is pinned at 4.6 GiB (139,810 tokens). Left to size itself, vLLM counts whatever the desktop allocates during startup against the cache, so the size changed from boot to boot and some boots failed.
- `TRITON_ATTN` is pinned because FlashInfer, the default, needed about 0.6 GiB more memory.
- Video is off because it needs several GiB this card doesn't have. A conversation can hold up to 8 images, since each one can cost 16,384 tokens.

Each client's context setting has to match the server, so both use 131072. After changing anything here, check `Available KV cache memory` and `GPU KV cache size` in the startup log; vLLM refuses to start if the settings don't fit.

Two tools use this server, omp day to day and opencode as a fallback. [coding-agents.md](coding-agents.md) covers both. Only one model is loaded at a time, so start the one you want first.
