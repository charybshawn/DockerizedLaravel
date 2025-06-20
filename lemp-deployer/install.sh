#!/bin/bash

# LEMP Stack Installer for Ubuntu
# Installs Linux, Nginx, MariaDB/PostgreSQL, PHP, and Composer

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PHP_VERSION="8.3"
DATABASE_TYPE="mariadb"
DATABASE_PASSWORD=""
VERBOSE=false
DEBUG=false
NON_INTERACTIVE=false

# Print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "SUCCESS") echo -e "${GREEN}[✓]${NC} $message" ;;
        "ERROR") echo -e "${RED}[✗]${NC} $message" ;;
        "INFO") echo -e "${BLUE}[i]${NC} $message" ;;
        "WARN") echo -e "${YELLOW}[!]${NC} $message" ;;
    esac
}

# Show help
show_help() {
    cat << EOF
LEMP Stack Installer for Ubuntu

Usage: $0 [OPTIONS]

Options:
    --php-version VERSION       PHP version to install (default: 8.3)
    --database TYPE            Database type: mariadb or postgres (default: mariadb)
    --db-password PASSWORD     Database root password
    --non-interactive          Run without prompts
    --verbose                  Show detailed output
    --debug                    Show debug output
    --help                     Show this help message

Examples:
    $0                         Interactive installation
    $0 --non-interactive       Use defaults, prompt only for password
    $0 --php-version 8.2 --database postgres --verbose

Rollback:
    ./rollback.sh              Remove all LEMP components
    ./rollback.sh --keep-data  Remove packages but keep data
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --php-version)
            PHP_VERSION="$2"
            shift 2
            ;;
        --database)
            DATABASE_TYPE="$2"
            shift 2
            ;;
        --db-password)
            DATABASE_PASSWORD="$2"
            shift 2
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --debug)
            DEBUG=true
            VERBOSE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate OS
validate_os() {
    if [[ ! -f /etc/os-release ]]; then
        print_status "ERROR" "Cannot detect OS version"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        print_status "ERROR" "This installer only supports Ubuntu"
        exit 1
    fi
    
    print_status "SUCCESS" "Ubuntu $VERSION_ID detected"
}

# Check root privileges
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        print_status "ERROR" "This script must be run as root or with sudo"
        exit 1
    fi
    print_status "SUCCESS" "Root privileges confirmed"
}

# Install Ansible if not present
install_ansible() {
    if command -v ansible-playbook &> /dev/null; then
        print_status "SUCCESS" "Ansible already installed"
        return
    fi
    
    print_status "INFO" "Installing Ansible..."
    apt-get update -qq
    apt-get install -y ansible
    print_status "SUCCESS" "Ansible installed"
}

# Interactive prompts
get_user_input() {
    if [[ "$NON_INTERACTIVE" == true ]]; then
        return
    fi
    
    echo
    print_status "INFO" "LEMP Stack Configuration"
    echo
    
    # PHP Version
    read -p "PHP version (default: $PHP_VERSION): " input
    if [[ -n "$input" ]]; then
        PHP_VERSION="$input"
    fi
    
    # Database type
    echo "Database options:"
    echo "  1) MariaDB (default)"
    echo "  2) PostgreSQL"
    read -p "Choose database [1-2]: " db_choice
    case $db_choice in
        2) DATABASE_TYPE="postgres" ;;
        *) DATABASE_TYPE="mariadb" ;;
    esac
}

# Get database password
get_database_password() {
    if [[ -n "$DATABASE_PASSWORD" ]]; then
        return
    fi
    
    while [[ -z "$DATABASE_PASSWORD" ]]; do
        echo
        read -s -p "Enter database root password: " DATABASE_PASSWORD
        echo
        if [[ -z "$DATABASE_PASSWORD" ]]; then
            print_status "WARN" "Password cannot be empty"
        fi
    done
}

# Create configuration file
create_config() {
    cat > vars/config.yml << EOF
# LEMP Stack Configuration
php_version: "$PHP_VERSION"
database_type: "$DATABASE_TYPE"
database_password: "$DATABASE_PASSWORD"
verbose_mode: $VERBOSE
EOF
}

# Run Ansible playbook
run_playbook() {
    local ansible_args=()
    
    if [[ "$DEBUG" == true ]]; then
        ansible_args+=("-vvv")
    elif [[ "$VERBOSE" == true ]]; then
        ansible_args+=("-v")
    fi
    
    print_status "INFO" "Starting LEMP stack installation..."
    
    if ansible-playbook "${ansible_args[@]}" deploy-lemp.yml; then
        echo
        print_status "SUCCESS" "LEMP stack installed successfully!"
        
        # Show installed versions
        echo
        echo "Installed Components:"
        php$PHP_VERSION --version | head -1
        composer --version 2>/dev/null || echo "Composer: Installation pending"
        nginx -v 2>&1
        if [[ "$DATABASE_TYPE" == "mariadb" ]]; then
            mysql --version | head -1
        else
            psql --version | head -1
        fi
    else
        print_status "ERROR" "Installation failed"
        exit 1
    fi
}

# Main execution
main() {
    echo "==============================================="
    echo "LEMP Stack Installer for Ubuntu"
    echo "==============================================="
    echo
    
    validate_os
    check_privileges
    install_ansible
    get_user_input
    get_database_password
    create_config
    run_playbook
}

# Run main function
main "$@"