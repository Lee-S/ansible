# Package Install Role

This Ansible role installs standard packages for PopOS 24.04 Cosmic systems in a home lab environment.

## Description

The `package-install` role automates the installation of essential packages that are commonly needed after a fresh PopOS installation. It includes system monitoring tools, text editors, terminal utilities, and other useful applications.

## Requirements

- PopOS 24.04 Cosmic (or compatible Ubuntu-based distribution)
- Ansible 2.9 or higher
- sudo privileges on the target system

## Role Variables

### Default Variables (defaults/main.yml)

- `standard_packages`: List of packages to install
- `package_state`: State of packages (default: `present`)
- `update_cache`: Whether to update package cache (default: `yes`)
- `cache_valid_time`: Cache validity time in seconds (default: `3600`)

### Packages Installed

The role installs the following packages:

- **System Monitoring**: anacron, btop, hardinfo, htop, inxi, lm-sensors
- **Terminal Tools**: autojump, fzf, ripgrep, silversearcher-ag, thefuck, tmux, tree
- **Text Editors**: vim
- **Terminal Emulator**: kitty
- **System Configuration**: dconf-editor
- **Backup Tools**: restic
- **Hardware Tools**: solaar, yubikey-manager
- **System Utilities**: snapd, stress
- **Media Codecs**: ubuntu-restricted-extras

## Dependencies

None.

## Example Playbook

```yaml
---
- name: Install standard packages
  hosts: local
  become: yes
  roles:
    - package-install
```

## Tags

The role supports the following tags:

- `packages`: All package-related tasks
- `package-install`: All tasks in this role
- `cache-update`: Package cache update task
- `verification`: Package verification tasks
- `info`: Information display tasks

## Usage Examples

Install all packages:
```bash
ansible-playbook site.yml --tags package-install
```

Only update cache and install packages (skip verification):
```bash
ansible-playbook site.yml --tags packages --skip-tags verification
```

## Author Information

Created for home lab automation on PopOS 24.04 Cosmic systems.