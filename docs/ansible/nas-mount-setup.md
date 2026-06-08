# Setup Instructions for Stage 1 - NAS Mounting

## Prerequisites

Before running the playbook, ensure you have:
- Python 3 installed
- Ansible installed (`pip install ansible`)
- This repository checked out
- Network connectivity to your NAS at `nas.local`
- Passwordless sudo configured for your user (required — Ansible is incompatible with `sudo-rs`'s prompt format):
  ```bash
  echo 'lee ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/lee-nopasswd
  ```

## Initial Setup

### 1. Encrypt the Vault File

The vault file contains placeholder credentials that need to be updated and encrypted:

```bash
# First, update vault.yml with your actual credentials, then encrypt it
ansible-vault encrypt vault.yml

# Or create a new encrypted vault file
ansible-vault create vault.yml
```

When prompted, add your actual NAS credentials:
```yaml
vault_nas_username: your_actual_username
vault_nas_password: your_actual_password
```

### 2. Test Ansible Configuration

Verify your setup:
```bash
# Test connectivity to localhost (no sudo required for ping)
ansible all -m ping

# Check if the playbook syntax is valid
ansible-playbook local_setup.yml --syntax-check
```

### 3. Run the Playbook

Execute the NAS mounting playbook:
```bash
# Run with vault password prompt (will prompt for sudo password when needed)
ansible-playbook local_setup.yml --ask-vault-pass --ask-become-pass

# Or if you have a vault password file
ansible-playbook local_setup.yml --vault-password-file ~/.ansible_vault_pass --ask-become-pass
```

**Note**: The playbook requires sudo privileges for mounting operations, so you'll be prompted for your sudo password during execution.

## What the Playbook Does

1. **Installs cifs-utils** - Required package for SMB/CIFS mounting
2. **Creates mount directories** - Creates `/mnt/nas/lee` with proper permissions
3. **Sets up credentials** - Creates secure credential file at `/etc/cifs-credentials`
4. **Tests connectivity** - Pings the NAS server to ensure it's reachable
5. **Mounts the share** - Mounts `//nas.local/lee` to `/mnt/nas/lee`
6. **Updates fstab** - Adds persistent mount entry for automatic mounting on boot
7. **Verifies mount** - Confirms the mount is accessible

## Customization

To customize the setup, you can override variables in your playbook or create host-specific variables:

```yaml
# Example: Mount to a different location
nas_mount_point: /home/lee/nas

# Example: Different share name
nas_share: shared_folder

# Example: Different NAS server
nas_server: 192.168.1.100
```

## Troubleshooting

### Common Issues

1. **"cifs-utils not found"**
   - Update package cache: `sudo apt update`
   - Install manually: `sudo apt install cifs-utils`

2. **"Permission denied" when mounting**
   - Check your vault credentials are correct
   - Verify the share name exists on your NAS
   - Ensure your NAS user has access to the share

3. **"Network unreachable"**
   - Test connectivity: `ping nas.local`
   - Check your network configuration
   - Verify the NAS is powered on and connected

4. **Mount works but not persistent after reboot**
   - Check `/etc/fstab` entry was created
   - Verify the credentials file exists at `/etc/cifs-credentials`
   - Test manual mount: `sudo mount -a`

### Useful Commands

```bash
# Check current mounts
mount | grep cifs

# Check fstab entries
cat /etc/fstab | grep nas

# Test manual mount
sudo mount -t cifs //nas.local/lee /mnt/nas/lee -o credentials=/etc/cifs-credentials,uid=1000,gid=1000

# Unmount if needed
sudo umount /mnt/nas/lee
```

## Security Notes

- The vault file is encrypted and contains your NAS credentials
- The credentials file on the system (`/etc/cifs-credentials`) has restrictive permissions (600)
- Only root can read the credentials file
- The mount uses your user ID (1000) for file ownership

## Next Steps

After successful completion of Stage 1, you can:
- Add additional NAS shares by running the role with different variables
- Proceed to Stage 2 (package installation) when ready
- Customize mount options as needed for your use case