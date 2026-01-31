# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is an Ansible playbook repository for automating home lab setup tasks. It supports both Pop!_OS (Ubuntu-based/apt) and Nobara (Fedora-based/dnf) distributions. The playbook runs against localhost by default.

## Common Commands

```bash
# Validate setup and check prerequisites
./validate.sh

# Run the full playbook
ansible-playbook site.yml --ask-vault-pass --ask-become-pass

# Syntax check
ansible-playbook site.yml --syntax-check

# Test connectivity
ansible all -m ping

# Run specific role using tags
ansible-playbook site.yml --tags "git-setup" --ask-vault-pass --ask-become-pass
ansible-playbook site.yml --tags "nas-mount" --ask-vault-pass --ask-become-pass
ansible-playbook site.yml --tags "package-install" --ask-vault-pass --ask-become-pass
ansible-playbook site.yml --tags "msmtp-setup" --ask-vault-pass --ask-become-pass
ansible-playbook site.yml --tags "nas-backup" --ask-vault-pass --ask-become-pass
ansible-playbook site.yml --tags "nas-sync" --ask-vault-pass --ask-become-pass

# Check mode (dry run)
ansible-playbook site.yml --check

# Vault operations
ansible-vault encrypt vault.yml
ansible-vault decrypt vault.yml
ansible-vault edit vault.yml
```

## Architecture

### Playbook Structure
- `site.yml` - Main playbook that includes all roles
- `vault.yml` - Encrypted secrets (NAS credentials, SMTP credentials, etc.)
- `inventory/hosts` - Inventory targeting localhost
- `group_vars/all/main.yml` - Global variables for all hosts

### Roles
- **git-setup** - Configures Git with user.name and user.email
- **nas-mount** - Mounts CIFS/SMB shares from NAS with persistent fstab entries
- **package-install** - Installs packages, auto-detects OS and uses apt or dnf
- **msmtp-setup** - Configures msmtp mail transfer agent for sending email notifications
- **nas-backup** - Configures restic backups to NAS with email notifications (depends on nas-mount and msmtp-setup)
- **nas-sync** - Configures lsyncd for real-time synchronization of user directories to NAS (depends on nas-mount)

### Multi-OS Support
The `package-install` role uses `ansible_os_family` to include OS-specific task files:
- `apt.yml` - For Debian/Ubuntu family
- `dnf.yml` - For RedHat/Fedora family

### Vault Configuration
- Vault password file: `.ansible_vault_pass` (local, gitignored)
- Config in `ansible.cfg` sets both `vault_password_file` and `ask_vault_pass = True` as fallback
- Sensitive vars are prefixed with `vault_` in vault.yml

### Tags
Each role defines tags for selective execution. Common patterns:
- Role-specific: `git-setup`, `nas-mount`, `package-install`, `msmtp-setup`, `nas-backup`, `nas-sync`
- Functional: `packages`, `directories`, `credentials`, `mount`

### Key Patterns
- Roles detect the actual user (via `$SUDO_USER`) to configure user-specific settings rather than root
- Tags are used extensively for selective execution
- All roles use `become: yes` at the playbook level with `become_ask_pass: True`
