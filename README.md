# ansible

Ansible playbooks for automating home lab setup across Pop!_OS (Ubuntu/apt) and Nobara (Fedora/dnf).

## Playbooks

| Playbook | Target | Purpose |
|---|---|---|
| `local_setup.yml` | localhost | Full workstation setup (NAS, packages, backups, sync) |
| `remote_setup.yml` | remote hosts | Headless server setup (user, git, CLI packages) |
| `cloud_sync_setup.yml` | cloud-sync VM | pCloud → NAS sync via rclone |

## Quick Start

```bash
# Validate prerequisites
./validate.sh

# Run local setup
ansible-playbook local_setup.yml --ask-vault-pass --ask-become-pass

# Run with a specific role only
ansible-playbook local_setup.yml --tags "nas-mount" --ask-vault-pass --ask-become-pass
```

See [CLAUDE.md](CLAUDE.md) for full command reference, role descriptions, and tag list.

## Roles

- **user-setup** — Creates user, SSH keys, passwordless sudo (remote only)
- **git-setup** — Configures git user.name and user.email
- **nas-mount** — Mounts CIFS/SMB NAS shares, updates fstab
- **package-install** — Installs CLI and desktop packages (apt or dnf, auto-detected)
- **citrix-distrobox** — Citrix Workspace inside Ubuntu distrobox (Fedora/Nobara only)
- **msmtp-setup** — Configures msmtp for email notifications
- **nas-backup** — Restic backups to NAS with email alerts
- **nas-sync** — lsyncd real-time sync of user dirs to NAS
- **cloud-sync** — rclone pCloud → NAS sync via systemd timer (every 6 hours)

## Docs

- [docs/ansible/nas-mount-setup.md](docs/ansible/nas-mount-setup.md) — NAS mount role setup and troubleshooting
- [docs/ansible/VAULT_SECURITY.md](docs/ansible/VAULT_SECURITY.md) — Vault encryption and pre-commit hook setup
- [docs/fedora/FEDORA_MIGRATION.md](docs/fedora/FEDORA_MIGRATION.md) — Running this repo on Fedora 43 (MINISFORUM MS-S1 MAX)
- [docs/fedora/FEDORA_TWEAKS.md](docs/fedora/FEDORA_TWEAKS.md) — Nobara/Ultramarine tweaks mapped to Ansible tasks
- [docs/hardware/nvme-benchmark-summary.md](docs/hardware/nvme-benchmark-summary.md) — NVMe benchmark results and partition plan
- [docs/llm/strix-halo-llm-quickstart.md](docs/llm/strix-halo-llm-quickstart.md) — llama.cpp on AMD Strix Halo via ROCm toolbox
- [docs/llm/OPENCLAW_VM_SETUP.md](docs/llm/OPENCLAW_VM_SETUP.md) — OpenClaw AI agent VM (Nobara host)
- [docs/llm/OPENCLAW_VM_SETUP_UBUNTU.md](docs/llm/OPENCLAW_VM_SETUP_UBUNTU.md) — OpenClaw AI agent VM (Ubuntu host)
- [docs/llm/qwen35-openclaw-setup.md](docs/llm/qwen35-openclaw-setup.md) — Qwen3.5 + OpenClaw on Minisforum MS-S1 MAX
