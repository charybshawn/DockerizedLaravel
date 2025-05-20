#!/bin/bash
# Deployment script for Laravel Ansible environment
# Usage: ./deploy.sh [destination_server]

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if we received a server argument
if [ -z "$1" ]; then
  echo -e "${RED}Please specify the destination server${NC}"
  echo "Usage: ./deploy.sh [user@server]"
  exit 1
fi

DESTINATION=$1

echo -e "${BLUE}Preparing to deploy Laravel Ansible environment to ${DESTINATION}${NC}"

# Create directory structure on remote server
echo -e "${BLUE}Creating directory structure...${NC}"
ssh $DESTINATION "mkdir -p ~/ansible/webserver/templates ~/ansible/webserver/roles/laravel_site/tasks ~/ansible/webserver/playbooks"

# Copy template files
echo -e "${BLUE}Copying template files...${NC}"
scp templates/laravel.env.j2 $DESTINATION:~/ansible/webserver/templates/
scp templates/laravel_nginx.j2 $DESTINATION:~/ansible/webserver/templates/
scp templates/server_info.j2 $DESTINATION:~/ansible/webserver/templates/

# Copy role files
echo -e "${BLUE}Copying role files...${NC}"
scp roles/laravel_site/tasks/main.yml $DESTINATION:~/ansible/webserver/roles/laravel_site/tasks/

# Copy playbook files
echo -e "${BLUE}Copying playbook files...${NC}"
scp playbooks/setup_laravel_server.yml $DESTINATION:~/ansible/webserver/playbooks/
scp playbooks/manage_laravel_sites.yml $DESTINATION:~/ansible/webserver/playbooks/

# Copy script files
echo -e "${BLUE}Copying script files...${NC}"
scp setup-laravel.sh $DESTINATION:~/ansible/webserver/
scp setup-site.sh $DESTINATION:~/ansible/webserver/

# Make scripts executable
echo -e "${BLUE}Setting executable permissions...${NC}"
ssh $DESTINATION "chmod +x ~/ansible/webserver/setup-laravel.sh ~/ansible/webserver/setup-site.sh"

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}Your Laravel Ansible environment is now available at ${DESTINATION}:~/ansible/webserver/${NC}"
echo -e "${GREEN}Run the following commands on your server:${NC}"
echo -e "cd ~/ansible/webserver"
echo -e "sudo ./setup-laravel.sh  # To set up the server"
echo -e "sudo ./setup-site.sh sitename domain.local [port] [git_repo] [git_branch]  # To create a site" 