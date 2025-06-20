#!/bin/bash

# Laravel Sites Information Script
# Lists all configured Laravel sites with their details

set -euo pipefail

# Configuration
SITES_INFO_DIR="/var/lib/nginx/sites"
NGINX_SITES_DIR="/etc/nginx/sites-available"
SITES_ENABLED_DIR="/etc/nginx/sites-enabled"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print section headers
print_header() {
    echo
    print_color $BLUE "=================================================="
    print_color $BLUE "$1"
    print_color $BLUE "=================================================="
    echo
}

# Function to check if script is run as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_color $RED "❌ This script should be run as root (use sudo) for full functionality"
        print_color $YELLOW "⚠️  Some information may not be available"
        echo
    fi
}

# Function to get site status
get_site_status() {
    local site_name=$1
    local enabled_file="$SITES_ENABLED_DIR/$site_name"
    
    if [[ -L "$enabled_file" ]]; then
        echo "enabled"
    else
        echo "disabled"
    fi
}

# Function to get nginx status
get_nginx_status() {
    if systemctl is-active --quiet nginx; then
        echo "running"
    else
        echo "stopped"
    fi
}

# Function to test site configuration
test_site_config() {
    local site_name=$1
    if nginx -t -c "$NGINX_SITES_DIR/$site_name" 2>/dev/null; then
        echo "valid"
    else
        echo "invalid"
    fi
}

# Function to get PHP-FPM status
get_php_fpm_status() {
    local php_version=$1
    if systemctl is-active --quiet "php${php_version}-fpm"; then
        echo "running"
    else
        echo "stopped"
    fi
}

# Function to display site summary
display_site_summary() {
    local site_name=$1
    local info_file="$SITES_INFO_DIR/$site_name/status.env"
    local summary_file="$SITES_INFO_DIR/$site_name/summary.txt"
    
    print_color $CYAN "📋 Site: $site_name"
    echo "   ────────────────────────────"
    
    if [[ -f "$info_file" ]]; then
        source "$info_file"
        
        local site_status=$(get_site_status "$site_name")
        local config_status="unknown"
        if [[ -f "$NGINX_SITES_DIR/$site_name" ]]; then
            config_status=$(test_site_config "$site_name")
        fi
        
        # Display basic info
        echo "   🌐 Domain: $DOMAIN"
        echo "   🚪 Port: $PORT"
        echo "   📁 Root: $DOCUMENT_ROOT"
        echo "   ⚙️  PHP: $PHP_VERSION"
        
        # Display status indicators
        if [[ "$site_status" == "enabled" ]]; then
            print_color $GREEN "   ✅ Status: Enabled"
        else
            print_color $YELLOW "   ⚠️  Status: Disabled"
        fi
        
        if [[ "$config_status" == "valid" ]]; then
            print_color $GREEN "   ✅ Config: Valid"
        else
            print_color $RED "   ❌ Config: Invalid"
        fi
        
        # Check PHP-FPM status
        local php_fpm_status=$(get_php_fpm_status "$PHP_VERSION")
        if [[ "$php_fmp_status" == "running" ]]; then
            print_color $GREEN "   ✅ PHP-FPM: Running"
        else
            print_color $RED "   ❌ PHP-FPM: Stopped"
        fi
        
        # Git repository info
        if [[ -n "${GIT_REPO:-}" ]]; then
            echo "   📦 Git: $GIT_REPO ($GIT_BRANCH)"
        else
            echo "   📦 Git: Fresh Laravel installation"
        fi
        
        # URLs
        echo "   🔗 URL: http://$DOMAIN$([ "$PORT" != "80" ] && echo ":$PORT")/"
        echo "   🔗 Health: http://$DOMAIN$([ "$PORT" != "80" ] && echo ":$PORT")/health"
        
        # File paths
        echo "   📄 Config: $NGINX_CONFIG"
        echo "   📊 Summary: $summary_file"
        echo "   📈 Logs: $LOG_FILE, $ERROR_LOG"
        
    else
        print_color $RED "   ❌ No site information found"
        if [[ -f "$NGINX_SITES_DIR/$site_name" ]]; then
            echo "   📄 Config exists: $NGINX_SITES_DIR/$site_name"
            local site_status=$(get_site_status "$site_name")
            echo "   📊 Status: $site_status"
        fi
    fi
    
    echo
}

# Function to display overall system status
display_system_status() {
    print_header "System Status"
    
    # Nginx status
    local nginx_status=$(get_nginx_status)
    if [[ "$nginx_status" == "running" ]]; then
        print_color $GREEN "✅ Nginx: Running"
    else
        print_color $RED "❌ Nginx: Stopped"
    fi
    
    # Count sites
    local total_sites=0
    local enabled_sites=0
    
    if [[ -d "$NGINX_SITES_DIR" ]]; then
        for site_file in "$NGINX_SITES_DIR"/*; do
            if [[ -f "$site_file" ]]; then
                local site_name=$(basename "$site_file")
                # Skip default and status sites
                if [[ "$site_name" != "default" && "$site_name" != "status" ]]; then
                    ((total_sites++))
                    if [[ -L "$SITES_ENABLED_DIR/$site_name" ]]; then
                        ((enabled_sites++))
                    fi
                fi
            fi
        done
    fi
    
    print_color $CYAN "📊 Sites: $enabled_sites enabled / $total_sites total"
    
    # PHP versions
    echo
    print_color $CYAN "🐘 PHP Versions:"
    for php_service in /etc/systemd/system/multi-user.target.wants/php*-fpm.service; do
        if [[ -f "$php_service" ]]; then
            local php_version=$(basename "$php_service" | sed 's/php\([0-9.]*\)-fmp.service/\1/')
            local php_status=$(get_php_fpm_status "$php_version")
            if [[ "$php_status" == "running" ]]; then
                print_color $GREEN "   ✅ PHP $php_version: Running"
            else
                print_color $RED "   ❌ PHP $php_version: Stopped"
            fi
        fi
    done
}

# Function to display site list
display_site_list() {
    print_header "Laravel Sites Configuration"
    
    local sites_found=0
    
    # Check sites with info files
    if [[ -d "$SITES_INFO_DIR" ]]; then
        for site_dir in "$SITES_INFO_DIR"/*; do
            if [[ -d "$site_dir" ]]; then
                local site_name=$(basename "$site_dir")
                display_site_summary "$site_name"
                ((sites_found++))
            fi
        done
    fi
    
    # Check for nginx sites without info files
    if [[ -d "$NGINX_SITES_DIR" ]]; then
        for site_file in "$NGINX_SITES_DIR"/*; do
            if [[ -f "$site_file" ]]; then
                local site_name=$(basename "$site_file")
                # Skip default and status sites, and sites already shown
                if [[ "$site_name" != "default" && "$site_name" != "status" && ! -d "$SITES_INFO_DIR/$site_name" ]]; then
                    display_site_summary "$site_name"
                    ((sites_found++))
                fi
            fi
        done
    fi
    
    if [[ $sites_found -eq 0 ]]; then
        print_color $YELLOW "⚠️  No Laravel sites found"
        echo "   Use './setup-site.sh' to create a new site"
        echo "   Or run 'ansible-playbook playbooks/manage_laravel_sites.yml'"
    fi
}

# Function to show quick commands
display_quick_commands() {
    print_header "Quick Commands"
    
    echo "📋 Site Management:"
    echo "   List sites:           sudo $0"
    echo "   Create new site:      sudo ./setup-site.sh"
    echo "   Manage multiple:      ansible-playbook playbooks/manage_laravel_sites.yml"
    echo
    echo "🔧 Service Management:"
    echo "   Restart Nginx:        sudo systemctl restart nginx"
    echo "   Test Nginx config:    sudo nginx -t"
    echo "   Reload Nginx:         sudo systemctl reload nginx"
    echo "   PHP-FPM status:       sudo systemctl status php8.3-fpm"
    echo
    echo "📊 Monitoring:"
    echo "   View access logs:     sudo tail -f /var/log/nginx/*_access.log"
    echo "   View error logs:      sudo tail -f /var/log/nginx/*_error.log"
    echo "   Nginx status:         curl http://localhost/nginx_status"
    echo "   Health checks:        ansible-playbook --tags health playbooks/setup_laravel_server_improved.yml"
    echo
    echo "🗂️  Site Information:"
    echo "   Site summaries:       ls -la /var/lib/nginx/sites/*/summary.txt"
    echo "   Site configs:         ls -la /etc/nginx/sites-available/"
    echo "   Enabled sites:        ls -la /etc/nginx/sites-enabled/"
}

# Main function
main() {
    print_color $GREEN "🚀 Laravel Development Environment - Site Manager"
    print_color $GREEN "=================================================="
    
    check_root
    display_system_status
    display_site_list
    display_quick_commands
    
    print_color $GREEN "✨ Site listing complete!"
}

# Check for command line arguments
case "${1:-list}" in
    list|"")
        main
        ;;
    --help|-h)
        echo "Usage: $0 [list]"
        echo
        echo "This script lists all configured Laravel sites with their status and configuration details."
        echo
        echo "Options:"
        echo "  list, (default)  List all sites and system status"
        echo "  --help, -h       Show this help message"
        ;;
    *)
        print_color $RED "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac