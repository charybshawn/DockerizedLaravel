#!/usr/bin/env python3
"""
Custom Ansible filter plugins for input validation
"""

import re
import ipaddress
from urllib.parse import urlparse

class FilterModule(object):
    """Custom filters for Laravel environment setup"""
    
    def filters(self):
        return {
            'validate_php_version': self.validate_php_version,
            'validate_database_name': self.validate_database_name,
            'validate_domain_name': self.validate_domain_name,
            'validate_port': self.validate_port,
            'validate_git_url': self.validate_git_url,
            'validate_password_strength': self.validate_password_strength,
            'sanitize_input': self.sanitize_input,
            'validate_email': self.validate_email
        }
    
    def validate_php_version(self, version):
        """Validate PHP version format (e.g., 8.1, 8.2, 8.3, 8.4)"""
        if not isinstance(version, str):
            return False
        
        pattern = r'^[78]\.[0-9]$'
        return bool(re.match(pattern, version))
    
    def validate_database_name(self, name):
        """Validate database name (alphanumeric + underscore, no spaces)"""
        if not isinstance(name, str) or len(name) == 0:
            return False
        
        if len(name) > 64:  # MySQL limit
            return False
        
        pattern = r'^[a-zA-Z0-9_]+$'
        return bool(re.match(pattern, name))
    
    def validate_domain_name(self, domain):
        """Validate domain name format"""
        if not isinstance(domain, str) or len(domain) == 0:
            return False
        
        if len(domain) > 253:
            return False
        
        # Allow localhost and .local domains for development
        pattern = r'^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$'
        return bool(re.match(pattern, domain))
    
    def validate_port(self, port):
        """Validate port number (1-65535, avoid reserved ports)"""
        try:
            port_int = int(port)
        except (ValueError, TypeError):
            return False
        
        if port_int < 1 or port_int > 65535:
            return False
        
        # Warn about reserved ports but don't block them for development
        reserved_ports = [22, 25, 53, 80, 110, 143, 443, 993, 995]
        if port_int in reserved_ports and port_int not in [80, 443]:
            # Allow 80 and 443 for web servers
            return False
        
        return True
    
    def validate_git_url(self, url):
        """Validate Git repository URL"""
        if not isinstance(url, str) or len(url) == 0:
            return False
        
        # Support HTTP(S) and SSH URLs
        patterns = [
            r'^https?://[^\s/$.?#].[^\s]*\.git$',  # HTTPS
            r'^git@[^\s/$.?#].[^\s]*:[^\s]*\.git$',  # SSH
            r'^https?://github\.com/[^/]+/[^/]+/?$',  # GitHub without .git
            r'^https?://gitlab\.com/[^/]+/[^/]+/?$',  # GitLab without .git
        ]
        
        return any(re.match(pattern, url) for pattern in patterns)
    
    def validate_password_strength(self, password):
        """Validate password strength"""
        if not isinstance(password, str):
            return False
        
        if len(password) < 8:
            return False
        
        # Check for at least one uppercase, lowercase, and digit
        if not re.search(r'[A-Z]', password):
            return False
        if not re.search(r'[a-z]', password):
            return False
        if not re.search(r'\d', password):
            return False
        
        return True
    
    def sanitize_input(self, input_str):
        """Sanitize user input to prevent injection"""
        if not isinstance(input_str, str):
            return str(input_str)
        
        # Remove potentially dangerous characters
        dangerous_chars = ['`', '$', '|', '&', ';', '(', ')', '{', '}', '<', '>']
        sanitized = input_str
        
        for char in dangerous_chars:
            sanitized = sanitized.replace(char, '')
        
        return sanitized.strip()
    
    def validate_email(self, email):
        """Basic email validation"""
        if not isinstance(email, str):
            return False
        
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        return bool(re.match(pattern, email))