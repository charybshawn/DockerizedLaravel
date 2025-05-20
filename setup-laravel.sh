#!/bin/bash
# Setup script for Laravel environment

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[1;36m'  # Cyan (more visible on dark themes)
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run this script as root or with sudo${NC}"
    exit 1
fi

# Get the actual username (even when run with sudo)
if [ -n "$SUDO_USER" ]; then
    ACTUAL_USER=$SUDO_USER
else
    ACTUAL_USER=$(whoami)
fi
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

echo -e "${BLUE}Setting up environment for user: ${ACTUAL_USER}${NC}"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install OpenSSH server if not present
if ! dpkg -l | grep -q openssh-server; then
    echo -e "${BLUE}Installing OpenSSH server...${NC}"
    apt update
    apt install -y openssh-server
fi

# Ensure SSH service is enabled and running
systemctl enable ssh
systemctl start ssh

# Setup SSH for current user
echo -e "${BLUE}Setting up SSH for ${ACTUAL_USER}...${NC}"

# Create .ssh directory if it doesn't exist
if [ ! -d "$ACTUAL_HOME/.ssh" ]; then
    mkdir -p "$ACTUAL_HOME/.ssh"
    chmod 700 "$ACTUAL_HOME/.ssh"
    chown $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/.ssh"
fi

# Generate SSH key if it doesn't exist
if [ ! -f "$ACTUAL_HOME/.ssh/id_rsa" ]; then
    echo -e "${BLUE}Generating SSH key for ${ACTUAL_USER}...${NC}"
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
echo -e "${BLUE}SSH key generated. Your public key is:${NC}"
echo "--------------------------------------------------"
cat "$ACTUAL_HOME/.ssh/id_rsa.pub"
echo "--------------------------------------------------"

# Install Python and Ansible dependencies
echo -e "${BLUE}Installing Python and Ansible dependencies...${NC}"
apt update
apt install -y ansible python3 python3-pip

# Check if pip3 is now available
if ! command_exists pip3; then
    echo -e "${RED}Error: pip3 installation failed. Please install manually with:${NC}"
    echo "apt-get install python3-pip"
    exit 1
fi

# Install required Python packages
echo -e "${BLUE}Installing required Python packages...${NC}"
pip3 install -r requirements.txt

# Prompt for PHP versions to install
read -p "Enter PHP versions to install (space-separated, e.g., '8.1 8.2 8.3'): " PHP_VERSIONS
PHP_VERSIONS=${PHP_VERSIONS:-"8.1"}

read -p "Enter default PHP version: " DEFAULT_PHP_VERSION
DEFAULT_PHP_VERSION=${DEFAULT_PHP_VERSION:-"8.1"}

# Export variables so they can be used by Ansible
export ANSIBLE_EXTRA_VARS="php_versions='$PHP_VERSIONS' default_php_version='$DEFAULT_PHP_VERSION'"

# Run the Ansible playbook
echo -e "${BLUE}Running Ansible playbook...${NC}"
ansible-playbook main.yml -i inventory/hosts.yml --extra-vars "$ANSIBLE_EXTRA_VARS"

# Get services status
NGINX_STATUS=$(systemctl is-active nginx)
MYSQL_STATUS=$(systemctl is-active mysql)
POSTGRESQL_STATUS=$(systemctl is-active postgresql)

# Get PHP versions from directories
echo -e "${BLUE}Checking installed PHP versions...${NC}"
PHP_VERSIONS_INSTALLED=$(ls /etc/php/ 2>/dev/null | grep -E '^[0-9]+\.[0-9]+$' | sort -V)

if [ -z "$PHP_VERSIONS_INSTALLED" ]; then
    PHP_VERSIONS_INSTALLED="8.1"  # Default if none found
fi

# Get public IP
PUBLIC_IP=$(hostname -I | awk '{print $1}')

# Check if sample site was created
SAMPLE_SITE=""
if [ -d "/var/www/laravel" ]; then
    SAMPLE_SITE="laravel"
fi

echo ""
echo -e "${GREEN}✅ Laravel environment setup complete!${NC}"
echo -e "${GREEN}✅ SSH has been set up for user ${ACTUAL_USER}${NC}"
echo ""
echo -e "${BLUE}📊 Environment Summary:${NC}"
echo "===================================================="
echo -e "${BLUE}🔧 Services Status:${NC}"
echo "  - Nginx: ${NGINX_STATUS}"
echo "  - MySQL: ${MYSQL_STATUS}"
echo "  - PostgreSQL: ${POSTGRESQL_STATUS}"

# Check each PHP-FPM version status
for VERSION in $PHP_VERSIONS_INSTALLED; do
    PHP_SERVICE_STATUS=$(systemctl is-active php$VERSION-fpm 2>/dev/null || echo "not installed")
    echo "  - PHP $VERSION-FPM: ${PHP_SERVICE_STATUS}"
done

echo ""
echo -e "${BLUE}🌐 Network Information:${NC}"
echo "  - Server IP: ${PUBLIC_IP}"
echo "  - Web Port: 80 (HTTP)"
echo "  - SSH Port: 22"
echo "  - MySQL Port: 3306"
echo "  - PostgreSQL Port: 5432"
echo ""

echo -e "${BLUE}🐘 PHP Information:${NC}"
echo "  - Installed PHP versions: ${PHP_VERSIONS_INSTALLED}"
echo "  - Default PHP version: ${DEFAULT_PHP_VERSION}"
echo ""

if [ -n "$SAMPLE_SITE" ]; then
    SAMPLE_SITE_PHP=$(grep -r "fastcgi_pass" /etc/nginx/sites-available/$SAMPLE_SITE | grep -o "php[0-9]\+\.[0-9]\+" | head -1 | sed 's/php//')
    echo -e "${BLUE}🚀 Sample Laravel Site:${NC}"
    echo "  - Site: $SAMPLE_SITE"
    echo "  - URL: http://${PUBLIC_IP}/"
    echo "  - URL: http://${SAMPLE_SITE}.local/ (add to your hosts file)"
    echo "  - Path: /var/www/${SAMPLE_SITE}/"
    echo "  - PHP Version: ${SAMPLE_SITE_PHP:-"unknown"}"
else
    echo -e "${YELLOW}ℹ️ No sample site was created.${NC}"
    echo "  - Run './setup-site.sh' to create a new Laravel site"
fi

echo ""
echo "===================================================="
echo -e "${GREEN}To create additional Laravel sites run: sudo ./setup-site.sh${NC}"
echo "" 