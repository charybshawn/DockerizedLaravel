#!/bin/bash

# LEMP Stack Rollback Script
# Removes all components installed by the LEMP installer

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
VERBOSE=false
FORCE=false
KEEP_DATA=false

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
LEMP Stack Rollback Script

Usage: $0 [OPTIONS]

Options:
    --keep-data         Keep database data and /var/www files
    --force             Skip confirmation prompts
    --verbose           Show detailed output
    --help              Show this help message

Examples:
    $0                  Interactive rollback with data removal
    $0 --keep-data      Remove packages but keep data
    $0 --force          Non-interactive complete removal

WARNING: This will remove all LEMP components and optionally their data!
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --keep-data)
            KEEP_DATA=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --verbose)
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

# Check root privileges
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        print_status "ERROR" "This script must be run as root or with sudo"
        exit 1
    fi
}

# Confirmation prompt
confirm_rollback() {
    if [[ "$FORCE" == true ]]; then
        return
    fi
    
    echo
    print_status "WARN" "This will remove the following:"
    echo "  - Nginx web server"
    echo "  - PHP and all extensions"
    echo "  - MariaDB/PostgreSQL database"
    echo "  - Composer"
    echo "  - All configuration files"
    
    if [[ "$KEEP_DATA" == false ]]; then
        echo "  - Database data"
        echo "  - Website files in /var/www"
    fi
    
    echo
    read -p "Are you sure you want to continue? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_status "INFO" "Rollback cancelled"
        exit 0
    fi
}

# Check if service exists
service_exists() {
    systemctl list-unit-files | grep -q "^$1"
}

# Check if package is installed
package_installed() {
    dpkg -l | grep -q "^ii  $1"
}

# Stop and disable services
stop_services() {
    print_status "INFO" "Stopping services..."
    
    # Stop Nginx
    if service_exists nginx; then
        systemctl stop nginx || true
        systemctl disable nginx || true
        [[ "$VERBOSE" == true ]] && print_status "SUCCESS" "Nginx service stopped"
    fi
    
    # Stop PHP-FPM (check multiple versions)
    for version in 7.4 8.0 8.1 8.2 8.3 8.4; do
        if service_exists "php$version-fpm"; then
            systemctl stop "php$version-fpm" || true
            systemctl disable "php$version-fpm" || true
            [[ "$VERBOSE" == true ]] && print_status "SUCCESS" "PHP $version-FPM stopped"
        fi
    done
    
    # Stop MariaDB
    if service_exists mariadb; then
        systemctl stop mariadb || true
        systemctl disable mariadb || true
        [[ "$VERBOSE" == true ]] && print_status "SUCCESS" "MariaDB stopped"
    fi
    
    # Stop MySQL (if installed instead of MariaDB)
    if service_exists mysql; then
        systemctl stop mysql || true
        systemctl disable mysql || true
        [[ "$VERBOSE" == true ]] && print_status "SUCCESS" "MySQL stopped"
    fi
    
    # Stop PostgreSQL
    if service_exists postgresql; then
        systemctl stop postgresql || true
        systemctl disable postgresql || true
        [[ "$VERBOSE" == true ]] && print_status "SUCCESS" "PostgreSQL stopped"
    fi
}

# Remove packages
remove_packages() {
    print_status "INFO" "Removing packages..."
    
    # Remove Nginx
    if package_installed nginx; then
        apt-get remove -y nginx nginx-common nginx-core
        [[ "$VERBOSE" == true ]] && print_status "SUCCESS" "Nginx packages removed"
    fi
    
    # Remove PHP packages (all versions)
    php_packages_removed=false
    for version in 7.4 8.0 8.1 8.2 8.3 8.4; do
        if package_installed "php$version"; then
            apt-get remove -y "php$version*"
            php_packages_removed=true
        fi
    done
    [[ "$php_packages_removed" == true && "$VERBOSE" == true ]] && print_status "SUCCESS" "PHP packages removed"
    
    # Remove MariaDB
    if package_installed mariadb-server; then
        apt-get remove -y mariadb-server mariadb-client mariadb-common mysql-common
        [[ "$VERBOSE" == true ]] && print_status "SUCCESS" "MariaDB packages removed"
    fi
    
    # Remove MySQL (if installed)
    if package_installed mysql-server; then
        apt-get remove -y mysql-server mysql-client mysql-common
        [[ "$VERBOSE" == true ]] && print_status "SUCCESS" "MySQL packages removed"
    fi
    
    # Remove PostgreSQL
    if package_installed postgresql; then
        apt-get remove -y postgresql postgresql-contrib postgresql-client-common postgresql-common
        [[ "$VERBOSE" == true ]] && print_status "SUCCESS" "PostgreSQL packages removed"
    fi
    
    # Clean up
    apt-get autoremove -y
    apt-get autoclean
}

# Remove Composer
remove_composer() {
    if [[ -f /usr/local/bin/composer ]]; then
        rm -f /usr/local/bin/composer
        [[ "$VERBOSE" == true ]] && print_status "SUCCESS" "Composer removed"
    fi
}

# Remove configuration files
remove_configs() {
    print_status "INFO" "Removing configuration files..."
    
    # Remove Nginx configs
    rm -rf /etc/nginx
    
    # Remove PHP configs
    rm -rf /etc/php
    
    # Remove database configs
    if [[ "$KEEP_DATA" == false ]]; then
        rm -rf /etc/mysql
        rm -rf /etc/postgresql
        rm -rf /var/lib/mysql
        rm -rf /var/lib/postgresql
    fi
    
    [[ "$VERBOSE" == true ]] && print_status "SUCCESS" "Configuration files removed"
}

# Remove PPA repositories
remove_repositories() {
    print_status "INFO" "Removing repositories..."
    
    # Remove Ondrej PHP PPA
    if [[ -f /etc/apt/sources.list.d/ondrej-ubuntu-php-*.list ]]; then
        add-apt-repository --remove ppa:ondrej/php -y
        [[ "$VERBOSE" == true ]] && print_status "SUCCESS" "PHP PPA removed"
    fi
}

# Remove web files
remove_web_files() {
    if [[ "$KEEP_DATA" == false ]]; then
        print_status "INFO" "Removing web files..."
        
        # Backup current sites if any exist
        if [[ -d /var/www && "$(ls -A /var/www 2>/dev/null)" ]]; then
            backup_dir="/tmp/lemp-rollback-backup-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir"
            cp -r /var/www/* "$backup_dir/" 2>/dev/null || true
            print_status "INFO" "Website files backed up to: $backup_dir"
        fi
        
        rm -rf /var/www
        [[ "$VERBOSE" == true ]] && print_status "SUCCESS" "Web files removed"
    else
        print_status "INFO" "Keeping website files (--keep-data specified)"
    fi
}

# Remove log files
remove_logs() {
    print_status "INFO" "Removing log files..."
    
    rm -rf /var/log/nginx
    rm -rf /var/log/php*
    
    if [[ "$KEEP_DATA" == false ]]; then
        rm -rf /var/log/mysql*
        rm -rf /var/log/postgresql
    fi
    
    [[ "$VERBOSE" == true ]] && print_status "SUCCESS" "Log files removed"
}

# Update package lists
update_packages() {
    print_status "INFO" "Updating package lists..."
    apt-get update
}

# Main execution
main() {
    echo "==============================================="
    echo "LEMP Stack Rollback Script"
    echo "==============================================="
    echo
    
    check_privileges
    confirm_rollback
    
    stop_services
    remove_packages
    remove_composer
    remove_configs
    remove_repositories
    remove_web_files
    remove_logs
    update_packages
    
    echo
    print_status "SUCCESS" "LEMP stack rollback completed!"
    
    if [[ "$KEEP_DATA" == false ]]; then
        print_status "INFO" "All components and data have been removed"
        if [[ -d /tmp/lemp-rollback-backup-* ]]; then
            print_status "INFO" "Website files were backed up to /tmp/lemp-rollback-backup-*"
        fi
    else
        print_status "INFO" "Packages removed, data preserved"
    fi
    
    echo
    print_status "INFO" "You may want to reboot the system to ensure all changes take effect"
}

# Run main function
main "$@"