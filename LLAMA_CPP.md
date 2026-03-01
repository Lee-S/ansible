# AMD Strix Halo LLM Quickstart

## Toolbox Setup

### Create Toolbox (ROCm 7.2 - fastest)
```bash
toolbox create llama-rocm-7.2 \
  --image docker.io/kyuz0/amd-strix-halo-toolboxes:rocm-7.2 \
  -- --device /dev/dri --device /dev/kfd \
  --group-add video --group-add render --group-add sudo \
  --security-opt seccomp=unconfined \
  -v /data/models:/data/models:Z

## This mounts it at /run/host/data/models/

toolbox enter llama-rocm-7.2
```

> If you need Vulkan (more compatible, slightly slower), replace `rocm-7.2` with `vulkan-radv` and drop the `--device /dev/kfd` and `--group-add render/sudo` flags.

### Verify GPU Access
```bash
llama-cli --list-devices
```

---

## Installing huggingface-cli

Inside the toolbox, pip and huggingface-cli are not pre-installed:

```bash
# From host, install pip as root into the container
podman exec -u root -it llama-rocm-7.2 dnf install python3-pip -y

# Then inside the toolbox
pip install huggingface_hub hf_xet
```

> The CLI is available as `hf` (not `huggingface-cli`).

---

## Downloading Models

```bash
# Qwen3-30B-A3B BF16 (~61 GB) - good general purpose MoE model
HF_XET_HIGH_PERFORMANCE=1 hf download unsloth/Qwen3-30B-A3B-GGUF \
  BF16/Qwen3-30B-A3B-BF16-00001-of-00002.gguf \
  BF16/Qwen3-30B-A3B-BF16-00002-of-00002.gguf \
  --local-dir /run/host/data/models/qwen3-30B-A3B/

# Qwen3-32B BF16 (~65 GB) - dense 32B model
HF_XET_HIGH_PERFORMANCE=1 hf download unsloth/Qwen3-32B-GGUF \
  BF16/Qwen3-32B-BF16-00001-of-00002.gguf \
  BF16/Qwen3-32B-BF16-00002-of-00002.gguf \
  --local-dir /run/host/data/models/qwen3-32B/
```

---

## Running the Server

> ⚠️ **Always use `-fa 1` and `--no-mmap`** on Strix Halo — required to avoid crashes and slowdowns.

```bash
# Qwen3-30B-A3B
llama-server \
  -m /run/host/data/models/qwen3-30B-A3B/BF16/Qwen3-30B-A3B-BF16-00001-of-00002.gguf \
  --ctx-size 65536 -ngl 999 -fa 1 --no-mmap --host 0.0.0.0 --port 8080

# Qwen3-32B
llama-server \
  -m /run/host/data/models/qwen3-32B/BF16/Qwen3-32B-BF16-00001-of-00002.gguf \
  --ctx-size 65536 -ngl 999 -fa 1 --no-mmap --host 0.0.0.0 --port 8080
```

Server runs on `http://localhost:8080` (OpenAI-compatible API).  
Increase `-c` for more context, e.g. `-c 32768`. With 128GB unified memory there's plenty of headroom.

---

## Notes

- Models stored on `/data` (separate filesystem) — mounted into toolbox via `--volume /data:/data`
- Toolbox home directory is shared with host `~` automatically
- ROCm 7.2 is noticeably faster than Vulkan RADV for inference
- Qwen3 supports `/think` and `/no_think` in prompts to toggle reasoning mode
- Project repo: https://github.com/kyuz0/amd-strix-halo-toolboxes


## Next Steps

Is there a better model for coding?18:53For coding specifically on your setup, a few strong options:
Top picks for coding:
*Qwen2.5-Coder-32B* — probably the best local coding model right now. Purpose-built for code, beats a lot of larger general models on coding benchmarks. Available in BF16 (~64GB) which fits your machine well.
*DeepSeek-R1 or V3* — excellent at reasoning through complex code problems. V3 is huge (671B MoE) so not practical locally, but distilled R1 versions (32B) are very capable and fit your machine.
*Qwen3-30B-A3B vs Qwen2.5-Coder-32B* — your current model is actually solid for general tasks but Qwen2.5-Coder will likely outperform it specifically on coding tasks.
My recommendation for your setup:
```
Qwen2.5-Coder-32B-Instruct (BF16)
```
It's roughly the same memory footprint as what you're running now, fits comfortably in your 128GB, and is purpose-trained for code generation, completion, debugging, and multi-file edits — exactly what Roo Code needs.
You can grab it from Hugging Face and convert/use the GGUF version, or run BF16 directly if you're using llama.cpp built with full precision support.
If you want reasoning ability on top of coding, DeepSeek-R1-Distill-Qwen-32B is also worth trying — it's slower but thinks through problems more carefully.Give me the download instructions for DeepSeek-R1-Distill-Qwen-32B18:54The easiest way is with huggingface-cli:


```bash
# Install if you don't have it
pip install huggingface_hub

# Download the GGUF version (easiest for llama.cpp)
huggingface-cli download bartowski/DeepSeek-R1-Distill-Qwen-32B-GGUF \
  --include "DeepSeek-R1-Distill-Qwen-32B-Q8_0.gguf" \
  --local-dir ~/models/deepseek-r1-32b
```
Which quant to pick for your 128GB machine:

Q8_0 (~34GB) — best quality, fits easily, recommended
BF16 (~65GB) — full precision, also fits, maximum quality
Q4_K_M (~18GB) — if you want faster inference and smaller footprint

For your use case I'd go Q8_0 — near-BF16 quality at roughly half the size, leaving plenty of headroom.
Then run it:

```bash
./llama-server -m ~/models/deepseek-r1-32b/DeepSeek-R1-Distill-Qwen-32B-Q8_0.gguf \
  --host 0.0.0.0 --port 8080 \
  --ctx-size 65536 \
  -ngl 99
```

Note: DeepSeek-R1 uses <think> tags for its reasoning chain before answering. Roo Code should handle this fine, but you'll notice responses take longer as it "thinks" through problems — that's normal and actually why it's good at complex code tasks.