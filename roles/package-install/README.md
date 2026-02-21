# Package Install Role

This Ansible role installs packages for both desktop and server systems in a home lab environment.

## Description

The `package-install` role automates the installation of essential packages with separate package lists for CLI (server-suitable) and desktop (GUI) applications. This allows you to install only CLI tools on headless servers while getting the full suite on desktop systems.

## Requirements

- Ubuntu/Debian (apt) or Fedora/RedHat (dnf) based distribution
- Ansible 2.9 or higher
- sudo privileges on the target system

## Role Variables

### Default Variables (defaults/main.yml)

- `cli_packages`: List of CLI packages suitable for servers and desktops
- `desktop_packages`: List of GUI/desktop-specific packages
- `install_cli_packages`: Install CLI packages (default: `yes`)
- `install_desktop_packages`: Install desktop packages (default: `yes`)
- `package_state`: State of packages (default: `present`)
- `update_cache`: Whether to update package cache (default: `yes`)
- `cache_valid_time`: Cache validity time in seconds (default: `3600`)

### CLI Packages (Headless Server Compatible)

- **System Monitoring**: anacron, btop, htop, inxi, lm-sensors
- **Terminal Tools**: autojump, fzf, ripgrep, silversearcher-ag, thefuck, tmux, tree
- **Text Editors**: vim
- **Backup Tools**: restic
- **System Utilities**: stress

### Desktop Packages (GUI Applications)

- **Terminal Emulator**: kitty
- **System Configuration**: dconf-editor, hardinfo
- **Hardware Tools**: solaar, yubikey-manager
- **System Utilities**: snapd
- **Media Codecs**: ubuntu-restricted-extras

## Dependencies

None.

## Example Playbook

Install all packages on desktop:
```yaml
---
- name: Install all packages (desktop)
  hosts: local
  become: yes
  roles:
    - package-install
```

Install only CLI packages on server:
```yaml
---
- name: Install CLI packages only (server)
  hosts: remote
  become: yes
  vars:
    install_desktop_packages: no
  roles:
    - package-install
```

## Tags

The role supports the following tags:

- `packages`: All package-related tasks
- `package-install`: All tasks in this role
- `cli-packages`: Only CLI package installation
- `desktop-packages`: Only desktop package installation
- `cache-update`: Package cache update task
- `verification`: Package verification tasks
- `info`: Information display tasks

## Usage Examples

Install all packages (desktop):
```bash
ansible-playbook local_setup.yml --tags package-install
```

Install only CLI packages:
```bash
ansible-playbook local_setup.yml --tags cli-packages
```

Install only desktop packages:
```bash
ansible-playbook local_setup.yml --tags desktop-packages
```

Install CLI packages on remote server:
```bash
ansible-playbook remote_setup.yml --tags package-install
```

## Multi-OS Support

The role automatically detects the OS family and includes the appropriate task file:
- `debian.yml` - For Debian/Ubuntu systems (uses apt)
- `redhat.yml` - For Fedora/RedHat systems (uses dnf)

## Author Information

Created for home lab automation supporting both Debian/Ubuntu and Fedora/RedHat systems.