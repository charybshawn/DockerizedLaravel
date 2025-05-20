# Laravel Development Environment

This is an Ansible-based Laravel development environment setup tool. It automates the process of setting up a LEMP stack (Linux, Nginx, MySQL, PostgreSQL, PHP) optimized for Laravel development.

## Features

- Complete LEMP stack installation (Linux, Nginx, MySQL, PostgreSQL, PHP 8.1)
- Node.js and Composer installation
- Multiple Laravel site management
- Git repository integration
- Database setup and configuration
- Easy-to-use shell scripts for common tasks

## Prerequisites

- Ubuntu/Debian-based Linux system
- sudo access
- Basic knowledge of Linux command line

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/laravel-dev-environment.git
   cd laravel-dev-environment
   ```

2. Run the setup script:
   ```bash
   sudo ./setup-laravel.sh
   ```

This will install all necessary dependencies and configure the server for Laravel development.

## Setting Up a Laravel Site

### Using the setup-site.sh Script

The simplest way to create a new Laravel site is using the provided `setup-site.sh` script:

```bash
sudo ./setup-site.sh mysite example.local
```

This will:
- Create a new site directory at `/var/www/mysite`
- Install a fresh Laravel project
- Create a MySQL database named `mysite`
- Configure Nginx with the domain `example.local`
- Set up proper permissions

### Cloning an Existing Laravel Project

To set up a site from an existing Git repository:

```bash
sudo ./setup-site.sh mysite example.local https://github.com/username/laravel-project.git main
```

Where:
- `mysite` - The site name (used for directory and default database name)
- `example.local` - The domain name
- `https://github.com/username/laravel-project.git` - Git repository URL
- `main` - Branch name (optional, defaults to 'main')

## Managing Multiple Sites

For managing multiple Laravel sites, you can edit the `playbooks/manage_laravel_sites.yml` file to define your sites:

```yml
vars:
  laravel_sites:
    - name: site1
      domain: site1.local
      db_connection: mysql
      db_database: site1_db
      
    - name: site2
      domain: site2.local
      git_repo: https://github.com/username/site2.git
      git_branch: develop
      db_connection: pgsql
      run_migrations: true
```

Then run:

```bash
ansible-playbook playbooks/manage_laravel_sites.yml
```

## Directory Structure

- `playbooks/` - Ansible playbooks
- `roles/` - Ansible roles
- `templates/` - Configuration templates
- `setup-laravel.sh` - Main setup script
- `setup-site.sh` - Site creation script

## Customization

You can customize various aspects of the environment:

- Edit `playbooks/setup_laravel_server.yml` to modify server configuration
- Modify templates in the `templates/` directory
- Edit role defaults in `roles/*/defaults/main.yml`

## Troubleshooting

Common issues:

1. **Permission problems**: Run the setup script with sudo
2. **Domain not accessible**: Add the domain to your local hosts file
3. **Database connection issues**: Check your .env file configuration 