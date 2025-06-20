# Laravel Development Environment

## Enterprise-Grade Development Environment Management System

A professional Ansible-based automation platform for deploying and managing Laravel development environments. This system provides comprehensive tooling for creating, configuring, and maintaining multiple Laravel applications with enterprise-level reliability and security.

## Key Features

### Infrastructure Management
- **Multi-Stack Support**: Complete LEMP stack with MySQL, PostgreSQL, and SQLite
- **PHP Version Management**: Support for PHP 7.4, 8.0, 8.1, 8.2, 8.3, and 8.4
- **Container-Ready**: Optimized configuration for containerized deployments
- **High Performance**: Nginx with optimized configurations for Laravel applications

### Development Tools
- **Automated Site Creation**: Professional site management interface
- **Git Integration**: Seamless repository cloning and branch management
- **Database Management**: Integrated Adminer with security controls
- **Asset Pipeline**: Node.js LTS with npm/yarn support
- **Dependency Management**: Composer 2.x with optimization features

### Enterprise Features
- **Security-First Design**: Ansible Vault integration, secure password generation
- **Comprehensive Logging**: Structured logging with audit trails
- **Health Monitoring**: Built-in health checks and status reporting
- **Backup & Recovery**: Automated backup procedures with retention policies
- **Configuration Validation**: Pre-flight checks and validation frameworks
- **Professional CLI**: Consistent, documented command-line interfaces

## System Requirements

### Minimum Requirements
- **Operating System**: Ubuntu 20.04+ or Debian 10+
- **CPU**: 2 cores (4+ recommended)
- **Memory**: 2GB RAM (4GB+ recommended)
- **Storage**: 10GB available space
- **Network**: Internet connectivity for package installation
- **Privileges**: Root or sudo access

### Supported Platforms
- Ubuntu 20.04 LTS, 22.04 LTS, 24.04 LTS
- Debian 10 (Buster), 11 (Bullseye), 12 (Bookworm)
- WSL2 (Windows Subsystem for Linux)
- Cloud platforms: AWS EC2, Google Cloud, Azure, DigitalOcean

## Installation

### Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/laravel-dev-environment.git
   cd laravel-dev-environment
   ```

2. **Run the installer:**
   ```bash
   sudo ./laravel-env-installer --mode full
   ```

### Installation Options

```bash
# Full installation with all components
sudo ./laravel-env-installer --mode full

# Custom installation with component selection
sudo ./laravel-env-installer --mode custom

# Validate existing installation
sudo ./laravel-env-installer --mode validate

# Perform system health check
sudo ./laravel-env-installer --mode health

# View all options
./laravel-env-installer --help
```

### Advanced Installation

```bash
# Installation with custom configuration
sudo ./laravel-env-installer --mode full --config custom.yml

# Dry run to preview changes
sudo ./laravel-env-installer --mode full --dry-run

# Verbose output for debugging
sudo ./laravel-env-installer --mode full --verbose
```

## Uninstallation

To completely remove the Laravel development environment and all its components:

```bash
sudo ./rollback.sh
```

This will:
- Remove all installed packages
- Delete configuration files
- Remove created directories
- Clean up system settings

## Site Management

### Creating a Laravel Site

#### Interactive Mode
```bash
sudo ./laravel-site-manager create --name myapp --domain myapp.local
```

#### From Git Repository
```bash
sudo ./laravel-site-manager create \
  --name myapp \
  --domain myapp.local \
  --git-repo https://github.com/username/myapp.git \
  --git-branch main
```

#### With Custom Configuration
```bash
sudo ./laravel-site-manager create \
  --name myapp \
  --domain myapp.local \
  --port 8080 \
  --php-version 8.3
```

### Managing Sites

#### List All Sites
```bash
# Table format with system status
sudo ./laravel-site-inventory

# JSON output for automation
sudo ./laravel-site-inventory --format json

# Detailed site information
sudo ./laravel-site-inventory --format detailed

# Export to CSV
sudo ./laravel-site-inventory --format csv > sites.csv
```

#### Site Operations
```bash
# Enable/disable sites
sudo ./laravel-site-manager enable --name myapp
sudo ./laravel-site-manager disable --name myapp

# Check site status
sudo ./laravel-site-manager status --name myapp

# Backup site
sudo ./laravel-site-manager backup --name myapp

# Update site from Git
sudo ./laravel-site-manager update --name myapp

# Delete site (with confirmation)
sudo ./laravel-site-manager delete --name myapp
```

This will:
- Create a new site directory at `/var/www/sitename`
- Install a fresh Laravel project or clone from Git
- Create a database
- Configure Nginx
- Set up proper permissions

### Setting Up a Site with Custom Port

When running the script, you'll be prompted for the port number. Simply enter your desired port (e.g., 8080) when asked.

### Cloning an Existing Laravel Project

When running the script, you'll be prompted for a Git repository URL. Enter the full URL when asked:

```
Enter Git repository URL (leave empty for new Laravel project): https://github.com/username/laravel-project.git
```

The script will then:
- Ask for the branch name (defaults to 'main')
- Check PHP version requirements from composer.json
- Validate PHP version compatibility
- Offer to switch to a compatible PHP version if needed
- Handle database configuration automatically
- Set up proper permissions and environment

### Working with GitHub Repositories

For GitHub repositories, you have two options:

1. **Public Repositories**: The script will detect public repositories and attempt to clone them anonymously.

2. **Private Repositories**: For private repositories, use SSH URLs instead of HTTPS:
   ```
   Enter Git repository URL: git@github.com:username/private-repo.git
   ```

   Make sure your SSH keys are properly set up on the server with access to the repository.

### Automatic Updates via Cron

When setting up a Git-based project, you'll be asked if you want to enable automatic updates:

```
Enable automatic updates via cron? (yes/no) [no]:
```

When auto-update is enabled:
- A cron job will be created to pull the latest changes every 6 hours
- The update script will handle stashing local changes, pulling updates, running Composer and npm tasks, and running migrations
- All update activities are logged to `/var/log/sitename-updates.log`
- The update script is created at `/usr/local/bin/update-sitename.sh` and can be manually executed at any time

This feature is especially useful for development environments that need to stay in sync with a shared repository.

## Managing Multiple Sites

For managing multiple Laravel sites, you can edit the `playbooks/manage_laravel_sites.yml` file to define your sites:

```yml
vars:
  laravel_sites:
    - name: site1
      domain: site1.local
      port: 80
      db_connection: mysql
      db_database: site1_db
      php_version: 8.1
      
    - name: site2
      domain: site2.local
      port: 8080
      git_repo: git@github.com:username/site2.git
      git_branch: develop
      db_connection: pgsql
      php_version: 8.2
      run_migrations: true
      auto_update: yes
```

Then run:

```bash
ansible-playbook playbooks/manage_laravel_sites.yml
```

Each site can have its own:
- PHP version
- Database system (MySQL or PostgreSQL)
- Git repository and branch
- Port configuration
- Auto-update settings

## Directory Structure

- `playbooks/` - Ansible playbooks
- `roles/` - Ansible roles
- `templates/` - Configuration templates
- `install.sh` - Main installation script
- `rollback.sh` - Uninstallation script
- `setup-site.sh` - Site creation script

## Customization

You can customize various aspects of the environment:

- Edit `playbooks/setup_laravel_server.yml` to modify server configuration
- Modify templates in the `templates/` directory
- Edit role defaults in `roles/*/defaults/main.yml`

## Monitoring and Health Checks

### System Health Check
```bash
sudo ./laravel-env-installer --mode health
```

### Service Monitoring
```bash
# Check Nginx status
curl http://localhost/nginx_status

# View system logs
sudo tail -f /var/log/laravel-env/operations.log

# Monitor site-specific logs
sudo tail -f /var/log/nginx/myapp_*.log
```

### Performance Monitoring
- Built-in health check endpoints for each site
- Nginx status page for connection monitoring
- Structured logging for troubleshooting
- Resource usage tracking

## Security Features

- **Ansible Vault**: Encrypted storage for sensitive data
- **Secure Password Generation**: Automated strong password creation
- **Input Validation**: Comprehensive validation for all user inputs
- **Audit Logging**: Complete audit trail of all operations
- **File Permissions**: Automated permission management
- **Security Headers**: Pre-configured security headers for all sites

For detailed security information, see [SECURITY.md](SECURITY.md).

## Documentation

### Available Guides

- **[OPERATIONS_GUIDE.md](OPERATIONS_GUIDE.md)**: Comprehensive operations manual
- **[NGINX_GUIDE.md](NGINX_GUIDE.md)**: Detailed Nginx configuration guide
- **[SECURITY.md](SECURITY.md)**: Security policies and best practices
- **API Documentation**: Available in `docs/api/`
- **Architecture Diagrams**: Available in `docs/architecture/`

### Quick Reference

```bash
# Installation
sudo ./laravel-env-installer --mode full

# Create site
sudo ./laravel-site-manager create --name myapp --domain myapp.local

# List sites
sudo ./laravel-site-inventory

# Health check
sudo ./laravel-env-installer --mode health

# View logs
sudo tail -f /var/log/laravel-env/operations.log
```

## Support

### Getting Help

1. **Documentation**: Start with the guides in this repository
2. **Command Help**: Use `--help` flag with any command
3. **Logs**: Check `/var/log/laravel-env/` for detailed logs
4. **Issues**: Report bugs at [GitHub Issues](https://github.com/yourorg/laravel-dev-environment/issues)

### Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

- Laravel Framework
- Ansible Community
- Nginx Team
- PHP Development Team

---

**Version**: 2.0  
**Last Updated**: March 2024  
**Maintainers**: Laravel Development Environment Team