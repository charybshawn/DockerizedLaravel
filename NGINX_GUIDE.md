# Nginx Configuration Guide for Laravel Development Environment

## Overview

This guide explains the comprehensive Nginx configuration system implemented in this Ansible-based Laravel development environment, including site management, configuration tracking, and detailed output information.

## 🏗️ Architecture Overview

### Configuration Structure

```
/etc/nginx/
├── nginx.conf                    # Main Nginx configuration (optimized)
├── sites-available/              # Available site configurations
│   ├── sitename                  # Individual Laravel site configs
│   ├── adminer                   # Database manager
│   └── status                    # Nginx monitoring
├── sites-enabled/                # Enabled sites (symlinks)
└── mime.types                    # MIME type definitions

/var/lib/nginx/sites/             # Site information tracking
├── sitename/
│   ├── summary.txt               # Detailed site information
│   └── status.env                # Machine-readable site status
└── installation_summary.txt      # Nginx installation details

/var/log/nginx/                   # Logging
├── access.log                    # Global access log
├── error.log                     # Global error log
├── sites/                        # Site-specific logs
├── sitename_access.log           # Per-site access logs
└── sitename_error.log            # Per-site error logs
```

## 🚀 Features

### 1. **Optimized Main Configuration**

The `nginx.conf` provides:
- **Performance Optimizations**: Worker processes, connections, and buffering
- **Security Headers**: X-Frame-Options, X-Content-Type-Options, etc.
- **Gzip Compression**: Optimized for web assets
- **Rate Limiting**: Protection against abuse
- **SSL/TLS Ready**: Pre-configured for future SSL implementation

### 2. **Laravel-Optimized Site Configuration**

Each Laravel site includes:
- **Vite Asset Support**: Optimized handling for Laravel Vite builds
- **Static Asset Caching**: Long-term caching for CSS, JS, images
- **Security Protection**: Hidden files, sensitive directories blocked
- **PHP-FPM Integration**: Optimized FastCGI configuration
- **Health Check Endpoints**: Built-in `/health` endpoint
- **Site-Specific Logging**: Individual access and error logs

### 3. **Comprehensive Site Tracking**

Every site creates:
- **Configuration Summary**: Human-readable site details
- **Status File**: Machine-readable configuration data
- **Access Information**: URLs, paths, and quick commands
- **Technical Details**: PHP version, database info, Git repository

### 4. **Monitoring and Status**

Built-in monitoring includes:
- **Nginx Status Page**: `/nginx_status` endpoint
- **Health Checks**: `/health` endpoints for each site
- **Server Information**: `/server-info` for debugging
- **Service Status Tracking**: Real-time service monitoring

## 📋 Site Information Tracking

### Where Site Information is Stored

1. **Primary Configuration**: `/etc/nginx/sites-available/[sitename]`
2. **Site Summary**: `/var/lib/nginx/sites/[sitename]/summary.txt`
3. **Status Data**: `/var/lib/nginx/sites/[sitename]/status.env`
4. **Logs**: `/var/log/nginx/[sitename]_*.log`

### Site Summary Contents

Each site summary includes:
- **Access Information**: URLs, ports, document root
- **Configuration Files**: Nginx config, Laravel .env, etc.
- **Technical Details**: PHP version, database configuration
- **Git Repository**: Repository URL, branch, auto-update settings
- **Logging Paths**: Access logs, error logs, Laravel logs
- **Quick Commands**: Testing, monitoring, and maintenance commands
- **Troubleshooting**: Common debugging steps

### Example Site Summary Output

```
🎉 Laravel Site 'myapp' Created Successfully!
=====================================================

🌐 Access Information:
- Primary URL: http://myapp.local/
- IP Access: http://192.168.1.100/
- Document Root: /var/www/myapp/public

🔧 Configuration Files:
- Nginx Config: /etc/nginx/sites-available/myapp
- Nginx Enabled: /etc/nginx/sites-enabled/myapp
- Laravel .env: /var/www/myapp/.env
- Site Summary: /var/lib/nginx/sites/myapp/summary.txt

📊 Technical Details:
- PHP Version: 8.3
- PHP-FPM Socket: /run/php/php8.3-fmp.sock
- Git Repository: https://github.com/user/myapp.git
- Branch: main

🗄️ Database Configuration:
- Connection: mysql
- Database: myapp
- Host: 127.0.0.1
- Port: 3306

📈 Logging:
- Access Log: /var/log/nginx/myapp_access.log
- Error Log: /var/log/nginx/myapp_error.log

🚀 Quick Commands:
- Test site: curl -H "Host: myapp.local" http://localhost/
- View logs: tail -f /var/log/nginx/myapp_*.log
- Laravel commands: cd /var/www/myapp && php artisan <command>
- Update site: git pull && composer install

📝 Next Steps:
1. Add '127.0.0.1 myapp.local' to your hosts file
2. Visit http://myapp.local/ to see your Laravel application
3. Configure your Laravel .env file for database connections
4. Run migrations: cd /var/www/myapp && php artisan migrate
```

## 🔧 Site Management Commands

### View All Sites

```bash
sudo ./scripts/list_sites.sh
```

This shows:
- System status (Nginx, PHP-FPM)
- All configured sites with status
- Configuration validity
- Quick management commands

### Create New Site

```bash
sudo ./setup-site.sh
# or
ansible-playbook playbooks/manage_laravel_sites.yml
```

### Check Site Configuration

```bash
# Test Nginx configuration
sudo nginx -t

# Check specific site config
sudo nginx -t -c /etc/nginx/sites-available/sitename

# View site summary
cat /var/lib/nginx/sites/sitename/summary.txt

# Check site status
source /var/lib/nginx/sites/sitename/status.env
echo "Site: $SITE_NAME, Status: $STATUS, Domain: $DOMAIN"
```

### Monitor Site Logs

```bash
# Real-time access logs
sudo tail -f /var/log/nginx/sitename_access.log

# Real-time error logs
sudo tail -f /var/log/nginx/sitename_error.log

# All site logs
sudo tail -f /var/log/nginx/*_*.log

# Laravel application logs
tail -f /var/www/sitename/storage/logs/laravel.log
```

## 🔍 Better Output Information

### During Site Creation

The enhanced Laravel site role now provides:

1. **Step-by-Step Progress**: Each major step shows progress with emoji indicators
2. **Configuration Details**: Shows exactly what's being configured
3. **File Locations**: Lists all created files and their purposes
4. **Access Information**: Provides URLs and connection details
5. **Quick Commands**: Ready-to-use commands for testing and management
6. **Next Steps**: Clear guidance on what to do after site creation

### System-Wide Information

The improved setup script shows:

1. **Service Status**: Real-time status of all services
2. **Performance Metrics**: System load, memory, disk usage
3. **Network Information**: IP addresses, ports, URLs
4. **Security Status**: Firewall, authentication, SSL status
5. **Installation Summary**: Complete list of installed components

## 🛠️ Nginx Role Features

### Performance Optimizations

```nginx
# Worker configuration
worker_processes auto;
worker_connections 1024;
worker_rlimit_nofile 65535;

# Performance settings
sendfile on;
tcp_nopush on;
tcp_nodelay on;
keepalive_timeout 65;

# Compression
gzip on;
gzip_comp_level 6;
gzip_min_length 1000;
```

### Security Features

```nginx
# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;

# Hide sensitive files
location ~ /\.(?!well-known) {
    deny all;
}

# Rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
```

### Laravel-Specific Features

```nginx
# Vite asset handling
location /build/ {
    expires 1M;
    add_header Cache-Control "public, immutable";
}

# Laravel health check
location = /health {
    return 200 "OK\n";
    add_header Content-Type text/plain;
}

# Protected directories
location ^~ /storage/ {
    deny all;
}
```

## 📊 Monitoring and Health Checks

### Built-in Endpoints

- **Nginx Status**: `http://localhost/nginx_status`
- **Health Check**: `http://sitename.local/health`
- **Server Info**: `http://localhost/server-info`

### Log Analysis

```bash
# Check for errors
sudo grep "ERROR" /var/log/nginx/error.log

# Monitor access patterns
sudo tail -f /var/log/nginx/access.log | grep -v "\.css\|\.js\|\.png\|\.jpg"

# Check site-specific issues
sudo grep "5xx" /var/log/nginx/sitename_access.log
```

### Performance Monitoring

```bash
# Check Nginx status
curl http://localhost/nginx_status

# Monitor connections
ss -tulnp | grep :80

# Check PHP-FPM status
sudo systemctl status php8.3-fpm
```

## 🔄 Site Lifecycle Management

### Creation Process

1. **Site Directory**: Created with proper permissions
2. **Laravel Installation**: Fresh install or Git clone
3. **Nginx Configuration**: Generated from optimized template
4. **PHP-FPM Integration**: Configured for specific PHP version
5. **Database Setup**: Optional database creation
6. **Information Tracking**: Summary and status files created
7. **Service Integration**: Nginx reloaded with new configuration

### Maintenance Operations

1. **Updates**: Git pull, Composer install, asset compilation
2. **Monitoring**: Log analysis, health checks, performance metrics
3. **Backup**: Configuration files, database, application code
4. **Security**: SSL certificate management, access control

## 🚀 Quick Start Examples

### View Current Sites

```bash
sudo ./scripts/list_sites.sh
```

### Create a New Site

```bash
sudo ./setup-site.sh
# Follow interactive prompts for site configuration
```

### Check Site Details

```bash
# View detailed summary
cat /var/lib/nginx/sites/mysite/summary.txt

# Check if site is working
curl -H "Host: mysite.local" http://localhost/health
```

### Monitor Site Activity

```bash
# Watch access logs in real-time
sudo tail -f /var/log/nginx/mysite_access.log

# Check for errors
sudo tail -f /var/log/nginx/mysite_error.log
```

This comprehensive Nginx management system provides complete visibility into your Laravel development environment with detailed tracking, monitoring, and easy management of multiple sites.