# Fedora Migration Guide

Migration steps for running this Ansible setup on Fedora 43 (MINISFORUM MS-S1 MAX Mini AI).

## Current Compatibility Status

| Role | Status | Notes |
|------|--------|-------|
| git-setup | Ready | No changes needed |
| user-setup | Ready | No changes needed |
| nas-mount | Minor fix | Add SELinux boolean for CIFS |
| nas-backup | Ready | No changes needed |
| nas-sync | Ready | No changes needed |
| cloud-sync | Ready | No changes needed |
| **package-install** | **Needs fixes** | Debian-specific package names in defaults |
| **msmtp-setup** | **Needs fix** | `msmtp-mta` package doesn't exist on Fedora |

## Package Name Differences

### CLI packages

| Debian/Ubuntu | Fedora | Notes |
|--------------|--------|-------|
| `silversearcher-ag` | `the_silver_searcher` | Different package name |
| `avahi-daemon` | `avahi` | Different package name |
| `vim` | `vim-enhanced` | Base `vim` on Fedora is vim-minimal |
| `autojump` | `autojump` | Same |
| `btop` | `btop` | Same |
| `fzf` | `fzf` | Same |
| `htop` | `htop` | Same |
| `inxi` | `inxi` | Same |
| `lm-sensors` | `lm_sensors` | Same |
| `restic` | `restic` | Same |
| `ripgrep` | `ripgrep` | Same |
| `stress` | `stress` | Same |
| `thefuck` | `thefuck` | Same |
| `tmux` | `tmux` | Same |
| `tree` | `tree` | Same |

### Desktop packages

| Debian/Ubuntu | Fedora | Notes |
|--------------|--------|-------|
| `ubuntu-restricted-extras` | N/A | No equivalent; requires RPM Fusion repos + individual codec packages |
| `snapd` | `snapd` | Available but Flatpak is native on Fedora; consider skipping |
| `hardinfo` | `hardinfo2` | Different package name |
| `dconf-editor` | `dconf-editor` | Same |
| `kitty` | `kitty` | Same |
| `solaar` | `solaar` | Same |
| `yubikey-manager` | `yubikey-manager` | Same |

### msmtp packages

| Debian/Ubuntu | Fedora | Notes |
|--------------|--------|-------|
| `msmtp` + `msmtp-mta` | `msmtp` only | `msmtp-mta` doesn't exist as separate package on Fedora |

## Migration Steps

### Step 1: Create OS-specific package variable files

Create `roles/package-install/vars/debian.yml` with the current Debian/Ubuntu package lists (moved from `defaults/main.yml`).

Create `roles/package-install/vars/redhat.yml` with Fedora-correct package names.

### Step 2: Update package-install tasks/main.yml

Add `include_vars` to load the right package list before including OS-specific tasks:

```yaml
---
- name: Include OS-specific variables
  include_vars: "{{ ansible_os_family | lower }}.yml"

- name: Include OS-specific tasks
  include_tasks: "{{ ansible_os_family | lower }}.yml"
```

### Step 3: Clean up defaults/main.yml

Remove `cli_packages` and `desktop_packages` lists from `roles/package-install/defaults/main.yml` (they now live in the vars files). Keep only control variables:

```yaml
---
install_cli_packages: yes
install_desktop_packages: yes
package_state: present
update_cache: yes
cache_valid_time: 3600
```

### Step 4: Fix msmtp-setup for Fedora

In `roles/msmtp-setup/tasks/main.yml`, make the package list OS-aware:

```yaml
- name: Install msmtp packages
  package:
    name: "{{ msmtp_packages }}"
    state: present
  vars:
    msmtp_packages: "{{ ['msmtp', 'msmtp-mta'] if ansible_os_family == 'Debian' else ['msmtp'] }}"
```

### Step 5: Add SELinux support for NAS mounts

Fedora has SELinux enforcing by default. Add to `roles/nas-mount/tasks/main.yml` after the package install task:

```yaml
- name: Set SELinux boolean for CIFS home directories
  ansible.posix.seboolean:
    name: use_samba_home_dirs
    state: yes
    persistent: yes
  when: ansible_selinux.status == 'enabled'
  tags:
    - selinux
    - nas-mount
```

This requires the `ansible.posix` collection. Install if needed:
```bash
ansible-galaxy collection install ansible.posix
```

## Fedora 43 Specific Notes

- **DNF5**: Fedora 43 uses DNF5 by default. Ensure your Ansible version supports it (Ansible core 2.15+ recommended).
- **Firewalld**: Default firewall on Fedora (not ufw). No roles currently manage firewall rules, so no impact.
- **GNOME**: Default desktop on Fedora. `dconf-editor` works natively.
- **Flatpak**: Native package format on Fedora. Consider using Flatpak for GUI apps instead of snapd.
- **RPM Fusion**: For multimedia codecs (replacing `ubuntu-restricted-extras`), enable RPM Fusion repos:
  ```bash
  sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
  sudo dnf install https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
  sudo dnf install gstreamer1-plugins-bad-free gstreamer1-plugins-ugly gstreamer1-plugins-good-extras
  ```

## Verification

After making the changes:

1. **Syntax check**: `ansible-playbook local_setup.yml --syntax-check`
2. **Dry run (current Debian system)**: `ansible-playbook local_setup.yml --check --tags "package-install" --ask-vault-pass --ask-become-pass`
3. **On Fedora**: Run the full playbook and verify all packages install, msmtp works, and NAS mounts succeed with SELinux enforcing.
