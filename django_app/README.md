# Django Application with Docker

This directory contains a containerized Django application with LDAP authentication for the Rule4 POC environment.

## Directory Structure

```
django_app/
├── Dockerfile              # Docker image definition
├── docker-compose.yml      # Container orchestration
├── requirements.txt        # Python dependencies
├── manage.py               # Django management script
├── create_superuser.py     # Creates the 'fox' admin user
├── django_app/             # Main Django application
│   ├── __init__.py
│   ├── settings.py         # Django configuration with LDAP
│   ├── urls.py             # URL routing
│   └── wsgi.py             # WSGI application
└── README.md               # This file
```

## Features

- **Containerized Deployment**: Uses Docker for consistent, portable deployments
- **LDAP Authentication**: Integrates with Active Directory for user authentication
- **Dynamic Configuration**: IP addresses and secrets configured via environment variables
- **Production Ready**: Uses Gunicorn WSGI server and WhiteNoise for static files

## Environment Variables

The application uses the following environment variables:

- `DJANGO_SECRET_KEY`: Django secret key (from Azure Key Vault)
- `DEBUG`: Debug mode (default: False)
- `ALLOWED_HOSTS`: Comma-separated list of allowed hosts
- `LDAP_SERVER_URI`: LDAP server URI (e.g., `ldap://10.1.1.10`)
- `LDAP_BIND_DN`: LDAP bind DN for service account
- `LDAP_BIND_PASSWORD`: LDAP bind password (from Azure Key Vault)

## Usage

### Automated Deployment

The application is automatically deployed using the `deploy_poc_v2.sh` script:

```bash
# Deploy to POC environment 1
./deploy_poc_v2.sh 1

# Deploy to POC environment 5
./deploy_poc_v2.sh 5
```

### Manual Docker Commands

If you need to run the container manually:

```bash
# Build the image
docker build -t rule4-django .

# Run with environment file
docker-compose up -d

# View logs
docker-compose logs

# Stop the container
docker-compose down
```

## Network Configuration

Each POC environment uses a different IP range:

- **POC1**: 10.1.0.0/16 (Domain Controller: 10.1.1.10, Django: 10.1.1.11)
- **POC2**: 10.2.0.0/16 (Domain Controller: 10.2.1.10, Django: 10.2.1.11)
- **POC5**: 10.5.0.0/16 (Domain Controller: 10.5.1.10, Django: 10.5.1.11)

## LDAP Integration

The application authenticates users against Active Directory with the following configuration:

- **Domain**: rule4.local
- **User Search**: `DC=rule4,DC=local`
- **Groups**: 
  - `DjangoStaff`: Users with staff privileges
  - `DjangoAdmins`: Users with admin privileges

## Admin Access

- **URL**: `http://<django-vm-ip>:8000/admin/`
- **Local Admin**: 
  - Username: `fox`
  - Password: `FoxAdmin2025!`
- **LDAP Test Users**:
  - `testuser` / `TestPass123!` (staff)
  - `adminuser` / `AdminPass123!` (admin)

## Troubleshooting

### Check Container Status
```bash
docker-compose ps
docker-compose logs
```

### Test LDAP Connectivity
```bash
# From inside the Django VM
telnet <domain-controller-ip> 389
```

### Restart Container
```bash
docker-compose restart
``` 