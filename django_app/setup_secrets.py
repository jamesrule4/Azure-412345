#!/usr/bin/env python3
"""
Django Environment Setup Script
Retrieves secrets from Azure Key Vault and sets up Django environment
"""

import os
import sys
import subprocess
import json
from pathlib import Path

def run_command(cmd, check=True):
    """Run a shell command and return the result"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, check=check)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Command failed: {cmd}")
        print(f"Error: {e.stderr}")
        if check:
            raise
        return None

def get_azure_secret(vault_name, secret_name):
    """Retrieve a secret from Azure Key Vault"""
    try:
        # Use managed identity to authenticate
        cmd = f"az keyvault secret show --vault-name {vault_name} --name {secret_name} --query value -o tsv"
        secret = run_command(cmd)
        return secret
    except Exception as e:
        print(f"Failed to retrieve secret {secret_name}: {e}")
        return None

def setup_environment():
    """Setup Django environment with secrets from Key Vault"""
    
    # Get Key Vault name from environment or metadata
    vault_name = os.environ.get('KEY_VAULT_NAME')
    if not vault_name:
        # Try to get from Azure metadata
        try:
            # Get the workspace from hostname or other method
            hostname = run_command("hostname")
            if "poc1" in hostname:
                workspace = "poc1"
            elif "poc2" in hostname:
                workspace = "poc2"
            elif "poc3" in hostname:
                workspace = "poc3"
            else:
                workspace = "poc1"  # default
            
            # Try to find the key vault
            vaults = run_command(f"az keyvault list --query \"[?contains(name, '{workspace}')].name\" -o tsv")
            if vaults:
                vault_name = vaults.split('\n')[0]
        except:
            print("Could not determine Key Vault name")
            return False
    
    if not vault_name:
        print("Key Vault name not found")
        return False
    
    print(f"Using Key Vault: {vault_name}")
    
    # Define secrets to retrieve
    secrets = {
        'DJANGO_SECRET_KEY': 'django-secret-key-1',
        'DJANGO_ADMIN_PASSWORD': 'django-admin-password-1',
        'DOMAIN_ADMIN_PASSWORD': 'domain-admin-password-1',
        'LDAP_BIND_PASSWORD': 'ldap-bind-password-1'
    }
    
    # Retrieve secrets
    env_vars = {}
    for env_name, secret_name in secrets.items():
        secret_value = get_azure_secret(vault_name, secret_name)
        if secret_value:
            env_vars[env_name] = secret_value
            print(f"Retrieved {env_name}")
        else:
            print(f"Failed to retrieve {env_name}")
            return False
    
    # Add other environment variables
    env_vars.update({
        'DJANGO_DEBUG': 'False',
        'DJANGO_ALLOWED_HOSTS': '*',
        'LDAP_SERVER_URI': 'ldap://10.1.1.10:389',
        'LDAP_BIND_DN': 'django@rule4.local',
        'LDAP_USER_SEARCH_BASE': 'CN=Users,DC=rule4,DC=local',
        'LDAP_GROUP_SEARCH_BASE': 'CN=Users,DC=rule4,DC=local',
        'DATABASE_URL': 'sqlite:///db.sqlite3'
    })
    
    # Write environment file
    env_file_path = '/opt/django/app/.env'
    with open(env_file_path, 'w') as f:
        for key, value in env_vars.items():
            f.write(f"{key}={value}\n")
    
    print(f"Environment file created: {env_file_path}")
    
    return True

def create_superuser():
    """Create Django superuser"""
    try:
        # Change to Django directory
        os.chdir('/opt/django/app')
        
        print("Secrets setup completed successfully!")
        return True
    except Exception as e:
        print("Secrets setup failed!")
        print(f"Error: {e}")
        return False

if __name__ == "__main__":
    if setup_environment():
        create_superuser()
    else:
        sys.exit(1) 