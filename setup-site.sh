#!/bin/bash
# Script to create a new Laravel site
# Usage: ./setup-site.sh sitename [domain] [port] [git_repo] [git_branch] [php_version]

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[1;36m'  # Cyan (more visible on dark themes)
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root or with sudo${NC}"
  exit 1
fi

# Get site name
if [ -z "$1" ]; then
  echo -e "${RED}Error: Site name is required${NC}"
  echo "Usage: ./setup-site.sh sitename [domain] [port] [git_repo] [git_branch] [php_version]"
  exit 1
fi

SITE_NAME=$1

# Check if site directory already exists
SITE_DIR="/var/www/${SITE_NAME}"
if [ -d "$SITE_DIR" ]; then
  echo -e "${YELLOW}Warning: Site directory already exists at ${SITE_DIR}${NC}"
  read -p "Do you want to overwrite the existing site? This will delete all files in $SITE_DIR (y/n): " CONFIRM_OVERWRITE
  
  if [[ $CONFIRM_OVERWRITE != "y" && $CONFIRM_OVERWRITE != "Y" ]]; then
    echo -e "${BLUE}Setup cancelled. Existing site was not modified.${NC}"
    exit 0
  fi
  
  echo -e "${YELLOW}Removing existing site directory...${NC}"
  rm -rf "$SITE_DIR"
  
  # Also check if the database exists and prompt to drop it
  if [ -x "$(command -v mysql)" ]; then
    DB_EXISTS=$(mysql -e "SHOW DATABASES LIKE '${SITE_NAME}';" | grep "${SITE_NAME}" | wc -l)
    if [ "$DB_EXISTS" -eq 1 ]; then
      read -p "Database '${SITE_NAME}' also exists. Drop it? (y/n): " DROP_DB
      if [[ $DROP_DB == "y" || $DROP_DB == "Y" ]]; then
        echo -e "${YELLOW}Dropping database ${SITE_NAME}...${NC}"
        mysql -e "DROP DATABASE ${SITE_NAME};"
      fi
    fi
  fi
  
  # Check if Nginx config exists and remove it
  if [ -f "/etc/nginx/sites-available/${SITE_NAME}" ]; then
    echo -e "${YELLOW}Removing existing Nginx configuration...${NC}"
    rm -f "/etc/nginx/sites-available/${SITE_NAME}"
    if [ -L "/etc/nginx/sites-enabled/${SITE_NAME}" ]; then
      rm -f "/etc/nginx/sites-enabled/${SITE_NAME}"
    fi
  fi
fi

# Get domain (default to sitename.local)
if [ -z "$2" ]; then
  DOMAIN="${SITE_NAME}.local"
else
  DOMAIN=$2
fi

# Get port (default to 80)
if [ -z "$3" ]; then
  PORT="80"
else
  PORT=$3
fi

# Get Git repository (optional)
GIT_REPO=${4:-""}

# Check if using HTTPS or HTTP for GitHub
if [[ "$GIT_REPO" == *"github.com"* ]]; then
  echo -e "${YELLOW}Warning: Using GitHub repository URLs.${NC}"
  echo -e "${YELLOW}GitHub no longer supports password authentication for Git operations.${NC}"
  
  # Convert http to https if needed
  if [[ "$GIT_REPO" == "http://github.com"* ]]; then
    HTTPS_URL=$(echo "$GIT_REPO" | sed 's|http://github.com|https://github.com|')
    echo -e "${YELLOW}Converting HTTP GitHub URL to HTTPS: ${HTTPS_URL}${NC}"
    GIT_REPO=$HTTPS_URL
  fi
  
  echo -e "${YELLOW}If this is a private repository, consider using an SSH URL (git@github.com:username/repo.git) instead.${NC}"
  echo -e "${YELLOW}For public repositories, the script will attempt to clone using HTTPS.${NC}"
  echo ""
  
  # Ask if they want to continue or switch to SSH
  read -p "Do you want to continue with HTTPS URL? (y/n): " CONTINUE_HTTPS
  if [[ $CONTINUE_HTTPS != "y" && $CONTINUE_HTTPS != "Y" ]]; then
    SSH_URL=$(echo "$GIT_REPO" | sed 's|https://github.com/|git@github.com:|' | sed 's|\.git$|.git|')
    echo -e "${BLUE}Converting to SSH URL: ${SSH_URL}${NC}"
    GIT_REPO=$SSH_URL
  fi
fi

# Get Git branch (default to main if repo is provided)
GIT_BRANCH=${5:-"main"}

# Get PHP version (default to 8.1)
PHP_VERSION=${6:-"8.1"}

# List available PHP versions
echo -e "${BLUE}Checking available PHP versions on this server...${NC}"
AVAILABLE_PHP_VERSIONS=$(ls /etc/php/ 2>/dev/null | grep -E '^[0-9]+\.[0-9]+$' | sort -V)

if [ -z "$AVAILABLE_PHP_VERSIONS" ]; then
  echo -e "${RED}Error: No PHP versions found on this server.${NC}"
  exit 1
fi

echo -e "${BLUE}Available PHP versions:${NC}"
echo "$AVAILABLE_PHP_VERSIONS"

# Validate the selected PHP version
if ! echo "$AVAILABLE_PHP_VERSIONS" | grep -q "$PHP_VERSION"; then
  echo -e "${YELLOW}Warning: PHP $PHP_VERSION is not installed on this server.${NC}"
  echo -e "${YELLOW}Available versions: $AVAILABLE_PHP_VERSIONS${NC}"
  read -p "Do you want to continue with PHP $PHP_VERSION (not installed)? This will likely fail. (y/n): " CONTINUE_INVALID_PHP
  if [[ $CONTINUE_INVALID_PHP != "y" && $CONTINUE_INVALID_PHP != "Y" ]]; then
    echo -e "${BLUE}Please select from the available PHP versions:${NC}"
    select PHP_VERSION in $AVAILABLE_PHP_VERSIONS; do
      if [ -n "$PHP_VERSION" ]; then
        break
      else
        echo -e "${RED}Invalid selection. Please try again.${NC}"
      fi
    done
  fi
fi

# Check current PHP version
CURRENT_PHP_VERSION=$(php -r 'echo PHP_VERSION;')
CURRENT_PHP_MAJOR=$(echo $CURRENT_PHP_VERSION | cut -d. -f1)
CURRENT_PHP_MINOR=$(echo $CURRENT_PHP_VERSION | cut -d. -f2)

echo -e "${BLUE}Current default PHP version: ${CURRENT_PHP_VERSION}${NC}"
echo -e "${BLUE}Selected PHP version for this site: ${PHP_VERSION}${NC}"

# Database type - default to MySQL
DB_TYPE="mysql"
DB_NAME=$SITE_NAME
DB_USER="root"

# Special handling for git repository mode
SKIP_COMPOSER=false
FORCE_IGNORE_PHP_VERSION=false

if [ -n "$GIT_REPO" ]; then
  # Create a temporary directory to clone the repo first for inspection
  TEMP_DIR=$(mktemp -d)
  echo -e "${BLUE}Cloning repository to temporary location for inspection...${NC}"
  
  if git clone --depth 1 --branch $GIT_BRANCH $GIT_REPO $TEMP_DIR; then
    # Check PHP version requirement in composer.json
    if [ -f "$TEMP_DIR/composer.json" ]; then
      echo -e "${BLUE}Checking PHP version requirements...${NC}"
      REQUIRED_PHP=$(grep -o '"php"[^,]*' $TEMP_DIR/composer.json | grep -o '[0-9]\+\.[0-9]\+' | head -1)
      
      if [ -n "$REQUIRED_PHP" ]; then
        REQUIRED_PHP_MAJOR=$(echo $REQUIRED_PHP | cut -d. -f1)
        REQUIRED_PHP_MINOR=$(echo $REQUIRED_PHP | cut -d. -f2)
        
        echo -e "${BLUE}Project requires PHP ${REQUIRED_PHP}+${NC}"
        
        # Check if selected PHP version meets requirements
        SELECTED_PHP_MAJOR=$(echo $PHP_VERSION | cut -d. -f1)
        SELECTED_PHP_MINOR=$(echo $PHP_VERSION | cut -d. -f2)
        
        # Check if selected PHP version meets the requirements
        if [ "$SELECTED_PHP_MAJOR" -lt "$REQUIRED_PHP_MAJOR" ] || ([ "$SELECTED_PHP_MAJOR" -eq "$REQUIRED_PHP_MAJOR" ] && [ "$SELECTED_PHP_MINOR" -lt "$REQUIRED_PHP_MINOR" ]); then
          echo -e "${RED}Warning: Your selected PHP version ($PHP_VERSION) is lower than the required version (${REQUIRED_PHP}+).${NC}"
          echo -e "${YELLOW}The composer install step might fail due to version incompatibility.${NC}"
          
          # List PHP versions that meet the requirement
          COMPATIBLE_VERSIONS=""
          for ver in $AVAILABLE_PHP_VERSIONS; do
            VER_MAJOR=$(echo $ver | cut -d. -f1)
            VER_MINOR=$(echo $ver | cut -d. -f2)
            if [ "$VER_MAJOR" -gt "$REQUIRED_PHP_MAJOR" ] || ([ "$VER_MAJOR" -eq "$REQUIRED_PHP_MAJOR" ] && [ "$VER_MINOR" -ge "$REQUIRED_PHP_MINOR" ]); then
              COMPATIBLE_VERSIONS="$COMPATIBLE_VERSIONS $ver"
            fi
          done
          
          if [ -n "$COMPATIBLE_VERSIONS" ]; then
            echo -e "${GREEN}Compatible PHP versions installed on this server:${GREEN} $COMPATIBLE_VERSIONS"
            echo -e "${YELLOW}Would you like to use one of these versions instead?${NC}"
            read -p "Switch to a compatible version? (y/n): " SWITCH_VERSION
            if [[ $SWITCH_VERSION == "y" || $SWITCH_VERSION == "Y" ]]; then
              select PHP_VERSION in $COMPATIBLE_VERSIONS; do
                if [ -n "$PHP_VERSION" ]; then
                  echo -e "${GREEN}Switching to PHP $PHP_VERSION${NC}"
                  break
                else
                  echo -e "${RED}Invalid selection. Please try again.${NC}"
                fi
              done
            else
              # Offer options
              echo ""
              echo "Options:"
              echo "1. Continue anyway (might fail)"
              echo "2. Skip the composer install step (you'll need to handle dependencies manually)"
              echo "3. Abort installation"
              
              read -p "Choose an option (1-3): " PHP_VERSION_OPTION
              
              case $PHP_VERSION_OPTION in
                1)
                  echo -e "${YELLOW}Continuing with installation attempt...${NC}"
                  FORCE_IGNORE_PHP_VERSION=true
                  ;;
                2)
                  echo -e "${YELLOW}Will skip composer install step...${NC}"
                  SKIP_COMPOSER=true
                  ;;
                3)
                  echo -e "${BLUE}Installation aborted.${NC}"
                  rm -rf $TEMP_DIR
                  exit 0
                  ;;
                *)
                  echo -e "${RED}Invalid option. Aborting installation.${NC}"
                  rm -rf $TEMP_DIR
                  exit 1
                  ;;
              esac
            fi
          else
            echo -e "${RED}No compatible PHP versions found on this server.${NC}"
            echo "Options:"
            echo "1. Continue anyway (might fail)"
            echo "2. Skip the composer install step (you'll need to handle dependencies manually)"
            echo "3. Abort installation"
            
            read -p "Choose an option (1-3): " PHP_VERSION_OPTION
            
            case $PHP_VERSION_OPTION in
              1)
                echo -e "${YELLOW}Continuing with installation attempt...${NC}"
                FORCE_IGNORE_PHP_VERSION=true
                ;;
              2)
                echo -e "${YELLOW}Will skip composer install step...${NC}"
                SKIP_COMPOSER=true
                ;;
              3)
                echo -e "${BLUE}Installation aborted.${NC}"
                rm -rf $TEMP_DIR
                exit 0
                ;;
              *)
                echo -e "${RED}Invalid option. Aborting installation.${NC}"
                rm -rf $TEMP_DIR
                exit 1
                ;;
            esac
          fi
        else
          echo -e "${GREEN}Your selected PHP version meets the requirements.${NC}"
        fi
      else
        echo -e "${YELLOW}Could not determine PHP version requirement from composer.json.${NC}"
        read -p "Continue with installation? (y/n): " CONTINUE_INSTALL
        if [[ $CONTINUE_INSTALL != "y" && $CONTINUE_INSTALL != "Y" ]]; then
          echo -e "${BLUE}Installation aborted.${NC}"
          rm -rf $TEMP_DIR
          exit 0
        fi
      fi
    else
      echo -e "${YELLOW}No composer.json found in repository. Cannot check PHP version requirements.${NC}"
    fi
    
    # Clean up temp directory
    rm -rf $TEMP_DIR
  else
    echo -e "${RED}Failed to clone repository for inspection. Aborting.${NC}"
    rm -rf $TEMP_DIR
    exit 1
  fi
fi

# Create a temporary playbook for this specific site
cat > /tmp/site_setup.yml << EOF
---
- name: Setup Laravel Site
  hosts: localhost
  connection: local
  become: yes
  gather_facts: yes
  
  vars:
    laravel_sites:
      - name: ${SITE_NAME}
        domain: ${DOMAIN}
        port: ${PORT}
        db_connection: ${DB_TYPE}
        db_database: ${DB_NAME}
        git_repo: "${GIT_REPO}"
        git_branch: "${GIT_BRANCH}"
        php_version: "${PHP_VERSION}"
        run_migrations: true
        seed_db: false
        skip_composer: ${SKIP_COMPOSER}
        force_ignore_php_version: ${FORCE_IGNORE_PHP_VERSION}
        
  pre_tasks:
    - name: Set a flag that npm is installed
      set_fact:
        npm_installed: true
  
  tasks:
    - name: Check MySQL database exists
      mysql_db:
        name: "{{ site.db_database | default(site.name) }}"
        state: present
        login_unix_socket: /var/run/mysqld/mysqld.sock
      when: site.db_connection | default('mysql') == 'mysql'
      loop: "{{ laravel_sites }}"
      loop_control:
        loop_var: site
      register: mysql_db_created
      
    - name: Mark database as configured
      set_fact:
        site_db_configured: true
      
    - name: Set up Laravel sites
      include_role:
        name: laravel_site
      vars:
        site_name: "{{ site.name }}"
        site_domain: "{{ site.domain | default(site.name + '.local') }}"
        site_port: "{{ site.port | default('80') }}"
        git_repo: "{{ site.git_repo | default('') }}"
        git_branch: "{{ site.git_branch | default('main') }}"
        php_version: "{{ site.php_version | default('8.1') }}"
        copy_env: "{{ site.copy_env | default(true) }}"
        install_dependencies: "{{ not site.skip_composer | default(true) }}"
        generate_key: "{{ site.generate_key | default(true) }}"
        install_npm_dependencies: "{{ site.install_npm_dependencies | default(false) }}"
        compile_assets: "{{ site.compile_assets | default(false) }}"
        run_migrations: "{{ site.run_migrations | default(true) }}"
        seed_db: "{{ site.seed_db | default(false) }}"
        db_configured: "{{ site_db_configured | default(true) }}"
        db_connection: "{{ site.db_connection | default('mysql') }}"
        db_host: "{{ site.db_host | default('127.0.0.1') }}"
        db_port: "{{ site.db_port | default('3306') }}"
        db_database: "{{ site.db_database | default(site.name) }}"
        db_username: "{{ site.db_username | default('root') }}"
        db_password: "{{ site.db_password | default('') }}"
        skip_composer: "{{ site.skip_composer | default(false) }}"
        force_ignore_php_version: "{{ site.force_ignore_php_version | default(false) }}"
      loop: "{{ laravel_sites }}"
      loop_control:
        loop_var: site
        
  post_tasks:
    - name: Restart Nginx
      service:
        name: nginx
        state: restarted
        
    - name: Display site information
      debug:
        msg: |
          Laravel site configured:
          - {{ laravel_sites[0].name }} ({{ laravel_sites[0].domain | default(laravel_sites[0].name + '.local') }}) on port {{ laravel_sites[0].port | default('80') }}
          
          You can access this site at:
          http://{{ laravel_sites[0].domain | default(laravel_sites[0].name + '.local') }}{% if laravel_sites[0].port | default('80') != '80' %}:{{ laravel_sites[0].port }}{% endif %}
          
          Site path: /var/www/{{ laravel_sites[0].name }}/
EOF

echo -e "${BLUE}Setting up Laravel site: ${SITE_NAME}${NC}"
echo -e "${BLUE}Domain: ${DOMAIN}${NC}"
echo -e "${BLUE}Port: ${PORT}${NC}"
echo -e "${BLUE}PHP Version: ${PHP_VERSION}${NC}"
if [ -n "$GIT_REPO" ]; then
  echo -e "${BLUE}Git Repository: ${GIT_REPO} (branch: ${GIT_BRANCH})${NC}"
  if [ "$SKIP_COMPOSER" = true ]; then
    echo -e "${YELLOW}Composer install will be skipped. You'll need to run it manually.${NC}"
  fi
else
  echo -e "${BLUE}Creating new Laravel project${NC}"
fi
echo -e "${BLUE}Running Ansible playbook...${NC}"

# Run the temporary playbook
ansible-playbook /tmp/site_setup.yml || {
  echo -e "${RED}Error occurred during setup.${NC}"
  if [ -n "$GIT_REPO" ]; then
    echo -e "${RED}If your repository could not be cloned, please check:${NC}"
    echo -e "${RED}1. The repository URL is correct${NC}"
    echo -e "${RED}2. You have proper access permissions${NC}"
    echo -e "${RED}3. For GitHub repositories, consider using SSH instead of HTTPS${NC}"
    
    if [ "$SKIP_COMPOSER" = false ]; then
      echo -e "${RED}If Composer installation failed, it might be due to PHP version incompatibility.${NC}"
      echo -e "${RED}Try running the script again and choose to skip composer install.${NC}"
    fi
  fi
  echo -e "${RED}Site creation failed.${NC}"
  # Clean up
  rm /tmp/site_setup.yml
  exit 1
}

# Clean up
rm /tmp/site_setup.yml

echo -e "${GREEN}Site setup complete!${NC}"
echo -e "${GREEN}Your Laravel site is available at:${NC}"
if [ "$PORT" = "80" ]; then
  echo -e "${GREEN}http://${DOMAIN}${NC}"
else
  echo -e "${GREEN}http://${DOMAIN}:${PORT}${NC}"
fi
echo -e "${GREEN}Local path: /var/www/${SITE_NAME}/${NC}"

# Get services status
NGINX_STATUS=$(systemctl is-active nginx 2>/dev/null || echo "unknown")
DB_STATUS=$(systemctl is-active $([[ "$DB_TYPE" == "mysql" ]] && echo "mysql" || echo "postgresql") 2>/dev/null || echo "unknown")
PHP_STATUS=$(systemctl is-active php${PHP_VERSION}-fpm 2>/dev/null || echo "unknown")

# Get PHP version info
PHP_VERSION_FULL=$(php${PHP_VERSION} -r "echo PHP_VERSION;" 2>/dev/null || echo "unknown")

# Get public IP
PUBLIC_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "📊 Site Summary:"
echo "===================================================="
echo "🔧 Services Status:"
echo "  - Nginx: ${NGINX_STATUS}"
echo "  - Database ($DB_TYPE): ${DB_STATUS}"
echo "  - PHP-FPM (${PHP_VERSION}): ${PHP_STATUS}"
echo "  - PHP Version: ${PHP_VERSION} (${PHP_VERSION_FULL})"
echo ""
echo "🌐 Site Information:"
echo "  - Site Name: $SITE_NAME"
echo "  - Domain: $DOMAIN"
echo "  - Port: $PORT"
echo "  - PHP Version: $PHP_VERSION"
if [ "$PORT" = "80" ]; then
  echo "  - URL: http://${PUBLIC_IP}/"
  echo "  - URL: http://${DOMAIN}/ (add to your hosts file)"
else
  echo "  - URL: http://${PUBLIC_IP}:${PORT}/"
  echo "  - URL: http://${DOMAIN}:${PORT}/ (add to your hosts file)"
fi
echo "  - Path: /var/www/${SITE_NAME}/"
echo ""
echo "💾 Database Information:"
echo "  - Type: $DB_TYPE"
echo "  - Name: $DB_NAME"
echo "  - User: $DB_USER"
echo "  - Port: $([ "$DB_TYPE" == "mysql" ] && echo "3306" || echo "5432")"
echo ""

if [ -n "$GIT_REPO" ]; then
  echo "🔄 Git Information:"
  echo "  - Repository: $GIT_REPO"
  echo "  - Branch: $GIT_BRANCH"
  if [ "$SKIP_COMPOSER" = true ]; then
    echo "  - Note: Composer dependencies not installed. Run these commands manually:"
    echo "    cd /var/www/${SITE_NAME}"
    echo "    composer install --ignore-platform-reqs" 
  fi
  echo ""
fi

# Check if .env file exists to extract APP_URL
if [ -f "/var/www/${SITE_NAME}/.env" ]; then
    APP_URL=$(grep APP_URL /var/www/${SITE_NAME}/.env | cut -d= -f2)
    APP_ENV=$(grep APP_ENV /var/www/${SITE_NAME}/.env | cut -d= -f2)
    echo "⚙️ Environment:"
    echo "  - APP_URL: $APP_URL"
    echo "  - APP_ENV: $APP_ENV"
    echo ""
fi

echo "===================================================="
echo "To access your site, add this entry to your local machine's hosts file:"
echo "${PUBLIC_IP} ${DOMAIN}"
echo "" 