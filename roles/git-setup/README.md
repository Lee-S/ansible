# Git Setup Role

This Ansible role configures Git for first-time setup on a local system, including user identity and common global configuration options.

## Requirements

- Ansible 2.9+
- Target system running Linux
- Sudo/root privileges on the target system (to install Git package)

## Role Variables

### Variables

#### Group Variables (group_vars/all/main.yml)

```yaml
git_user_name: "Lee-S"                     # Git user name
git_user_email: "lee.skelton@gmail.com"    # Git user email
```

#### Default Variables (roles/git-setup/defaults/main.yml)

```yaml
# Git global configuration options
git_config_options:
  - name: user.name
    value: "{{ git_user_name }}"
  - name: user.email
    value: "{{ git_user_email }}"
  - name: init.defaultBranch
    value: "main"
  - name: pull.rebase
    value: "false"
  - name: core.editor
    value: "nano"
  - name: color.ui
    value: "auto"

# Package requirements
required_packages:
  - git
```

## Dependencies

None.

## Example Playbook

```yaml
---
- name: Configure Git for first-time setup
  hosts: localhost
  become: yes
  roles:
    - git-setup
```

## Usage

1. **Customize variables** (optional): Override default variables in your playbook or inventory:
   ```yaml
   git_user_name: "Your Name"
   git_user_email: "your.email@example.com"
   git_config_options:
     - name: user.name
       value: "{{ git_user_name }}"
     - name: user.email
       value: "{{ git_user_email }}"
     - name: init.defaultBranch
       value: "main"
     - name: core.editor
       value: "vim"
   ```

2. **Run the playbook**:
   ```bash
   ansible-playbook -i inventory/hosts site.yml --ask-become-pass
   ```

## What This Role Does

1. **Package Installation**: Installs the `git` package if not already present
2. **User Detection**: Automatically detects the actual user (not root) to configure Git for
3. **Configuration Check**: Checks current Git configuration before making changes
4. **Global Configuration**: Sets up Git global configuration including:
   - User name and email
   - Default branch name (main)
   - Pull strategy (merge vs rebase)
   - Default editor
   - Color output settings
5. **Verification**: Displays the final Git configuration for confirmation

## Configuration Options

The role sets up the following Git global configurations by default:

- `user.name`: Your full name for Git commits
- `user.email`: Your email address for Git commits
- `init.defaultBranch`: Sets "main" as the default branch name for new repositories
- `pull.rebase`: Sets to "false" to use merge strategy for pulls
- `core.editor`: Sets "nano" as the default editor for Git operations
- `color.ui`: Enables automatic color output for Git commands

## Customization

You can customize the Git configuration by overriding the `git_config_options` variable:

```yaml
git_config_options:
  - name: user.name
    value: "{{ git_user_name }}"
  - name: user.email
    value: "{{ git_user_email }}"
  - name: init.defaultBranch
    value: "main"
  - name: pull.rebase
    value: "true"          # Use rebase instead of merge
  - name: core.editor
    value: "vim"           # Use vim instead of nano
  - name: color.ui
    value: "auto"
  - name: push.default
    value: "simple"        # Additional configuration
```

## Security Features

- The role automatically detects the actual user (not root) to ensure Git is configured for the correct user account
- No sensitive information is stored or transmitted
- Configuration is applied at the user level, not system-wide

## Tags

The role supports the following tags for selective execution:

- `packages`: Install Git package only
- `user-info`: Detect user information only
- `git-check`: Check current Git configuration only
- `git-config`: Apply Git configuration only
- `git-verify`: Verify final configuration only
- `git-info`: Display configuration information only

Example: `ansible-playbook site.yml --tags "git-config"`

## Troubleshooting

- **Git not found**: The role will install Git automatically
- **Permission issues**: Ensure you run with `--ask-become-pass` for package installation
- **Wrong user configured**: The role automatically detects the actual user, but you can override by setting `ansible_user`

## License

MIT

## Author Information

Created for home lab automation setup.