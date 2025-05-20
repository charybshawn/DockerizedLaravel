#!/bin/bash
# Setup script for Laravel environment

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or with sudo"
    exit 1
fi

# Get the actual username (even when run with sudo)
if [ -n "$SUDO_USER" ]; then
    ACTUAL_USER=$SUDO_USER
else
    ACTUAL_USER=$(whoami)
fi
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

echo "Setting up environment for user: $ACTUAL_USER"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install OpenSSH server if not present
if ! dpkg -l | grep -q openssh-server; then
    echo "Installing OpenSSH server..."
    apt update
    apt install -y openssh-server
fi

# Ensure SSH service is enabled and running
systemctl enable ssh
systemctl start ssh

# Setup SSH for current user
echo "Setting up SSH for $ACTUAL_USER..."

# Create .ssh directory if it doesn't exist
if [ ! -d "$ACTUAL_HOME/.ssh" ]; then
    mkdir -p "$ACTUAL_HOME/.ssh"
    chmod 700 "$ACTUAL_HOME/.ssh"
    chown $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/.ssh"
fi

# Generate SSH key if it doesn't exist
if [ ! -f "$ACTUAL_HOME/.ssh/id_rsa" ]; then
    echo "Generating SSH key for $ACTUAL_USER..."
    sudo -u $ACTUAL_USER ssh-keygen -t rsa -b 4096 -f "$ACTUAL_HOME/.ssh/id_rsa" -N ""
fi

# Set proper permissions
chmod 700 "$ACTUAL_HOME/.ssh"
chmod 600 "$ACTUAL_HOME/.ssh/id_rsa"
chmod 644 "$ACTUAL_HOME/.ssh/id_rsa.pub"
chown -R $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/.ssh"

# If authorized_keys doesn't exist, create and add the public key
if [ ! -f "$ACTUAL_HOME/.ssh/authorized_keys" ]; then
    cat "$ACTUAL_HOME/.ssh/id_rsa.pub" > "$ACTUAL_HOME/.ssh/authorized_keys"
    chmod 600 "$ACTUAL_HOME/.ssh/authorized_keys"
    chown $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/.ssh/authorized_keys"
fi

# Display SSH public key
echo "SSH key generated. Your public key is:"
echo "--------------------------------------------------"
cat "$ACTUAL_HOME/.ssh/id_rsa.pub"
echo "--------------------------------------------------"

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
echo "✅ SSH has been set up for user $ACTUAL_USER"
echo "" 