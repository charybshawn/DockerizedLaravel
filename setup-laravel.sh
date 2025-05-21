#!/bin/bash
# Setup script for Laravel environment

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[1;36m'  # Cyan (more visible on dark themes)
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Default values
MYSQL_PASSWORD=""
POSTGRES_PASSWORD=""
PHP_VERSIONS="8.1"
DEFAULT_PHP="8.1"
CREATE_SAMPLE="no"
INSTALL_ADMINER="yes"
ADMINER_PASSWORD=""
VERBOSE=false

# Help message
show_help() {
    echo -e "${BLUE}Laravel Development Environment Setup${NC}"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help                 Show this help message"
    echo "  -m, --mysql-password       MySQL root password"
    echo "  -p, --postgres-password    PostgreSQL postgres user password"
    echo "  -v, --php-versions         PHP versions to install (space-separated, e.g., '8.1 8.2 8.3')"
    echo "  -d, --default-php          Default PHP version to use"
    echo "  -s, --sample-site          Create a sample Laravel site (yes/no)"
    echo "  -a, --adminer              Install Adminer database manager (yes/no)"
    echo "  -w, --adminer-password     Adminer admin password"
    echo "  -V, --verbose              Show detailed output"
    echo ""
    echo "Example:"
    echo "  $0 -m 'mysqlpass' -p 'postgrespass' -v '8.1 8.2' -d 8.1 -s yes -a yes -w 'adminpass'"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -m|--mysql-password)
            MYSQL_PASSWORD="$2"
            shift 2
            ;;
        -p|--postgres-password)
            POSTGRES_PASSWORD="$2"
            shift 2
            ;;
        -v|--php-versions)
            PHP_VERSIONS="$2"
            shift 2
            ;;
        -d|--default-php)
            DEFAULT_PHP="$2"
            shift 2
            ;;
        -s|--sample-site)
            CREATE_SAMPLE="$2"
            shift 2
            ;;
        -a|--adminer)
            INSTALL_ADMINER="$2"
            shift 2
            ;;
        -w|--adminer-password)
            ADMINER_PASSWORD="$2"
            shift 2
            ;;
        -V|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Check if required passwords are provided
if [ -z "$MYSQL_PASSWORD" ]; then
    echo -e "${RED}Error: MySQL root password is required${NC}"
    echo "Use -m or --mysql-password to provide it"
    exit 1
fi

if [ -z "$POSTGRES_PASSWORD" ]; then
    echo -e "${RED}Error: PostgreSQL postgres user password is required${NC}"
    echo "Use -p or --postgres-password to provide it"
    exit 1
fi

# Build the ansible-playbook command
CMD="ansible-playbook playbooks/setup_laravel_server.yml"

# Add variables
CMD="$CMD -e mysql_root_password='$MYSQL_PASSWORD'"
CMD="$CMD -e postgres_password='$POSTGRES_PASSWORD'"
CMD="$CMD -e php_versions='$PHP_VERSIONS'"
CMD="$CMD -e default_php_version='$DEFAULT_PHP'"
CMD="$CMD -e create_sample_site='$CREATE_SAMPLE'"
CMD="$CMD -e install_adminer='$INSTALL_ADMINER'"
if [ ! -z "$ADMINER_PASSWORD" ]; then
    CMD="$CMD -e adminer_password='$ADMINER_PASSWORD'"
fi
CMD="$CMD -e verbose=$VERBOSE"

# Run the playbook
echo -e "${BLUE}Setting up Laravel development environment...${NC}"
eval $CMD

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

# Ensure home directory permissions are correct
echo -e "${BLUE}Checking home directory permissions...${NC}"
chown $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME"
chmod 750 "$ACTUAL_HOME"

# Create ansible directory if it doesn't exist
if [ ! -d "$ACTUAL_HOME/ansible" ]; then
    echo -e "${BLUE}Creating ansible directory in home folder...${NC}"
    mkdir -p "$ACTUAL_HOME/ansible"
    chown $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/ansible"
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

# Set up the webserver repository if we're not already in it
if [ ! -f "$(pwd)/setup-laravel.sh" ] || [ ! -d "$(pwd)/.git" ]; then
    echo -e "${BLUE}Setting up webserver repository...${NC}"
    
    # Create ansible directory if it doesn't exist
    if [ ! -d "$ACTUAL_HOME/ansible" ]; then
        mkdir -p "$ACTUAL_HOME/ansible"
        chown $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/ansible"
    fi
    
    # Clone the repository if needed
    if [ ! -d "$ACTUAL_HOME/ansible/webserver" ]; then
        echo -e "${BLUE}Cloning webserver repository...${NC}"
        sudo -u $ACTUAL_USER git clone https://github.com/charybshawn/webserver.git "$ACTUAL_HOME/ansible/webserver"
    else
        echo -e "${BLUE}Updating webserver repository...${NC}"
        cd "$ACTUAL_HOME/ansible/webserver"
        sudo -u $ACTUAL_USER git pull
    fi
    
    # Switch to the repository directory
    cd "$ACTUAL_HOME/ansible/webserver"
    echo -e "${GREEN}Now working in the webserver repository directory${NC}"
fi

# Prompt for PHP versions to install
read -p "Enter PHP versions to install (space-separated, e.g., '8.1 8.2 8.3'): " PHP_VERSIONS
PHP_VERSIONS=${PHP_VERSIONS:-"8.1"}

read -p "Enter default PHP version: " DEFAULT_PHP_VERSION
DEFAULT_PHP_VERSION=${DEFAULT_PHP_VERSION:-"8.1"}

# Prompt for Node.js version
read -p "Enter Node.js version to install (18, 20, or 'lts'): " NODE_VERSION
NODE_VERSION=${NODE_VERSION:-"lts"}
if [ "$NODE_VERSION" = "lts" ]; then
  NODE_VERSION="18" # Current LTS version
fi

# Ask about sample site
read -p "Create a sample Laravel site? (yes/no) [no]: " CREATE_SAMPLE_SITE
CREATE_SAMPLE_SITE=${CREATE_SAMPLE_SITE:-"no"}

# Export variables so they can be used by Ansible
export ANSIBLE_EXTRA_VARS="php_versions='$PHP_VERSIONS' default_php_version='$DEFAULT_PHP_VERSION' create_sample_site='$CREATE_SAMPLE_SITE' node_version='$NODE_VERSION'"

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

# Check if sample site was created - look for both directory and Nginx config
SAMPLE_SITE=""
SITE_CREATED=false
if [ "$CREATE_SAMPLE_SITE" = "yes" ] && [ -d "/var/www/laravel" ] && [ -f "/etc/nginx/sites-available/laravel" ]; then
    SAMPLE_SITE="laravel"
    SITE_CREATED=true
elif [ "$CREATE_SAMPLE_SITE" = "yes" ] && [ -d "/var/www/laravel" ]; then
    echo -e "${YELLOW}Warning: Laravel directory exists but no Nginx config found. Sample site may not be fully configured.${NC}"
    SAMPLE_SITE="laravel"
    SITE_CREATED=true
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

if [ "$SITE_CREATED" = true ]; then
    SAMPLE_SITE_PHP=$(grep -r "fastcgi_pass" /etc/nginx/sites-available/$SAMPLE_SITE 2>/dev/null | grep -o "php[0-9]\+\.[0-9]\+" | head -1 | sed 's/php//' || echo "unknown")
    echo -e "${BLUE}🚀 Sample Laravel Site:${NC}"
    echo "  - Site: $SAMPLE_SITE"
    echo "  - URL: http://${PUBLIC_IP}/"
    echo "  - URL: http://${SAMPLE_SITE}.local/ (add to your hosts file)"
    echo "  - Path: /var/www/${SAMPLE_SITE}/"
    echo "  - PHP Version: ${SAMPLE_SITE_PHP}"
else
    echo -e "${YELLOW}ℹ️ No sample site was created.${NC}"
    echo "  - Run './setup-site.sh' to create a new Laravel site"
fi

echo ""
echo "===================================================="
echo -e "${GREEN}To create additional Laravel sites run: sudo ./setup-site.sh${NC}"
echo "" 