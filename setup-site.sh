#!/bin/bash
# Script to create a new Laravel site
# Usage: ./setup-site.sh sitename [domain] [port] [git_repo] [git_branch]

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
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
  echo "Usage: ./setup-site.sh sitename [domain] [port] [git_repo] [git_branch]"
  exit 1
fi

SITE_NAME=$1

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

# Check if using HTTPS for GitHub
if [[ "$GIT_REPO" == *"https://github.com"* ]]; then
  echo -e "${YELLOW}Warning: Using HTTPS for GitHub repository URLs.${NC}"
  echo -e "${YELLOW}GitHub no longer supports password authentication for Git operations.${NC}"
  echo -e "${YELLOW}If this is a private repository, consider using an SSH URL (git@github.com:username/repo.git) instead.${NC}"
  echo -e "${YELLOW}For public repositories, the script will attempt to clone anonymously.${NC}"
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

# Database type - default to MySQL
DB_TYPE="mysql"
DB_NAME=$SITE_NAME
DB_USER="root"

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
        run_migrations: true
        seed_db: false
        
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
        copy_env: "{{ site.copy_env | default(true) }}"
        install_dependencies: "{{ site.install_dependencies | default(true) }}"
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
if [ -n "$GIT_REPO" ]; then
  echo -e "${BLUE}Git Repository: ${GIT_REPO} (branch: ${GIT_BRANCH})${NC}"
else
  echo -e "${BLUE}Creating new Laravel project${NC}"
fi
echo -e "${BLUE}Running Ansible playbook...${NC}"

# Run the temporary playbook
ansible-playbook /tmp/site_setup.yml

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
PHP_STATUS=$(systemctl is-active php8.1-fpm 2>/dev/null || echo "unknown")

# Get public IP
PUBLIC_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "📊 Site Summary:"
echo "===================================================="
echo "🔧 Services Status:"
echo "  - Nginx: ${NGINX_STATUS}"
echo "  - Database ($DB_TYPE): ${DB_STATUS}"
echo "  - PHP-FPM: ${PHP_STATUS}"
echo ""
echo "🌐 Site Information:"
echo "  - Site Name: $SITE_NAME"
echo "  - Domain: $DOMAIN"
echo "  - Port: $PORT"
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