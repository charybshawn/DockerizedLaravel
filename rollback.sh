#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[1;36m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Help message
show_help() {
    echo -e "${BLUE}Laravel Development Environment Rollback${NC}"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help                 Show this help message"
    echo "  -d, --db-system           Database system to remove (mysql, postgres, sqlite)"
    echo "  -v, --php-versions        PHP versions to remove (space-separated, e.g., '8.1 8.2 8.3')"
    echo "  -a, --adminer             Remove Adminer (yes/no)"
    echo "  -s, --sample-sites        Remove sample sites (yes/no)"
    echo "  -V, --verbose             Show detailed output"
    echo ""
    echo "Example:"
    echo "  $0 -d mysql -v '8.1 8.2' -a yes -s yes"
}

# Default values
DB_SYSTEM="mysql"
PHP_VERSIONS="8.1"
REMOVE_ADMINER="yes"
REMOVE_SAMPLES="yes"
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--db-system)
            DB_SYSTEM="$2"
            shift 2
            ;;
        -v|--php-versions)
            PHP_VERSIONS="$2"
            shift 2
            ;;
        -a|--adminer)
            REMOVE_ADMINER="$2"
            shift 2
            ;;
        -s|--sample-sites)
            REMOVE_SAMPLES="$2"
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

# Validate database system choice
if [[ ! "$DB_SYSTEM" =~ ^(mysql|postgres|sqlite)$ ]]; then
    echo -e "${RED}Error: Invalid database system. Choose from: mysql, postgres, sqlite${NC}"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run this script as root or with sudo${NC}"
    exit 1
fi

echo -e "${BLUE}Starting rollback of Laravel development environment...${NC}"

# Function to check if a service exists
service_exists() {
    systemctl list-unit-files | grep -q "$1"
}

# Function to check if a package is installed
package_exists() {
    dpkg -l | grep -q "^ii  $1 "
}

# Stop and remove services
echo -e "${BLUE}Stopping services...${NC}"

# Stop Nginx
if service_exists nginx; then
    systemctl stop nginx
    systemctl disable nginx
fi

# Stop PHP-FPM services
for version in $PHP_VERSIONS; do
    if service_exists "php$version-fpm"; then
        systemctl stop "php$version-fpm"
        systemctl disable "php$version-fpm"
    fi
done

# Stop database services
if [ "$DB_SYSTEM" = "mysql" ] && service_exists mysql; then
    systemctl stop mysql
    systemctl disable mysql
elif [ "$DB_SYSTEM" = "postgres" ] && service_exists postgresql; then
    systemctl stop postgresql
    systemctl disable postgresql
fi

# Remove packages
echo -e "${BLUE}Removing packages...${NC}"

# Remove Nginx
if package_exists nginx; then
    apt-get remove -y nginx nginx-common nginx-full
    apt-get autoremove -y
fi

# Remove PHP versions
for version in $PHP_VERSIONS; do
    if package_exists "php$version"; then
        apt-get remove -y "php$version" "php$version-fpm" "php$version-cli" "php$version-common" \
            "php$version-mysql" "php$version-pgsql" "php$version-mbstring" "php$version-xml" \
            "php$version-curl" "php$version-zip" "php$version-gd" "php$version-intl" \
            "php$version-bcmath" "php$version-soap" "php$version-xdebug" "php$version-redis"
    fi
done

# Remove database systems
if [ "$DB_SYSTEM" = "mysql" ]; then
    if package_exists mysql-server; then
        apt-get remove -y mysql-server mysql-client
        apt-get autoremove -y
    fi
elif [ "$DB_SYSTEM" = "postgres" ]; then
    if package_exists postgresql; then
        apt-get remove -y postgresql postgresql-contrib
        apt-get autoremove -y
    fi
elif [ "$DB_SYSTEM" = "sqlite" ]; then
    if package_exists sqlite3; then
        apt-get remove -y sqlite3
        apt-get autoremove -y
    fi
fi

# Remove Adminer
if [ "$REMOVE_ADMINER" = "yes" ]; then
    echo -e "${BLUE}Removing Adminer...${NC}"
    rm -rf /var/www/adminer
    rm -f /etc/nginx/sites-available/adminer
    rm -f /etc/nginx/sites-enabled/adminer
    rm -f /etc/nginx/.htpasswd_adminer
fi

# Remove sample sites
if [ "$REMOVE_SAMPLES" = "yes" ]; then
    echo -e "${BLUE}Removing sample sites...${NC}"
    # Find all Laravel sites in /var/www
    for site in /var/www/*; do
        if [ -d "$site" ] && [ -f "$site/artisan" ]; then
            echo "Removing site: $site"
            rm -rf "$site"
            site_name=$(basename "$site")
            rm -f "/etc/nginx/sites-available/$site_name"
            rm -f "/etc/nginx/sites-enabled/$site_name"
        fi
    done
fi

# Clean up configuration files
echo -e "${BLUE}Cleaning up configuration files...${NC}"
rm -rf /etc/php
rm -rf /etc/nginx/sites-enabled/*
rm -rf /etc/nginx/sites-available/*
rm -f /etc/nginx/conf.d/*

# Remove PHP repository
if [ -f /etc/apt/sources.list.d/ondrej-ubuntu-php-*.list ]; then
    add-apt-repository --remove ppa:ondrej/php -y
fi

# Clean up hosts file entries
echo -e "${BLUE}Cleaning up hosts file...${NC}"
sed -i '/\.local$/d' /etc/hosts

# Clean up Composer
if [ -f /usr/local/bin/composer ]; then
    echo -e "${BLUE}Removing Composer...${NC}"
    rm -f /usr/local/bin/composer
fi

# Clean up Node.js
if package_exists nodejs; then
    echo -e "${BLUE}Removing Node.js...${NC}"
    apt-get remove -y nodejs npm
    apt-get autoremove -y
    # Remove NodeSource repository
    if [ -f /etc/apt/sources.list.d/nodesource.list ]; then
        rm -f /etc/apt/sources.list.d/nodesource.list
    fi
fi

# Update package lists
apt-get update

echo -e "${GREEN}Rollback completed successfully!${NC}"

if [ "$VERBOSE" = true ]; then
    echo -e "${BLUE}Summary of removed components:${NC}"
    echo "===================================================="
    echo "🔧 Services:"
    echo "  - Nginx"
    for version in $PHP_VERSIONS; do
        echo "  - PHP $version-FPM"
    done
    if [ "$DB_SYSTEM" = "mysql" ]; then
        echo "  - MySQL"
    elif [ "$DB_SYSTEM" = "postgres" ]; then
        echo "  - PostgreSQL"
    elif [ "$DB_SYSTEM" = "sqlite" ]; then
        echo "  - SQLite"
    fi
    echo ""
    echo "📦 Packages:"
    echo "  - Nginx and related packages"
    for version in $PHP_VERSIONS; do
        echo "  - PHP $version and extensions"
    done
    if [ "$DB_SYSTEM" = "mysql" ]; then
        echo "  - MySQL Server and Client"
    elif [ "$DB_SYSTEM" = "postgres" ]; then
        echo "  - PostgreSQL and contrib"
    elif [ "$DB_SYSTEM" = "sqlite" ]; then
        echo "  - SQLite3"
    fi
    echo "  - Node.js and npm"
    echo "  - Composer"
    echo ""
    if [ "$REMOVE_ADMINER" = "yes" ]; then
        echo "🗄️ Database Management:"
        echo "  - Adminer installation"
    fi
    if [ "$REMOVE_SAMPLES" = "yes" ]; then
        echo "🚀 Sample Sites:"
        echo "  - All Laravel sample sites"
    fi
    echo "===================================================="
fi 