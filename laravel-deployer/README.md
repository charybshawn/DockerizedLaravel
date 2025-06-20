# Laravel Site Deployment Tool

Automatically deploy Laravel applications from GitHub repositories with zero-downtime deployments, automatic Nginx configuration, and database setup.

## Features

- **GitHub Integration**: Deploy directly from GitHub repos (public/private)
- **Zero-Downtime Deployments**: Symlink-based deployments with release history
- **Auto Nginx Configuration**: Laravel-optimized server blocks with security headers
- **Database Management**: Automatic MySQL database and user creation
- **SSL Support**: Optional HTTPS configuration
- **Shared Storage**: Persistent storage and .env files across deployments
- **Release Management**: Keeps last 5 releases, easy rollbacks
- **Complete Removal**: Clean uninstall with optional data preservation

## Prerequisites

- LEMP stack installed (use `../lemp-deployer/install.sh`)
- Git installed
- Root/sudo access
- GitHub repository with Laravel project

## Quick Start

```bash
# Clone this repository
git clone <your-repo-url>
cd webserver/laravel-deployer

# Deploy a Laravel site
sudo ./deploy-laravel.sh \
  --site-name myapp \
  --domain myapp.local \
  --github-repo https://github.com/user/myapp.git

# Remove a site
sudo ./remove-laravel.sh --site-name myapp
```

## Deployment Options

```bash
sudo ./deploy-laravel.sh [OPTIONS]

Required:
  --site-name NAME           Site name (alphanumeric + underscores only)
  --domain DOMAIN            Domain name for the site
  --github-repo URL          GitHub repository URL

Optional:
  --branch BRANCH            Git branch (default: main)
  --database-name NAME       Database name (default: site_name)
  --database-user USER       Database user (default: site_name)
  --database-password PASS   Database password (prompts if not provided)
  --ssl                      Enable SSL/HTTPS configuration
  --force                    Overwrite existing site
  --verbose                  Show detailed output
```

## Examples

### Basic Deployment
```bash
sudo ./deploy-laravel.sh \
  --site-name blog \
  --domain blog.example.com \
  --github-repo https://github.com/user/blog.git
```

### Production with SSL
```bash
sudo ./deploy-laravel.sh \
  --site-name api \
  --domain api.example.com \
  --github-repo git@github.com:company/api.git \
  --branch production \
  --ssl \
  --database-name api_prod
```

### Development Environment
```bash
sudo ./deploy-laravel.sh \
  --site-name testapp \
  --domain testapp.local \
  --github-repo https://github.com/user/testapp.git \
  --branch develop \
  --force
```

## Directory Structure

Each deployed site follows this structure:

```
/var/www/SITE_NAME/
├── current/              # Symlink to current release
├── releases/             # Release history (last 5 kept)
│   ├── 20231215_143022/  # Timestamped releases
│   └── 20231215_145511/
└── shared/               # Persistent files across deployments
    ├── .env              # Environment configuration
    └── storage/          # Laravel storage directory
        ├── app/
        ├── framework/
        └── logs/
```

## Nginx Configuration

Auto-generated Nginx configuration includes:

- Laravel-specific URL rewriting
- Security headers (XSS, CSRF, etc.)
- Gzip compression
- Static asset caching
- PHP-FPM integration
- Optional SSL/HTTPS support

## Database Setup

Automatically creates:
- MySQL database with UTF8MB4 charset
- Database user with full privileges
- Secure password authentication

## Laravel Configuration

Automatically handles:
- `.env` file creation and management
- Shared storage directory linking
- Application key generation
- Database migrations
- Composer dependency installation
- Laravel optimizations (config cache, route cache, view cache)

## Site Removal

```bash
sudo ./remove-laravel.sh [OPTIONS]

Options:
  --site-name NAME          Site to remove (required)
  --keep-database          Preserve database and user
  --keep-files             Backup files instead of deleting
  --force                  Skip confirmation prompts
  --verbose                Show detailed output
```

### Removal Examples

```bash
# Complete removal
sudo ./remove-laravel.sh --site-name myapp

# Keep database for migration
sudo ./remove-laravel.sh --site-name myapp --keep-database

# Backup files before removal
sudo ./remove-laravel.sh --site-name myapp --keep-files
```

## Post-Deployment

After successful deployment:

1. **DNS Configuration**: Point your domain to the server
2. **Environment Variables**: Review `/var/www/SITE_NAME/shared/.env`
3. **SSL Certificates**: Install certificates if using `--ssl`
4. **Additional Setup**: Run any custom Laravel commands:

```bash
cd /var/www/SITE_NAME/current
sudo -u www-data php artisan migrate
sudo -u www-data php artisan db:seed
sudo -u www-data php artisan queue:work --daemon
```

## File Locations

- **Document Root**: `/var/www/SITE_NAME/current/public`
- **Environment**: `/var/www/SITE_NAME/shared/.env`
- **Nginx Config**: `/etc/nginx/sites-available/SITE_NAME`
- **Logs**: `/var/log/nginx/SITE_NAME_*.log`
- **SSL Certs**: `/etc/ssl/certs/DOMAIN.crt` (if SSL enabled)

## Security Features

- Denies access to hidden files (`.env`, `.git`, etc.)
- Security headers for XSS and clickjacking protection
- Runs PHP processes as `www-data` user
- Proper file permissions (644 for files, 755 for directories)
- Database users with minimal required privileges

## Troubleshooting

### Common Issues

**Permission Errors**
```bash
sudo chown -R www-data:www-data /var/www/SITE_NAME
sudo chmod -R 755 /var/www/SITE_NAME
sudo chmod -R 775 /var/www/SITE_NAME/shared/storage
```

**Database Connection Issues**
```bash
# Test database connection
mysql -u SITE_USER -p SITE_DATABASE
```

**Nginx Configuration Issues**
```bash
# Test configuration
sudo nginx -t

# Check logs
sudo tail -f /var/log/nginx/SITE_NAME_error.log
```

**Laravel Issues**
```bash
cd /var/www/SITE_NAME/current

# Clear all caches
sudo -u www-data php artisan cache:clear
sudo -u www-data php artisan config:clear
sudo -u www-data php artisan route:clear
sudo -u www-data php artisan view:clear

# Regenerate caches
sudo -u www-data php artisan config:cache
sudo -u www-data php artisan route:cache
sudo -u www-data php artisan view:cache
```

## GitHub Integration

### Public Repositories
Use HTTPS URLs:
```bash
--github-repo https://github.com/user/repo.git
```

### Private Repositories
Set up SSH keys for the root user:
```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "server@domain.com"

# Add public key to GitHub
cat ~/.ssh/id_ed25519.pub

# Use SSH URLs
--github-repo git@github.com:user/private-repo.git
```

## Advanced Usage

### Custom Environment Variables
Edit the environment file after deployment:
```bash
sudo nano /var/www/SITE_NAME/shared/.env
```

### Manual Deployments
Re-run the deployment script with the same parameters to deploy updates:
```bash
sudo ./deploy-laravel.sh --site-name myapp --domain myapp.com --github-repo https://github.com/user/myapp.git
```

### Rollback to Previous Release
```bash
cd /var/www/SITE_NAME
sudo rm current
sudo ln -sf releases/PREVIOUS_RELEASE current
sudo systemctl reload nginx
```

## Performance Optimization

The deployment automatically applies Laravel optimizations:
- Composer autoloader optimization
- Configuration caching
- Route caching
- View compilation
- OPcache enabled (via LEMP stack)

For additional performance:
- Consider Redis for sessions/cache
- Enable Laravel Horizon for queues
- Use CDN for static assets
- Implement database indexing

## Support

This tool is designed to work with the companion LEMP stack installer. For best results:

1. Install LEMP stack first: `../lemp-deployer/install.sh`
2. Deploy Laravel sites: `./deploy-laravel.sh`
3. Manage sites: `./remove-laravel.sh`