#!/bin/bash
# Migration script to Laravel Development Environment v2.0
# This script creates compatibility symlinks for the new professional naming

set -euo pipefail

echo "Laravel Development Environment - Migration to v2.0"
echo "=================================================="
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This migration script must be run as root (use sudo)"
    exit 1
fi

# Create symlinks for backward compatibility
echo "Creating compatibility symlinks..."

# Map old names to new names
declare -A name_mappings=(
    ["install.sh"]="laravel-env-installer"
    ["setup-site.sh"]="laravel-site-manager create"
    ["list_sites.sh"]="laravel-site-inventory"
    ["rollback.sh"]="laravel-env-uninstaller"
)

# Create wrapper scripts for compatibility
for old_name in "${!name_mappings[@]}"; do
    new_command="${name_mappings[$old_name]}"
    
    if [[ -f "$old_name" ]] && [[ ! -L "$old_name" ]]; then
        # Backup old script
        mv "$old_name" "${old_name}.v1.backup"
        echo "  - Backed up $old_name to ${old_name}.v1.backup"
        
        # Create wrapper script
        cat > "$old_name" << EOF
#!/bin/bash
# Compatibility wrapper for v2.0
echo "Note: $old_name is deprecated. Please use: $new_command" >&2
echo "" >&2
exec ./$(echo $new_command | cut -d' ' -f1) \$@
EOF
        chmod +x "$old_name"
        echo "  - Created compatibility wrapper: $old_name"
    fi
done

# Update configuration files
echo
echo "Updating configuration files..."

# Remove emoji from ansible.cfg if present
if [[ -f "ansible.cfg" ]]; then
    # Create backup
    cp ansible.cfg ansible.cfg.v1.backup
    echo "  - Backed up ansible.cfg"
fi

# Create new log directory structure
echo
echo "Setting up new logging structure..."
mkdir -p /var/log/laravel-env
chmod 755 /var/log/laravel-env
echo "  - Created /var/log/laravel-env/"

# Migrate old logs if they exist
if [[ -d "/var/log/laravel-setup" ]]; then
    cp -r /var/log/laravel-setup/* /var/log/laravel-env/ 2>/dev/null || true
    echo "  - Migrated existing logs"
fi

# Create new site information directory
mkdir -p /var/lib/nginx/sites
chmod 755 /var/lib/nginx/sites
echo "  - Created /var/lib/nginx/sites/"

echo
echo "Migration Complete!"
echo "=================="
echo
echo "Important Changes in v2.0:"
echo "-------------------------"
echo "1. Professional naming conventions:"
echo "   - install.sh → laravel-env-installer"
echo "   - setup-site.sh → laravel-site-manager"
echo "   - list_sites.sh → laravel-site-inventory"
echo
echo "2. Enhanced features:"
echo "   - Structured logging in /var/log/laravel-env/"
echo "   - Professional output (no emojis)"
echo "   - Comprehensive error handling"
echo "   - Audit trail support"
echo
echo "3. New commands:"
echo "   - laravel-env-installer --mode health"
echo "   - laravel-site-manager [create|delete|enable|disable|backup]"
echo "   - laravel-site-inventory --format [table|json|csv|detailed]"
echo
echo "Compatibility wrappers have been created for old script names."
echo "Please update your documentation and scripts to use the new names."
echo
echo "For more information, see:"
echo "  - README.md"
echo "  - OPERATIONS_GUIDE.md"
echo "  - SECURITY.md"
echo