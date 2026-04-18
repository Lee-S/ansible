# Qwen3.5 + OpenClaw Setup Guide - Ubuntu

**System:** Minisforum MS-S1 MAX — AMD Strix Halo, 128GB unified RAM  
**OS:** Ubuntu 25.10, Kernel 6.18  
**Toolbox:** kyuz0/amd-strix-halo-toolboxes (ROCm 7.x)

---

## 1. Distrobox Setup (Ubuntu requires distrobox, not toolbox)

### Create the ROCm container

```bash
distrobox create -n llama-rocm-7.2 \
  --image docker.io/kyuz0/amd-strix-halo-toolboxes:rocm-7.2\
  --additional-flags "--device /dev/kfd --device /dev/dri --group-add video --group-add render --security-opt seccomp=unconfined"
```

> **Tags available:** `rocm-7rc-rocwmma` (ROCm 7.9 GA — recommended), `rocm-7.1-rocwmma`, `rocm-7alpha-rocwmma` (nightly/bleeding edge)

### Enter the container

```bash
distrobox enter llama-rocm-7.2
```

### Verify GPU is detected (inside distrobox)

```bash
llama-cli --list-devices
```

### Update container to latest llama.cpp build

```bash
# Exit distrobox first, then:
distrobox stop lllama-rocm-7.2
distrobox rm lllama-rocm-7.2
# Recreate with --pull to force fresh image
distrobox create -n lllama-rocm-7.2 \
  --image docker.io/kyuz0/amd-strix-halo-toolboxes:rocm-7rc-rocwmma \
  --pull \
  --additional-flags "--device /dev/kfd --device /dev/dri --group-add video --group-add render --security-opt seccomp=unconfined"
```

---

## 2. Bash Prompt — Show Distrobox Name

Add to `~/.bashrc` to show a purple distrobox indicator in your prompt:

```bash
if [ -f /run/.containerenv ]; then
    CONTAINER_NAME=$(grep -oP '(?<=name=")[^"]+' /run/.containerenv 2>/dev/null || echo "container")
    PS1="[\033[1;35m distrobox:$CONTAINER_NAME\033[0m] $PS1"
fi
```

```bash
source ~/.bashrc
```

---

## 3. Python / huggingface-cli Fix

The system has two Python binaries — `/usr/sbin/python3` (system, no packages) and `/usr/bin/python3` (has huggingface_hub). Always use `/usr/bin/python3`.

`huggingface-cli` is not on PATH, use the Python API directly:

```bash
/usr/bin/python3 -c "from huggingface_hub import hf_hub_download; print('ok')"
```

---

## 4. Downloading Models

### Model recommendations for 128GB system

| Model | Size (Q4) | Active Params | Best for |
|-------|-----------|---------------|----------|
| Qwen3.5-35B-A3B | ~20GB | 3B | Fast responses, simple tasks |
| Qwen3.5-122B-A10B | ~74GB | 10B | Complex reasoning, coding, health analysis |

**Recommended:** 122B-A10B for OpenClaw agentic use (health data, coding, calendar, life admin).

### Download Qwen3.5-35B-A3B (single file, good for testing)

```bash
HF_HUB_ENABLE_HF_TRANSFER=1 /usr/bin/python3 -c "
from huggingface_hub import hf_hub_download
import os
os.makedirs('/home/lee/models/qwen3.5-35B-A3B', exist_ok=True)
hf_hub_download(
    repo_id='unsloth/Qwen3.5-35B-A3B-GGUF',
    filename='Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf',
    local_dir='/home/lee/models/qwen3.5-35B-A3B/'
)
print('Done!')
"
```

### Download Qwen3.5-122B-A10B (3 shards, ~74GB total)

```bash
HF_HUB_ENABLE_HF_TRANSFER=1 /usr/bin/python3 -c "
from huggingface_hub import hf_hub_download
import os
os.makedirs('/home/lee/models/qwen3.5-122B-A10B', exist_ok=True)
for i in ['00001', '00002', '00003']:
    print(f'Downloading shard {i}...')
    hf_hub_download(
        repo_id='unsloth/Qwen3.5-122B-A10B-GGUF',
        filename=f'Q4_K_M/Qwen3.5-122B-A10B-Q4_K_M-{i}-of-00003.gguf',
        local_dir='/home/lee/models/qwen3.5-122B-A10B/'
    )
print('Done!')
"
```

---

## 5. Running Models

> ⚠️ **`-fa 1 --no-mmap` are MANDATORY on Strix Halo.** Omitting either causes crashes or severe performance degradation due to the unified memory architecture.

### llama-server (OpenAI-compatible API on port 8080)

```bash
# 35B
llama-server \
  -m /home/lee/models/qwen3.5-35B-A3B/Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf \
  -c 32768 -ngl 999 -fa 1 --no-mmap

# 122B (sharded — point at first shard, llama.cpp loads the rest automatically)
llama-server \
  -m /home/lee/models/qwen3.5-122B-A10B/Q4_K_M/Qwen3.5-122B-A10B-Q4_K_M-00001-of-00003.gguf \
  -c 32768 -ngl 999 -fa 1 --no-mmap
```

### llama-cli (quick test)

```bash
llama-cli --no-mmap -ngl 999 -fa 1 \
  -m /home/lee/models/qwen3.5-35B-A3B/Qwen3.5-35B-A3B-UD-Q4_K_XL.gguf \
  -p "Hello, are you working?"
```

---

## 6. Qwen3.5 Thinking Mode

Qwen3.5 defaults to **thinking mode** — it generates internal `<think>...</think>` reasoning chains before responding. For OpenClaw life-admin tasks this adds latency with little benefit.

- Disable thinking: add `/no_think` to the system prompt or append to user messages
- Enable thinking: add `/think` (useful for health data analysis, complex coding tasks)

**Recommended OpenClaw system prompt addition:**
```
/no_think
```
Then selectively use `/think` when asking for deep analysis.

---

## 7. Kernel Parameters for Unified Memory (Strix Halo)

Add to `/etc/default/grub` in `GRUB_CMDLINE_LINUX`:

```
amd_iommu=off amdgpu.gttsize=126976 ttm.pages_limit=32505856
```

| Parameter | Effect |
|-----------|--------|
| `amd_iommu=off` | Lower latency |
| `amdgpu.gttsize=126976` | Caps GPU unified memory to 124 GiB |
| `ttm.pages_limit=32505856` | Caps pinned memory to 124 GiB |

Apply changes:
```bash
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
sudo reboot
```

---

## 8. Model Notes

- **Unsloth Dynamic 2.0** quants are recommended — they upcast important layers to 8-bit or 16-bit for better accuracy at low bit depths.
- The `UD-Q4_K_XL` suffix = Unsloth Dynamic 4-bit with XL recipe (higher quality than plain `Q4_K_M`).
- Qwen3.5 uses a **hybrid MoE + Gated Delta Network** architecture — it's a new arch (`qwen35moe`), so you need an up-to-date llama.cpp build. Update the distrobox if you get `unknown model architecture` errors.

---

## 9. References

- Toolbox repo: https://github.com/kyuz0/amd-strix-halo-toolboxes
- Unsloth Qwen3.5 GGUFs: https://huggingface.co/collections/unsloth/qwen35
- Unsloth Qwen3.5 guide: https://unsloth.ai/docs/models/qwen3.5
- Strix Halo homelab wiki: https://strixhalo-homelab.d7.wtf/
- OpenClaw: https://github.com/openclaw/openclaw
