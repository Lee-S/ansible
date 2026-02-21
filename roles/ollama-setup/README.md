# Ollama Setup Role

Ansible role to install and configure Ollama LLM on AMD Strix Halo systems.

## Requirements

- AMD Strix Halo GPU (Ryzen AI Max+)
- Ollama 0.6.2+ (has official Strix Halo support)
- For ROCm backend: ROCm 7.0.2+ (official Strix Halo support)
- For Vulkan backend: Vulkan drivers and Mesa

## Role Variables

Available variables are listed below, along with default values (see `defaults/main.yml`):

```yaml
# GPU backend: 'rocm' or 'vulkan'
# Vulkan is recommended for Strix Halo due to better stability
ollama_gpu_backend: vulkan

# Installation method
ollama_install_method: script

# Service configuration
ollama_host: "0.0.0.0:11434"
ollama_origins: "*"

# Models to pull after installation
ollama_models_to_pull: []

# Memory configuration
ollama_max_loaded_models: 1
ollama_num_parallel: 1
```

## GPU Backend Selection

### Vulkan (Recommended)
- More stable on Strix Halo
- Broader GPU compatibility
- No ROCm installation required
- Good for testing and development

### ROCm
- Better performance
- Requires ROCm 7.0.2+
- Some stability issues reported on Strix Halo
- May experience compute corruption after several inference rounds

## Dependencies

None.

## Example Playbook

```yaml
- hosts: ollama
  become: yes
  vars:
    ollama_gpu_backend: vulkan
    ollama_models_to_pull:
      - llama3.2
      - phi3
  roles:
    - ollama-setup
```

## Tags

- `ollama-setup` - All tasks
- `ollama-install` - Installation only
- `ollama-service` - Service configuration
- `ollama-models` - Model pulling
- `ollama-verify` - Health checks
- `ollama-rocm` - ROCm setup (when using ROCm backend)
- `ollama-vulkan` - Vulkan setup (when using Vulkan backend)

## Testing Memory Allocation

After installation, test memory allocation with:

```bash
# Check GPU status
vulkaninfo --summary  # For Vulkan
rocm-smi              # For ROCm

# Run a test inference
ollama run llama3.2 "Hello, how are you?"

# Monitor memory usage
watch -n 1 'ollama ps'
```

## Troubleshooting

### Service not starting
```bash
sudo systemctl status ollama
sudo journalctl -u ollama -f
```

### GPU not detected
```bash
# For Vulkan
vulkaninfo | grep -i device

# For ROCm
rocm-smi
```

### Switching backends
Edit `/etc/systemd/system/ollama.service.d/override.conf` and change:
```
Environment="OLLAMA_GPU_BACKEND=vulkan"
```
to:
```
Environment="OLLAMA_GPU_BACKEND=rocm"
```

Then restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

## Known Issues

- ROCm on Strix Halo may experience instability after 4-5 conversational turns
- Compute corruption can occur with extended use
- Vulkan backend is more stable but may have lower performance

## References

- [Ollama 0.6.2 Release with Strix Halo support](https://www.phoronix.com/news/ollama-0.6.2)
- [ROCm Strix Halo Guide](https://github.com/Shoresh613/rocm-strix-halo)
- [Ollama GPU Documentation](https://docs.ollama.com/gpu)
- [AMD ROCm GPU Support](https://www.amd.com/en/developer/resources/technical-articles/running-llms-locally-on-amd-gpus-with-ollama.html)

## License

MIT

## Author Information

Created for home lab automation.


## Perfoamce issues

"I am getting 6 tokens a second"

This is the core finding and honestly it reframes the whole situation. Ollama does not support Vulkan or AMD GPUs very well in general and is not recommended for Strix Halo. 
Strix Halo Wiki
 That's the root cause of your 6 tokens/sec — it's not a config problem you can tune away, it's a fundamental Ollama + Vulkan + gfx1151 limitation.

On a 70B model with the best Vulkan setup, around 5 tokens per second is considered perfectly usable 
Hardware Corner
 — so ironically you're getting roughly expected performance for Ollama on this hardware. The good news is that switching to llama.cpp directly with the Vulkan backend gives dramatically better results.

The recommended path: use the kyuz0 toolboxes instead of Ollama

This is the container-based llama.cpp setup specifically built and optimised for Strix Halo. Since you're on Nobara (Fedora-based), toolbox is available natively:

bash
# Install the Vulkan/RADV toolbox
```bash
toolbox create llama-vulkan \
  --image docker.io/kyuz0/amd-strix-halo-toolboxes:vulkan-radv \
  -- --device /dev/dri --group-add video --security-opt seccomp=unconfined

toolbox enter llama-vulkan
```

Then run your model directly with llama.cpp inside it, pointing at your existing Ollama model files:

```bash
llama-server \
  -m ~/.ollama/models/blobs/<your-model-file>.gguf \
  --n-gpu-layers 99 \
  --threads 16 \
  --ctx-size 8192 \
  --host 0.0.0.0 \
  --port 11434

```

This exposes the same OpenAI-compatible API endpoint that OpenClaw expects, so nothing changes on the client side. You should see token generation jump to 20-35 tokens/sec on the 32B Q8 model compared to the 6 you're getting now.

The tradeoff is that you lose Ollama's convenient model management, but for raw inference performance on Strix Halo it's currently the right tool for the job.


