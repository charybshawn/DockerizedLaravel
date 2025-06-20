# LEMP Stack Deployment Tool

A clean, production-ready LEMP stack installer for Ubuntu that avoids the complexity of traditional role-based Ansible deployments.

## Features

- **Simple Installation**: Single command setup with interactive prompts
- **Multiple PHP Versions**: Support for PHP 7.4 through 8.4
- **Database Options**: Choose between MariaDB or PostgreSQL
- **Laravel Optimized**: Nginx configured for Laravel projects
- **Global Composer**: Composer installed system-wide
- **Clean Output**: Minimal output by default, verbose/debug modes available
- **Complete Rollback**: Full uninstall capability with data protection options

## Quick Start

```bash
# Clone and navigate
git clone <your-repo-url>
cd webserver/lemp-deployer

# Interactive installation
sudo ./install.sh

# Non-interactive with options
sudo ./install.sh --php-version 8.2 --database postgres --verbose
```

## Installation Options

```bash
sudo ./install.sh [OPTIONS]

Options:
    --php-version VERSION       PHP version (default: 8.3)
    --database TYPE            Database: mariadb or postgres (default: mariadb)
    --db-password PASSWORD     Database root password
    --non-interactive          Use defaults, minimal prompts
    --verbose                  Show detailed output
    --debug                    Show full debug output
    --help                     Show help message
```

## Rollback

Complete removal of all LEMP components:

```bash
# Interactive rollback (keeps data by default)
sudo ./rollback.sh

# Remove everything including data
sudo ./rollback.sh --force

# Keep website files and databases
sudo ./rollback.sh --keep-data
```

## What Gets Installed

- **PHP**: Version of choice with essential extensions (mbstring, xml, curl, zip, gd, intl, bcmath, mysql/pgsql, opcache)
- **Nginx**: Laravel-optimized configuration with security headers and gzip compression
- **Database**: MariaDB or PostgreSQL with secure defaults
- **Composer**: Global installation at `/usr/local/bin/composer`

## Directory Structure

```
lemp-deployer/
├── install.sh              # Main installer
├── rollback.sh             # Complete removal tool
├── deploy-lemp.yml          # Ansible playbook
├── ansible.cfg             # Ansible configuration
├── inventory.yml           # Inventory file
├── vars/
│   └── config.yml          # Configuration variables
└── tasks/
    ├── validation.yml      # Pre-flight checks
    ├── php.yml            # PHP installation
    ├── composer.yml       # Composer installation
    ├── nginx.yml          # Nginx configuration
    └── database.yml       # Database setup
```

## Requirements

- Ubuntu 18.04+ (tested on 20.04, 22.04)
- Root/sudo privileges
- Internet connection for package downloads

## After Installation

1. **Test the setup**: Visit your server IP to see the default Nginx page
2. **Create Laravel projects**: Use `composer create-project laravel/laravel myproject`
3. **Configure virtual hosts**: Add Nginx server blocks for your domains

## Security Notes

This tool is configured for development use with an eye toward production. For production deployment:

- Change default database passwords
- Configure SSL/TLS certificates
- Review and harden Nginx security headers
- Set up proper firewall rules
- Configure backup strategies

## Troubleshooting

**Installation fails**: Check with `--verbose` or `--debug` flags
**Service issues**: Verify with `systemctl status nginx php8.3-fpm mariadb`
**Permission problems**: Ensure you're running with sudo

## Support

This is a clean rewrite designed to avoid the complexity issues of traditional Ansible role-based deployments. The code is intentionally simple and maintainable.