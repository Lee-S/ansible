# NAS Mount Role

This Ansible role mounts a UGREEN NAS (or any SMB/CIFS share) on a local system and configures it for persistent mounting via fstab.

## Requirements

- Ansible 2.9+
- Target system running Linux with systemd
- Network connectivity to the NAS server
- Sudo/root privileges on the target system

## Role Variables

### Default Variables (roles/nas-mount/defaults/main.yml)

```yaml
nas_server: nas.local                    # NAS server hostname or IP
nas_fs_type: cifs                       # File system type
nas_mount_options: "uid=1000,gid=1000,file_mode=0644,dir_mode=0755,iocharset=utf8"
nas_credentials_file: /etc/cifs-credentials
nas_fstab_options: "defaults,_netdev,credentials={{ nas_credentials_file }},{{ nas_mount_options }}"

# List of NAS mounts to configure
nas_mounts:
  - share: personal_folder              # Share name on the NAS
    mount_point: lee                    # Local mount point under /mnt/nas/
  - share: share                        # Share name on the NAS
    mount_point: share                  # Local mount point under /mnt/nas/
```

### Vault Variables (group_vars/all/vault.yml)

```yaml
vault_nas_username: your_username       # NAS username
vault_nas_password: your_password       # NAS password
```

## Dependencies

None.

## Example Playbook

```yaml
---
- name: Mount NAS shares
  hosts: localhost
  become: yes
  roles:
    - nas-mount
```

## Usage

1. **Set up credentials**: Create and encrypt the vault file:
   ```bash
   ansible-vault create group_vars/all/vault.yml
   ```
   
   Add your NAS credentials:
   ```yaml
   vault_nas_username: your_nas_username
   vault_nas_password: your_nas_password
   ```

2. **Customize variables** (optional): Override default variables in your playbook or inventory:
   ```yaml
   nas_server: "192.168.1.100"
   nas_mounts:
     - share: "personal_folder"
       mount_point: "lee"
     - share: "shared_folder"
       mount_point: "shared"
     - share: "media"
       mount_point: "media"
   ```

3. **Run the playbook**:
   ```bash
   ansible-playbook -i inventory/hosts site.yml --ask-vault-pass --ask-become-pass
   ```

## What This Role Does

1. **Package Installation**: Installs `cifs-utils` package required for SMB/CIFS mounting
2. **Directory Creation**: Creates the mount point directory with proper permissions
3. **Credential Management**: Creates a secure credentials file (`/etc/cifs-credentials`) with restricted permissions (600)
4. **Connectivity Test**: Verifies network connectivity to the NAS server
5. **Mount Operation**: Mounts the NAS share with appropriate options
6. **fstab Configuration**: Adds an entry to `/etc/fstab` for persistent mounting across reboots
7. **Verification**: Confirms the mount is accessible and working

## Security Features

- Credentials are stored in an Ansible Vault encrypted file
- The credentials file on the target system has restrictive permissions (600, root:root)
- Network dependency (`_netdev`) ensures mounting only occurs when network is available

## Multiple Shares Support

This role now supports mounting multiple NAS shares in a single run. Simply define the `nas_mounts` list with your desired shares:

```yaml
nas_mounts:
  - share: personal_folder
    mount_point: lee
  - share: shared_documents
    mount_point: shared
  - share: media_files
    mount_point: media
```

Each share will be mounted under `/mnt/nas/{{ mount_point }}`. For example:
- `personal_folder` → `/mnt/nas/lee`
- `shared_documents` → `/mnt/nas/shared`
- `media_files` → `/mnt/nas/media`

## Troubleshooting

- **Mount fails**: Check network connectivity to `nas_server`
- **Permission denied**: Verify credentials in the vault file
- **Package not found**: Ensure the system package manager is up to date
- **Mount point issues**: Check that the parent directory exists and has proper permissions

## Tags

The role supports the following tags for selective execution:

- `packages`: Install required packages only
- `directories`: Create directories only
- `credentials`: Handle credential file only
- `connectivity`: Test NAS connectivity only
- `mount`: Handle mounting operations only
- `fstab`: Update fstab only
- `verification`: Verify mount accessibility only

Example: `ansible-playbook site.yml --tags "packages,directories"`

## License

MIT

## Author Information

Created for home lab automation setup.