#!/usr/bin/env python3
"""
Secure password generator for Ansible vault variables
Usage: python3 generate_passwords.py
"""

import secrets
import string
import hashlib
import crypt
import getpass

def generate_password(length=16, complexity='high'):
    """Generate a secure random password"""
    if complexity == 'high':
        characters = string.ascii_letters + string.digits + "!@#$%^&*"
    elif complexity == 'medium':
        characters = string.ascii_letters + string.digits
    else:
        characters = string.ascii_letters + string.digits
    
    return ''.join(secrets.choice(characters) for _ in range(length))

def generate_salt():
    """Generate a random salt for password hashing"""
    return secrets.token_urlsafe(32)

def hash_password(password):
    """Generate Apache-compatible password hash"""
    return crypt.crypt(password, crypt.mksalt(crypt.METHOD_SHA512))

def main():
    print("🔐 Laravel Development Environment - Password Generator")
    print("=" * 60)
    
    passwords = {}
    
    # Generate all required passwords
    passwords['mysql_root'] = generate_password(20, 'high')
    passwords['postgres'] = generate_password(20, 'high')
    passwords['adminer'] = generate_password(16, 'medium')
    passwords['laravel_db'] = generate_password(16, 'medium')
    passwords['app_key'] = f"base64:{secrets.token_urlsafe(32)}"
    passwords['jwt_secret'] = secrets.token_urlsafe(64)
    passwords['backup_key'] = secrets.token_urlsafe(32)
    
    print("\n🎲 Generated Passwords:")
    print("-" * 40)
    for key, password in passwords.items():
        print(f"{key:15}: {password}")
    
    # Generate hashed version for Adminer
    adminer_hash = hash_password(passwords['adminer'])
    
    print(f"\n🔒 Hashed Passwords:")
    print("-" * 40)
    print(f"adminer_hash   : {adminer_hash}")
    
    print(f"\n📝 Vault File Template:")
    print("-" * 40)
    vault_content = f"""---
# Encrypted vault file - create with: ansible-vault create group_vars/vault.yml

vault_mysql_root_password: "{passwords['mysql_root']}"
vault_postgres_password: "{passwords['postgres']}"
vault_adminer_password: "{passwords['adminer']}"
vault_adminer_password_hash: "{adminer_hash}"
vault_laravel_db_password: "{passwords['laravel_db']}"
vault_app_key: "{passwords['app_key']}"
vault_jwt_secret: "{passwords['jwt_secret']}"
vault_backup_encryption_key: "{passwords['backup_key']}"

vault_adminer_user: "dbadmin"

vault_db_users:
  - name: "laravel_user"
    password: "{passwords['laravel_db']}"
    privileges: "SELECT,INSERT,UPDATE,DELETE,CREATE,ALTER,INDEX,DROP"
"""
    
    print(vault_content)
    
    # Save to file
    save = input("\n💾 Save vault template to file? (y/N): ").lower()
    if save == 'y':
        with open('vault_template.yml', 'w') as f:
            f.write(vault_content)
        print("✅ Saved to vault_template.yml")
        print("\n🔧 Next steps:")
        print("1. ansible-vault create group_vars/vault.yml")
        print("2. Copy content from vault_template.yml into the vault")
        print("3. Delete vault_template.yml for security")
        print("4. Use --ask-vault-pass when running playbooks")

if __name__ == "__main__":
    main()