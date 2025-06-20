# Security Guidelines for Laravel Development Environment

## Overview

This document outlines the security measures implemented in this Ansible-based Laravel development environment and provides guidelines for secure usage.

## Security Features Implemented

### 1. Credential Management
- **Ansible Vault**: All sensitive variables are encrypted using Ansible Vault
- **Password Generation**: Secure random password generation with complexity requirements
- **No Hardcoded Secrets**: All default passwords replaced with vault variables

### 2. Privilege Management
- **Least Privilege**: Tasks run with minimal required privileges
- **Selective Escalation**: `become: yes` only used when root access is necessary
- **User Context**: Proper user/group ownership for files and directories

### 3. Input Validation
- **Custom Filters**: Comprehensive input validation filters
- **Sanitization**: User inputs are sanitized to prevent injection attacks
- **Format Validation**: Domain names, ports, URLs, and database names are validated

### 4. Network Security
- **Firewall Configuration**: UFW firewall rules for production environments
- **Service Binding**: Services bound to localhost where appropriate
- **Port Management**: Non-standard ports for development services

### 5. File System Security
- **Proper Permissions**: Correct file and directory permissions
- **Ownership Management**: Appropriate user/group ownership
- **Log File Security**: Secure log file locations and permissions

## Security Configuration

### Vault Setup

1. **Create Vault Password File** (optional):
   ```bash
   echo "your-vault-password" > .vault_pass
   chmod 600 .vault_pass
   ```

2. **Create Encrypted Vault**:
   ```bash
   ansible-vault create group_vars/vault.yml
   ```

3. **Generate Secure Passwords**:
   ```bash
   python3 scripts/generate_passwords.py
   ```

### Running Playbooks Securely

1. **With Vault Password Prompt**:
   ```bash
   ansible-playbook --ask-vault-pass playbooks/setup_laravel_server_improved.yml
   ```

2. **With Vault Password File**:
   ```bash
   ansible-playbook --vault-password-file .vault_pass playbooks/setup_laravel_server_improved.yml
   ```

3. **Tags for Selective Execution**:
   ```bash
   ansible-playbook --ask-vault-pass --tags "php,mysql" playbooks/setup_laravel_server_improved.yml
   ```

## Security Checklist

### Before Deployment
- [ ] Generate unique passwords for all services
- [ ] Review and customize vault variables
- [ ] Verify input validation is enabled
- [ ] Check firewall rules for production
- [ ] Ensure SSH key authentication is configured

### After Deployment
- [ ] Run health checks
- [ ] Verify service configurations
- [ ] Test authentication mechanisms
- [ ] Review log files for errors
- [ ] Confirm proper file permissions

### Ongoing Security
- [ ] Regularly update system packages
- [ ] Monitor service logs
- [ ] Rotate passwords periodically
- [ ] Review user access
- [ ] Update Ansible and roles

## Security Best Practices

### Development Environment
1. **Network Isolation**: Use private networks or VPNs
2. **Regular Updates**: Keep all components updated
3. **Access Control**: Limit access to development servers
4. **Data Protection**: Don't use production data in development

### Production Considerations
1. **SSL/TLS**: Enable HTTPS with valid certificates
2. **Database Security**: Use dedicated database users with limited privileges
3. **Backup Encryption**: Encrypt backup files
4. **Monitoring**: Implement security monitoring and alerting

### Password Management
1. **Complexity**: Use strong, unique passwords
2. **Storage**: Store passwords securely in vault
3. **Rotation**: Rotate passwords regularly
4. **Access**: Limit access to vault passwords

## Incident Response

### Security Breach Response
1. **Immediate Actions**:
   - Disconnect affected systems
   - Change all passwords
   - Review access logs
   - Document the incident

2. **Investigation**:
   - Analyze log files
   - Identify attack vectors
   - Assess data exposure
   - Review security controls

3. **Recovery**:
   - Patch vulnerabilities
   - Restore from clean backups
   - Update security measures
   - Monitor for persistence

## Reporting Security Issues

If you discover a security vulnerability:

1. **Do Not** create a public GitHub issue
2. Contact the maintainers privately
3. Provide detailed information about the vulnerability
4. Allow time for patches before public disclosure

## Security Resources

- [Ansible Security Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html#best-practices-for-variables-and-vaults)
- [OWASP Development Guide](https://owasp.org/www-project-developer-guide/)
- [Laravel Security Best Practices](https://laravel.com/docs/security)
- [MySQL Security Guidelines](https://dev.mysql.com/doc/refman/8.0/en/general-security-issues.html)

## Compliance Notes

This configuration implements security controls that align with:
- OWASP Application Security Guidelines
- CIS Benchmarks for Linux
- Laravel Security Best Practices
- Industry standard password policies

Remember: Security is an ongoing process, not a one-time configuration.