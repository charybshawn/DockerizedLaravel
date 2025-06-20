# Laravel Development Environment - Operations Guide

## Table of Contents

1. [System Architecture](#1-system-architecture)
2. [Installation Procedures](#2-installation-procedures)
3. [Configuration Management](#3-configuration-management)
4. [Operational Procedures](#4-operational-procedures)
5. [Monitoring and Health Checks](#5-monitoring-and-health-checks)
6. [Backup and Recovery](#6-backup-and-recovery)
7. [Troubleshooting Guide](#7-troubleshooting-guide)
8. [Security Policies](#8-security-policies)
9. [Change Management](#9-change-management)
10. [Support Procedures](#10-support-procedures)

---

## 1. System Architecture

### 1.1 Component Overview

The Laravel Development Environment consists of the following primary components:

- **Web Server**: Nginx (latest stable)
- **Application Runtime**: PHP-FPM (versions 7.4, 8.0, 8.1, 8.2, 8.3, 8.4)
- **Database Servers**: MySQL 8.0, PostgreSQL 13+, SQLite 3
- **Cache/Session**: Redis (optional)
- **Package Management**: Composer 2.x, npm/yarn
- **Process Management**: systemd
- **Configuration Management**: Ansible 2.9+

### 1.2 Directory Structure

```
/
├── etc/
│   ├── nginx/                    # Nginx configuration
│   │   ├── sites-available/      # Site configurations
│   │   └── sites-enabled/        # Active site symlinks
│   └── php/                      # PHP configurations by version
├── var/
│   ├── www/                      # Web root for all sites
│   │   └── [site-name]/          # Individual site directories
│   ├── lib/nginx/sites/          # Site metadata and status
│   ├── log/
│   │   ├── nginx/                # Nginx logs
│   │   └── laravel-env/          # System operation logs
│   └── backups/laravel-sites/    # Site backups
└── usr/local/bin/                # Management scripts
```

### 1.3 Network Architecture

- Default HTTP Port: 80
- Additional site ports: Configurable (8000-8999 recommended)
- Database ports: MySQL (3306), PostgreSQL (5432)
- Internal communication: Unix sockets for PHP-FPM

---

## 2. Installation Procedures

### 2.1 Prerequisites

**System Requirements:**
- Operating System: Ubuntu 20.04+ or Debian 10+
- CPU: Minimum 2 cores
- Memory: Minimum 2GB RAM
- Storage: Minimum 10GB available
- Network: Internet connectivity for package installation

### 2.2 Installation Process

#### Full Installation
```bash
sudo ./laravel-env-installer --mode full
```

#### Custom Installation
```bash
sudo ./laravel-env-installer --mode custom --config custom.yml
```

#### Validation Only
```bash
sudo ./laravel-env-installer --mode validate
```

### 2.3 Post-Installation Verification

1. **Check system health:**
   ```bash
   sudo ./laravel-env-installer --mode health
   ```

2. **Verify service status:**
   ```bash
   systemctl status nginx
   systemctl status php8.3-fpm
   systemctl status mysql
   ```

3. **Review installation logs:**
   ```bash
   sudo tail -f /var/log/laravel-env/operations.log
   ```

---

## 3. Configuration Management

### 3.1 Configuration Files

**Primary configuration locations:**
- Ansible configuration: `ansible.cfg`
- Global variables: `group_vars/all.yml`
- Sensitive data: `group_vars/vault.yml` (encrypted)
- Inventory: `inventory/hosts.yml`

### 3.2 Managing Sensitive Data

**Create/Edit vault:**
```bash
ansible-vault create group_vars/vault.yml
ansible-vault edit group_vars/vault.yml
```

**Using vault in playbooks:**
```bash
ansible-playbook --ask-vault-pass playbook.yml
# or
ansible-playbook --vault-password-file .vault_pass playbook.yml
```

### 3.3 Configuration Validation

**Validate all configurations:**
```bash
sudo ./laravel-env-installer --mode validate
```

**Test specific configuration:**
```bash
ansible-playbook --syntax-check playbooks/setup_laravel_server_improved.yml
```

---

## 4. Operational Procedures

### 4.1 Site Management

#### Creating a Site
```bash
sudo ./laravel-site-manager create \
  --name myapp \
  --domain myapp.local \
  --port 8080 \
  --php-version 8.3
```

#### Creating from Git Repository
```bash
sudo ./laravel-site-manager create \
  --name myapp \
  --domain myapp.local \
  --git-repo https://github.com/user/myapp.git \
  --git-branch main
```

#### Listing Sites
```bash
# Table format (default)
sudo ./laravel-site-inventory

# JSON format
sudo ./laravel-site-inventory --format json

# CSV export
sudo ./laravel-site-inventory --format csv > sites.csv

# Detailed view
sudo ./laravel-site-inventory --format detailed
```

#### Managing Site State
```bash
# Enable site
sudo ./laravel-site-manager enable --name myapp

# Disable site
sudo ./laravel-site-manager disable --name myapp

# Delete site
sudo ./laravel-site-manager delete --name myapp --force
```

### 4.2 Service Management

#### Nginx Operations
```bash
# Test configuration
sudo nginx -t

# Reload configuration
sudo systemctl reload nginx

# Restart service
sudo systemctl restart nginx

# View logs
sudo tail -f /var/log/nginx/error.log
```

#### PHP-FPM Operations
```bash
# Restart specific version
sudo systemctl restart php8.3-fpm

# Check pool status
sudo systemctl status php8.3-fpm

# View PHP info
php8.3 -i
```

### 4.3 Database Operations

#### MySQL Management
```bash
# Access MySQL
sudo mysql -u root -p

# Create database
CREATE DATABASE myapp_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# Create user
CREATE USER 'myapp_user'@'localhost' IDENTIFIED BY 'secure_password';
GRANT ALL PRIVILEGES ON myapp_db.* TO 'myapp_user'@'localhost';
FLUSH PRIVILEGES;
```

#### PostgreSQL Management
```bash
# Access PostgreSQL
sudo -u postgres psql

# Create database
CREATE DATABASE myapp_db;

# Create user
CREATE USER myapp_user WITH ENCRYPTED PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE myapp_db TO myapp_user;
```

---

## 5. Monitoring and Health Checks

### 5.1 System Health Monitoring

**Run comprehensive health check:**
```bash
sudo ./laravel-env-installer --mode health
```

**Check specific service:**
```bash
# Nginx status
curl http://localhost/nginx_status

# PHP-FPM status
sudo systemctl status php*-fpm

# Database status
sudo systemctl status mysql postgresql
```

### 5.2 Log Monitoring

**System logs:**
```bash
# Operation logs
sudo tail -f /var/log/laravel-env/operations.log

# Error logs
sudo tail -f /var/log/laravel-env/error.log

# Audit logs
sudo tail -f /var/log/laravel-env/audit.log
```

**Application logs:**
```bash
# Nginx access logs
sudo tail -f /var/log/nginx/*_access.log

# Nginx error logs
sudo tail -f /var/log/nginx/*_error.log

# Laravel application logs
tail -f /var/www/[site-name]/storage/logs/laravel.log
```

### 5.3 Performance Monitoring

**Resource usage:**
```bash
# CPU and memory
htop

# Disk usage
df -h

# Network connections
ss -tulnp
```

**Site performance:**
```bash
# Test site response
curl -w "@curl-format.txt" -o /dev/null -s http://site.local

# Load test (requires ab)
ab -n 1000 -c 10 http://site.local/
```

---

## 6. Backup and Recovery

### 6.1 Backup Procedures

#### Manual Site Backup
```bash
sudo ./laravel-site-manager backup --name myapp
```

#### Automated Backups
Create cron job:
```bash
# Edit crontab
sudo crontab -e

# Add daily backup at 2 AM
0 2 * * * /path/to/laravel-site-manager backup --name myapp
```

### 6.2 Backup Storage

**Default location:** `/var/backups/laravel-sites/[site-name]/`

**Backup contents:**
- Application code
- Nginx configuration
- Site metadata
- Database export (if configured)

### 6.3 Recovery Procedures

#### Restore from Backup
```bash
# List available backups
ls -la /var/backups/laravel-sites/myapp/

# Extract backup
cd /var/www
sudo tar -xzf /var/backups/laravel-sites/myapp/backup_20240315_143022.tar.gz

# Restore Nginx config
sudo cp /var/backups/laravel-sites/myapp/backup_20240315_143022_nginx.conf \
       /etc/nginx/sites-available/myapp

# Enable site
sudo ./laravel-site-manager enable --name myapp
```

---

## 7. Troubleshooting Guide

### 7.1 Common Issues

#### Site Not Accessible

**Diagnosis:**
```bash
# Check if Nginx is running
sudo systemctl status nginx

# Test Nginx configuration
sudo nginx -t

# Check if site is enabled
ls -la /etc/nginx/sites-enabled/

# Check port availability
sudo lsof -i :80
```

**Resolution:**
1. Ensure Nginx is running: `sudo systemctl start nginx`
2. Fix configuration errors shown by `nginx -t`
3. Enable site: `sudo ./laravel-site-manager enable --name myapp`
4. Check firewall: `sudo ufw status`

#### PHP Errors

**Diagnosis:**
```bash
# Check PHP-FPM status
sudo systemctl status php8.3-fpm

# View PHP error log
sudo tail -f /var/log/php8.3-fpm.log

# Test PHP processing
echo "<?php phpinfo(); ?>" | sudo tee /var/www/test.php
curl http://localhost/test.php
```

**Resolution:**
1. Restart PHP-FPM: `sudo systemctl restart php8.3-fpm`
2. Check socket permissions: `ls -la /run/php/`
3. Verify PHP extensions: `php8.3 -m`

#### Database Connection Issues

**Diagnosis:**
```bash
# Test MySQL connection
mysql -u root -p -e "SELECT 1"

# Test PostgreSQL connection
sudo -u postgres psql -c "SELECT 1"

# Check Laravel database config
cat /var/www/myapp/.env | grep DB_
```

**Resolution:**
1. Verify database service is running
2. Check credentials in `.env` file
3. Test connection manually
4. Review Laravel logs

### 7.2 Error Logs

**Key log locations:**
- System operations: `/var/log/laravel-env/operations.log`
- System errors: `/var/log/laravel-env/error.log`
- Nginx errors: `/var/log/nginx/error.log`
- PHP errors: `/var/log/php*.log`
- Laravel errors: `/var/www/[site]/storage/logs/laravel.log`

### 7.3 Debug Mode

**Enable debug output:**
```bash
# For scripts
export LOG_LEVEL=0  # Debug level

# For Ansible
ansible-playbook -vvv playbook.yml

# For Laravel
# Edit .env file
APP_DEBUG=true
```

---

## 8. Security Policies

### 8.1 Access Control

**File Permissions:**
- Web directories: 755
- Application files: 644
- Sensitive files (.env): 600
- Log files: 644

**Service Users:**
- Nginx: www-data
- PHP-FPM: www-data
- MySQL: mysql
- PostgreSQL: postgres

### 8.2 Security Best Practices

1. **Regular Updates:**
   ```bash
   sudo apt update && sudo apt upgrade
   ```

2. **Firewall Configuration:**
   ```bash
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw enable
   ```

3. **Secure Passwords:**
   - Use password generator: `python3 scripts/generate_passwords.py`
   - Store in Ansible vault
   - Rotate regularly

4. **SSL/TLS (Production):**
   ```bash
   sudo certbot --nginx -d example.com
   ```

### 8.3 Audit Procedures

**Review audit logs:**
```bash
sudo tail -f /var/log/laravel-env/audit.log
```

**Audit log format:**
```json
{
  "timestamp": "2024-03-15 14:30:22",
  "user": "admin",
  "action": "site_create",
  "resource": "myapp",
  "result": "success",
  "details": "domain=myapp.local,port=80"
}
```

---

## 9. Change Management

### 9.1 Change Procedures

1. **Plan Change:**
   - Document proposed changes
   - Assess impact
   - Schedule maintenance window

2. **Test Change:**
   - Apply to test environment
   - Validate functionality
   - Document results

3. **Implement Change:**
   - Create backup
   - Apply change
   - Verify success
   - Update documentation

### 9.2 Version Control

**Track configuration changes:**
```bash
cd /path/to/ansible-project
git add .
git commit -m "Update: Description of change"
git push origin main
```

### 9.3 Rollback Procedures

**Site rollback:**
```bash
# Restore from backup
sudo ./laravel-site-manager restore --name myapp --backup [backup-id]
```

**System rollback:**
```bash
# Revert Ansible changes
git checkout [previous-commit]
ansible-playbook playbooks/setup_laravel_server_improved.yml
```

---

## 10. Support Procedures

### 10.1 Support Levels

**Level 1 - Basic Operations:**
- Site creation/deletion
- Service restart
- Log review

**Level 2 - Advanced Operations:**
- Configuration changes
- Performance tuning
- Security updates

**Level 3 - System Administration:**
- Infrastructure changes
- Major upgrades
- Disaster recovery

### 10.2 Escalation Procedures

1. Check documentation and guides
2. Review error logs
3. Search knowledge base
4. Contact system administrator
5. Open support ticket

### 10.3 Documentation

**Available documentation:**
- `README.md` - Project overview
- `OPERATIONS_GUIDE.md` - This guide
- `NGINX_GUIDE.md` - Nginx configuration details
- `SECURITY.md` - Security guidelines
- Inline help: `[command] --help`

### 10.4 Maintenance Schedule

**Daily:**
- Monitor system health
- Review error logs
- Check disk space

**Weekly:**
- Update system packages
- Review security logs
- Backup verification

**Monthly:**
- Performance review
- Security audit
- Documentation update

---

## Appendix A: Quick Reference

### Common Commands

```bash
# Installation
sudo ./laravel-env-installer --mode full

# Site Management
sudo ./laravel-site-manager create --name myapp --domain myapp.local
sudo ./laravel-site-manager delete --name myapp
sudo ./laravel-site-manager status --name myapp

# Monitoring
sudo ./laravel-site-inventory
sudo ./laravel-env-installer --mode health

# Logs
sudo tail -f /var/log/laravel-env/operations.log
sudo tail -f /var/log/nginx/*_error.log

# Services
sudo systemctl restart nginx
sudo systemctl restart php8.3-fpm
sudo systemctl status mysql
```

### File Locations

- Configuration: `/etc/nginx/sites-available/[site]`
- Web root: `/var/www/[site]/`
- Logs: `/var/log/nginx/[site]_*.log`
- Backups: `/var/backups/laravel-sites/[site]/`
- Site info: `/var/lib/nginx/sites/[site]/`

---

*Document Version: 2.0*  
*Last Updated: March 2024*  
*Copyright: Laravel Development Environment Project*