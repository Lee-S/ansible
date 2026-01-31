# user-setup

Creates a user account on remote systems and configures SSH access.

## Description

This role creates a user account on remote systems, sets up SSH key authentication by copying the public key from the local user, and configures passwordless sudo access.

## Requirements

- Ansible must be running with root privileges on the target system
- The local user must have an SSH public key (default: `~/.ssh/id_ed25519.pub`)

## Role Variables

Available variables are listed below, along with default values (see `defaults/main.yml`):

```yaml
target_user: lee
target_user_shell: /bin/bash
target_user_groups: sudo
ssh_key_path: "{{ lookup('env','HOME') }}/.ssh/id_ed25519.pub"
```

- `target_user`: The username to create on the remote system
- `target_user_shell`: The default shell for the user
- `target_user_groups`: Additional groups to add the user to (sudo for Ubuntu/Debian, wheel for Fedora/RedHat)
- `ssh_key_path`: Path to the SSH public key to copy to the remote user (can be overridden for id_rsa.pub or other keys)

## Dependencies

None.

## Tags

- `user-setup` - All tasks in this role
- `user` - User account creation
- `ssh` - SSH key setup
- `sudo` - Sudo configuration

## Example Playbook

```yaml
- hosts: remote
  become: yes
  roles:
    - user-setup
```

## Author Information

Created for home lab automation.
