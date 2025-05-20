#!/bin/bash
# Script to set up a new Laravel site

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or with sudo"
    exit 1
fi

# Get site details
read -p "Enter site name (e.g., myproject): " SITE_NAME
read -p "Enter domain name [$SITE_NAME.local]: " DOMAIN_NAME
DOMAIN_NAME=${DOMAIN_NAME:-$SITE_NAME.local}

read -p "Use Git repository? (y/n): " USE_GIT
if [[ $USE_GIT == "y" ]]; then
    read -p "Enter Git repository URL: " GIT_REPO
    read -p "Enter Git branch [main]: " GIT_BRANCH
    GIT_BRANCH=${GIT_BRANCH:-main}
fi

read -p "Database type (mysql/pgsql) [mysql]: " DB_TYPE
DB_TYPE=${DB_TYPE:-mysql}
read -p "Database name [$SITE_NAME]: " DB_NAME
DB_NAME=${DB_NAME:-$SITE_NAME}
read -p "Database username [root]: " DB_USER
DB_USER=${DB_USER:-root}
read -s -p "Database password: " DB_PASS
echo ""

read -p "Run migrations after setup? (y/n) [n]: " RUN_MIGRATIONS
RUN_MIGRATIONS=${RUN_MIGRATIONS:-n}

read -p "Install NPM dependencies? (y/n) [n]: " INSTALL_NPM
INSTALL_NPM=${INSTALL_NPM:-n}

read -p "Compile assets? (y/n) [n]: " COMPILE_ASSETS
COMPILE_ASSETS=${COMPILE_ASSETS:-n}

# Create site configuration file
CONFIG_FILE="site_config.yml"

echo "---" > $CONFIG_FILE
echo "laravel_sites:" >> $CONFIG_FILE
echo "  - name: $SITE_NAME" >> $CONFIG_FILE
echo "    domain: $DOMAIN_NAME" >> $CONFIG_FILE

if [[ $USE_GIT == "y" ]]; then
    echo "    git_repo: $GIT_REPO" >> $CONFIG_FILE
    echo "    git_branch: $GIT_BRANCH" >> $CONFIG_FILE
fi

echo "    db_connection: $DB_TYPE" >> $CONFIG_FILE
echo "    db_database: $DB_NAME" >> $CONFIG_FILE
echo "    db_username: $DB_USER" >> $CONFIG_FILE
echo "    db_password: $DB_PASS" >> $CONFIG_FILE

if [[ $RUN_MIGRATIONS == "y" ]]; then
    echo "    run_migrations: true" >> $CONFIG_FILE
    echo "    seed_db: false" >> $CONFIG_FILE
fi

if [[ $INSTALL_NPM == "y" ]]; then
    echo "    install_npm_dependencies: true" >> $CONFIG_FILE
fi

if [[ $COMPILE_ASSETS == "y" ]]; then
    echo "    compile_assets: true" >> $CONFIG_FILE
    echo "    npm_command: dev" >> $CONFIG_FILE
fi

# Run the Ansible playbook with our configuration
echo "Setting up site $SITE_NAME..."
ansible-playbook playbooks/manage_laravel_sites.yml -i inventory/hosts.yml -e "@$CONFIG_FILE"

# Clean up
rm $CONFIG_FILE

echo ""
echo "✅ Site $SITE_NAME setup complete!"
echo "🌐 You can access your site at: http://$DOMAIN_NAME"
echo "" 