# Local LLM server

The workstation runs a local LLM server from `.config/llm`. `run.sh` starts a model from its config in `configs/`, and the `llm` function in `.zshrc` wraps it:

```sh
llm --list             # list configured models
llm qwen3.8-27b        # main: research, general reasoning, tools (NVFP4)
llm gpt-oss-20b        # lighter reasoning + tools (MXFP4)
```

Models run in the official vLLM OpenAI server in Docker, one at a time, on port 8000. Each config is flat YAML where `flag: value` becomes `vllm serve --flag value`, plus three special keys: `image:`, `model:` and `env-NAME:`. Weights download to `~/.cache/huggingface`, which `run.sh` mounts into the container.

The bar's [LLM panel](quickshell.md#llm-panel) does the same as `llm <model>`, but runs it as a systemd user unit, `llm-<model>`, so it keeps going without a terminal. The panel polls `/v1/models` and `/metrics` every three seconds, so both configs keep those two endpoints out of the access log. The launcher's `?` also asks this server while it runs ([quickshell.md](quickshell.md#launcher)).

| Model | Quant | Use |
|-------|-------|-----|
| `qwen3.8-27b` | NVFP4 | The main model: research, reasoning, coding and tools. Text and images, 100K context, no video. The same server also answers as `qwen3.8-pi`, the coding LoRA below. |
| `gpt-oss-20b` | MXFP4 | Faster and lighter (a 21B MoE with 3.6B active). Text only, 131K context, and `reasoning_effort` sets how hard it thinks per request. |

Both are 4-bit formats that Blackwell runs natively, and the checkpoints declare them, so neither config sets `--quantization`. gpt-oss comes from OpenAI's own repo because the mirrors ship a `generation_config.json` without the `</call>` stop token, which breaks tool calling.

## The Qwen config

Each setting in `configs/qwen3.8-27b.yaml` has a comment with the measurements behind it. In short:

- It uses unsloth's NVFP4 build instead of NVIDIA's ModelOpt one. NVIDIA's falls back to the Marlin kernel, which prefills at half the speed and crashes on Blackwell.
- Every client asks for `reasoning_effort: medium`. The template defaults to `xhigh`, which used about five times the tokens on six coding tasks without passing more of them, and once thought until it ran out of output budget. omp maps its `high` level to medium for this model, so only `:xhigh` asks for more; opencode sends it in `chat_template_kwargs`.
- Speculative decoding through the checkpoint's MTP layer is on, and it takes decode from about 63 to 105-158 tokens per second. The drafter's weights and KV hold the context to 102400 tokens, down from the 131072 that fp8 without MTP allowed, so omp compacts about a third more often.
- The KV cache is stored as nvfp4, which fits about 1.8 times as many tokens per byte as fp8. On 8 facts hidden in 94k tokens and 100 GSM8K questions it scored the same as fp8, give or take one question.
- The KV cache is pinned at 2.9 GiB (104,296 tokens). Left to size itself, vLLM counts whatever the desktop allocates during startup against the cache, so the size changed from boot to boot and some boots failed.
- Prefix-cache hits hold up to about 85k tokens. Past that, a prompt and its reply nearly fill the pool and the next turn prefills from scratch, but pi and omp both compact 16,384 tokens before the window fills, which keeps sessions under that.
- `FLASHINFER` attention is pinned because the nvfp4 cache needs it on this card. It takes about 0.85 GiB more than `TRITON_ATTN`, which the smaller pin covers.
- harness-hub's [pi-adapted LoRA](https://huggingface.co/harness-hub/Qwen3.8-27B-pi-adapted) is loaded and served as `qwen3.8-pi`. It was trained with reinforcement learning on coding tasks inside pi and runs with thinking off. In omp it passed 17 of 17 runs on five small coding tasks against 15 of 17 for the base model at medium thinking, in about half the time and output tokens. It costs 0.5 GiB at idle and about 11% of decode speed.
- Video is off because it needs several GiB this card doesn't have. A conversation can hold up to 6 images, since each one can cost 16,384 tokens.

Each client's context setting has to match the server, so both use 102400. After changing anything here, check `Available KV cache memory` and `GPU KV cache size` in the startup log; vLLM refuses to start if the settings don't fit.

Three tools use this server: pi day to day, with omp and opencode as fallbacks. [coding-agents.md](coding-agents.md) covers them. Only one model is loaded at a time, so start the one you want first.

## On the Mac

On macOS, `run.sh` reads `configs/macos/` instead and runs each model on llama.cpp's `llama-server` with Metal (`brew install llama.cpp`). Those configs set `engine: llamacpp`, and every other `flag: value` becomes `llama-server --flag value`. The first run of each model downloads it into `~/.cache/huggingface`.

Both models have the same served names, port and context windows as on the workstation, so opencode works with them unchanged. The Mac doesn't serve the `qwen3.8-pi` LoRA, though, and pi and omp default to it, so on the Mac pick `vllm/qwen3.8-27b` or `vllm/gpt-oss-20b` with `--model`:

```sh
llm gpt-oss-20b        # fast: ~80 tok/s, 56 at 25k tokens of context
llm qwen3.8-27b        # the main model, but slow: ~16 tok/s, 10 at 20k
```

gpt-oss-20b runs as shipped (MXFP4) at the full 131072 context and wires about 15 GB of the MacBook's 24.

Qwen3.8-27B is unsloth's UD-Q3_K_XL, because the 4-bit files don't leave room for the KV cache in the 18.2 GB that Metal allows. The KV cache is q4_0, which holds the 102400 window in 1.8 GB and recalled 8 of 8 facts hidden in 83k tokens, but it reads prompts slowly: 192 tokens per second at 20k, and 9.5 minutes for an 83k prompt. Images work, through the mmproj file that llama-server downloads with the model. MTP stays off on the Mac, because at 20k tokens of context it made both prefill and decode slower and used another 1.4 GB.

With either model loaded, the Mac has about 10% of its memory free under a normal app load.

If an SSH tunnel to the workstation already holds port 8000, `llm` refuses to start.
