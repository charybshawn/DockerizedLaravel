#!/bin/bash

# Default values
VERBOSE=""
ROLLBACK_FIRST=false

# Function to display help
show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -v, --verbose        Show detailed output"
    echo "  -r, --rollback-first Run rollback script before installation"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run with minimal output"
    echo "  $0 -v                 # Run with verbose output"
    echo "  $0 -r                 # Run rollback first, then install with minimal output"
    echo "  $0 -v -r              # Run rollback first, then install with verbose output"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE="-v"
            shift
            ;;
        -r|--rollback-first)
            ROLLBACK_FIRST=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if Ansible is installed
if ! command -v ansible &> /dev/null; then
    echo "Ansible is not installed. Please install it first."
    exit 1
fi

# Check if the playbook exists
if [ ! -f "playbooks/setup_laravel_server.yml" ]; then
    echo "playbooks/setup_laravel_server.yml not found in the current directory."
    exit 1
fi

# Run rollback first if requested
if [ "$ROLLBACK_FIRST" = true ]; then
    echo "Running rollback first..."
    ./rollback.sh
    if [ $? -ne 0 ]; then
        echo "Rollback failed. Aborting installation."
        exit 1
    fi
    echo "Rollback completed successfully."
fi

# Run the Ansible playbook
echo "Running Ansible playbook..."
ansible-playbook playbooks/setup_laravel_server.yml $VERBOSE

# Check if the playbook execution was successful
if [ $? -eq 0 ]; then
    echo "Setup completed successfully!"
else
    echo "Setup failed. Please check the error messages above."
    exit 1
fi 