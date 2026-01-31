#!/bin/bash

# Validation script for Stage 1 - NAS Mount Role
# This script performs basic validation of the Ansible setup

set -e

echo "=== Ansible Home Lab Setup - Stage 1 Validation ==="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "1. Checking Ansible installation..."
if command -v ansible >/dev/null 2>&1; then
    ansible_version=$(ansible --version | head -n1)
    print_status 0 "Ansible is installed: $ansible_version"
else
    print_status 1 "Ansible is not installed"
    echo "   Install with: pip install ansible"
    exit 1
fi

echo
echo "2. Checking Python installation..."
if command -v python3 >/dev/null 2>&1; then
    python_version=$(python3 --version)
    print_status 0 "Python3 is installed: $python_version"
else
    print_status 1 "Python3 is not installed"
    exit 1
fi

echo
echo "3. Validating Ansible configuration..."
if [ -f "ansible.cfg" ]; then
    print_status 0 "ansible.cfg exists"
else
    print_status 1 "ansible.cfg missing"
fi

echo
echo "4. Validating inventory..."
if [ -f "inventory/hosts" ]; then
    print_status 0 "inventory/hosts exists"
    if ansible all --list-hosts >/dev/null 2>&1; then
        print_status 0 "Inventory is valid"
    else
        print_status 1 "Inventory validation failed"
    fi
else
    print_status 1 "inventory/hosts missing"
fi

echo
echo "5. Validating playbook syntax..."
if [ -f "local_setup.yml" ]; then
    print_status 0 "local_setup.yml exists"
    # Check if vault file is encrypted by looking for the $ANSIBLE_VAULT header
    if [ -f "vault.yml" ] && head -n1 vault.yml | grep -q "\$ANSIBLE_VAULT"; then
        # Vault is encrypted, skip syntax check in validation
        print_warning "Vault file is encrypted - skipping syntax check in validation"
        echo "   Run manually: ansible-playbook local_setup.yml --syntax-check --ask-vault-pass"
    else
        # Vault is not encrypted or doesn't exist, can do syntax check
        if ansible-playbook local_setup.yml --syntax-check >/dev/null 2>&1; then
            print_status 0 "Playbook syntax is valid"
        else
            print_status 1 "Playbook syntax check failed"
            ansible-playbook local_setup.yml --syntax-check
        fi
    fi
else
    print_status 1 "local_setup.yml missing"
fi

echo
echo "6. Validating role structure..."
role_files=(
    "roles/nas-mount/tasks/main.yml"
    "roles/nas-mount/handlers/main.yml"
    "roles/nas-mount/defaults/main.yml"
    "roles/nas-mount/vars/main.yml"
    "roles/nas-mount/templates/cifs-credentials.j2"
    "roles/nas-mount/README.md"
)

for file in "${role_files[@]}"; do
    if [ -f "$file" ]; then
        print_status 0 "$file exists"
    else
        print_status 1 "$file missing"
    fi
done

echo
echo "7. Checking vault file..."
if [ -f "vault.yml" ]; then
    print_status 0 "vault.yml exists"
    # Check if vault file is encrypted by looking for the $ANSIBLE_VAULT header
    if head -n1 vault.yml | grep -q "\$ANSIBLE_VAULT"; then
        print_status 0 "Vault file is encrypted (good for security)"
    else
        print_warning "Vault file exists but is not encrypted"
        echo "   Encrypt it with: ansible-vault encrypt vault.yml"
    fi
else
    print_status 1 "vault.yml missing"
fi

echo
echo "8. Testing localhost connectivity..."
if ansible all -m ping >/dev/null 2>&1; then
    print_status 0 "Localhost connectivity successful"
else
    print_status 1 "Localhost connectivity failed"
fi

echo
echo "9. Checking for required system packages..."
if command -v mount.cifs >/dev/null 2>&1; then
    print_status 0 "cifs-utils already installed"
else
    print_warning "cifs-utils not installed (will be installed by playbook)"
fi

echo
echo "=== Validation Summary ==="
echo
echo "The Ansible setup for Stage 1 (NAS mounting) appears to be ready."
echo
echo "Next steps:"
echo "1. Update vault.yml with your actual NAS credentials"
echo "2. Encrypt the vault file: ansible-vault encrypt vault.yml"
echo "3. Run the playbook: ansible-playbook local_setup.yml --ask-vault-pass"
echo
echo "For detailed instructions, see setup.md"