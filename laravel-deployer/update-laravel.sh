#!/bin/bash

# Laravel Site Update Tool
# Updates deployed Laravel sites with latest code from GitHub

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SITE_NAME=""
VERBOSE=false
BRANCH="main"

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
Laravel Site Update Tool

Usage: $0 [OPTIONS] SITE_NAME

Arguments:
    SITE_NAME                  Name of the site to update (directory under /var/www/)

Options:
    --branch BRANCH            Git branch to pull (default: main)
    --verbose                  Show detailed output
    --help                     Show this help message

Examples:
    $0 myapp                   # Update myapp site from main branch
    $0 myapp --branch develop  # Update from develop branch
    $0 myapp --verbose         # Update with detailed output

Update Process:
    1. Pull latest code from GitHub
    2. Install/update Composer dependencies
    3. Run database migrations
    4. Clear and rebuild Laravel caches

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$SITE_NAME" ]]; then
                SITE_NAME="$1"
            else
                echo "Too many arguments"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [[ -z "$SITE_NAME" ]]; then
    print_status "ERROR" "Site name is required"
    show_help
    exit 1
fi

# Check root privileges
check_privileges() {
    if [[ $EUID -ne 0 ]]; then
        print_status "ERROR" "This script must be run as root or with sudo"
        exit 1
    fi
}

# Check if site exists
check_site_exists() {
    if [[ ! -d "/var/www/$SITE_NAME" ]]; then
        print_status "ERROR" "Site directory '/var/www/$SITE_NAME' does not exist"
        exit 1
    fi
    
    if [[ ! -d "/var/www/$SITE_NAME/.git" ]]; then
        print_status "ERROR" "Site '$SITE_NAME' is not a git repository"
        print_status "INFO" "This script only works with sites deployed using the simplified git structure"
        exit 1
    fi
    
    print_status "SUCCESS" "Site '$SITE_NAME' found"
}

# Update git repository
update_repository() {
    print_status "INFO" "Updating repository from origin/$BRANCH..."
    
    cd "/var/www/$SITE_NAME"
    
    # Stash any local changes (just in case)
    if sudo -u www-data git status --porcelain | grep -q .; then
        print_status "WARN" "Local changes detected, stashing them"
        sudo -u www-data git stash push -m "Auto-stash before update $(date)"
    fi
    
    # Fetch and pull latest changes
    sudo -u www-data git fetch origin || {
        print_status "ERROR" "Failed to fetch from origin"
        exit 1
    }
    
    sudo -u www-data git pull origin "$BRANCH" || {
        print_status "ERROR" "Failed to pull from origin/$BRANCH"
        exit 1
    }
    
    print_status "SUCCESS" "Repository updated"
}

# Update composer dependencies
update_dependencies() {
    print_status "INFO" "Updating Composer dependencies..."
    
    cd "/var/www/$SITE_NAME"
    
    if [[ ! -f "composer.json" ]]; then
        print_status "WARN" "No composer.json found, skipping dependency update"
        return 0
    fi
    
    local composer_output
    local composer_exit_code
    
    set +e  # Temporarily disable exit on error
    composer_output=$(sudo -u www-data composer install --no-dev --optimize-autoloader --no-interaction 2>&1)
    composer_exit_code=$?
    set -e  # Re-enable exit on error
    
    if [[ $composer_exit_code -eq 0 ]]; then
        print_status "SUCCESS" "Dependencies updated successfully"
    else
        print_status "ERROR" "Composer update failed:"
        echo "$composer_output"
        exit 1
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        print_status "INFO" "Composer output:"
        echo "$composer_output"
    fi
}

# Run database migrations
run_migrations() {
    print_status "INFO" "Running database migrations..."
    
    cd "/var/www/$SITE_NAME"
    
    if [[ ! -f "artisan" ]]; then
        print_status "WARN" "No artisan file found, skipping migrations"
        return 0
    fi
    
    local migration_output
    local migration_exit_code
    
    set +e  # Temporarily disable exit on error
    migration_output=$(sudo -u www-data php artisan migrate --force 2>&1)
    migration_exit_code=$?
    set -e  # Re-enable exit on error
    
    if [[ $migration_exit_code -eq 0 ]]; then
        print_status "SUCCESS" "Migrations completed"
    else
        print_status "WARN" "Migration failed (this may be normal if no new migrations):"
        if [[ "$VERBOSE" == true ]]; then
            echo "$migration_output"
        fi
    fi
}

# Clear and rebuild caches
update_caches() {
    print_status "INFO" "Clearing and rebuilding Laravel caches..."
    
    cd "/var/www/$SITE_NAME"
    
    if [[ ! -f "artisan" ]]; then
        print_status "WARN" "No artisan file found, skipping cache operations"
        return 0
    fi
    
    # Clear and rebuild caches
    sudo -u www-data php artisan config:cache || print_status "WARN" "Config cache failed"
    sudo -u www-data php artisan route:cache 2>/dev/null || print_status "WARN" "Route cache failed (may not have routes)"
    sudo -u www-data php artisan view:cache || print_status "WARN" "View cache failed"
    
    print_status "SUCCESS" "Caches updated"
}

# Build frontend assets if needed
build_assets() {
    cd "/var/www/$SITE_NAME"
    
    # Check if package.json exists and has build script
    if [[ -f "package.json" ]] && command -v npm >/dev/null 2>&1; then
        if npm run --silent 2>/dev/null | grep -q "build"; then
            print_status "INFO" "Building frontend assets..."
            
            # Install npm dependencies
            sudo -u www-data npm install --production 2>/dev/null || {
                print_status "WARN" "npm install failed"
                return 0
            }
            
            # Build assets
            if sudo -u www-data npm run build 2>/dev/null; then
                print_status "SUCCESS" "Frontend assets built"
            else
                print_status "WARN" "npm run build failed"
            fi
        fi
    fi
}

# Main execution
main() {
    echo "==============================================="
    echo "Laravel Site Update Tool"
    echo "==============================================="
    echo
    
    check_privileges
    check_site_exists
    
    print_status "INFO" "Updating Laravel site: $SITE_NAME"
    print_status "INFO" "Branch: $BRANCH"
    echo
    
    update_repository
    update_dependencies
    run_migrations
    update_caches
    build_assets
    
    echo
    print_status "SUCCESS" "Laravel site '$SITE_NAME' updated successfully!"
    echo
    echo "Site Details:"
    echo "  Directory: /var/www/$SITE_NAME"
    echo "  Branch: $BRANCH"
    echo "  Last Commit: $(cd "/var/www/$SITE_NAME" && git log -1 --format="%h - %s (%cr)" 2>/dev/null || echo "Unable to retrieve")"
    echo
}

# Run main function
main "$@"