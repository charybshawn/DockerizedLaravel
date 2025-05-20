# Laravel Development Environment Setup

This repository contains a simple, self-contained Ansible setup for configuring Laravel development environments directly on your server or VM.

## Features

- **Runs locally**: Just clone and execute on the machine you want to configure
- **Complete LEMP stack**: Installs Nginx, MySQL, PostgreSQL, PHP with all Laravel requirements
- **Node.js & Composer**: Sets up the complete JavaScript and PHP dependency tools
- **Multi-site support**: Easily create and manage multiple Laravel sites on a single server

## Quick Setup

1. Clone this repository to your server:
   ```
   git clone <repository-url>
   cd laravel-ansible-setup
   ```

2. Run the setup script:
   ```
   sudo ./setup-laravel.sh
   ```

   This script will:
   - Install Ansible if needed
   - Install required dependencies
   - Set up the LEMP stack with PHP 8.1, MySQL, PostgreSQL
   - Install Node.js, NPM, Yarn, and Composer
   - Configure PHP for optimal Laravel performance

3. Create Laravel sites using the site setup script:
   ```
   sudo ./setup-site.sh
   ```

   This interactive script will prompt you for:
   - Site name and domain
   - Git repository (optional)
   - Database configuration
   - Additional options like migrations and asset compilation

## Manual Configuration

If you prefer to configure things manually, you can use the Ansible playbooks directly:

### Set up the server environment:
```
sudo ansible-playbook playbooks/setup_laravel_server.yml -i inventory/hosts.yml
```

### Add Laravel sites:
Edit `playbooks/manage_laravel_sites.yml` to configure your sites, then run:
```
sudo ansible-playbook playbooks/manage_laravel_sites.yml -i inventory/hosts.yml
```

## Site Configuration

When setting up a Laravel site, you can configure multiple options:

```yaml
laravel_sites:
  - name: myproject                        # Site name
    domain: myproject.local                # Domain name
    git_repo: https://github.com/user/repo # Optional Git repository
    git_branch: main                       # Git branch
    db_connection: mysql                   # Database type (mysql or pgsql)
    db_database: myproject                 # Database name
    db_username: root                      # Database username
    db_password: password                  # Database password
    run_migrations: true                   # Run migrations after setup
    seed_db: false                         # Seed the database
    install_npm_dependencies: true         # Install npm dependencies
    compile_assets: true                   # Compile assets
    npm_command: dev                       # npm command to run
```

## Requirements

- Ubuntu/Debian-based system
- Basic system packages (installed automatically by the setup script)
- Sudo/root access 