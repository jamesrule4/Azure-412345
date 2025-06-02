"""
Azure Key Vault integration for Django settings.
This module provides functionality to load sensitive configuration from Azure Key Vault.
"""

from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
import os

def load_secrets():
    """
    Load secrets from Azure Key Vault into environment variables.
    Uses DefaultAzureCredential for authentication, which supports:
    - Managed Identity (when deployed to Azure)
    - Azure CLI credentials (for local development)
    """
    vault_url = os.environ.get('AZURE_KEY_VAULT_URL')
    if not vault_url:
        return
        
    try:
        # Initialize the Key Vault client
        credential = DefaultAzureCredential()
        client = SecretClient(vault_url=vault_url, credential=credential)
        
        # Map of Key Vault secret names to environment variable names
        secrets = {
            'ldap-bind-password': 'LDAP_BIND_PASSWORD',
            'django-secret-key': 'DJANGO_SECRET_KEY'
        }
        
        # Load each secret into environment variables
        for vault_name, env_name in secrets.items():
            try:
                value = client.get_secret(vault_name).value
                if value:
                    os.environ[env_name] = value
            except Exception:
                pass  # Use environment variable/default if secret not found
                
    except Exception:
        pass  # Use environment variables/defaults if Key Vault not available 