#!/bin/bash
# Setup script for Laravel environment

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or with sudo"
    exit 1
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for ansible
if ! command_exists ansible; then
    echo "Ansible not found. Installing..."
    apt update
    apt install -y ansible python3-pip
fi

# Install required Python packages
pip3 install -r requirements.txt

# Run the Ansible playbook
ansible-playbook main.yml -i inventory/hosts.yml

echo ""
echo "✅ Laravel environment setup complete!"
echo "" 