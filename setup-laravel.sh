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

# Install Python and Ansible dependencies
echo "Installing Python and Ansible dependencies..."
apt update
apt install -y ansible python3 python3-pip

# Check if pip3 is now available
if ! command_exists pip3; then
    echo "Error: pip3 installation failed. Please install manually with:"
    echo "apt-get install python3-pip"
    exit 1
fi

# Install required Python packages
echo "Installing required Python packages..."
pip3 install -r requirements.txt

# Run the Ansible playbook
echo "Running Ansible playbook..."
ansible-playbook main.yml -i inventory/hosts.yml

# Get services status
NGINX_STATUS=$(systemctl is-active nginx)
MYSQL_STATUS=$(systemctl is-active mysql)
POSTGRESQL_STATUS=$(systemctl is-active postgresql)
PHP_STATUS=$(systemctl is-active php8.1-fpm)

# Get public IP
PUBLIC_IP=$(hostname -I | awk '{print $1}')

# Check if sample site was created
SAMPLE_SITE=""
if [ -d "/var/www/laravel" ]; then
    SAMPLE_SITE="laravel"
fi

echo ""
echo "✅ Laravel environment setup complete!"
echo "✅ SSH has been set up for user $ACTUAL_USER"
echo ""
echo "📊 Environment Summary:"
echo "===================================================="
echo "🔧 Services Status:"
echo "  - Nginx: ${NGINX_STATUS}"
echo "  - MySQL: ${MYSQL_STATUS}"
echo "  - PostgreSQL: ${POSTGRESQL_STATUS}"
echo "  - PHP-FPM: ${PHP_STATUS}"
echo ""
echo "🌐 Network Information:"
echo "  - Server IP: ${PUBLIC_IP}"
echo "  - Web Port: 80 (HTTP)"
echo "  - SSH Port: 22"
echo "  - MySQL Port: 3306"
echo "  - PostgreSQL Port: 5432"
echo ""

if [ -n "$SAMPLE_SITE" ]; then
    echo "🚀 Sample Laravel Site:"
    echo "  - Site: $SAMPLE_SITE"
    echo "  - URL: http://${PUBLIC_IP}/"
    echo "  - URL: http://${SAMPLE_SITE}.local/ (add to your hosts file)"
    echo "  - Path: /var/www/${SAMPLE_SITE}/"
else
    echo "ℹ️ No sample site was created."
    echo "  - Run './setup-site.sh' to create a new Laravel site"
fi

echo ""
echo "===================================================="
echo "To create additional Laravel sites run: sudo ./setup-site.sh"
echo "" 