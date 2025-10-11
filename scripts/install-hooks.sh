#!/bin/bash

# Script to install Git hooks for the Ansible project
# This ensures all team members have the same pre-commit protection

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

echo "Installing Git hooks for Ansible vault protection..."

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Copy pre-commit hook
cp "$SCRIPT_DIR/pre-commit" "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"

echo "✅ Pre-commit hook installed successfully!"
echo "This hook will prevent committing unencrypted vault files."
echo ""
echo "To test the hook, try committing an unencrypted vault file."
echo "The hook will block the commit and provide instructions."