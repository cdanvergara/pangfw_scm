# =============================================================================
# Palo Alto Next Generation Firewall on Azure - Multi-Region Template
# =============================================================================

terraform {
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
  required_version = ">=1.0"
}

# Configure the Azure Provider
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# =============================================================================
# Local Values
# =============================================================================

locals {
  # Common tags applied to all resources
  common_tags = merge(var.tags, {
    Environment   = var.environment
    Project       = var.project_name
    DeployedBy    = "Terraform"
    DeployedDate  = timestamp()
  })

  # Standardized naming convention
  resource_prefix = "${var.project_name}-${var.environment}"
  
  # Region configurations
  regions = {
    primary = {
      name                = var.primary_region
      short_name          = var.primary_region_short
      resource_group_name = "${local.resource_prefix}-rg-${var.primary_region_short}"
    }
    secondary = {
      name                = var.secondary_region
      short_name          = var.secondary_region_short
      resource_group_name = "${local.resource_prefix}-rg-${var.secondary_region_short}"
    }
  }
}

# =============================================================================
# Data Sources
# =============================================================================

# Get existing Virtual WAN
data "azurerm_virtual_wan" "existing_vwan" {
  name                = var.existing_vwan_name
  resource_group_name = var.existing_vwan_resource_group
}

# Get existing Virtual Hubs
data "azurerm_virtual_hub" "primary_hub" {
  name                = var.existing_vhub_primary_name
  resource_group_name = var.existing_vwan_resource_group
}

data "azurerm_virtual_hub" "secondary_hub" {
  name                = var.existing_vhub_secondary_name
  resource_group_name = var.existing_vwan_resource_group
}

# =============================================================================
# Resource Groups
# =============================================================================

# Primary region resource group
resource "azurerm_resource_group" "primary" {
  name     = local.regions.primary.resource_group_name
  location = local.regions.primary.name
  tags     = local.common_tags
}

# Secondary region resource group
resource "azurerm_resource_group" "secondary" {
  name     = local.regions.secondary.resource_group_name
  location = local.regions.secondary.name
  tags     = local.common_tags
}

# =============================================================================
# Public IP Addresses
# =============================================================================

# Public IP for primary region NGFW
resource "azurerm_public_ip" "primary_ngfw" {
  name                = "${local.resource_prefix}-pip-ngfw-${local.regions.primary.short_name}"
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name
  allocation_method   = "Static"
  sku                = "Standard"
  zones              = var.availability_zones
  tags               = local.common_tags
}

# Public IP for secondary region NGFW
resource "azurerm_public_ip" "secondary_ngfw" {
  name                = "${local.resource_prefix}-pip-ngfw-${local.regions.secondary.short_name}"
  location            = azurerm_resource_group.secondary.location
  resource_group_name = azurerm_resource_group.secondary.name
  allocation_method   = "Static"
  sku                = "Standard"
  zones              = var.availability_zones
  tags               = local.common_tags
}

# =============================================================================
# Palo Alto Virtual Network Appliances
# =============================================================================

# Primary region Virtual Network Appliance
resource "azurerm_palo_alto_virtual_network_appliance" "primary" {
  name           = "${local.resource_prefix}-appliance-${local.regions.primary.short_name}"
  virtual_hub_id = data.azurerm_virtual_hub.primary_hub.id
  
  tags = local.common_tags
}

# Secondary region Virtual Network Appliance
resource "azurerm_palo_alto_virtual_network_appliance" "secondary" {
  name           = "${local.resource_prefix}-appliance-${local.regions.secondary.short_name}"
  virtual_hub_id = data.azurerm_virtual_hub.secondary_hub.id
  
  tags = local.common_tags
}

# =============================================================================
# Palo Alto Next Generation Firewalls with Strata Cloud Manager
# =============================================================================

# Primary region NGFW with Strata Cloud Manager
resource "azurerm_palo_alto_next_generation_firewall_virtual_hub_strata_cloud_manager" "primary" {
  name                             = "${local.resource_prefix}-ngfw-${local.regions.primary.short_name}"
  resource_group_name              = azurerm_resource_group.primary.name
  location                        = azurerm_resource_group.primary.location
  strata_cloud_manager_tenant_name = var.strata_cloud_manager_tenant_name

  network_profile {
    public_ip_address_ids        = [azurerm_public_ip.primary_ngfw.id]
    virtual_hub_id              = data.azurerm_virtual_hub.primary_hub.id
    network_virtual_appliance_id = azurerm_palo_alto_virtual_network_appliance.primary.id
    
    dynamic "trusted_address_ranges" {
      for_each = var.trusted_address_ranges
      content {
        trusted_address_ranges = trusted_address_ranges.value
      }
    }
  }

  dynamic "dns_settings" {
    for_each = var.enable_custom_dns ? [1] : []
    content {
      dns_servers    = var.custom_dns_servers
      use_azure_dns  = length(var.custom_dns_servers) == 0
    }
  }

  dynamic "destination_nat" {
    for_each = var.destination_nat_rules
    content {
      name     = destination_nat.value.name
      protocol = destination_nat.value.protocol
      
      dynamic "backend_config" {
        for_each = destination_nat.value.backend_configs
        content {
          port               = backend_config.value.port
          public_ip_address  = backend_config.value.public_ip_address
        }
      }
      
      dynamic "frontend_config" {
        for_each = destination_nat.value.frontend_configs
        content {
          port                  = frontend_config.value.port
          public_ip_address_id  = frontend_config.value.public_ip_address_id
        }
      }
    }
  }

  tags = local.common_tags

  depends_on = [azurerm_palo_alto_virtual_network_appliance.primary]
}

# Secondary region NGFW with Strata Cloud Manager
resource "azurerm_palo_alto_next_generation_firewall_virtual_hub_strata_cloud_manager" "secondary" {
  name                             = "${local.resource_prefix}-ngfw-${local.regions.secondary.short_name}"
  resource_group_name              = azurerm_resource_group.secondary.name
  location                        = azurerm_resource_group.secondary.location
  strata_cloud_manager_tenant_name = var.strata_cloud_manager_tenant_name

  network_profile {
    public_ip_address_ids        = [azurerm_public_ip.secondary_ngfw.id]
    virtual_hub_id              = data.azurerm_virtual_hub.secondary_hub.id
    network_virtual_appliance_id = azurerm_palo_alto_virtual_network_appliance.secondary.id
    
    dynamic "trusted_address_ranges" {
      for_each = var.trusted_address_ranges
      content {
        trusted_address_ranges = trusted_address_ranges.value
      }
    }
  }

  dynamic "dns_settings" {
    for_each = var.enable_custom_dns ? [1] : []
    content {
      dns_servers    = var.custom_dns_servers
      use_azure_dns  = length(var.custom_dns_servers) == 0
    }
  }

  dynamic "destination_nat" {
    for_each = var.destination_nat_rules
    content {
      name     = destination_nat.value.name
      protocol = destination_nat.value.protocol
      
      dynamic "backend_config" {
        for_each = destination_nat.value.backend_configs
        content {
          port               = backend_config.value.port
          public_ip_address  = backend_config.value.public_ip_address
        }
      }
      
      dynamic "frontend_config" {
        for_each = destination_nat.value.frontend_configs
        content {
          port                  = frontend_config.value.port
          public_ip_address_id  = frontend_config.value.public_ip_address_id
        }
      }
    }
  }

  tags = local.common_tags

  depends_on = [azurerm_palo_alto_virtual_network_appliance.secondary]
}



# =============================================================================
# Virtual Hub Routing Intents
# =============================================================================

# Primary region routing intent
resource "azurerm_virtual_hub_routing_intent" "primary" {
  name           = "${local.resource_prefix}-routing-intent-${local.regions.primary.short_name}"
  virtual_hub_id = data.azurerm_virtual_hub.primary_hub.id

  dynamic "routing_policy" {
    for_each = var.routing_policies
    content {
      name         = routing_policy.value.name
      destinations = routing_policy.value.destinations
      next_hop     = azurerm_palo_alto_virtual_network_appliance.primary.id
    }
  }

  depends_on = [azurerm_palo_alto_virtual_network_appliance.primary]
}

# Secondary region routing intent
resource "azurerm_virtual_hub_routing_intent" "secondary" {
  name           = "${local.resource_prefix}-routing-intent-${local.regions.secondary.short_name}"
  virtual_hub_id = data.azurerm_virtual_hub.secondary_hub.id

  dynamic "routing_policy" {
    for_each = var.routing_policies
    content {
      name         = routing_policy.value.name
      destinations = routing_policy.value.destinations
      next_hop     = azurerm_palo_alto_virtual_network_appliance.secondary.id
    }
  }

  depends_on = [azurerm_palo_alto_virtual_network_appliance.secondary]
}

# =============================================================================
# Optional: Log Analytics Workspace for Monitoring
# =============================================================================

resource "azurerm_log_analytics_workspace" "ngfw_monitoring" {
  count               = var.enable_monitoring ? 1 : 0
  name                = "${local.resource_prefix}-law-ngfw"
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_retention_days
  tags                = local.common_tags
}

# =============================================================================
# Optional: Network Security Groups
# =============================================================================

resource "azurerm_network_security_group" "ngfw_management" {
  count               = var.create_management_nsg ? 1 : 0
  name                = "${local.resource_prefix}-nsg-mgmt"
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.management_allowed_ips
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.management_allowed_ips
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}