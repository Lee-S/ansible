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
