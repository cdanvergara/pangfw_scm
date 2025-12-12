#!/bin/bash

# =============================================================================
# Palo Alto NGFW Deployment Script for Azure
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR"
TFVARS_FILE="terraform.tfvars"
TFVARS_EXAMPLE="terraform.tfvars.example"

# =============================================================================
# Functions
# =============================================================================

print_banner() {
    echo -e "${BLUE}"
    echo "======================================================================"
    echo "  Palo Alto Next Generation Firewall on Azure - Multi-Region"
    echo "  Terraform Deployment Script"
    echo "======================================================================"
    echo -e "${NC}"
}

print_step() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform first."
        echo "Installation guide: https://learn.hashicorp.com/tutorials/terraform/install-cli"
        exit 1
    fi
    
    # Check Terraform version
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
    print_success "Terraform version: $TERRAFORM_VERSION"
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        print_warning "Azure CLI is not installed. Some features may not work."
        print_step "Installation guide: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    else
        print_success "Azure CLI is installed"
    fi
    
    # Check if jq is installed (for JSON parsing)
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed. Some features may not work properly."
    fi
}

check_azure_login() {
    print_step "Checking Azure authentication..."
    
    if command -v az &> /dev/null; then
        if az account show &> /dev/null; then
            ACCOUNT_NAME=$(az account show --query 'name' -o tsv)
            SUBSCRIPTION_ID=$(az account show --query 'id' -o tsv)
            print_success "Logged in to Azure subscription: $ACCOUNT_NAME ($SUBSCRIPTION_ID)"
        else
            print_warning "Not logged in to Azure CLI. Please run 'az login' first."
        fi
    fi
}

setup_configuration() {
    print_step "Setting up configuration..."
    
    if [[ ! -f "$TFVARS_FILE" ]]; then
        if [[ -f "$TFVARS_EXAMPLE" ]]; then
            print_step "Creating $TFVARS_FILE from example..."
            cp "$TFVARS_EXAMPLE" "$TFVARS_FILE"
            print_warning "Please edit $TFVARS_FILE with your actual values before proceeding."
            echo "Required values to configure:"
            echo "  - subscription_id"
            echo "  - existing_vwan_resource_group"
            echo "  - existing_vwan_name"
            echo "  - existing_vhub_primary_name"
            echo "  - existing_vhub_secondary_name"
            echo "  - management_allowed_ips"
            read -p "Press Enter when you have configured the variables..."
        else
            print_error "terraform.tfvars.example not found. Cannot create configuration."
            exit 1
        fi
    else
        print_success "Configuration file $TFVARS_FILE exists"
    fi
}

validate_configuration() {
    print_step "Validating configuration..."
    
    # Check for required variables
    if ! grep -q "^subscription_id" "$TFVARS_FILE" 2>/dev/null; then
        print_error "subscription_id not found in $TFVARS_FILE"
        return 1
    fi
    
    if ! grep -q "^existing_vwan_resource_group" "$TFVARS_FILE" 2>/dev/null; then
        print_error "existing_vwan_resource_group not found in $TFVARS_FILE"
        return 1
    fi
    
    # Check for default insecure values
    if grep -q "0.0.0.0/0" "$TFVARS_FILE" 2>/dev/null; then
        print_warning "Found 0.0.0.0/0 in management_allowed_ips. This is insecure for production."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    print_success "Configuration validation passed"
}

terraform_init() {
    print_step "Initializing Terraform..."
    
    cd "$TERRAFORM_DIR"
    terraform init
    
    print_success "Terraform initialized successfully"
}

terraform_validate() {
    print_step "Validating Terraform configuration..."
    
    cd "$TERRAFORM_DIR"
    terraform validate
    
    print_success "Terraform validation passed"
}

terraform_plan() {
    print_step "Creating Terraform plan..."
    
    cd "$TERRAFORM_DIR"
    terraform plan -var-file="$TFVARS_FILE" -out="tfplan"
    
    print_success "Terraform plan created successfully"
    print_step "Review the plan above and confirm if you want to proceed with deployment."
}

terraform_apply() {
    print_step "Applying Terraform configuration..."
    
    read -p "Do you want to apply this configuration? (yes/no): " confirm
    if [[ $confirm != "yes" ]]; then
        print_warning "Deployment cancelled by user"
        exit 0
    fi
    
    cd "$TERRAFORM_DIR"
    terraform apply "tfplan"
    
    print_success "Terraform deployment completed successfully"
}

show_outputs() {
    print_step "Deployment outputs:"
    
    cd "$TERRAFORM_DIR"
    terraform output
    
    print_success "Deployment completed! Check the outputs above for important information."
    
    # Try to get management URLs
    if terraform output management_urls &> /dev/null; then
        echo
        print_step "Management URLs:"
        terraform output -json management_urls | jq -r 'to_entries[] | "  \(.key): \(.value)"'
    fi
}

register_providers() {
    print_step "Registering required Azure resource providers..."
    
    if command -v az &> /dev/null && az account show &> /dev/null; then
        az provider register --namespace PaloAltoNetworks.Cloudngfw
        az provider register --namespace Microsoft.Network
        print_success "Resource providers registered"
    else
        print_warning "Cannot register providers - Azure CLI not available or not logged in"
        echo "Please run the following commands manually:"
        echo "  az provider register --namespace PaloAltoNetworks.Cloudngfw"
        echo "  az provider register --namespace Microsoft.Network"
    fi
}

accept_marketplace_terms() {
    print_step "Checking marketplace terms..."
    
    if command -v az &> /dev/null && az account show &> /dev/null; then
        print_step "Accepting Palo Alto marketplace terms..."
        az vm image terms accept --publisher paloaltonetworks --offer pan_swfw_cloud_ngfw --plan panw-cloud-ngfw-payg
        print_success "Marketplace terms accepted"
    else
        print_warning "Cannot accept marketplace terms - Azure CLI not available or not logged in"
        echo "Please run the following command manually:"
        echo "  az vm image terms accept --publisher paloaltonetworks --offer pan_swfw_cloud_ngfw --plan panw-cloud-ngfw-payg"
    fi
}

cleanup() {
    print_step "Cleaning up temporary files..."
    
    cd "$TERRAFORM_DIR"
    [[ -f "tfplan" ]] && rm "tfplan"
    
    print_success "Cleanup completed"
}

show_help() {
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  deploy          Full deployment (default)"
    echo "  init            Initialize Terraform only"
    echo "  plan            Create deployment plan only"
    echo "  apply           Apply existing plan"
    echo "  destroy         Destroy infrastructure"
    echo "  validate        Validate configuration only"
    echo "  setup           Setup configuration files only"
    echo "  providers       Register Azure providers only"
    echo "  terms           Accept marketplace terms only"
    echo "  help            Show this help message"
    echo
    echo "Examples:"
    echo "  $0 deploy       # Full deployment workflow"
    echo "  $0 plan         # Just create a plan"
    echo "  $0 destroy      # Destroy all resources"
}

deploy() {
    check_prerequisites
    check_azure_login
    setup_configuration
    validate_configuration
    register_providers
    accept_marketplace_terms
    terraform_init
    terraform_validate
    terraform_plan
    terraform_apply
    show_outputs
    cleanup
}

destroy() {
    print_step "Destroying infrastructure..."
    print_warning "This will destroy ALL resources created by this template!"
    
    read -p "Are you sure you want to destroy all resources? Type 'yes' to confirm: " confirm
    if [[ $confirm != "yes" ]]; then
        print_warning "Destruction cancelled by user"
        exit 0
    fi
    
    cd "$TERRAFORM_DIR"
    terraform destroy -var-file="$TFVARS_FILE"
    
    print_success "Infrastructure destroyed successfully"
}

# =============================================================================
# Main Script Logic
# =============================================================================

print_banner

case "${1:-deploy}" in
    "deploy")
        deploy
        ;;
    "init")
        check_prerequisites
        terraform_init
        ;;
    "plan")
        check_prerequisites
        setup_configuration
        validate_configuration
        terraform_init
        terraform_validate
        terraform_plan
        ;;
    "apply")
        check_prerequisites
        terraform_apply
        show_outputs
        cleanup
        ;;
    "destroy")
        check_prerequisites
        destroy
        ;;
    "validate")
        check_prerequisites
        setup_configuration
        validate_configuration
        terraform_validate
        ;;
    "setup")
        setup_configuration
        ;;
    "providers")
        register_providers
        ;;
    "terms")
        accept_marketplace_terms
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac

print_success "Script completed successfully!"