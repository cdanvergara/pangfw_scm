# Palo Alto Next Generation Firewall on Azure - Multi-Region

This Terraform template deploys Palo Alto Next Generation Firewall (NGFW) across two customizable Azure regions with existing Virtual WAN infrastructure. The template is designed to be flexible, secure, and production-ready.

## 🏗️ Architecture Overview

```
    Internet
       |
   [Public IPs]
       |
[Cloud NGFW Instances]
       |
  [Virtual Hubs]
       |
   [Virtual WAN]
       |
[Connected Networks]
```

### Components Deployed

- **Palo Alto Local Rulestacks** in both regions
- **Cloud NGFW instances** with Panorama integration
- **Network Virtual Appliances** for traffic routing
- **Public IP addresses** for external access
- **Virtual Hub routing intents** for traffic direction
- **Log Analytics workspace** for monitoring (optional)
- **Network Security Groups** for management access (optional)

## 📋 Prerequisites

### Step 1: Azure Subscription Setup
1. **Ensure Azure Subscription with Payment Method**:
   - Log in to [Azure Portal](https://portal.azure.com)
   - Navigate to **Subscriptions**
   - Select your subscription
   - Go to **Payment methods** and ensure a valid payment method is configured
   - Note your **Subscription ID** (you'll need this later)

2. **Verify Required Permissions**:
   ```bash
   # Check your current role assignments
   az role assignment list --assignee $(az account show --query user.name -o tsv) --output table
   ```
   Required roles:
   - **Contributor** access to the subscription
   - **Network Contributor** role on existing Virtual WAN resources

### Step 2: Existing Virtual WAN Infrastructure
**⚠️ CRITICAL**: This template requires existing Virtual WAN infrastructure. If you don't have this, create it first:

1. **Create Virtual WAN**:
   ```bash
   # Create resource group for Virtual WAN
   az group create --name "vwan-infrastructure-rg" --location "East US"
   
   # Create Virtual WAN
   az network vwan create \
     --name "my-virtual-wan" \
     --resource-group "vwan-infrastructure-rg" \
     --location "East US" \
     --type "Standard"
   ```

2. **Create Virtual Hubs in Both Regions**:
   ```bash
   # Primary region hub (East US)
   az network vhub create \
     --name "hub-eastus" \
     --resource-group "vwan-infrastructure-rg" \
     --vwan "my-virtual-wan" \
     --location "East US" \
     --address-prefix "10.0.0.0/24"
   
   # Secondary region hub (Central US)  
   az network vhub create \
     --name "hub-centralus" \
     --resource-group "vwan-infrastructure-rg" \
     --vwan "my-virtual-wan" \
     --location "Central US" \
     --address-prefix "10.1.0.0/24"
   ```

3. **Verify Virtual WAN Setup**:
   ```bash
   # List Virtual WANs
   az network vwan list --output table
   
   # List Virtual Hubs
   az network vhub list --output table
   
   # Get specific hub details
   az network vhub show --name "hub-eastus" --resource-group "vwan-infrastructure-rg"
   ```

### Step 3: Install Required Tools

#### Install Terraform
**Windows (PowerShell)**:
```powershell
# Option 1: Using Chocolatey
choco install terraform

# Option 2: Using Scoop
scoop install terraform

# Option 3: Using Winget
winget install Hashicorp.Terraform

# Verify installation
terraform --version
```

**Linux/macOS**:
```bash
# Download and install Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify installation
terraform --version
```

#### Install Azure CLI
**Windows**:
```powershell
winget install Microsoft.AzureCLI
```

**Linux**:
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

**macOS**:
```bash
brew install azure-cli
```

#### Install Additional Tools (Optional)
```bash
# jq for JSON parsing
# Windows: winget install stedolan.jq
# Linux: sudo apt-get install jq
# macOS: brew install jq

# Git for version control
# Windows: winget install Git.Git
# Linux: sudo apt-get install git
# macOS: brew install git
```

### Step 4: Azure Authentication and Setup

1. **Login to Azure CLI**:
   ```bash
   az login
   ```
   This will open a browser window for authentication.

2. **Set Default Subscription** (if you have multiple):
   ```bash
   az account set --subscription "your-subscription-id"
   ```

3. **Verify Authentication**:
   ```bash
   az account show
   ```

4. **Register Required Resource Providers**:
   ```bash
   # Register Palo Alto Networks provider
   az provider register --namespace PaloAltoNetworks.Cloudngfw
   
   # Register Microsoft Network provider
   az provider register --namespace Microsoft.Network
   
   # Check registration status
   az provider show --namespace PaloAltoNetworks.Cloudngfw --query "registrationState"
   az provider show --namespace Microsoft.Network --query "registrationState"
   ```
   **Note**: Registration can take 5-10 minutes. Wait for "Registered" status.

5. **Accept Marketplace Terms**:
   ```bash
   az vm image terms accept \
     --publisher paloaltonetworks \
     --offer pan_swfw_cloud_ngfw \
     --plan panw-cloud-ngfw-payg
   ```

6. **Verify Marketplace Terms**:
   ```bash
   az vm image terms show \
     --publisher paloaltonetworks \
     --offer pan_swfw_cloud_ngfw \
     --plan panw-cloud-ngfw-payg \
     --query "accepted"
   ```

## 🚀 Detailed Deployment Steps

### Step 1: Download and Prepare the Template

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/cdanvergara/pangfw.git
   cd pangfw
   ```

2. **Verify Template Files**:
   ```bash
   # Check that all required files are present
   ls -la
   ```
   You should see:
   - `main.tf` - Main Terraform configuration
   - `variables.tf` - Variable definitions
   - `outputs.tf` - Output configurations
   - `terraform.tfvars.example` - Example variables file
   - `deploy.sh` / `deploy.ps1` - Deployment scripts

### Step 2: Configure Deployment Variables

1. **Create Your Configuration File**:
   ```bash
   # Copy the example file
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit terraform.tfvars with Your Values**:
   Open `terraform.tfvars` in your preferred editor and configure:

   **Required Variables** (⚠️ Must be configured):
   ```hcl
   # Replace with your actual subscription ID
   subscription_id = "12345678-1234-1234-1234-123456789abc"
   
   # Your existing Virtual WAN details
   existing_vwan_resource_group = "vwan-infrastructure-rg"
   existing_vwan_name = "my-virtual-wan"
   existing_vhub_primary_name = "hub-eastus"
   existing_vhub_secondary_name = "hub-centralus"
   
   # SECURITY: Replace with your actual office/home IP ranges
   management_allowed_ips = [
     "203.0.113.0/24",    # Replace with your office IP range
     "198.51.100.0/24"    # Replace with your home IP range
   ]
   ```

   **Region Configuration** (Choose your regions):
   ```hcl
   # Option 1: US East + Central (default)
   primary_region = "East US"
   primary_region_short = "eus"
   secondary_region = "Central US"
   secondary_region_short = "cus"
   
   # Option 2: US East + West Coast
   # primary_region = "East US"
   # primary_region_short = "eus"
   # secondary_region = "West US 2"
   # secondary_region_short = "wus2"
   
   # Option 3: Europe
   # primary_region = "West Europe"
   # primary_region_short = "weu" 
   # secondary_region = "North Europe"
   # secondary_region_short = "neu"
   ```

3. **Validate Your Configuration**:
   ```bash
   # Check for required variables
   grep -E "^subscription_id|^existing_vwan|management_allowed_ips" terraform.tfvars
   
   # Ensure no placeholder values remain
   grep -i "your-\|replace\|example" terraform.tfvars
   ```

4. **Security Check**:
   ```bash
   # Verify you're not using insecure defaults
   if grep -q "0.0.0.0/0" terraform.tfvars; then
     echo "⚠️  WARNING: Found 0.0.0.0/0 - this allows access from anywhere!"
     echo "Replace with your specific IP ranges for security"
   fi
   ```

### Step 3: Initialize Terraform

1. **Initialize Terraform Backend**:
   ```bash
   terraform init
   ```
   This will:
   - Download required providers (Azure RM, Palo Alto)
   - Initialize the working directory
   - Prepare the backend for state management

2. **Verify Initialization**:
   ```bash
   # Check provider versions
   terraform version
   
   # Verify initialization was successful
   ls .terraform/
   ```

### Step 4: Validate and Plan Deployment

1. **Validate Configuration Syntax**:
   ```bash
   terraform validate
   ```
   This checks for syntax errors and validates the configuration.

2. **Format Code** (Optional):
   ```bash
   terraform fmt
   ```

3. **Create Deployment Plan**:
   ```bash
   terraform plan -var-file="terraform.tfvars" -out="deployment.tfplan"
   ```

4. **Review the Plan Carefully**:
   The plan will show you:
   - **Resources to be created**: NGFWs, public IPs, rulestacks, etc.
   - **Estimated costs**: Review the pricing impact
   - **Dependencies**: Verify Virtual WAN references are correct

   Look for these key items in the plan:
   ```
   + azurerm_palo_alto_next_generation_firewall_virtual_hub_panorama.primary
   + azurerm_palo_alto_next_generation_firewall_virtual_hub_panorama.secondary
   + azurerm_public_ip.primary_ngfw
   + azurerm_public_ip.secondary_ngfw
   + azurerm_palo_alto_local_rulestack.primary
   + azurerm_palo_alto_local_rulestack.secondary
   ```

### Step 5: Deploy Infrastructure

1. **Apply the Configuration**:
   ```bash
   terraform apply "deployment.tfplan"
   ```

2. **Monitor Deployment Progress**:
   The deployment typically takes 15-30 minutes. You'll see progress for:
   - Resource group creation (~1 min)
   - Public IP allocation (~2 min)
   - Local rulestack creation (~5 min)
   - NGFW deployment (~15-20 min)
   - Routing configuration (~5 min)

3. **Handle Common Issues During Deployment**:
   
   **Payment Method Error**:
   ```
   Error: PaymentRequired: SaaS Purchase Payment Check Failed
   ```
   **Solution**: Add a payment method to your subscription in Azure Portal.

   **Provider Registration Error**:
   ```
   Error: MissingSubscriptionRegistration
   ```
   **Solution**: 
   ```bash
   az provider register --namespace PaloAltoNetworks.Cloudngfw
   # Wait 5-10 minutes and retry
   ```

   **Marketplace Terms Error**:
   ```
   Error: MarketplacePurchaseEligibilityFailed
   ```
   **Solution**:
   ```bash
   az vm image terms accept --publisher paloaltonetworks --offer pan_swfw_cloud_ngfw --plan panw-cloud-ngfw-payg
   ```

### Step 6: Verify Deployment

1. **Check Terraform Outputs**:
   ```bash
   terraform output
   ```
   You should see:
   - Management URLs for both NGFWs
   - Public IP addresses
   - Resource group names and IDs
   - Azure Portal links

2. **Verify Resources in Azure Portal**:
   ```bash
   # Get direct links to Azure Portal
   terraform output azure_portal_links
   ```
   Or manually check:
   - Navigate to your resource groups
   - Verify NGFW instances are running
   - Check public IP allocations
   - Confirm Virtual Hub routing intents are active

3. **Test NGFW Management Access**:
   ```bash
   # Get management URLs
   PRIMARY_URL=$(terraform output -raw primary_ngfw_public_ip)
   SECONDARY_URL=$(terraform output -raw secondary_ngfw_public_ip)
   
   echo "Primary NGFW: https://$PRIMARY_URL"
   echo "Secondary NGFW: https://$SECONDARY_URL"
   ```
   
   Try accessing these URLs in your browser (may take 5-10 minutes after deployment for services to fully start).

### Step 7: Initial NGFW Configuration

1. **Access NGFW Web Interface**:
   - Open the management URLs from the Terraform outputs
   - Default credentials: `admin` / `admin` (change immediately)
   - Accept SSL certificate warnings (expected for new deployment)

2. **Basic Security Configuration**:
   ```bash
   # If using Panorama, the configuration will be pushed from there
   # Otherwise, configure basic security policies through the web UI
   ```

3. **Verify Traffic Flow**:
   - Check Virtual Hub routing tables
   - Verify traffic is being routed through NGFWs
   - Test connectivity through the firewalls

### Step 8: Post-Deployment Tasks

1. **Secure the Environment**:
   - Change default passwords
   - Configure certificate-based authentication
   - Review and tighten security group rules
   - Enable logging to Azure Monitor

2. **Configure Monitoring** (if enabled):
   ```bash
   # Get Log Analytics workspace details
   terraform output log_analytics_workspace_id
   ```

3. **Backup Configuration**:
   ```bash
   # Save Terraform state securely
   terraform state pull > terraform.tfstate.backup
   
   # Document your configuration
   cp terraform.tfvars terraform.tfvars.backup
   ```

4. **Set Up Ongoing Monitoring**:
   - Configure Azure Monitor alerts
   - Set up cost monitoring
   - Enable security center recommendations

### Step 9: Testing and Validation

1. **Network Connectivity Test**:
   ```bash
   # Test from connected VNets or on-premises
   # Verify traffic is flowing through NGFWs
   ```

2. **Security Policy Testing**:
   - Test allowed traffic flows
   - Verify blocked traffic is properly denied
   - Check logging is working

3. **High Availability Testing**:
   - Test failover between regions
   - Verify redundancy is working

### Step 10: Documentation and Handover

1. **Document Your Deployment**:
   - Save all configuration files
   - Document any customizations made
   - Record management credentials securely
   - Note any special routing requirements

2. **Create Operations Runbook**:
   - Management procedures
   - Troubleshooting steps
   - Update procedures
   - Emergency contacts

## 🌍 Region Customization

The template supports deployment to any two Azure regions. Here are some popular configurations:

### US Regions
```hcl
# East + Central US
primary_region = "East US"
secondary_region = "Central US"

# East + West Coast
primary_region = "East US"
secondary_region = "West US 2"
```

### European Regions
```hcl
# West Europe + North Europe
primary_region = "West Europe"
secondary_region = "North Europe"

# UK Regions
primary_region = "UK South"
secondary_region = "UK West"
```

### Asia Pacific Regions
```hcl
# Southeast Asia + East Asia
primary_region = "Southeast Asia"
secondary_region = "East Asia"

# Japan Regions
primary_region = "Japan East"
secondary_region = "Japan West"
```

## 🔧 Configuration Options

### Core Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `subscription_id` | Azure subscription ID | - | ✅ |
| `primary_region` | Primary deployment region | "East US" | ✅ |
| `secondary_region` | Secondary deployment region | "Central US" | ✅ |
| `existing_vwan_name` | Existing Virtual WAN name | - | ✅ |
| `existing_vhub_primary_name` | Primary region hub name | - | ✅ |
| `existing_vhub_secondary_name` | Secondary region hub name | - | ✅ |

### Security Configuration

```hcl
# Security profiles
anti_spyware_profile = "BestPractice"
anti_virus_profile = "BestPractice"
vulnerability_profile = "BestPractice"

# Management access
create_management_nsg = true
management_allowed_ips = ["your-office-ip/24"]
```

### Performance Tuning

```hcl
# Scale settings
nva_scale_unit = 1           # 1-20
throughput_capacity = 1      # Gbps
session_capacity = 100       # Thousands
```

### Monitoring Setup

```hcl
enable_monitoring = true
log_analytics_sku = "PerGB2018"
log_retention_days = 30
```

## 📊 Resource Naming Convention

Resources follow a standardized naming pattern:
```
{project_name}-{environment}-{resource_type}-{region_short}
```

Examples:
- Resource Group: `pangfw-prod-rg-eus`
- NGFW: `pangfw-prod-ngfw-eus`
- Public IP: `pangfw-prod-pip-ngfw-eus`

## 🔐 Security Best Practices

### Management Access
```hcl
# Restrict management access to known IPs
management_allowed_ips = [
  "203.0.113.0/24",    # Office network
  "198.51.100.0/24"    # VPN gateway
]
```

### DDoS Protection
```hcl
enable_ddos_protection = true
```

### Monitoring
```hcl
enable_monitoring = true
log_retention_days = 90  # Compliance requirement
```

## 📈 Monitoring and Logging

### Log Analytics Integration
The template optionally creates a Log Analytics workspace for centralized logging:

```hcl
enable_monitoring = true
log_analytics_sku = "PerGB2018"
log_retention_days = 30
```

### Management URLs
After deployment, access your firewalls at:
- Primary: `https://{primary-public-ip}`
- Secondary: `https://{secondary-public-ip}`

## 💰 Detailed Cost Management

### Understanding Costs

#### Cost Components
1. **Palo Alto Cloud NGFW Licensing**:
   - Pay-as-you-go model based on throughput
   - Typical cost: $0.125/hour per scale unit + data processing fees
   - Scale units: 1-20 (each provides ~1 Gbps throughput)

2. **Azure Infrastructure Costs**:
   - Public IP addresses: ~$3.65/month per IP (2 IPs total)
   - Virtual Network Appliances: Included with NGFW licensing
   - Log Analytics (if enabled): ~$2.30/GB ingested
   - Bandwidth: Standard Azure egress charges apply

#### Cost Estimation Tool
```bash
# Calculate monthly costs (approximate)
echo "Monthly Cost Estimation:"
echo "========================"
echo "NGFW License (2 regions, 1 scale unit each): $$(echo '2 * 24 * 30 * 0.125' | bc) USD"
echo "Public IPs (2): $$(echo '2 * 3.65' | bc) USD"
echo "Log Analytics (estimated 10GB/month): $$(echo '10 * 2.30' | bc) USD"
echo "Total (excluding bandwidth): $$(echo '2 * 24 * 30 * 0.125 + 2 * 3.65 + 10 * 2.30' | bc) USD"
```

### Cost Optimization Strategies

#### 1. Development Environment Settings
```hcl
# In terraform.tfvars for dev/test
environment = "dev"
nva_scale_unit = 1                    # Minimum scale
enable_auto_shutdown = true           # Auto-shutdown after hours
auto_shutdown_time = "19:00"          # Shutdown at 7 PM
enable_monitoring = false             # Disable expensive monitoring
log_retention_days = 7                # Shorter retention for dev
```

#### 2. Production Environment Settings
```hcl
# In terraform.tfvars for production
environment = "prod"
nva_scale_unit = 2                    # Higher scale for performance
enable_auto_shutdown = false          # Always on
enable_monitoring = true              # Full monitoring
log_retention_days = 90               # Compliance retention
enable_ddos_protection = true         # Enhanced security
```

#### 3. Cost Monitoring Setup
```bash
# Create budget alert
az consumption budget create \
  --budget-name "NGFW-Monthly-Budget" \
  --amount 500 \
  --category "Cost" \
  --time-grain "Monthly" \
  --time-period-start "$(date -d 'first day of this month' +%Y-%m-%d)" \
  --time-period-end "$(date -d 'last day of next month' +%Y-%m-%d)" \
  --filter "{\"dimensions\":{\"name\":\"ResourceGroupName\",\"operator\":\"In\",\"values\":[\"pangfw-prod-rg-eus\",\"pangfw-prod-rg-cus\"]}}"
```

### Performance Tuning Guidelines

#### Scale Unit Configuration
```hcl
# Performance vs Cost matrix
# Scale Unit 1:  ~1 Gbps  - $90/month
# Scale Unit 2:  ~2 Gbps  - $180/month  
# Scale Unit 5:  ~5 Gbps  - $450/month
# Scale Unit 10: ~10 Gbps - $900/month

# Configure based on your needs
nva_scale_unit = 1           # Start small and scale up
throughput_capacity = 1      # Match scale unit
session_capacity = 100       # Adjust for concurrent sessions
```

#### Regional Performance Considerations
```hcl
# High-performance regions (lower latency)
primary_region = "East US"      # Microsoft's largest datacenter
secondary_region = "West US 2"  # High-performance region

# Cost-optimized regions
primary_region = "Central US"   # Often lower costs
secondary_region = "South Central US"
```

### Monitoring and Alerts

#### Set Up Cost Alerts
```bash
# Create action group for notifications
az monitor action-group create \
  --name "NGFW-Cost-Alerts" \
  --resource-group "pangfw-prod-rg-eus" \
  --short-name "NGFWAlerts" \
  --email "admin@company.com"

# Create cost alert rule
az monitor metrics alert create \
  --name "High-Cost-Alert" \
  --resource-group "pangfw-prod-rg-eus" \
  --scopes "/subscriptions/$(az account show --query id -o tsv)" \
  --condition "avg Cost > 400" \
  --description "Alert when monthly cost exceeds $400"
```

#### Performance Monitoring
```hcl
# In terraform.tfvars
enable_monitoring = true

# Custom monitoring tags
tags = {
  CostCenter   = "IT-Security"
  Environment  = "Production"
  Owner        = "NetworkTeam"
  Purpose      = "Firewall"
  MonitoringLevel = "High"
}
```

## 📈 Advanced Configuration Examples

### Multi-Region Disaster Recovery Setup
```hcl
# terraform.tfvars for DR configuration
primary_region = "East US"
secondary_region = "West US 2"
backup_region = "Central US"

enable_backup = true
enable_disaster_recovery = true

# Enhanced monitoring for DR
enable_monitoring = true
log_retention_days = 365
```

### High-Availability Production Setup
```hcl
# terraform.tfvars for HA production
primary_region = "East US"
secondary_region = "Central US"

# High availability settings
nva_scale_unit = 3
throughput_capacity = 3
session_capacity = 500
availability_zones = ["1", "2", "3"]

# Enhanced security
enable_ddos_protection = true
create_management_nsg = true
management_allowed_ips = ["10.0.0.0/8", "172.16.0.0/12"]

# Comprehensive monitoring
enable_monitoring = true
log_analytics_sku = "PerGB2018" 
log_retention_days = 365
```

### Development/Testing Environment
```hcl
# terraform.tfvars for dev/test
project_name = "pangfw-dev"
environment = "dev"

primary_region = "Central US"      # Lower cost region
secondary_region = "South Central US"

# Minimal settings for testing
nva_scale_unit = 1
enable_auto_shutdown = true
auto_shutdown_time = "18:00"

# Reduced monitoring
enable_monitoring = false
log_retention_days = 7

# Allow broader access for testing
management_allowed_ips = ["0.0.0.0/0"]  # Only for dev!
```

### Security-Hardened Configuration
```hcl
# terraform.tfvars for maximum security
# Restrict management access
management_allowed_ips = [
  "203.0.113.0/24"    # Office network only
]

# Enhanced security features
enable_ddos_protection = true
create_management_nsg = true

# Security profiles
anti_spyware_profile = "Strict"
anti_virus_profile = "Strict"
url_filtering_profile = "Strict"
vulnerability_profile = "Strict"
file_blocking_profile = "Strict"

# Comprehensive logging
enable_monitoring = true
log_retention_days = 2555  # 7 years for compliance

# Custom DNS for security
custom_dns_servers = ["1.1.1.1", "1.0.0.1"]  # Cloudflare DNS
```

### Panorama Integration Configuration
```hcl
# terraform.tfvars for Panorama management
panorama_hostname = "panorama.company.com"
panorama_server = "10.0.1.100"
panorama_server_2 = "10.0.2.100"    # HA Panorama
panorama_template_name = "Azure-NGFW-Template"
panorama_config_string = "type=dhcp-client&ip-address=192.168.1.1"

# SSH key for management
panorama_vm_ssh_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQ... admin@company.com"

# Feature flags
feature_flags = {
  enable_panorama_integration = true
  enable_advanced_monitoring  = true
  enable_auto_scaling        = true
}
```

## 🔄 Routing Configuration

Traffic routing is configured through routing policies:

```hcl
routing_policies = [
  {
    name         = "InternetTraffic"
    destinations = ["Internet"]
  },
  {
    name         = "PrivateTraffic"
    destinations = ["PrivateTraffic"]
  }
]
```

## 📤 Outputs

The template provides comprehensive outputs including:

- Public IP addresses
- Management URLs
- Azure Portal links
- Resource IDs for integration
- SSH connection strings

Access outputs after deployment:
```bash
terraform output
```

## 🧹 Complete Cleanup Process

### Option 1: Terraform Destroy (Recommended)

#### Step-by-Step Destruction
1. **Backup Important Data**:
   ```bash
   # Export current configuration
   terraform output > terraform-outputs.backup
   
   # Backup state file
   cp terraform.tfstate terraform.tfstate.backup
   
   # Backup configuration
   cp terraform.tfvars terraform.tfvars.backup
   ```

2. **Plan Destruction**:
   ```bash
   terraform plan -destroy -var-file="terraform.tfvars"
   ```
   Review the destruction plan carefully to ensure only expected resources will be deleted.

3. **Execute Destruction**:
   ```bash
   terraform destroy -var-file="terraform.tfvars"
   ```

4. **Verify Complete Removal**:
   ```bash
   # Check if resource groups are gone
   az group list --output table | grep "pangfw"
   
   # Verify no orphaned resources
   az resource list --output table | grep "pangfw"
   ```

#### Automated Cleanup Script
Use the provided PowerShell script:
```powershell
# Windows
.\deploy.ps1 destroy -Force

# Or with confirmation
.\deploy.ps1 destroy
```

Use the provided Bash script:
```bash
# Linux/macOS
./deploy.sh destroy
```

### Option 2: Manual Azure CLI Cleanup

#### If Terraform Destroy Fails
```bash
# Get resource group names from Terraform state
PRIMARY_RG=$(terraform output -raw primary_resource_group_name)
SECONDARY_RG=$(terraform output -raw secondary_resource_group_name)

# Delete resource groups (this will delete all contained resources)
az group delete --name "$PRIMARY_RG" --yes --no-wait
az group delete --name "$SECONDARY_RG" --yes --no-wait

# Monitor deletion progress
az group list --output table | grep "pangfw"
```

#### Complete Manual Cleanup
```bash
# List all resources with pangfw in the name
az resource list --query "[?contains(name,'pangfw')]" --output table

# Delete specific resources if needed
az network public-ip delete --name "pangfw-prod-pip-ngfw-eus" --resource-group "pangfw-prod-rg-eus"
az network public-ip delete --name "pangfw-prod-pip-ngfw-cus" --resource-group "pangfw-prod-rg-cus"

# Delete firewalls
az palo-alto next-generation-firewall delete --name "pangfw-prod-ngfw-eus" --resource-group "pangfw-prod-rg-eus"
az palo-alto next-generation-firewall delete --name "pangfw-prod-ngfw-cus" --resource-group "pangfw-prod-rg-cus"
```

### Post-Cleanup Verification

#### Verify All Resources Removed
```bash
# Check for any remaining pangfw resources
az resource list --query "[?contains(name,'pangfw')]" --output table

# Verify resource groups are gone
az group exists --name "pangfw-prod-rg-eus"
az group exists --name "pangfw-prod-rg-cus"

# Check for orphaned public IPs
az network public-ip list --query "[?contains(name,'pangfw')]" --output table
```

#### Clean Up Local Files
```bash
# Remove Terraform state and plan files
rm -f terraform.tfstate*
rm -f *.tfplan
rm -f terraform-debug.log

# Optional: Remove downloaded providers
rm -rf .terraform/
```

## 🔄 Migration and Updates

### Updating to New Template Version

#### Backup Current Deployment
```bash
# Export current state
terraform state pull > current-state.backup

# Export outputs
terraform output > current-outputs.backup

# Backup configuration
cp terraform.tfvars terraform.tfvars.backup
```

#### Update Process
```bash
# Pull latest template version
git pull origin main

# Check for breaking changes
git log --oneline --since="1 month ago"

# Reinitialize with new providers
terraform init -upgrade

# Plan the update
terraform plan -var-file="terraform.tfvars"

# Apply updates
terraform apply -var-file="terraform.tfvars"
```

### Scaling Operations

#### Scale Up NGFWs
```hcl
# In terraform.tfvars, increase scale units
nva_scale_unit = 2          # Was 1
throughput_capacity = 2     # Match scale units
session_capacity = 200      # Increase capacity
```

```bash
# Apply the scaling change
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

#### Add Additional Regions
```hcl
# This template supports 2 regions, but you can deploy multiple instances
# Create a new instance in different regions by:
# 1. Copy the entire template to a new directory
# 2. Change project_name to avoid conflicts
# 3. Configure new regions
```

## 📞 Advanced Support and Integration

### Integration with Azure Monitor

#### Custom Monitoring Dashboard
```bash
# Create custom dashboard for NGFW monitoring
az portal dashboard create \
  --name "NGFW-Monitoring-Dashboard" \
  --resource-group "pangfw-prod-rg-eus" \
  --input-path "ngfw-dashboard.json"
```

#### Log Analytics Queries
```kql
// Query for NGFW traffic logs
AzureActivity
| where ResourceGroup contains "pangfw"
| where ActivityStatus == "Success"
| summarize count() by ResourceGroup, bin(TimeGenerated, 1h)

// Query for security events
SecurityEvent
| where Computer contains "ngfw"
| where EventID in (4624, 4625)  // Logon events
| summarize count() by EventID, bin(TimeGenerated, 1h)
```

### Integration with Azure Security Center

#### Enable Security Center Integration
```bash
# Enable Security Center for the subscription
az security auto-provisioning-setting update \
  --name "default" \
  --auto-provision "On"

# Configure security contacts
az security contact create \
  --email "security@company.com" \
  --phone "555-1234" \
  --alert-notifications "On" \
  --alerts-to-admins "On"
```

### Backup and Disaster Recovery

#### Automated Backup Strategy
```bash
# Create backup script for NGFW configurations
cat << 'EOF' > backup-ngfw-config.sh
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="./backups/$DATE"
mkdir -p "$BACKUP_DIR"

# Backup Terraform state
terraform state pull > "$BACKUP_DIR/terraform.tfstate"

# Backup configuration
cp terraform.tfvars "$BACKUP_DIR/"
cp *.tf "$BACKUP_DIR/"

# Backup NGFW configs (if accessible)
PRIMARY_IP=$(terraform output -raw primary_ngfw_public_ip)
SECONDARY_IP=$(terraform output -raw secondary_ngfw_public_ip)

echo "Backup completed in $BACKUP_DIR"
EOF

chmod +x backup-ngfw-config.sh
```

### Performance Optimization

#### Network Performance Tuning
```hcl
# In terraform.tfvars for high-performance scenarios
nva_scale_unit = 5              # Higher throughput
throughput_capacity = 5         # Match scale units
session_capacity = 1000         # High session count

# Use performance-optimized regions
primary_region = "East US"      # Microsoft's largest datacenter
secondary_region = "West US 2"  # High-performance region

# Enable all availability zones
availability_zones = ["1", "2", "3"]
```

### Compliance and Auditing

#### Compliance Configuration
```hcl
# In terraform.tfvars for compliance environments
log_retention_days = 2555       # 7 years retention
enable_monitoring = true
log_analytics_sku = "PerGB2018"

# Compliance tags
tags = {
  Compliance    = "SOX-HIPAA-PCI"
  DataClass     = "Restricted"
  Environment   = "Production"
  BackupPolicy  = "Required"
  Monitoring    = "Required"
}
```

#### Audit Trail Setup
```bash
# Enable activity logging for the subscription
az monitor activity-log alert create \
  --name "NGFW-Configuration-Changes" \
  --resource-group "pangfw-prod-rg-eus" \
  --condition category=Administrative \
  --action-group "/subscriptions/.../actionGroups/security-alerts"
```

## 🎯 Best Practices Summary

### Security Best Practices
1. **Never use 0.0.0.0/0** in `management_allowed_ips`
2. **Enable DDoS protection** for production
3. **Use strong, unique project names** to avoid conflicts
4. **Implement least-privilege access** for management
5. **Enable comprehensive logging** for audit trails
6. **Regular backup** of configurations and state
7. **Monitor costs** and set up budget alerts

### Operational Best Practices
1. **Use version control** for all Terraform files
2. **Implement CI/CD pipelines** for deployments
3. **Test in development** before production
4. **Document all customizations**
5. **Regular updates** of providers and templates
6. **Monitor performance** and scale as needed
7. **Plan for disaster recovery**

### Cost Management Best Practices
1. **Start with minimal scale units** and increase as needed
2. **Use auto-shutdown** for development environments
3. **Monitor costs** with Azure Cost Management
4. **Regular review** of resource utilization
5. **Consider reserved instances** for long-term deployments
6. **Optimize regions** based on cost and performance
7. **Clean up unused resources** promptly

---

**🎉 Congratulations!** You now have a complete guide for deploying and managing Palo Alto Next Generation Firewall on Azure across multiple regions. This template provides enterprise-grade security with the flexibility to customize for your specific requirements.

## 🐛 Detailed Troubleshooting Guide

### Common Issues and Solutions

#### Issue 1: Payment Method Error
**Error Message**:
```
Error: PaymentRequired: SaaS Purchase Payment Check Failed
```

**Detailed Solution**:
1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Subscriptions** → Select your subscription
3. Click on **Payment methods** in the left menu
4. Add a valid credit card or other payment method
5. Wait 10-15 minutes for the change to propagate
6. Retry the Terraform deployment

**Verification**:
```bash
# Check subscription payment status
az account show --query "state"
```

#### Issue 2: Resource Provider Registration Error
**Error Message**:
```
Error: MissingSubscriptionRegistration: The subscription is not registered to use namespace 'PaloAltoNetworks.Cloudngfw'
```

**Detailed Solution**:
1. **Register Providers Manually**:
   ```bash
   # Register required providers
   az provider register --namespace PaloAltoNetworks.Cloudngfw
   az provider register --namespace Microsoft.Network
   ```

2. **Check Registration Status**:
   ```bash
   # Monitor registration progress (repeat until "Registered")
   az provider show --namespace PaloAltoNetworks.Cloudngfw --query "registrationState"
   az provider show --namespace Microsoft.Network --query "registrationState"
   ```

3. **Wait for Complete Registration**:
   ```bash
   # Registration can take 5-10 minutes. Monitor with:
   while true; do
     status=$(az provider show --namespace PaloAltoNetworks.Cloudngfw --query "registrationState" -o tsv)
     echo "Registration status: $status"
     if [ "$status" = "Registered" ]; then
       echo "✅ Registration complete!"
       break
     fi
     echo "Waiting 30 seconds..."
     sleep 30
   done
   ```

#### Issue 3: Marketplace Terms Not Accepted
**Error Message**:
```
Error: MarketplacePurchaseEligibilityFailed
```

**Detailed Solution**:
1. **Accept Terms via CLI**:
   ```bash
   az vm image terms accept \
     --publisher paloaltonetworks \
     --offer pan_swfw_cloud_ngfw \
     --plan panw-cloud-ngfw-payg
   ```

2. **Verify Terms Acceptance**:
   ```bash
   az vm image terms show \
     --publisher paloaltonetworks \
     --offer pan_swfw_cloud_ngfw \
     --plan panw-cloud-ngfw-payg \
     --query "accepted"
   ```

3. **Alternative: Accept via Azure Portal**:
   - Go to Azure Portal → **Marketplace**
   - Search for "Palo Alto Networks Cloud NGFW"
   - Click **Get It Now** and accept terms

#### Issue 4: Virtual WAN/Hub Not Found
**Error Message**:
```
Error: Resource not found: Virtual WAN 'my-vwan' not found in resource group 'vwan-rg'
```

**Detailed Solution**:
1. **Verify Virtual WAN Exists**:
   ```bash
   # List all Virtual WANs in subscription
   az network vwan list --output table
   
   # Check specific resource group
   az network vwan list --resource-group "your-vwan-rg" --output table
   ```

2. **Verify Virtual Hubs**:
   ```bash
   # List all Virtual Hubs
   az network vhub list --output table
   
   # Get specific hub details
   az network vhub show \
     --name "your-hub-name" \
     --resource-group "your-vwan-rg"
   ```

3. **Fix Configuration**:
   - Update `terraform.tfvars` with correct names
   - Ensure resource group and Virtual WAN names match exactly
   - Check for typos in hub names

#### Issue 5: Insufficient Permissions
**Error Message**:
```
Error: Insufficient privileges to complete the operation
```

**Detailed Solution**:
1. **Check Current Permissions**:
   ```bash
   # Check your role assignments
   az role assignment list \
     --assignee $(az account show --query user.name -o tsv) \
     --output table
   ```

2. **Required Roles**:
   - **Contributor** on the subscription or resource group
   - **Network Contributor** on Virtual WAN resources

3. **Request Access**:
   - Contact your Azure administrator
   - Request the required role assignments
   - Provide specific resource group names

#### Issue 6: Terraform State Lock
**Error Message**:
```
Error: Error acquiring the state lock
```

**Detailed Solution**:
1. **Check for Running Terraform Processes**:
   ```bash
   # Windows
   tasklist | findstr terraform
   
   # Linux/macOS
   ps aux | grep terraform
   ```

2. **Force Unlock** (Use with caution):
   ```bash
   # Only if you're sure no other terraform process is running
   terraform force-unlock <lock-id>
   ```

3. **Clean Restart**:
   ```bash
   # Remove lock file if using local backend
   rm -f .terraform/terraform.tfstate
   terraform init
   ```

#### Issue 7: Resource Naming Conflicts
**Error Message**:
```
Error: A resource with the name 'pangfw-prod-rg-eus' already exists
```

**Detailed Solution**:
1. **Change Project Name**:
   ```hcl
   # In terraform.tfvars
   project_name = "mycompany-pangfw"  # Make it unique
   ```

2. **Or Import Existing Resource**:
   ```bash
   # If you want to manage existing resource
   terraform import azurerm_resource_group.primary /subscriptions/sub-id/resourceGroups/existing-rg-name
   ```

#### Issue 8: Deployment Timeout
**Error Message**:
```
Error: timeout while waiting for state to become 'Running'
```

**Detailed Solution**:
1. **Check Azure Portal**:
   - Navigate to the resource group
   - Check deployment status in Azure Portal
   - Look for any error messages

2. **Increase Timeout** (in main.tf):
   ```hcl
   timeouts {
     create = "45m"  # Increase from default 30m
     update = "45m"
     delete = "45m"
   }
   ```

3. **Retry Deployment**:
   ```bash
   # Sometimes a retry resolves temporary issues
   terraform apply -var-file="terraform.tfvars"
   ```

### Debug Mode and Logging

#### Enable Detailed Terraform Logging
```bash
# Set debug level
export TF_LOG=DEBUG
export TF_LOG_PATH="terraform-debug.log"

# Run terraform command
terraform apply -var-file="terraform.tfvars"

# Review debug logs
less terraform-debug.log
```

#### Azure CLI Debug Mode
```bash
# Enable Azure CLI debug mode
az configure --defaults group=mygroup --verbose
az network vwan list --debug
```

### Performance Issues

#### Issue: Slow Deployment
**Causes and Solutions**:

1. **Region Selection**:
   - Some regions may have capacity constraints
   - Try different region combinations

2. **Resource Contention**:
   - Deploy during off-peak hours
   - Consider smaller scale units initially

3. **Network Latency**:
   - Run Terraform from an Azure VM in the same region
   - Use Azure Cloud Shell

### Recovery Procedures

#### Partial Deployment Failure
1. **Check What Was Created**:
   ```bash
   terraform show
   terraform state list
   ```

2. **Clean Up Partial Resources**:
   ```bash
   # Target specific resources for destruction
   terraform destroy -target=azurerm_resource_group.primary
   ```

3. **Fresh Start**:
   ```bash
   # If state is corrupted, start fresh
   rm -f terraform.tfstate*
   terraform init
   terraform plan -var-file="terraform.tfvars"
   ```

#### State File Issues
1. **Backup Current State**:
   ```bash
   cp terraform.tfstate terraform.tfstate.backup
   ```

2. **Recover from Backup**:
   ```bash
   cp terraform.tfstate.backup terraform.tfstate
   terraform refresh
   ```

#### Emergency Resource Cleanup
If Terraform can't destroy resources:
```bash
# Manual cleanup via Azure CLI
az group delete --name "pangfw-prod-rg-eus" --yes --no-wait
az group delete --name "pangfw-prod-rg-cus" --yes --no-wait
```

## 🔗 Integration Examples

### With Azure Monitor
```hcl
# Enable comprehensive monitoring
enable_monitoring = true
log_retention_days = 90

# Custom tags for cost tracking
tags = {
  CostCenter = "Security"
  Environment = "Production"
}
```

### With Backup Strategy
```hcl
enable_backup = true
backup_region = "West US 2"
```

## 📚 Additional Resources

- [Palo Alto Networks Documentation](https://docs.paloaltonetworks.com/)
- [Azure Virtual WAN Documentation](https://docs.microsoft.com/en-us/azure/virtual-wan/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Important Notes

- **Billing:** Cloud NGFW incurs charges based on usage
- **Security:** Never commit real credentials to version control
- **Dependencies:** Ensure Virtual WAN infrastructure exists before deployment
- **Compliance:** Review security settings for your compliance requirements

## 📞 Support

- **Template Issues:** Create an issue in this repository
- **Palo Alto NGFW:** Consult [Palo Alto Networks support](https://support.paloaltonetworks.com/)
- **Azure Issues:** Contact [Microsoft Azure support](https://azure.microsoft.com/support/)

---

**Note:** This template is designed for production use but should be thoroughly tested in your environment before deployment.
