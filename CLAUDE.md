# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is an Ansible playbook repository for automating home lab setup tasks. It supports both Pop!_OS (Ubuntu-based/apt) and Nobara (Fedora-based/dnf) distributions. It includes playbooks for both local workstation setup and remote server setup.

## Common Commands

### Local Setup (localhost)
```bash
# Validate setup and check prerequisites
./validate.sh

# Run the full playbook
ansible-playbook local_setup.yml --ask-vault-pass --ask-become-pass

# Syntax check
ansible-playbook local_setup.yml --syntax-check

# Test connectivity
ansible all -m ping

# Run specific role using tags
ansible-playbook local_setup.yml --tags "git-setup" --ask-vault-pass --ask-become-pass
ansible-playbook local_setup.yml --tags "nas-mount" --ask-vault-pass --ask-become-pass
ansible-playbook local_setup.yml --tags "package-install" --ask-vault-pass --ask-become-pass
ansible-playbook local_setup.yml --tags "citrix-distrobox" --ask-vault-pass --ask-become-pass
ansible-playbook local_setup.yml --tags "msmtp-setup" --ask-vault-pass --ask-become-pass
ansible-playbook local_setup.yml --tags "nas-backup" --ask-vault-pass --ask-become-pass
ansible-playbook local_setup.yml --tags "nas-sync" --ask-vault-pass --ask-become-pass

# Check mode (dry run)
ansible-playbook local_setup.yml --check
```

### Remote Setup (headless servers)
```bash
# Test SSH connectivity to remote hosts
ansible remote -m ping

# Run the full remote setup playbook
ansible-playbook remote_setup.yml --ask-vault-pass

# Syntax check
ansible-playbook remote_setup.yml --syntax-check

# Run only user setup (first play)
ansible-playbook remote_setup.yml --tags "user-setup" --ask-vault-pass

# Run specific roles after user is created
ansible-playbook remote_setup.yml --tags "git-setup" --ask-vault-pass
ansible-playbook remote_setup.yml --tags "package-install" --ask-vault-pass

# Check mode (dry run)
ansible-playbook remote_setup.yml --check
```

### Cloud Sync Setup (pCloud to NAS sync VM)
```bash
# Test SSH connectivity to cloud-sync host
ansible cloud-sync -m ping

# Run the full cloud sync setup playbook
ansible-playbook cloud_sync_setup.yml --ask-vault-pass --ask-become-pass

# Syntax check
ansible-playbook cloud_sync_setup.yml --syntax-check

# Run specific roles
ansible-playbook cloud_sync_setup.yml --tags "git-setup" --ask-vault-pass --ask-become-pass
ansible-playbook cloud_sync_setup.yml --tags "cloud-sync" --ask-vault-pass --ask-become-pass

# Check mode (dry run)
ansible-playbook cloud_sync_setup.yml --check
```

#### Post-Install: Authenticate rclone with pCloud
After running the playbook, you must authenticate rclone with pCloud (OAuth required):
```bash
# SSH to the VM
ssh lee@ubuntu-vm.local

# Authenticate rclone with pCloud (opens URL to authenticate in browser)
rclone config reconnect pcloud:

# Test the connection
rclone ls pcloud: | head

# Trigger initial sync manually
sudo systemctl start cloud-sync.service

# Check sync status
sudo journalctl -u cloud-sync.service -f

# Verify timer is active
systemctl status cloud-sync.timer
systemctl list-timers | grep cloud-sync
```

### Vault Operations
```bash
ansible-vault encrypt vault.yml
ansible-vault decrypt vault.yml
ansible-vault edit vault.yml
```

## Architecture

### Playbook Structure
- `local_setup.yml` - Main playbook for local desktop/workstation setup (runs against localhost)
  - Includes: user-setup, git-setup, package-install (all packages), nas-mount, citrix-distrobox, msmtp-setup, nas-backup, nas-sync
- `remote_setup.yml` - Playbook for remote headless server setup (runs against remote hosts)
  - First play: Creates user account and sets up SSH access (runs as root)
  - Second play: Configures system with core roles (runs as created user)
  - Includes: user-setup, git-setup, package-install (CLI only), msmtp-setup
  - Excludes: nas-mount, nas-backup, nas-sync (not compatible with LXC containers)
- `cloud_sync_setup.yml` - Playbook for cloud-to-NAS sync VM setup (runs against cloud-sync hosts)
  - Connects as `lee` user (assumes user already exists with SSH key access)
  - Requires `--ask-become-pass` for sudo operations
  - Includes: git-setup, package-install (CLI only), nas-mount, msmtp-setup, cloud-sync
- `vault.yml` - Encrypted secrets (NAS credentials, SMTP credentials, pCloud credentials, etc.)
- `inventory/hosts` - Inventory with local, remote, and cloud-sync host groups
- `group_vars/all/main.yml` - Global variables for all hosts

### Roles
- **user-setup** - Creates user account on remote systems, sets up SSH keys, configures passwordless sudo
- **git-setup** - Configures Git with user.name and user.email
- **nas-mount** - Mounts CIFS/SMB shares from NAS with persistent fstab entries
- **package-install** - Installs packages with separate CLI (server) and desktop (GUI) package lists, auto-detects OS and uses apt or dnf
- **citrix-distrobox** - Installs Citrix Workspace (ICA client) inside an Ubuntu distrobox on Fedora-based systems, sets up .ica file associations (Fedora/Nobara only, requires icaclient*.deb in ~/Downloads/)
- **msmtp-setup** - Configures msmtp mail transfer agent for sending email notifications
- **nas-backup** - Configures restic backups to NAS with email notifications (depends on nas-mount and msmtp-setup)
- **nas-sync** - Configures lsyncd for real-time synchronization of user directories to NAS (depends on nas-mount)
- **cloud-sync** - Syncs cloud storage (pCloud) to NAS using rclone with systemd timer (every 6 hours), email notifications on failure (depends on nas-mount and msmtp-setup)
- **llama-cpp-setup** - *(planned)* Installs and configures llama.cpp on AMD Strix Halo systems with GPU acceleration

### Multi-OS Support
The `package-install` role uses `ansible_os_family` to automatically detect the OS and load appropriate packages:
- **OS Detection**: Automatically detects Debian/Ubuntu (Pop!_OS) or RedHat/Fedora (Nobara)
- **Package Lists**: OS-specific package lists in `vars/Debian.yml` and `vars/RedHat.yml`
- **Task Files**: OS-specific installation tasks in `tasks/debian.yml` (uses apt) and `tasks/redhat.yml` (uses dnf)
- **Supported Distributions**:
  - Debian family: Ubuntu, Pop!_OS, Debian
  - RedHat family: Fedora, Nobara, RHEL, CentOS

### Vault Configuration
- Vault password file: `.ansible_vault_pass` (local, gitignored)
- Config in `ansible.cfg` sets both `vault_password_file` and `ask_vault_pass = True` as fallback
- Sensitive vars are prefixed with `vault_` in vault.yml
- pCloud password must be obscured using `rclone obscure 'password'` before adding to vault

### Tags
Each role defines tags for selective execution. Common patterns:
- Role-specific: `user-setup`, `git-setup`, `nas-mount`, `package-install`, `citrix-distrobox`, `msmtp-setup`, `nas-backup`, `nas-sync`, `cloud-sync`
- Functional: `packages`, `cli-packages`, `desktop-packages`, `directories`, `credentials`, `mount`, `user`, `ssh`, `sudo`
- Citrix-distrobox specific: `distrobox-install`, `distrobox-setup`, `citrix-install`, `citrix-wrapper`, `citrix-desktop`
- Cloud-sync specific: `cloud-sync-rclone`, `cloud-sync-notifications`

### Key Patterns
- Roles detect the actual user (via `$SUDO_USER`) to configure user-specific settings rather than root
- Tags are used extensively for selective execution
- All roles use `become: yes` at the playbook level with `become_ask_pass: True`
- Package installation is split into CLI (suitable for servers) and desktop (GUI apps) with variables to control which packages to install
- Remote servers automatically skip desktop packages via `install_desktop_packages: no` in remote_setup.yml
- NAS-related roles (nas-mount, nas-backup, nas-sync) are excluded from remote_setup.yml as they require capabilities not available in unprivileged LXC containers
- citrix-distrobox role is Fedora/Nobara-only and will fail gracefully on Debian-based systems
