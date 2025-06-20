#!/bin/bash
# Fix installation lock issue

echo "Laravel Development Environment - Lock File Fix"
echo "=============================================="
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Create log directory if it doesn't exist
echo "Creating log directory..."
mkdir -p /var/log/laravel-env
chmod 755 /var/log/laravel-env

# Remove any stale lock files
echo "Checking for lock files..."
if ls /var/log/laravel-env/.*.lock 1> /dev/null 2>&1; then
    echo "Found lock files:"
    ls -la /var/log/laravel-env/.*.lock
    
    echo
    read -p "Remove these lock files? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f /var/log/laravel-env/.*.lock
        echo "Lock files removed."
    fi
else
    echo "No lock files found."
fi

# Check if any Laravel processes are running
echo
echo "Checking for running Laravel installer processes..."
if pgrep -f "laravel-env-installer" > /dev/null; then
    echo "Found running installer processes:"
    ps aux | grep -E "laravel-env-installer|ansible-playbook.*laravel" | grep -v grep
    
    echo
    echo "You may want to kill these processes before continuing."
else
    echo "No installer processes found running."
fi

echo
echo "Fix complete. You can now run the installer again:"
echo "  sudo ./laravel-env-installer --mode full"
echo