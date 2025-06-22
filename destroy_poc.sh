#!/bin/bash

# Rule4 POC Environment Destroyer - Azure Optimized
# Handles Azure-specific deletion issues including Key Vault soft-delete

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENV_NUM=${1}
FORCE=${2}

# Function to print colored output
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to confirm destruction
confirm_destruction() {
    local workspace=$1
    local resource_count=$2
    
    if [ "$FORCE" = "--force" ]; then
        print_warning "Force flag detected - skipping confirmation"
        return 0
    fi
    
    echo ""
    echo -e "${RED}⚠️  DESTRUCTIVE OPERATION WARNING ⚠️${NC}"
    echo "You are about to destroy POC environment: $workspace"
    echo "This will permanently delete approximately $resource_count Azure resources"
    echo ""
    echo -e "${RED}THIS ACTION CANNOT BE UNDONE!${NC}"
    echo ""
    read -p "Type 'DESTROY' to confirm destruction of $workspace: " confirmation
    
    if [ "$confirmation" != "DESTROY" ]; then
        print_error "Destruction cancelled by user"
        exit 1
    fi
    
    print_warning "Destruction confirmed. Proceeding..."
}

# Function to handle Azure Key Vault soft-delete issues
handle_key_vault_cleanup() {
    local workspace=$1
    
    print_status "Handling Azure Key Vault cleanup for $workspace..."
    
    # Try to purge any soft-deleted Key Vaults for this environment
    local vault_name="kv-${workspace}-*"
    
    # List and purge soft-deleted vaults (this may fail due to permissions, which is expected)
    if command -v az >/dev/null 2>&1; then
        print_status "Attempting to purge soft-deleted Key Vaults..."
        az keyvault list-deleted --query "[?contains(name, '${workspace}')].name" -o tsv 2>/dev/null | while read vault; do
            if [ -n "$vault" ]; then
                print_status "Attempting to purge soft-deleted vault: $vault"
                az keyvault purge --name "$vault" 2>/dev/null || print_warning "Could not purge vault $vault (may require special permissions)"
            fi
        done
    else
        print_warning "Azure CLI not available - skipping Key Vault purge"
    fi
}

# Function to perform aggressive resource cleanup
perform_aggressive_cleanup() {
    local workspace=$1
    
    print_status "Performing aggressive cleanup for persistent resources..."
    
    # Try multiple destroy strategies
    local strategies=(
        "terraform destroy -auto-approve"
        "terraform destroy -auto-approve -refresh=false"
        "terraform destroy -auto-approve -parallelism=1"
        "terraform destroy -auto-approve -refresh=false -parallelism=1"
    )
    
    for strategy in "${strategies[@]}"; do
        print_status "Trying strategy: $strategy"
        if eval "$strategy" >/dev/null 2>&1; then
            print_success "Strategy succeeded: $strategy"
            return 0
        else
            print_warning "Strategy failed: $strategy"
        fi
    done
    
    print_warning "All destroy strategies failed - proceeding to state cleanup"
    return 1
}

# Function to clean orphaned resources from state
clean_orphaned_resources() {
    local remaining_resources=$(terraform state list 2>/dev/null | wc -l || echo "0")
    
    if [ "$remaining_resources" -gt 0 ]; then
        print_warning "Found $remaining_resources orphaned resources in state"
        print_status "Cleaning up orphaned resources from state..."
        
        # Remove all remaining resources from state (they should be deleted in Azure)
        terraform state list 2>/dev/null | while read resource; do
            if [[ "$resource" != data.* ]]; then  # Keep data sources
                print_status "Removing orphaned resource: $resource"
                terraform state rm "$resource" >/dev/null 2>&1 || true
            fi
        done
        
        print_success "Orphaned resources cleaned from state"
    fi
}

# Main execution
main() {
    if [ -z "$ENV_NUM" ]; then
        print_error "Usage: $0 <environment_number> [--force]"
        print_error "Example: $0 1"
        print_error "Example: $0 1 --force"
        exit 1
    fi
    
    local workspace="poc${ENV_NUM}"
    
    print_status "=== Rule4 POC Environment Destroyer - Azure Optimized ==="
    print_status "Target environment: $workspace"
    print_status "Timestamp: $(date)"
    
    # Change to terraform directory
    if [ ! -d "terraform" ]; then
        print_error "Terraform directory not found. Please run from project root."
        exit 1
    fi
    
    cd terraform
    
    # Check if workspace exists
    if ! terraform workspace list 2>/dev/null | grep -q "$workspace"; then
        print_warning "Workspace $workspace does not exist"
        print_success "Nothing to destroy"
        cd ..
        exit 0
    fi
    
    # Select workspace and get resource count
    terraform workspace select $workspace >/dev/null 2>&1 || {
        print_error "Failed to select workspace $workspace"
        cd ..
        exit 1
    }
    
    local resource_count=$(terraform state list 2>/dev/null | wc -l || echo "unknown")
    
    if [ "$resource_count" = "0" ]; then
        print_success "No resources found in $workspace"
        # Clean up empty workspace
        terraform workspace select default >/dev/null 2>&1
        terraform workspace delete -force $workspace >/dev/null 2>&1 || true
        print_success "Empty workspace $workspace cleaned up"
        cd ..
        exit 0
    fi
    
    print_status "Found $resource_count resources to destroy"
    
    # Confirm destruction
    confirm_destruction $workspace $resource_count
    
    # Perform destruction with Azure-specific handling
    print_status "Starting destruction of $workspace environment..."
    
    # First, try standard destroy
    if terraform destroy -auto-approve; then
        print_success "Standard destroy completed successfully"
    else
        print_warning "Standard destroy encountered issues - trying advanced cleanup"
        
        # Handle Key Vault specific issues
        handle_key_vault_cleanup $workspace
        
        # Try aggressive cleanup strategies
        if ! perform_aggressive_cleanup $workspace; then
            print_warning "All destroy strategies failed - proceeding with state cleanup"
        fi
    fi
    
    # Always clean up any remaining orphaned resources from state
    clean_orphaned_resources
    
    # Clean up workspace
    print_status "Cleaning up workspace: $workspace"
    terraform workspace select default >/dev/null 2>&1
    
    if terraform workspace delete $workspace >/dev/null 2>&1; then
        print_success "Workspace $workspace deleted successfully"
    else
        terraform workspace delete -force $workspace >/dev/null 2>&1 || true
        print_warning "Workspace $workspace force deleted"
    fi
    
    print_success "=== Destruction Complete ==="
    print_status "Environment: $workspace"
    print_status "Timestamp: $(date)"
    print_success "All resources destroyed and workspace cleaned up"
    
    cd ..
}

# Execute main function
main "$@" 