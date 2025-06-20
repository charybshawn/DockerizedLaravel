#!/bin/bash

# Laravel Development Environment Setup Script (Improved)
# This script provides a secure, user-friendly interface for setting up the Laravel environment

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/laravel-setup"
LOG_FILE="$LOG_DIR/setup.log"
VAULT_FILE="$SCRIPT_DIR/group_vars/vault.yml"
VAULT_EXAMPLE="$SCRIPT_DIR/group_vars/vault.yml.example"

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

# Function to print error and exit
die() {
    print_color $RED "❌ ERROR: $1" >&2
    exit 1
}

# Function to print warning
warn() {
    print_color $YELLOW "⚠️  WARNING: $1"
}

# Function to print success
success() {
    print_color $GREEN "✅ $1"
}

# Function to print info
info() {
    print_color $CYAN "ℹ️  $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        die "This script must be run as root (use sudo)"
    fi
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if we're on a supported OS
    if [[ ! -f /etc/os-release ]]; then
        die "Unable to determine operating system"
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        die "This script only supports Ubuntu and Debian systems"
    fi
    
    success "Operating system: $PRETTY_NAME"
    
    # Check for required commands
    local required_commands=("curl" "python3" "git")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            warn "$cmd not found, will be installed"
        else
            success "$cmd is available"
        fi
    done
    
    # Check for Ansible
    if ! command -v ansible-playbook &> /dev/null; then
        info "Ansible not found, installing..."
        apt update
        apt install -y ansible
        success "Ansible installed"
    else
        success "Ansible is available"
    fi
}

# Function to setup vault
setup_vault() {
    print_header "Setting Up Ansible Vault"
    
    if [[ -f "$VAULT_FILE" ]]; then
        info "Vault file already exists at $VAULT_FILE"
        read -p "Do you want to recreate it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    # Check if vault example exists
    if [[ ! -f "$VAULT_EXAMPLE" ]]; then
        die "Vault example file not found at $VAULT_EXAMPLE"
    fi
    
    # Generate passwords
    print_color $PURPLE "🎲 Generating secure passwords..."
    cd "$SCRIPT_DIR"
    python3 scripts/generate_passwords.py
    
    # Create vault
    print_color $PURPLE "🔐 Creating encrypted vault file..."
    echo "Please enter a strong vault password (you'll need this for future runs):"
    ansible-vault create "$VAULT_FILE"
    
    success "Vault file created at $VAULT_FILE"
    info "Remember your vault password - you'll need it to run playbooks"
}

# Function to run security checks
run_security_checks() {
    print_header "Running Security Checks"
    
    # Check file permissions
    local sensitive_files=("$VAULT_FILE" "$SCRIPT_DIR/.vault_pass")
    for file in "${sensitive_files[@]}"; do
        if [[ -f "$file" ]]; then
            local perms=$(stat -c %a "$file")
            if [[ "$perms" != "600" ]]; then
                warn "File $file has permissive permissions ($perms), fixing..."
                chmod 600 "$file"
                success "Fixed permissions for $file"
            else
                success "File $file has secure permissions"
            fi
        fi
    done
    
    # Check for default passwords (this would be more sophisticated in practice)
    info "Vault security check completed"
}

# Function to setup logging
setup_logging() {
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR"
        chmod 755 "$LOG_DIR"
    fi
    
    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE"
        chmod 644 "$LOG_FILE"
    fi
}

# Function to display menu
show_menu() {
    print_header "Laravel Development Environment Setup"
    echo "Select an option:"
    echo
    echo "1) 🚀 Full setup (recommended for new installations)"
    echo "2) 🔧 Custom setup (advanced users)"
    echo "3) 🏥 Health check only"
    echo "4) 🔐 Setup vault only"
    echo "5) 📊 View system information"
    echo "6) 🚪 Exit"
    echo
}

# Function to run full setup
run_full_setup() {
    print_header "Running Full Laravel Environment Setup"
    
    cd "$SCRIPT_DIR"
    
    info "Starting full setup with secure defaults..."
    
    # Run the improved playbook
    if [[ -f "$VAULT_FILE" ]]; then
        ansible-playbook --ask-vault-pass playbooks/setup_laravel_server_improved.yml
    else
        warn "No vault file found, running without vault (less secure)"
        ansible-playbook playbooks/setup_laravel_server_improved.yml
    fi
    
    success "Full setup completed!"
    info "Check the output above for access URLs and next steps"
}

# Function to run custom setup
run_custom_setup() {
    print_header "Custom Setup Options"
    
    echo "Available tags for selective installation:"
    echo "• system     - System packages and basic setup"
    echo "• security   - Security configurations (firewall, etc.)"
    echo "• php        - PHP and extensions"
    echo "• mysql      - MySQL database"
    echo "• postgresql - PostgreSQL database"
    echo "• sqlite     - SQLite database"
    echo "• nginx      - Nginx web server"
    echo "• nodejs     - Node.js and npm"
    echo "• composer   - Composer PHP package manager"
    echo "• adminer    - Adminer database manager"
    echo "• laravel    - Sample Laravel application"
    echo "• health     - Health checks and verification"
    echo
    
    read -p "Enter tags to install (space-separated, or 'all' for everything): " tags
    
    if [[ "$tags" == "all" ]]; then
        tags=""
        tag_option=""
    else
        tag_option="--tags $tags"
    fi
    
    cd "$SCRIPT_DIR"
    
    if [[ -f "$VAULT_FILE" ]]; then
        ansible-playbook --ask-vault-pass $tag_option playbooks/setup_laravel_server_improved.yml
    else
        ansible-playbook $tag_option playbooks/setup_laravel_server_improved.yml
    fi
    
    success "Custom setup completed!"
}

# Function to run health check
run_health_check() {
    print_header "Running Health Check"
    
    cd "$SCRIPT_DIR"
    ansible-playbook --tags health playbooks/setup_laravel_server_improved.yml
    
    if [[ -f "/tmp/health_check_report.txt" ]]; then
        echo
        info "Full health report:"
        cat "/tmp/health_check_report.txt"
    fi
}

# Function to show system information
show_system_info() {
    print_header "System Information"
    
    echo "Hostname: $(hostname)"
    echo "OS: $(lsb_release -d | cut -f2)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
    echo "Disk Usage: $(df -h / | awk 'NR==2 {print $5}')"
    echo "Uptime: $(uptime -p)"
    echo
    
    if command -v ansible &> /dev/null; then
        echo "Ansible Version: $(ansible --version | head -n1)"
    fi
    
    if command -v php &> /dev/null; then
        echo "PHP Version: $(php --version | head -n1)"
    fi
    
    if command -v nginx &> /dev/null; then
        echo "Nginx Version: $(nginx -v 2>&1)"
    fi
    
    if command -v mysql &> /dev/null; then
        echo "MySQL Version: $(mysql --version)"
    fi
}

# Function to cleanup on exit
cleanup() {
    if [[ -f "$SCRIPT_DIR/vault_template.yml" ]]; then
        rm -f "$SCRIPT_DIR/vault_template.yml"
    fi
}

# Main function
main() {
    # Set up signal handlers
    trap cleanup EXIT
    
    # Initial checks
    check_root
    setup_logging
    
    # Log start
    echo "$(date): Laravel setup script started by $(logname)" >> "$LOG_FILE"
    
    check_prerequisites
    
    # Main menu loop
    while true; do
        show_menu
        read -p "Enter your choice (1-6): " choice
        
        case $choice in
            1)
                setup_vault
                run_security_checks
                run_full_setup
                break
                ;;
            2)
                run_security_checks
                run_custom_setup
                break
                ;;
            3)
                run_health_check
                ;;
            4)
                setup_vault
                run_security_checks
                ;;
            5)
                show_system_info
                ;;
            6)
                print_color $GREEN "👋 Goodbye!"
                exit 0
                ;;
            *)
                warn "Invalid option. Please choose 1-6."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
    
    # Log completion
    echo "$(date): Laravel setup script completed" >> "$LOG_FILE"
    
    print_header "Setup Complete"
    success "Laravel development environment setup finished!"
    info "Logs are available at: $LOG_FILE"
    info "For help and documentation, see: README.md and SECURITY.md"
}

# Run main function
main "$@"