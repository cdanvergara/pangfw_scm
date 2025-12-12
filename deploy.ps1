# =============================================================================
# Palo Alto NGFW Deployment Script for Azure (PowerShell)
# =============================================================================

param(
    [Parameter(Position = 0)]
    [ValidateSet("deploy", "init", "plan", "apply", "destroy", "validate", "setup", "providers", "terms", "help")]
    [string]$Command = "deploy",
    
    [switch]$SkipPrerequisites,
    [switch]$Force,
    [switch]$AutoApprove
)

# Script variables
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TerraformDir = $ScriptDir
$TfVarsFile = "terraform.tfvars"
$TfVarsExample = "terraform.tfvars.example"

# =============================================================================
# Functions
# =============================================================================

function Write-Banner {
    Write-Host "======================================================================" -ForegroundColor Blue
    Write-Host "  Palo Alto Next Generation Firewall on Azure - Multi-Region" -ForegroundColor Blue
    Write-Host "  Terraform Deployment Script (PowerShell)" -ForegroundColor Blue
    Write-Host "======================================================================" -ForegroundColor Blue
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Test-Prerequisites {
    if ($SkipPrerequisites) {
        Write-Warning "Skipping prerequisites check"
        return $true
    }

    Write-Step "Checking prerequisites..."
    
    # Check if Terraform is installed
    try {
        $terraformVersion = & terraform version -json | ConvertFrom-Json
        Write-Success "Terraform version: $($terraformVersion.terraform_version)"
    }
    catch {
        Write-Error "Terraform is not installed or not in PATH"
        Write-Host "Install Terraform using one of these methods:" -ForegroundColor Yellow
        Write-Host "  - Chocolatey: choco install terraform" -ForegroundColor Yellow
        Write-Host "  - Scoop: scoop install terraform" -ForegroundColor Yellow
        Write-Host "  - Winget: winget install Hashicorp.Terraform" -ForegroundColor Yellow
        Write-Host "  - Download: https://www.terraform.io/downloads.html" -ForegroundColor Yellow
        return $false
    }
    
    # Check if Azure CLI is installed
    try {
        $azVersion = az version --output json | ConvertFrom-Json
        Write-Success "Azure CLI version: $($azVersion.'azure-cli')"
    }
    catch {
        Write-Warning "Azure CLI is not installed or not in PATH"
        Write-Host "Install Azure CLI: winget install Microsoft.AzureCLI" -ForegroundColor Yellow
    }
    
    # Check if jq is available (for JSON parsing)
    try {
        $null = & jq --version
        Write-Success "jq is available"
    }
    catch {
        Write-Warning "jq is not installed. Some features may not work properly."
        Write-Host "Install jq: winget install stedolan.jq" -ForegroundColor Yellow
    }
    
    return $true
}

function Test-AzureLogin {
    Write-Step "Checking Azure authentication..."
    
    try {
        $account = az account show --output json | ConvertFrom-Json
        Write-Success "Logged in to Azure subscription: $($account.name) ($($account.id))"
        return $true
    }
    catch {
        Write-Warning "Not logged in to Azure CLI. Please run 'az login' first."
        return $false
    }
}

function Initialize-Configuration {
    Write-Step "Setting up configuration..."
    
    if (-not (Test-Path $TfVarsFile)) {
        if (Test-Path $TfVarsExample) {
            Write-Step "Creating $TfVarsFile from example..."
            Copy-Item $TfVarsExample $TfVarsFile
            Write-Warning "Please edit $TfVarsFile with your actual values before proceeding."
            Write-Host ""
            Write-Host "Required values to configure:" -ForegroundColor Yellow
            Write-Host "  - subscription_id" -ForegroundColor Yellow
            Write-Host "  - existing_vwan_resource_group" -ForegroundColor Yellow
            Write-Host "  - existing_vwan_name" -ForegroundColor Yellow
            Write-Host "  - existing_vhub_primary_name" -ForegroundColor Yellow
            Write-Host "  - existing_vhub_secondary_name" -ForegroundColor Yellow
            Write-Host "  - management_allowed_ips" -ForegroundColor Yellow
            Write-Host ""
            
            if (-not $Force) {
                Read-Host "Press Enter when you have configured the variables"
            }
        }
        else {
            Write-Error "terraform.tfvars.example not found. Cannot create configuration."
            return $false
        }
    }
    else {
        Write-Success "Configuration file $TfVarsFile exists"
    }
    
    return $true
}

function Test-Configuration {
    Write-Step "Validating configuration..."
    
    if (-not (Test-Path $TfVarsFile)) {
        Write-Error "$TfVarsFile not found"
        return $false
    }
    
    $content = Get-Content $TfVarsFile -Raw
    
    # Check for required variables
    $requiredVars = @(
        "subscription_id",
        "existing_vwan_resource_group",
        "existing_vwan_name",
        "existing_vhub_primary_name",
        "existing_vhub_secondary_name"
    )
    
    foreach ($var in $requiredVars) {
        if ($content -notmatch "^$var\s*=") {
            Write-Error "$var not found in $TfVarsFile"
            return $false
        }
    }
    
    # Check for insecure default values
    if ($content -match "0\.0\.0\.0/0") {
        Write-Warning "Found 0.0.0.0/0 in management_allowed_ips. This is insecure for production."
        if (-not $Force -and -not $AutoApprove) {
            $confirm = Read-Host "Continue anyway? (y/N)"
            if ($confirm -ne "y" -and $confirm -ne "Y") {
                return $false
            }
        }
    }
    
    Write-Success "Configuration validation passed"
    return $true
}

function Invoke-TerraformInit {
    Write-Step "Initializing Terraform..."
    
    Set-Location $TerraformDir
    $result = & terraform init
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Terraform initialized successfully"
        return $true
    }
    else {
        Write-Error "Terraform initialization failed"
        return $false
    }
}

function Invoke-TerraformValidate {
    Write-Step "Validating Terraform configuration..."
    
    Set-Location $TerraformDir
    $result = & terraform validate
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Terraform validation passed"
        return $true
    }
    else {
        Write-Error "Terraform validation failed"
        return $false
    }
}

function Invoke-TerraformPlan {
    Write-Step "Creating Terraform plan..."
    
    Set-Location $TerraformDir
    $result = & terraform plan -var-file="$TfVarsFile" -out="tfplan"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Terraform plan created successfully"
        Write-Step "Review the plan above and confirm if you want to proceed with deployment."
        return $true
    }
    else {
        Write-Error "Terraform plan failed"
        return $false
    }
}

function Invoke-TerraformApply {
    Write-Step "Applying Terraform configuration..."
    
    if (-not $AutoApprove) {
        $confirm = Read-Host "Do you want to apply this configuration? (yes/no)"
        if ($confirm -ne "yes") {
            Write-Warning "Deployment cancelled by user"
            return $false
        }
    }
    
    Set-Location $TerraformDir
    $result = & terraform apply "tfplan"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Terraform deployment completed successfully"
        return $true
    }
    else {
        Write-Error "Terraform apply failed"
        return $false
    }
}

function Show-Outputs {
    Write-Step "Deployment outputs:"
    
    Set-Location $TerraformDir
    & terraform output
    
    Write-Success "Deployment completed! Check the outputs above for important information."
    
    # Try to show management URLs
    try {
        $managementUrls = & terraform output -json management_urls | ConvertFrom-Json
        Write-Host ""
        Write-Step "Management URLs:"
        $managementUrls.PSObject.Properties | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Value)" -ForegroundColor Cyan
        }
    }
    catch {
        # Management URLs not available or error occurred
    }
}

function Register-AzureProviders {
    Write-Step "Registering required Azure resource providers..."
    
    if (Test-AzureLogin) {
        try {
            & az provider register --namespace PaloAltoNetworks.Cloudngfw
            & az provider register --namespace Microsoft.Network
            Write-Success "Resource providers registered"
        }
        catch {
            Write-Warning "Failed to register providers automatically"
            Write-Host "Please run the following commands manually:" -ForegroundColor Yellow
            Write-Host "  az provider register --namespace PaloAltoNetworks.Cloudngfw" -ForegroundColor Yellow
            Write-Host "  az provider register --namespace Microsoft.Network" -ForegroundColor Yellow
        }
    }
    else {
        Write-Warning "Cannot register providers - not logged in to Azure CLI"
        Write-Host "Please run the following commands manually:" -ForegroundColor Yellow
        Write-Host "  az provider register --namespace PaloAltoNetworks.Cloudngfw" -ForegroundColor Yellow
        Write-Host "  az provider register --namespace Microsoft.Network" -ForegroundColor Yellow
    }
}

function Accept-MarketplaceTerms {
    Write-Step "Checking marketplace terms..."
    
    if (Test-AzureLogin) {
        try {
            Write-Step "Accepting Palo Alto marketplace terms..."
            & az vm image terms accept --publisher paloaltonetworks --offer pan_swfw_cloud_ngfw --plan panw-cloud-ngfw-payg
            Write-Success "Marketplace terms accepted"
        }
        catch {
            Write-Warning "Failed to accept marketplace terms automatically"
            Write-Host "Please run the following command manually:" -ForegroundColor Yellow
            Write-Host "  az vm image terms accept --publisher paloaltonetworks --offer pan_swfw_cloud_ngfw --plan panw-cloud-ngfw-payg" -ForegroundColor Yellow
        }
    }
    else {
        Write-Warning "Cannot accept marketplace terms - not logged in to Azure CLI"
        Write-Host "Please run the following command manually:" -ForegroundColor Yellow
        Write-Host "  az vm image terms accept --publisher paloaltonetworks --offer pan_swfw_cloud_ngfw --plan panw-cloud-ngfw-payg" -ForegroundColor Yellow
    }
}

function Remove-TempFiles {
    Write-Step "Cleaning up temporary files..."
    
    Set-Location $TerraformDir
    if (Test-Path "tfplan") {
        Remove-Item "tfplan" -Force
    }
    
    Write-Success "Cleanup completed"
}

function Show-Help {
    Write-Host "Usage: .\deploy.ps1 [COMMAND] [OPTIONS]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  deploy          Full deployment (default)"
    Write-Host "  init            Initialize Terraform only"
    Write-Host "  plan            Create deployment plan only"
    Write-Host "  apply           Apply existing plan"
    Write-Host "  destroy         Destroy infrastructure"
    Write-Host "  validate        Validate configuration only"
    Write-Host "  setup           Setup configuration files only"
    Write-Host "  providers       Register Azure providers only"
    Write-Host "  terms           Accept marketplace terms only"
    Write-Host "  help            Show this help message"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -SkipPrerequisites    Skip prerequisites check"
    Write-Host "  -Force                Skip confirmation prompts"
    Write-Host "  -AutoApprove          Auto-approve Terraform apply"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\deploy.ps1 deploy                    # Full deployment workflow"
    Write-Host "  .\deploy.ps1 plan                      # Just create a plan"
    Write-Host "  .\deploy.ps1 destroy -Force            # Destroy without confirmation"
    Write-Host "  .\deploy.ps1 deploy -AutoApprove       # Deploy without approval prompt"
}

function Start-Deployment {
    if (-not (Test-Prerequisites)) { return $false }
    Test-AzureLogin
    if (-not (Initialize-Configuration)) { return $false }
    if (-not (Test-Configuration)) { return $false }
    Register-AzureProviders
    Accept-MarketplaceTerms
    if (-not (Invoke-TerraformInit)) { return $false }
    if (-not (Invoke-TerraformValidate)) { return $false }
    if (-not (Invoke-TerraformPlan)) { return $false }
    if (-not (Invoke-TerraformApply)) { return $false }
    Show-Outputs
    Remove-TempFiles
    return $true
}

function Start-Destroy {
    Write-Step "Destroying infrastructure..."
    Write-Warning "This will destroy ALL resources created by this template!"
    
    if (-not $Force) {
        $confirm = Read-Host "Are you sure you want to destroy all resources? Type 'yes' to confirm"
        if ($confirm -ne "yes") {
            Write-Warning "Destruction cancelled by user"
            return $false
        }
    }
    
    Set-Location $TerraformDir
    $destroyArgs = @("destroy", "-var-file=$TfVarsFile")
    if ($AutoApprove) {
        $destroyArgs += "-auto-approve"
    }
    
    $result = & terraform @destroyArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Infrastructure destroyed successfully"
        return $true
    }
    else {
        Write-Error "Infrastructure destruction failed"
        return $false
    }
}

# =============================================================================
# Main Script Logic
# =============================================================================

Write-Banner

switch ($Command) {
    "deploy" {
        $success = Start-Deployment
    }
    "init" {
        $success = (Test-Prerequisites) -and (Invoke-TerraformInit)
    }
    "plan" {
        $success = (Test-Prerequisites) -and (Initialize-Configuration) -and 
                  (Test-Configuration) -and (Invoke-TerraformInit) -and 
                  (Invoke-TerraformValidate) -and (Invoke-TerraformPlan)
    }
    "apply" {
        $success = (Test-Prerequisites) -and (Invoke-TerraformApply)
        if ($success) {
            Show-Outputs
            Remove-TempFiles
        }
    }
    "destroy" {
        $success = (Test-Prerequisites) -and (Start-Destroy)
    }
    "validate" {
        $success = (Test-Prerequisites) -and (Initialize-Configuration) -and 
                  (Test-Configuration) -and (Invoke-TerraformValidate)
    }
    "setup" {
        $success = Initialize-Configuration
    }
    "providers" {
        Register-AzureProviders
        $success = $true
    }
    "terms" {
        Accept-MarketplaceTerms
        $success = $true
    }
    "help" {
        Show-Help
        $success = $true
    }
    default {
        Write-Error "Unknown command: $Command"
        Show-Help
        exit 1
    }
}

if ($success) {
    Write-Success "Script completed successfully!"
}
else {
    Write-Error "Script failed!"
    exit 1
}