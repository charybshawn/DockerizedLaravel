# Laravel Deployer - Ansible Version

Ansible-based Laravel deployment automation with the same functionality as the original Bash scripts, but with better organization, templating, and idempotency.

## Project Structure

```
ansible/
├── README.md
├── ansible.cfg
├── inventory/
│   ├── hosts.yml
│   └── group_vars/
│       └── all.yml
├── playbooks/
│   ├── deploy.yml
│   ├── remove.yml
│   └── update.yml
├── roles/
│   ├── laravel_deploy/
│   ├── laravel_remove/
│   ├── laravel_update/
│   └── common/
└── templates/
    ├── nginx-site.conf.j2
    └── env.j2

```

## Features

- **Zero-downtime deployments** with symlink-based release management
- **Nginx configuration** with Laravel-optimized settings
- **Database management** with MySQL setup and migrations
- **SSL support** with certificate management
- **Shared storage** for persistent files across deployments
- **Release management** with configurable retention
- **Idempotent operations** for reliable automation

## Quick Start

### Prerequisites

- Ansible 2.9+ installed on control machine
- Target server with SSH access
- LEMP stack installed on target server

### Basic Usage

```bash
# Deploy a Laravel site
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml \
  -e site_name=myapp \
  -e domain=myapp.example.com \
  -e github_repo=https://github.com/user/myapp.git

# Update an existing site
ansible-playbook -i inventory/hosts.yml playbooks/update.yml \
  -e site_name=myapp

# Remove a site
ansible-playbook -i inventory/hosts.yml playbooks/remove.yml \
  -e site_name=myapp
```

### Configuration

1. Copy and edit inventory files:
```bash
cp inventory/hosts.yml.example inventory/hosts.yml
cp inventory/group_vars/all.yml.example inventory/group_vars/all.yml
```

2. Update `inventory/hosts.yml` with your server details
3. Customize default settings in `inventory/group_vars/all.yml`

## Playbook Variables

### Deploy Playbook (`deploy.yml`)

**Required:**
- `site_name` - Alphanumeric site identifier
- `domain` - Domain name for the site
- `github_repo` - GitHub repository URL

**Optional:**
- `github_branch` - Git branch (default: main)
- `database_name` - Database name (default: site_name)
- `database_user` - Database user (default: site_name)
- `database_password` - Database password (auto-generated if not provided)
- `ssl_enabled` - Enable SSL/HTTPS (default: false)
- `force_deploy` - Overwrite existing site (default: false)
- `releases_to_keep` - Number of releases to retain (default: 5)

### Update Playbook (`update.yml`)

**Required:**
- `site_name` - Site to update

**Optional:**
- `github_branch` - Branch to update to (default: main)

### Remove Playbook (`remove.yml`)

**Required:**
- `site_name` - Site to remove

**Optional:**
- `keep_database` - Preserve database (default: false)
- `keep_files` - Backup files instead of deleting (default: false)
- `force_remove` - Skip confirmation (default: false)

## Examples

### Deploy with SSL
```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml \
  -e site_name=api \
  -e domain=api.example.com \
  -e github_repo=git@github.com:company/api.git \
  -e github_branch=production \
  -e ssl_enabled=true
```

### Remove site but keep database
```bash
ansible-playbook -i inventory/hosts.yml playbooks/remove.yml \
  -e site_name=api \
  -e keep_database=true
```

### Update to specific branch
```bash
ansible-playbook -i inventory/hosts.yml playbooks/update.yml \
  -e site_name=api \
  -e github_branch=develop
```

## Directory Structure (Target Server)

Each deployed site follows this structure:

```
/var/www/SITE_NAME/
├── current/              # Symlink to current release
├── releases/             # Release history
│   ├── 20231215_143022/  # Timestamped releases
│   └── 20231215_145511/
└── shared/               # Persistent files across deployments
    ├── .env              # Environment configuration
    └── storage/          # Laravel storage directory
```

## Security Features

- Secure file permissions (644 for files, 755 for directories)
- Hidden files protection in Nginx config
- Database users with minimal privileges
- Environment files outside document root
- Security headers in Nginx configuration