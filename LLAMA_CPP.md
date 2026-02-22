# AMD Strix Halo LLM Quickstart

## Toolbox Setup

### Create Toolbox (ROCm 7.2 - fastest)
```bash
toolbox create llama-rocm-7.2 \
  --image docker.io/kyuz0/amd-strix-halo-toolboxes:rocm-7.2 \
  -- --device /dev/dri --device /dev/kfd \
  --group-add video --group-add render --group-add sudo \
  --security-opt seccomp=unconfined \
  --volume /data:/data

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
  --local-dir /data/models/qwen3-30B-A3B/

# Qwen3-32B BF16 (~65 GB) - dense 32B model
HF_XET_HIGH_PERFORMANCE=1 hf download unsloth/Qwen3-32B-GGUF \
  BF16/Qwen3-32B-BF16-00001-of-00002.gguf \
  BF16/Qwen3-32B-BF16-00002-of-00002.gguf \
  --local-dir /data/models/qwen3-32B/
```

---

## Running the Server

> ⚠️ **Always use `-fa 1` and `--no-mmap`** on Strix Halo — required to avoid crashes and slowdowns.

```bash
# Qwen3-30B-A3B
llama-server \
  -m /data/models/qwen3-30B-A3B/BF16/Qwen3-30B-A3B-BF16-00001-of-00002.gguf \
  --ctx-size 65536 -ngl 999 -fa 1 --no-mmap --host 0.0.0.0 --port 8080

# Qwen3-32B
llama-server \
  -m /data/models/qwen3-32B/BF16/Qwen3-32B-BF16-00001-of-00002.gguf \
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