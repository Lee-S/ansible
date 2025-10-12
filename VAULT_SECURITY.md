# Ansible Vault Security Guide

This document outlines the security measures implemented to prevent accidentally committing unencrypted vault files to version control.

## Quick Setup for new chckouts

**After checkout you should run this first:**
```bash
./scripts/install-hooks.sh
```

This installs the pre-commit hook that prevents unencrypted vault files from being committed.

## Security Measures in Place

### 1. Pre-commit Hook
A Git pre-commit hook (`.git/hooks/pre-commit`) automatically checks all files being committed:

- **Detects vault files** by naming patterns:
  - Files matching `*vault*.yml`, `*secret*.yml`, `*credential*.yml`, `*password*.yml`, `*key*.yml`
  - Files in `group_vars/*/vault*.yml` or `host_vars/*/vault*.yml`
  - Specific files like `vault.yml`, `secrets.yml`

- **Verifies encryption** by checking for the `$ANSIBLE_VAULT;1.1;AES256` header
- **Blocks commits** if unencrypted vault files are detected
- **Warns about** YAML files containing sensitive data patterns

### 2. Ansible Configuration
The `ansible.cfg` file is configured with:
- `vault_password_file = .ansible_vault_pass` - Points to password file (excluded from git)
- `ask_vault_pass = True` - Prompts for password if file doesn't exist

### 3. .gitignore Protection
The `.gitignore` file excludes:
- `.ansible_vault_pass` - Vault password file
- `vault_password_file` - Alternative password file names
- `**/vault_password*` - Any vault password files

## How to Use Vault Files Safely

### Creating a New Vault File
```bash
# Create and encrypt a new vault file
ansible-vault create vault.yml

# Or create a plain file first, then encrypt it
echo "secret_password: mysecret" > vault.yml
ansible-vault encrypt vault.yml
```

### Editing Vault Files
```bash
# Edit an encrypted vault file
ansible-vault edit vault.yml

# View an encrypted vault file
ansible-vault view vault.yml
```

### Managing Vault Passwords
```bash
# Create a vault password file (DO NOT commit this)
echo "your_vault_password" > .ansible_vault_pass
chmod 600 .ansible_vault_pass

# Or use environment variable
export ANSIBLE_VAULT_PASSWORD_FILE=.ansible_vault_pass
```

### Decrypting for Editing (Temporary)
```bash
# Decrypt temporarily (remember to re-encrypt!)
ansible-vault decrypt vault.yml
# ... make changes ...
ansible-vault encrypt vault.yml
```

## What Happens When You Try to Commit

### ✅ Encrypted Vault File (Allowed)
```
$ git commit -m "Update vault"
Checking for unencrypted vault files...
✓ vault.yml is properly encrypted
✓ All vault files are properly encrypted
[main abc1234] Update vault
```

### ❌ Unencrypted Vault File (Blocked)
```
$ git commit -m "Update vault"
Checking for unencrypted vault files...
ERROR: Unencrypted vault file detected: vault.yml
This file appears to be a vault file but is not encrypted.
Please encrypt it with: ansible-vault encrypt vault.yml

Commit blocked due to unencrypted vault files!
To fix this:
1. Encrypt the files with: ansible-vault encrypt <filename>
2. Or if they shouldn't be vault files, rename them to not match vault patterns
3. Then commit again
```

### ⚠️ Sensitive Data Warning
```
$ git commit -m "Update config"
Checking for unencrypted vault files...
WARNING: config.yml contains sensitive data but is not encrypted
Consider encrypting it with: ansible-vault encrypt config.yml
Or move sensitive data to a vault file
✓ All vault files are properly encrypted
```

## Best Practices

1. **Always encrypt sensitive data** before committing
2. **Use descriptive vault file names** that match the detection patterns
3. **Keep vault passwords secure** and never commit them
4. **Test your vault files** after encryption to ensure they work
5. **Use separate vault files** for different environments (dev, staging, prod)
6. **Document your vault structure** for team members

## Troubleshooting

### Pre-commit Hook Not Working
```bash
# Check if hook is executable
ls -la .git/hooks/pre-commit
# If not executable, fix it:
chmod +x .git/hooks/pre-commit
```

### Bypassing the Hook (Emergency Only)
```bash
# Only use in emergencies - NOT recommended
git commit --no-verify -m "Emergency commit"
```

### Re-encrypting a Vault File
```bash
# If you need to change the vault password
ansible-vault rekey vault.yml
```

## File Patterns Detected

The pre-commit hook detects these patterns as potential vault files:
- `*vault*.yml` or `*vault*.yaml`
- `*secret*.yml` or `*secret*.yaml`  
- `*credential*.yml` or `*credential*.yaml`
- `*password*.yml` or `*password*.yaml`
- `*key*.yml` or `*key*.yaml`
- `group_vars/*/vault*.yml`
- `host_vars/*/vault*.yml`
- Exact matches: `vault.yml`, `secrets.yml`

## Security Notes

- The current `vault.yml` file is properly encrypted and safe to commit
- This system prevents accidental exposure of secrets but requires discipline
- Always verify your vault files are encrypted before committing
- Consider using additional tools like `git-secrets` for extra protection