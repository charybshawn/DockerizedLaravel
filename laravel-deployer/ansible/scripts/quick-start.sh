#!/bin/bash

# Laravel Deployer Ansible - Quick Start Script
# This script helps you get started quickly with the Ansible version

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo "==============================================="
echo "Laravel Deployer - Ansible Quick Start"
echo "==============================================="
echo

# Check if ansible is installed
if ! command -v ansible >/dev/null 2>&1; then
    print_status "ERROR" "Ansible is not installed. Please install Ansible first:"
    echo "  Ubuntu/Debian: sudo apt update && sudo apt install ansible"
    echo "  CentOS/RHEL: sudo yum install ansible"
    echo "  macOS: brew install ansible"
    echo "  pip: pip install ansible"
    exit 1
fi

print_status "SUCCESS" "Ansible found: $(ansible --version | head -1)"

# Check if we're in the right directory
if [[ ! -f "ansible.cfg" ]]; then
    print_status "ERROR" "Please run this script from the ansible/ directory"
    exit 1
fi

# Install required collections
print_status "INFO" "Installing required Ansible collections..."
if ansible-galaxy collection install -r requirements.yml; then
    print_status "SUCCESS" "Ansible collections installed"
else
    print_status "ERROR" "Failed to install collections"
    exit 1
fi

# Setup inventory files
print_status "INFO" "Setting up inventory files..."
make setup

print_status "WARN" "Please edit the following files with your server details:"
echo "  - inventory/hosts.yml (server connection details)"
echo "  - inventory/group_vars/all.yml (default configuration)"
echo

print_status "INFO" "Example usage after configuration:"
echo
echo "Deploy a site:"
echo "  make deploy SITE=blog DOMAIN=blog.example.com REPO=https://github.com/user/blog.git"
echo
echo "Deploy with SSL:"
echo "  make deploy SITE=api DOMAIN=api.example.com REPO=git@github.com:company/api.git SSL=true"
echo
echo "Update a site:"
echo "  make update SITE=blog"
echo
echo "Remove a site:"
echo "  make remove SITE=blog"
echo

print_status "SUCCESS" "Quick start setup complete!"
print_status "INFO" "Edit your inventory files and you're ready to deploy Laravel sites with Ansible!"