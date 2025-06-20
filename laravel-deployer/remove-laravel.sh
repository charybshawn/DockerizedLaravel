#!/bin/bash

# Laravel Site Removal Tool
# Removes Laravel sites deployed with deploy-laravel.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SITE_NAME=""
KEEP_DATABASE=false
KEEP_FILES=false
FORCE=false
VERBOSE=false
INTERACTIVE=true

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
Laravel Site Removal Tool

Usage: $0 [OPTIONS]

Interactive Mode (default):
    $0                        Run with interactive prompts

Non-Interactive Mode:
    --site-name NAME          Site name to remove
    --keep-database          Keep database and user
    --keep-files             Keep website files (backup only)
    --force                  Skip confirmation prompts
    --verbose                Show detailed output
    --help                   Show this help message

Examples:
    $0                       # Interactive mode
    $0 --site-name myapp --keep-database

WARNING: This will remove the site and optionally its database!

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --site-name)
            SITE_NAME="$2"
            INTERACTIVE=false
            shift 2
            ;;
        --keep-database)
            KEEP_DATABASE=true
            shift
            ;;
        --keep-files)
            KEEP_FILES=true
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

# Interactive prompts
get_user_input() {
    if [[ "$INTERACTIVE" != true ]]; then
        return
    fi
    
    echo
    print_status "INFO" "Laravel Site Removal Configuration"
    echo
    
    # List available sites
    if [[ -d "/var/www" ]]; then
        echo "Available sites:"
        for site in /var/www/*/; do
            if [[ -d "$site" ]]; then
                site_name=$(basename "$site")
                if [[ "$site_name" != "*" && -f "/etc/nginx/sites-available/$site_name" ]]; then
                    echo "  - $site_name"
                fi
            fi
        done
        echo
    fi
    
    # Site name
    while [[ -z "$SITE_NAME" ]]; do
        read -p "Site name to remove: " SITE_NAME
        if [[ -z "$SITE_NAME" ]]; then
            print_status "WARN" "Site name cannot be empty"
        elif [[ ! -d "/var/www/$SITE_NAME" && ! -f "/etc/nginx/sites-available/$SITE_NAME" ]]; then
            print_status "ERROR" "Site '$SITE_NAME' does not exist"
            SITE_NAME=""
        fi
    done
    
    # Database preservation
    read -p "Keep database and user? [y/N]: " keep_db
    if [[ "$keep_db" =~ ^[Yy]$ ]]; then
        KEEP_DATABASE=true
    fi
    
    # File preservation
    read -p "Backup files instead of deleting? [y/N]: " keep_files
    if [[ "$keep_files" =~ ^[Yy]$ ]]; then
        KEEP_FILES=true
    fi
    
    # Verbose output
    read -p "Show verbose output? [y/N]: " verbose_choice
    if [[ "$verbose_choice" =~ ^[Yy]$ ]]; then
        VERBOSE=true
    fi
}

# Validate required arguments (for non-interactive mode)
validate_arguments() {
    if [[ "$INTERACTIVE" != true && -z "$SITE_NAME" ]]; then
        print_status "ERROR" "Missing required argument: --site-name"
        show_help
        exit 1
    fi
}

# Check root privileges
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        print_status "ERROR" "This script must be run as root or with sudo"
        exit 1
    fi
}

# Check if site exists
check_site_exists() {
    if [[ ! -d "/var/www/$SITE_NAME" && ! -f "/etc/nginx/sites-available/$SITE_NAME" ]]; then
        print_status "ERROR" "Site '$SITE_NAME' does not exist"
        exit 1
    fi
}

# Confirmation prompt
confirm_removal() {
    if [[ "$FORCE" == true ]]; then
        return
    fi
    
    echo
    print_status "WARN" "This will remove the following for site '$SITE_NAME':"
    echo "  - Nginx configuration"
    [[ "$KEEP_FILES" == false ]] && echo "  - Website files in /var/www/$SITE_NAME"
    [[ "$KEEP_DATABASE" == false ]] && echo "  - Database and user"
    
    if [[ "$KEEP_FILES" == true ]]; then
        echo "  - Files will be backed up to /tmp/${SITE_NAME}_backup_$(date +%Y%m%d_%H%M%S)"
    fi
    
    echo
    read -p "Are you sure you want to continue? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_status "INFO" "Removal cancelled"
        exit 0
    fi
}

# Stop and remove nginx configuration
remove_nginx_config() {
    print_status "INFO" "Removing Nginx configuration..."
    
    # Remove from sites-enabled
    if [[ -L "/etc/nginx/sites-enabled/$SITE_NAME" ]]; then
        rm -f "/etc/nginx/sites-enabled/$SITE_NAME"
        [[ "$VERBOSE" == true ]] && print_status "SUCCESS" "Removed from sites-enabled"
    fi
    
    # Remove from sites-available
    if [[ -f "/etc/nginx/sites-available/$SITE_NAME" ]]; then
        rm -f "/etc/nginx/sites-available/$SITE_NAME"
        [[ "$VERBOSE" == true ]] && print_status "SUCCESS" "Removed configuration file"
    fi
    
    # Test and reload nginx
    if nginx -t 2>/dev/null; then
        systemctl reload nginx
        print_status "SUCCESS" "Nginx configuration removed and reloaded"
    else
        print_status "WARN" "Nginx configuration test failed - manual intervention may be needed"
    fi
}

# Remove or backup website files
remove_website_files() {
    if [[ ! -d "/var/www/$SITE_NAME" ]]; then
        return
    fi
    
    if [[ "$KEEP_FILES" == true ]]; then
        print_status "INFO" "Backing up website files..."
        local backup_dir="/tmp/${SITE_NAME}_backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        cp -r "/var/www/$SITE_NAME" "$backup_dir/"
        print_status "SUCCESS" "Files backed up to: $backup_dir"
    else
        print_status "INFO" "Removing website files..."
    fi
    
    rm -rf "/var/www/$SITE_NAME"
    [[ "$VERBOSE" == true ]] && print_status "SUCCESS" "Website files removed"
}

# Remove database and user
remove_database() {
    if [[ "$KEEP_DATABASE" == true ]]; then
        print_status "INFO" "Keeping database (--keep-database specified)"
        return
    fi
    
    print_status "INFO" "Removing database and user..."
    
    # Check if database exists
    if mysql -e "USE \`$SITE_NAME\`" 2>/dev/null; then
        mysql -e "DROP DATABASE \`$SITE_NAME\`;" 2>/dev/null || {
            print_status "WARN" "Failed to drop database '$SITE_NAME'"
        }
        [[ "$VERBOSE" == true ]] && print_status "SUCCESS" "Database '$SITE_NAME' removed"
    fi
    
    # Check if user exists
    if mysql -e "SELECT User FROM mysql.user WHERE User='$SITE_NAME'" 2>/dev/null | grep -q "$SITE_NAME"; then
        mysql -e "DROP USER '$SITE_NAME'@'localhost';" 2>/dev/null || {
            print_status "WARN" "Failed to drop user '$SITE_NAME'"
        }
        mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true
        [[ "$VERBOSE" == true ]] && print_status "SUCCESS" "Database user '$SITE_NAME' removed"
    fi
    
    print_status "SUCCESS" "Database cleanup completed"
}

# Remove log files
remove_logs() {
    print_status "INFO" "Removing log files..."
    
    rm -f "/var/log/nginx/${SITE_NAME}_access.log"*
    rm -f "/var/log/nginx/${SITE_NAME}_error.log"*
    
    [[ "$VERBOSE" == true ]] && print_status "SUCCESS" "Log files removed"
}

# Main execution
main() {
    echo "==============================================="
    echo "Laravel Site Removal Tool"
    echo "==============================================="
    echo
    
    check_privileges
    
    # Get user input (interactive or validate flags)
    get_user_input
    validate_arguments
    
    print_status "INFO" "Removing Laravel site: $SITE_NAME"
    echo
    
    check_site_exists
    confirm_removal
    
    remove_nginx_config
    remove_website_files
    remove_database
    remove_logs
    
    echo
    print_status "SUCCESS" "Laravel site '$SITE_NAME' removed successfully!"
    
    if [[ "$KEEP_FILES" == true ]]; then
        echo
        print_status "INFO" "Website files were backed up to /tmp/${SITE_NAME}_backup_*"
    fi
    
    if [[ "$KEEP_DATABASE" == true ]]; then
        echo
        print_status "INFO" "Database '$SITE_NAME' and user were preserved"
    fi
    
    echo
}

# Run main function
main "$@"