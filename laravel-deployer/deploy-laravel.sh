#!/bin/bash

# Laravel Site Deployment Tool
# Automatically deploys Laravel sites with Nginx configuration and GitHub integration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SITE_NAME=""
DOMAIN=""
GITHUB_REPO=""
GITHUB_BRANCH="main"
DATABASE_NAME=""
DATABASE_USER=""
DATABASE_PASSWORD=""
VERBOSE=false
FORCE=false
SSL_ENABLED=false
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
Laravel Site Deployment Tool

Usage: $0 [OPTIONS]

Interactive Mode (default):
    $0                         Run with interactive prompts

Non-Interactive Mode:
    --site-name NAME           Site name (used for directories and configs)
    --domain DOMAIN            Domain name for the site
    --github-repo URL          GitHub repository URL
    --branch BRANCH            Git branch to deploy (default: main)
    --database-name NAME       Database name (default: site_name)
    --database-user USER       Database user (default: site_name)
    --database-password PASS   Database password
    --ssl                      Enable SSL/HTTPS configuration
    --force                    Overwrite existing site
    --verbose                  Show detailed output
    --help                     Show this help message

Examples:
    $0                         # Interactive mode
    $0 --site-name myapp --domain myapp.local --github-repo https://github.com/user/myapp.git

Directory Structure:
    /var/www/SITE_NAME/         - Site root directory
    /var/www/SITE_NAME/current  - Current deployment (symlink)
    /var/www/SITE_NAME/releases - Release history
    /var/www/SITE_NAME/shared   - Shared files (.env, storage)

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
        --domain)
            DOMAIN="$2"
            INTERACTIVE=false
            shift 2
            ;;
        --github-repo)
            GITHUB_REPO="$2"
            INTERACTIVE=false
            shift 2
            ;;
        --branch)
            GITHUB_BRANCH="$2"
            shift 2
            ;;
        --database-name)
            DATABASE_NAME="$2"
            shift 2
            ;;
        --database-user)
            DATABASE_USER="$2"
            shift 2
            ;;
        --database-password)
            DATABASE_PASSWORD="$2"
            shift 2
            ;;
        --ssl)
            SSL_ENABLED=true
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
    print_status "INFO" "Laravel Site Deployment Configuration"
    echo
    
    # Site name
    while [[ -z "$SITE_NAME" ]]; do
        read -p "Site name (alphanumeric and underscores only): " SITE_NAME
        if [[ ! "$SITE_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
            print_status "ERROR" "Site name must contain only letters, numbers, and underscores"
            SITE_NAME=""
        elif [[ -d "/var/www/$SITE_NAME" && "$FORCE" != true ]]; then
            print_status "ERROR" "Site '$SITE_NAME' already exists"
            read -p "Overwrite existing site? [y/N]: " overwrite
            if [[ "$overwrite" =~ ^[Yy]$ ]]; then
                FORCE=true
            else
                SITE_NAME=""
            fi
        fi
    done
    
    # Domain
    while [[ -z "$DOMAIN" ]]; do
        read -p "Domain name (e.g., myapp.com): " DOMAIN
        if [[ -z "$DOMAIN" ]]; then
            print_status "WARN" "Domain cannot be empty"
        fi
    done
    
    # GitHub repository
    while [[ -z "$GITHUB_REPO" ]]; do
        read -p "GitHub repository URL: " GITHUB_REPO
        if [[ -z "$GITHUB_REPO" ]]; then
            print_status "WARN" "Repository URL cannot be empty"
        fi
    done
    
    # Git branch
    read -p "Git branch (default: main): " input
    if [[ -n "$input" ]]; then
        GITHUB_BRANCH="$input"
    fi
    
    # SSL configuration
    read -p "Enable SSL/HTTPS? [y/N]: " ssl_choice
    if [[ "$ssl_choice" =~ ^[Yy]$ ]]; then
        SSL_ENABLED=true
    fi
    
    # Database configuration
    echo
    print_status "INFO" "Database Configuration"
    
    read -p "Database name (default: $SITE_NAME): " input
    DATABASE_NAME="${input:-$SITE_NAME}"
    
    read -p "Database user (default: $SITE_NAME): " input
    DATABASE_USER="${input:-$SITE_NAME}"
    
    # Verbose output
    read -p "Show verbose output? [y/N]: " verbose_choice
    if [[ "$verbose_choice" =~ ^[Yy]$ ]]; then
        VERBOSE=true
    fi
}

# Validate required arguments (for non-interactive mode)
validate_arguments() {
    if [[ "$INTERACTIVE" != true ]]; then
        if [[ -z "$SITE_NAME" || -z "$DOMAIN" || -z "$GITHUB_REPO" ]]; then
            print_status "ERROR" "Missing required arguments for non-interactive mode"
            show_help
            exit 1
        fi
    fi
    
    # Set defaults
    [[ -z "$DATABASE_NAME" ]] && DATABASE_NAME="$SITE_NAME"
    [[ -z "$DATABASE_USER" ]] && DATABASE_USER="$SITE_NAME"
}

# Validate site name (alphanumeric and underscores only)
validate_site_name() {
    if [[ -n "$SITE_NAME" && ! "$SITE_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
        print_status "ERROR" "Site name must contain only letters, numbers, and underscores"
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

# Check if required packages are installed
check_dependencies() {
    local missing_deps=()
    
    command -v php >/dev/null 2>&1 || missing_deps+=("php")
    command -v composer >/dev/null 2>&1 || missing_deps+=("composer")
    command -v nginx >/dev/null 2>&1 || missing_deps+=("nginx")
    command -v git >/dev/null 2>&1 || missing_deps+=("git")
    
    # Check if MySQL/MariaDB service is available (don't require client)
    if ! systemctl is-active --quiet mariadb 2>/dev/null && ! systemctl is-active --quiet mysql 2>/dev/null; then
        missing_deps+=("mysql/mariadb service")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_status "ERROR" "Missing dependencies: ${missing_deps[*]}"
        print_status "INFO" "Please install the LEMP stack first using the lemp-deployer"
        exit 1
    fi
    
    print_status "SUCCESS" "All dependencies found"
}

# Check if site already exists (for non-interactive mode)
check_existing_site() {
    # Skip check in interactive mode since it's already handled in get_user_input
    if [[ "$INTERACTIVE" == true ]]; then
        return
    fi
    
    if [[ -d "/var/www/$SITE_NAME" && "$FORCE" != true ]]; then
        print_status "ERROR" "Site '$SITE_NAME' already exists. Use --force to overwrite"
        exit 1
    fi
    
    if [[ -f "/etc/nginx/sites-available/$SITE_NAME" && "$FORCE" != true ]]; then
        print_status "ERROR" "Nginx config for '$SITE_NAME' already exists. Use --force to overwrite"
        exit 1
    fi
}

# Get database password if not provided
get_database_password() {
    if [[ -z "$DATABASE_PASSWORD" ]]; then
        while [[ -z "$DATABASE_PASSWORD" ]]; do
            echo
            read -s -p "Enter database password for user '$DATABASE_USER': " DATABASE_PASSWORD
            echo
            if [[ -z "$DATABASE_PASSWORD" ]]; then
                print_status "WARN" "Password cannot be empty"
            fi
        done
    fi
}

# Create database and user
create_database() {
    print_status "INFO" "Creating database '$DATABASE_NAME' and user '$DATABASE_USER'..."
    
    # Try different MySQL command variations
    local mysql_cmd=""
    if command -v mysql >/dev/null 2>&1; then
        mysql_cmd="mysql"
    elif command -v mariadb >/dev/null 2>&1; then
        mysql_cmd="mariadb"
    else
        # Install mysql client if not available
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y mysql-client >/dev/null 2>&1 || {
            print_status "ERROR" "Cannot install MySQL client"
            exit 1
        }
        mysql_cmd="mysql"
    fi
    
    $mysql_cmd -e "CREATE DATABASE IF NOT EXISTS \`$DATABASE_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null || {
        print_status "ERROR" "Failed to create database - check MySQL root access"
        exit 1
    }
    
    $mysql_cmd -e "CREATE USER IF NOT EXISTS '$DATABASE_USER'@'localhost' IDENTIFIED BY '$DATABASE_PASSWORD';" 2>/dev/null || {
        print_status "ERROR" "Failed to create database user"
        exit 1
    }
    
    $mysql_cmd -e "GRANT ALL PRIVILEGES ON \`$DATABASE_NAME\`.* TO '$DATABASE_USER'@'localhost';" 2>/dev/null || {
        print_status "ERROR" "Failed to grant database privileges"
        exit 1
    }
    
    $mysql_cmd -e "FLUSH PRIVILEGES;" 2>/dev/null || {
        print_status "ERROR" "Failed to flush privileges"
        exit 1
    }
    
    print_status "SUCCESS" "Database created successfully"
}

# Create directory structure
create_directories() {
    print_status "INFO" "Creating directory structure..."
    
    [[ "$FORCE" == true ]] && rm -rf "/var/www/$SITE_NAME"
    
    mkdir -p "/var/www/$SITE_NAME"/{releases,shared,shared/storage}
    
    # Create shared directories that Laravel needs
    mkdir -p "/var/www/$SITE_NAME/shared/storage"/{app,framework,logs}
    mkdir -p "/var/www/$SITE_NAME/shared/storage/framework"/{cache,sessions,views}
    mkdir -p "/var/www/$SITE_NAME/shared/storage/app/public"
    
    chown -R www-data:www-data "/var/www/$SITE_NAME"
    print_status "SUCCESS" "Directory structure created"
}

# Clone repository
clone_repository() {
    print_status "INFO" "Cloning repository from $GITHUB_REPO..."
    
    local release_dir="/var/www/$SITE_NAME/releases/$(date +%Y%m%d_%H%M%S)"
    
    git clone --branch "$GITHUB_BRANCH" --depth 1 "$GITHUB_REPO" "$release_dir" || {
        print_status "ERROR" "Failed to clone repository"
        exit 1
    }
    
    # Remove .git directory to save space
    rm -rf "$release_dir/.git"
    
    chown -R www-data:www-data "$release_dir"
    print_status "SUCCESS" "Repository cloned to $release_dir"
    
    echo "$release_dir" > "/tmp/current_release"
}

# Install dependencies
install_dependencies() {
    local release_dir=$(cat /tmp/current_release)
    print_status "INFO" "Installing Composer dependencies..."
    
    cd "$release_dir"
    
    # Install dependencies as www-data user
    sudo -u www-data composer install --no-dev --optimize-autoloader --no-interaction || {
        print_status "ERROR" "Failed to install Composer dependencies"
        exit 1
    }
    
    print_status "SUCCESS" "Dependencies installed"
}

# Configure Laravel environment
configure_laravel() {
    local release_dir=$(cat /tmp/current_release)
    print_status "INFO" "Configuring Laravel environment..."
    
    cd "$release_dir"
    
    # Create .env file if it doesn't exist in shared
    if [[ ! -f "/var/www/$SITE_NAME/shared/.env" ]]; then
        if [[ -f ".env.example" ]]; then
            cp ".env.example" "/var/www/$SITE_NAME/shared/.env"
        else
            cat > "/var/www/$SITE_NAME/shared/.env" << EOF
APP_NAME="$SITE_NAME"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=http://$DOMAIN

LOG_CHANNEL=stack
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=error

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=$DATABASE_NAME
DB_USERNAME=$DATABASE_USER
DB_PASSWORD=$DATABASE_PASSWORD

BROADCAST_DRIVER=log
CACHE_DRIVER=file
FILESYSTEM_DISK=local
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

MEMCACHED_HOST=127.0.0.1

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=mailpit
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="\${APP_NAME}"
EOF
        fi
        
        chown www-data:www-data "/var/www/$SITE_NAME/shared/.env"
    fi
    
    # Link .env file
    ln -sf "/var/www/$SITE_NAME/shared/.env" "$release_dir/.env"
    
    # Link storage directory
    rm -rf "$release_dir/storage"
    ln -sf "/var/www/$SITE_NAME/shared/storage" "$release_dir/storage"
    
    # Generate application key if needed
    if ! grep -q "APP_KEY=base64:" "/var/www/$SITE_NAME/shared/.env"; then
        sudo -u www-data php artisan key:generate --force
    fi
    
    # Create storage link
    sudo -u www-data php artisan storage:link --force 2>/dev/null || true
    
    # Run migrations
    sudo -u www-data php artisan migrate --force || {
        print_status "WARN" "Database migrations failed - you may need to run them manually"
    }
    
    # Clear and cache config
    sudo -u www-data php artisan config:cache
    sudo -u www-data php artisan route:cache 2>/dev/null || true
    sudo -u www-data php artisan view:cache
    
    print_status "SUCCESS" "Laravel configured"
}

# Create symlink to current release
create_symlink() {
    local release_dir=$(cat /tmp/current_release)
    print_status "INFO" "Creating symlink to current release..."
    
    # Remove old current symlink
    rm -f "/var/www/$SITE_NAME/current"
    
    # Create new symlink
    ln -sf "$release_dir" "/var/www/$SITE_NAME/current"
    
    print_status "SUCCESS" "Symlink created"
}

# Configure Nginx
configure_nginx() {
    print_status "INFO" "Configuring Nginx for $DOMAIN..."
    
    local nginx_config="/etc/nginx/sites-available/$SITE_NAME"
    local ssl_config=""
    
    if [[ "$SSL_ENABLED" == true ]]; then
        ssl_config="
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    
    ssl_certificate /etc/ssl/certs/$DOMAIN.crt;
    ssl_certificate_key /etc/ssl/private/$DOMAIN.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # Redirect HTTP to HTTPS
    if (\$scheme != \"https\") {
        return 301 https://\$server_name\$request_uri;
    }"
    else
        ssl_config="
    listen 80;
    listen [::]:80;"
    fi
    
    cat > "$nginx_config" << EOF
server {
$ssl_config
    
    server_name $DOMAIN;
    root /var/www/$SITE_NAME/current/public;
    index index.php index.html index.htm;
    
    access_log /var/log/nginx/${SITE_NAME}_access.log;
    error_log /var/log/nginx/${SITE_NAME}_error.log;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Laravel specific configuration
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }
    
    # Handle PHP files
    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }
    
    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private no_last_modified no_etag auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/javascript application/json;
    
    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|txt)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
    
    # Enable the site
    ln -sf "$nginx_config" "/etc/nginx/sites-enabled/$SITE_NAME"
    
    # Test nginx configuration
    nginx -t || {
        print_status "ERROR" "Nginx configuration test failed"
        exit 1
    }
    
    # Reload nginx
    systemctl reload nginx
    
    print_status "SUCCESS" "Nginx configured for $DOMAIN"
}

# Set proper permissions
set_permissions() {
    print_status "INFO" "Setting proper file permissions..."
    
    chown -R www-data:www-data "/var/www/$SITE_NAME"
    find "/var/www/$SITE_NAME" -type f -exec chmod 644 {} \;
    find "/var/www/$SITE_NAME" -type d -exec chmod 755 {} \;
    
    # Make storage and cache writable
    chmod -R 775 "/var/www/$SITE_NAME/shared/storage"
    
    print_status "SUCCESS" "Permissions set"
}

# Cleanup old releases (keep last 5)
cleanup_releases() {
    print_status "INFO" "Cleaning up old releases..."
    
    cd "/var/www/$SITE_NAME/releases"
    ls -t | tail -n +6 | xargs -r rm -rf
    
    print_status "SUCCESS" "Old releases cleaned up"
}

# Main execution
main() {
    echo "==============================================="
    echo "Laravel Site Deployment Tool"
    echo "==============================================="
    echo
    
    check_privileges
    echo "DEBUG: Passed check_privileges"
    check_dependencies
    echo "DEBUG: Passed check_dependencies"
    
    # Get user input (interactive or validate flags)
    get_user_input
    echo "DEBUG: Passed get_user_input"
    validate_arguments
    echo "DEBUG: Passed validate_arguments"
    validate_site_name
    echo "DEBUG: Passed validate_site_name"
    
    # Display configuration
    print_status "INFO" "Deploying Laravel site: $SITE_NAME"
    print_status "INFO" "Domain: $DOMAIN"
    print_status "INFO" "Repository: $GITHUB_REPO"
    print_status "INFO" "Branch: $GITHUB_BRANCH"
    echo
    
    check_existing_site
    get_database_password
    
    create_database
    create_directories
    clone_repository
    install_dependencies
    configure_laravel
    create_symlink
    configure_nginx
    set_permissions
    cleanup_releases
    
    echo
    print_status "SUCCESS" "Laravel site '$SITE_NAME' deployed successfully!"
    echo
    echo "Site Details:"
    echo "  URL: http://$DOMAIN"
    echo "  Document Root: /var/www/$SITE_NAME/current/public"
    echo "  Database: $DATABASE_NAME"
    echo "  Logs: /var/log/nginx/${SITE_NAME}_*.log"
    echo
    echo "Next Steps:"
    echo "  1. Configure your DNS to point $DOMAIN to this server"
    echo "  2. Review and update .env file: /var/www/$SITE_NAME/shared/.env"
    if [[ "$SSL_ENABLED" == true ]]; then
        echo "  3. Install SSL certificates at:"
        echo "     - /etc/ssl/certs/$DOMAIN.crt"
        echo "     - /etc/ssl/private/$DOMAIN.key"
    else
        echo "  3. Consider enabling SSL with --ssl flag for production"
    fi
    echo "  4. Run additional Laravel commands as needed:"
    echo "     cd /var/www/$SITE_NAME/current && sudo -u www-data php artisan ..."
    echo
}

# Cleanup on exit
cleanup() {
    rm -f /tmp/current_release
}
trap cleanup EXIT

# Run main function
main "$@"