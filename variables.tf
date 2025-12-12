# =============================================================================
# Variables for Palo Alto Next Generation Firewall on Azure - Multi-Region
# =============================================================================

# =============================================================================
# General Configuration Variables
# =============================================================================

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "Subscription ID must be a valid GUID."
  }
}

variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
  default     = "pangfw"
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{2,10}$", var.project_name))
    error_message = "Project name must be 2-10 characters long and contain only alphanumeric characters and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, prod."
  }
}

# =============================================================================
# Region Configuration Variables
# =============================================================================

variable "primary_region" {
  description = "Primary Azure region for NGFW deployment"
  type        = string
  default     = "East US"
}

variable "primary_region_short" {
  description = "Short name for primary region (used in resource naming)"
  type        = string
  default     = "eus"
}

variable "secondary_region" {
  description = "Secondary Azure region for NGFW deployment"
  type        = string
  default     = "Central US"
}

variable "secondary_region_short" {
  description = "Short name for secondary region (used in resource naming)"
  type        = string
  default     = "cus"
}

variable "availability_zones" {
  description = "Availability zones for high availability deployment"
  type        = list(string)
  default     = ["1", "2", "3"]
}

# =============================================================================
# Existing Infrastructure Variables
# =============================================================================

variable "existing_vwan_resource_group" {
  description = "Resource group name containing the existing Virtual WAN"
  type        = string
}

variable "existing_vwan_name" {
  description = "Name of the existing Virtual WAN"
  type        = string
}

variable "existing_vhub_primary_name" {
  description = "Name of the existing Virtual Hub in the primary region"
  type        = string
}

variable "existing_vhub_secondary_name" {
  description = "Name of the existing Virtual Hub in the secondary region"
  type        = string
}

# =============================================================================
# Panorama Configuration Variables
# =============================================================================

variable "panorama_hostname" {
  description = "Panorama hostname for NGFW management"
  type        = string
  default     = ""
}

variable "panorama_server" {
  description = "Primary Panorama server IP address"
  type        = string
  default     = ""
}

variable "panorama_server_2" {
  description = "Secondary Panorama server IP address (optional)"
  type        = string
  default     = ""
}

variable "panorama_config_string" {
  description = "Panorama configuration string"
  type        = string
  default     = ""
}

variable "panorama_template_name" {
  description = "Panorama template name"
  type        = string
  default     = ""
}

variable "panorama_vm_ssh_key" {
  description = "SSH public key for Panorama VM access"
  type        = string
  default     = ""
}

# =============================================================================
# Security Profile Variables
# =============================================================================

variable "anti_spyware_profile" {
  description = "Anti-spyware profile name"
  type        = string
  default     = "BestPractice"
}

variable "anti_virus_profile" {
  description = "Anti-virus profile name"
  type        = string
  default     = "BestPractice"
}

variable "dns_subscription" {
  description = "DNS subscription type"
  type        = string
  default     = "BestPractice"
}

variable "file_blocking_profile" {
  description = "File blocking profile name"
  type        = string
  default     = "BestPractice"
}

variable "url_filtering_profile" {
  description = "URL filtering profile name"
  type        = string
  default     = "BestPractice"
}

variable "vulnerability_profile" {
  description = "Vulnerability protection profile name"
  type        = string
  default     = "BestPractice"
}

# =============================================================================
# Network Virtual Appliance Variables
# =============================================================================

variable "nva_scale_unit" {
  description = "Scale unit for Network Virtual Appliance"
  type        = number
  default     = 1
  validation {
    condition     = var.nva_scale_unit >= 1 && var.nva_scale_unit <= 20
    error_message = "NVA scale unit must be between 1 and 20."
  }
}

# =============================================================================
# Routing Configuration Variables
# =============================================================================

variable "routing_policies" {
  description = "List of routing policies for Virtual Hub routing intent"
  type = list(object({
    name         = string
    destinations = list(string)
  }))
  default = [
    {
      name         = "InternetTraffic"
      destinations = ["Internet"]
    },
    {
      name         = "PrivateTraffic"
      destinations = ["PrivateTraffic"]
    }
  ]
}

# =============================================================================
# Monitoring and Logging Variables
# =============================================================================

variable "enable_monitoring" {
  description = "Enable Log Analytics workspace for monitoring"
  type        = bool
  default     = true
}

variable "log_analytics_sku" {
  description = "SKU for Log Analytics workspace"
  type        = string
  default     = "PerGB2018"
  validation {
    condition     = contains(["Free", "Standalone", "PerNode", "PerGB2018"], var.log_analytics_sku)
    error_message = "Log Analytics SKU must be one of: Free, Standalone, PerNode, PerGB2018."
  }
}

variable "log_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 30
  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "Log retention days must be between 30 and 730."
  }
}

# =============================================================================
# Security Variables
# =============================================================================

variable "create_management_nsg" {
  description = "Create Network Security Group for management access"
  type        = bool
  default     = true
}

variable "management_allowed_ips" {
  description = "List of IP addresses allowed for management access"
  type        = list(string)
  default     = ["0.0.0.0/0"] # CHANGE THIS FOR PRODUCTION
  validation {
    condition = alltrue([
      for ip in var.management_allowed_ips : can(cidrhost(ip, 0))
    ])
    error_message = "All management allowed IPs must be valid CIDR blocks."
  }
}

# =============================================================================
# Tagging Variables
# =============================================================================

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# =============================================================================
# Cost Management Variables
# =============================================================================

variable "enable_auto_shutdown" {
  description = "Enable automatic shutdown for cost management (dev/test environments)"
  type        = bool
  default     = false
}

variable "auto_shutdown_time" {
  description = "Time for automatic shutdown in format HH:MM (24-hour format)"
  type        = string
  default     = "19:00"
  validation {
    condition     = can(regex("^([01]?[0-9]|2[0-3]):[0-5][0-9]$", var.auto_shutdown_time))
    error_message = "Auto shutdown time must be in HH:MM format (24-hour)."
  }
}

# =============================================================================
# Advanced Configuration Variables
# =============================================================================

variable "enable_ddos_protection" {
  description = "Enable DDoS protection on public IPs"
  type        = bool
  default     = true
}

variable "custom_dns_servers" {
  description = "Custom DNS servers for NGFW (optional)"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for ip in var.custom_dns_servers : can(cidrhost("${ip}/32", 0))
    ])
    error_message = "All DNS servers must be valid IP addresses."
  }
}

variable "backup_region" {
  description = "Backup region for disaster recovery (optional)"
  type        = string
  default     = "West US 2"
}

variable "enable_backup" {
  description = "Enable backup configuration for disaster recovery"
  type        = bool
  default     = false
}

# =============================================================================
# Performance Variables
# =============================================================================

variable "throughput_capacity" {
  description = "Throughput capacity in Gbps"
  type        = number
  default     = 1
  validation {
    condition     = var.throughput_capacity >= 1 && var.throughput_capacity <= 100
    error_message = "Throughput capacity must be between 1 and 100 Gbps."
  }
}

variable "session_capacity" {
  description = "Session capacity in thousands"
  type        = number
  default     = 100
  validation {
    condition     = var.session_capacity >= 50 && var.session_capacity <= 2000
    error_message = "Session capacity must be between 50 and 2000 thousands."
  }
}