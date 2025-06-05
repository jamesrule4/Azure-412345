#!/bin/bash

# Check if environment number is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <environment_number>"
    echo "Example: $0 4"
    exit 1
fi

ENV_NUM=$1
WORKSPACE="poc${ENV_NUM}"

# Navigate to Terraform directory
cd "$(dirname "$0")/../terraform" || exit 1

# Initialize Terraform if needed
terraform init

# Create new workspace
terraform workspace new "$WORKSPACE" || terraform workspace select "$WORKSPACE"

# Plan and apply
terraform plan -out=tfplan
terraform apply tfplan

echo "Environment $WORKSPACE has been created!"
echo "To destroy this environment later, run:"
echo "terraform workspace select $WORKSPACE && terraform destroy" 