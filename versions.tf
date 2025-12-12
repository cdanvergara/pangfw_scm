# =============================================================================
# Terraform Version and Provider Constraints
# =============================================================================

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }
    panos = {
      source  = "paloaltonetworks/panos"
      version = "~>1.11"
    }
  }
  
  # Optional: Configure remote state backend
  # Uncomment and configure for team/production use
  # backend "azurerm" {
  #   resource_group_name   = "terraform-state-rg"
  #   storage_account_name  = "terraformstate"
  #   container_name        = "tfstate"
  #   key                   = "pangfw.terraform.tfstate"
  # }
}

# =============================================================================
# Local Development Configuration
# =============================================================================

# For local development and testing
locals {
  # Check if we're running in a CI/CD pipeline
  is_ci_cd = can(regex("^(true|1)$", coalesce(
    try(env.TF_VAR_is_ci_cd, ""),
    try(env.CI, ""),
    try(env.BUILD_ID, ""),
    "false"
  )))
  
  # Terraform state management
  state_resource_group_name = "terraform-state-${var.project_name}-${var.environment}"
}

# =============================================================================
# Feature Flags for Development
# =============================================================================

variable "feature_flags" {
  description = "Feature flags for enabling/disabling components during development"
  type = object({
    enable_panorama_integration = optional(bool, true)
    enable_advanced_monitoring  = optional(bool, true)
    enable_backup_configuration = optional(bool, false)
    enable_disaster_recovery    = optional(bool, false)
    enable_auto_scaling        = optional(bool, false)
  })
  default = {}
}

# =============================================================================
# Development Environment Overrides
# =============================================================================

variable "dev_overrides" {
  description = "Development environment specific overrides"
  type = object({
    skip_panorama_config       = optional(bool, false)
    use_smaller_scale_units    = optional(bool, true)
    enable_debug_logging       = optional(bool, false)
    allow_insecure_management  = optional(bool, false)
  })
  default = {}
}