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

### Vault Operations
```bash
ansible-vault encrypt vault.yml
ansible-vault decrypt vault.yml
ansible-vault edit vault.yml
```

## Architecture

### Playbook Structure
- `local_setup.yml` - Main playbook for local desktop/workstation setup (runs against localhost)
  - Includes: user-setup, git-setup, package-install (all packages), nas-mount, msmtp-setup, nas-backup, nas-sync
- `remote_setup.yml` - Playbook for remote headless server setup (runs against remote hosts)
  - First play: Creates user account and sets up SSH access (runs as root)
  - Second play: Configures system with core roles (runs as created user)
  - Includes: user-setup, git-setup, package-install (CLI only), msmtp-setup
  - Excludes: nas-mount, nas-backup, nas-sync (not compatible with LXC containers)
- `vault.yml` - Encrypted secrets (NAS credentials, SMTP credentials, etc.)
- `inventory/hosts` - Inventory with both local and remote host groups
- `group_vars/all/main.yml` - Global variables for all hosts

### Roles
- **user-setup** - Creates user account on remote systems, sets up SSH keys, configures passwordless sudo
- **git-setup** - Configures Git with user.name and user.email
- **nas-mount** - Mounts CIFS/SMB shares from NAS with persistent fstab entries
- **package-install** - Installs packages with separate CLI (server) and desktop (GUI) package lists, auto-detects OS and uses apt or dnf
- **msmtp-setup** - Configures msmtp mail transfer agent for sending email notifications
- **nas-backup** - Configures restic backups to NAS with email notifications (depends on nas-mount and msmtp-setup)
- **nas-sync** - Configures lsyncd for real-time synchronization of user directories to NAS (depends on nas-mount)

### Multi-OS Support
The `package-install` role uses `ansible_os_family` to include OS-specific task files:
- `debian.yml` - For Debian/Ubuntu family (uses apt)
- `redhat.yml` - For RedHat/Fedora family (uses dnf)

### Vault Configuration
- Vault password file: `.ansible_vault_pass` (local, gitignored)
- Config in `ansible.cfg` sets both `vault_password_file` and `ask_vault_pass = True` as fallback
- Sensitive vars are prefixed with `vault_` in vault.yml

### Tags
Each role defines tags for selective execution. Common patterns:
- Role-specific: `user-setup`, `git-setup`, `nas-mount`, `package-install`, `msmtp-setup`, `nas-backup`, `nas-sync`
- Functional: `packages`, `cli-packages`, `desktop-packages`, `directories`, `credentials`, `mount`, `user`, `ssh`, `sudo`

### Key Patterns
- Roles detect the actual user (via `$SUDO_USER`) to configure user-specific settings rather than root
- Tags are used extensively for selective execution
- All roles use `become: yes` at the playbook level with `become_ask_pass: True`
- Package installation is split into CLI (suitable for servers) and desktop (GUI apps) with variables to control which packages to install
- Remote servers automatically skip desktop packages via `install_desktop_packages: no` in remote_setup.yml
- NAS-related roles (nas-mount, nas-backup, nas-sync) are excluded from remote_setup.yml as they require capabilities not available in unprivileged LXC containers
