# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Ansible-based home lab automation project for setting up and configuring Pop!_OS systems (specifically 24.04 Cosmic). It configures local machines with git settings, NAS mounts, and standard packages.

## Common Commands

```bash
# Run the full playbook (will prompt for sudo and vault passwords)
ansible-playbook site.yml

# Run with specific tags
ansible-playbook site.yml --tags "git-setup"
ansible-playbook site.yml --tags "nas-mount"
ansible-playbook site.yml --tags "package-install"
ansible-playbook site.yml --tags "msmtp-setup"
ansible-playbook site.yml --tags "nas-backup"
ansible-playbook site.yml --tags "nas-sync"

# Check mode (dry run)
ansible-playbook site.yml --check

# Syntax check
ansible-playbook site.yml --syntax-check

# View/edit encrypted vault
ansible-vault view vault.yml
ansible-vault edit vault.yml
```

## Architecture

**Inventory**: Single localhost connection defined in `inventory/hosts` - this is a local provisioning setup, not remote.

**Playbook**: `site.yml` is the main entry point, runs against `local` host group with privilege escalation.

**Vault**: `vault.yml` contains encrypted secrets (NAS credentials, SMTP credentials). Password is read from `.ansible_vault_pass` file if present, otherwise prompted.

**Roles**:
- `git-setup`: Installs git and configures global settings for the invoking user (not root)
- `nas-mount`: Mounts CIFS/SMB shares from local NAS server, creates credentials file, configures fstab
- `package-install`: Installs standard utility packages via apt
- `msmtp-setup`: Configures msmtp mail transfer agent for sending email notifications (can be run independently)
- `nas-backup`: Configures restic backups to NAS with email notifications (depends on nas-mount and msmtp-setup)
- `nas-sync`: Configures lsyncd for real-time synchronization of user directories (Documents, Pictures, repos) to NAS (depends on nas-mount)

**Variables**:
- `group_vars/all/main.yml`: Common variables (git user info)
- `roles/*/defaults/main.yml`: Role-specific defaults
- `vault.yml`: Encrypted sensitive data (nas_username, nas_password, smtp credentials)

## Key Patterns

- Roles detect the actual user (via `$SUDO_USER`) to configure user-specific settings rather than root
- Tags are used extensively for selective execution
- All roles use `become: yes` at the playbook level with `become_ask_pass: True`
