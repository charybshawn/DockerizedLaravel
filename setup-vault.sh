#!/bin/bash
# Setup Ansible Vault for Laravel Development Environment

set -euo pipefail

echo "Laravel Development Environment - Vault Setup"
echo "============================================"
echo

# Check if vault template exists
if [[ ! -f "vault_template.yml" ]]; then
    echo "Error: vault_template.yml not found."
    echo "The installer should have created this file with your passwords."
    exit 1
fi

# Check if vault already exists
if [[ -f "group_vars/vault.yml" ]]; then
    echo "Warning: group_vars/vault.yml already exists."
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Vault setup cancelled."
        exit 0
    fi
    # Backup existing vault
    cp group_vars/vault.yml group_vars/vault.yml.backup.$(date +%Y%m%d_%H%M%S)
    echo "Existing vault backed up."
fi

# Create vault from template
echo "Creating encrypted vault file..."
echo
echo "IMPORTANT: Choose a strong password for your vault."
echo "You will need this password every time you run playbooks."
echo

# Copy template to vault location
cp vault_template.yml group_vars/vault.yml

# Encrypt the vault file
ansible-vault encrypt group_vars/vault.yml

if [[ $? -eq 0 ]]; then
    echo
    echo "✅ Vault created successfully!"
    
    # Remove template for security
    echo "Removing vault_template.yml for security..."
    rm -f vault_template.yml
    
    echo
    echo "Next steps:"
    echo "1. Remember your vault password!"
    echo "2. To edit vault: ansible-vault edit group_vars/vault.yml"
    echo "3. To run playbooks: add --ask-vault-pass"
    echo
    echo "You can now continue with the installation:"
    echo "  sudo ./laravel-env-installer --mode full"
else
    echo
    echo "❌ Failed to create vault. Please try again."
    exit 1
fi