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
# Palo Alto Local Rulestacks
# =============================================================================

# Primary region local rulestack
resource "azurerm_palo_alto_local_rulestack" "primary" {
  name                = "${local.resource_prefix}-lrs-${local.regions.primary.short_name}"
  resource_group_name = azurerm_resource_group.primary.name
  location           = azurerm_resource_group.primary.location
  
  anti_spyware_profile   = var.anti_spyware_profile
  anti_virus_profile     = var.anti_virus_profile
  dns_subscription       = var.dns_subscription
  file_blocking_profile  = var.file_blocking_profile
  url_filtering_profile  = var.url_filtering_profile
  vulnerability_profile  = var.vulnerability_profile

  tags = local.common_tags
}

# Secondary region local rulestack
resource "azurerm_palo_alto_local_rulestack" "secondary" {
  name                = "${local.resource_prefix}-lrs-${local.regions.secondary.short_name}"
  resource_group_name = azurerm_resource_group.secondary.name
  location           = azurerm_resource_group.secondary.location
  
  anti_spyware_profile   = var.anti_spyware_profile
  anti_virus_profile     = var.anti_virus_profile
  dns_subscription       = var.dns_subscription
  file_blocking_profile  = var.file_blocking_profile
  url_filtering_profile  = var.url_filtering_profile
  vulnerability_profile  = var.vulnerability_profile

  tags = local.common_tags
}

# =============================================================================
# Palo Alto Next Generation Firewalls
# =============================================================================

# Primary region NGFW
resource "azurerm_palo_alto_next_generation_firewall_virtual_hub_panorama" "primary" {
  name                = "${local.resource_prefix}-ngfw-${local.regions.primary.short_name}"
  resource_group_name = azurerm_resource_group.primary.name
  location           = azurerm_resource_group.primary.location

  panorama_configuration {
    config_string    = var.panorama_config_string
    host_name       = var.panorama_hostname
    panorama_server = var.panorama_server
    panorama_server_2 = var.panorama_server_2
    template_name   = var.panorama_template_name
    virtual_machine_ssh_key = var.panorama_vm_ssh_key
  }

  network_profile {
    public_ip_address_ids          = [azurerm_public_ip.primary_ngfw.id]
    virtual_hub_id                = data.azurerm_virtual_hub.primary_hub.id
    network_virtual_appliance_id  = azurerm_network_virtual_appliance.primary.id
  }

  tags = local.common_tags

  depends_on = [azurerm_palo_alto_local_rulestack.primary]
}

# Secondary region NGFW
resource "azurerm_palo_alto_next_generation_firewall_virtual_hub_panorama" "secondary" {
  name                = "${local.resource_prefix}-ngfw-${local.regions.secondary.short_name}"
  resource_group_name = azurerm_resource_group.secondary.name
  location           = azurerm_resource_group.secondary.location

  panorama_configuration {
    config_string    = var.panorama_config_string
    host_name       = var.panorama_hostname
    panorama_server = var.panorama_server
    panorama_server_2 = var.panorama_server_2
    template_name   = var.panorama_template_name
    virtual_machine_ssh_key = var.panorama_vm_ssh_key
  }

  network_profile {
    public_ip_address_ids          = [azurerm_public_ip.secondary_ngfw.id]
    virtual_hub_id                = data.azurerm_virtual_hub.secondary_hub.id
    network_virtual_appliance_id  = azurerm_network_virtual_appliance.secondary.id
  }

  tags = local.common_tags

  depends_on = [azurerm_palo_alto_local_rulestack.secondary]
}

# =============================================================================
# Network Virtual Appliances
# =============================================================================

# Primary region NVA
resource "azurerm_network_virtual_appliance" "primary" {
  name                = "${local.resource_prefix}-nva-${local.regions.primary.short_name}"
  resource_group_name = azurerm_resource_group.primary.name
  location           = azurerm_resource_group.primary.location
  virtual_hub_id     = data.azurerm_virtual_hub.primary_hub.id

  sku {
    vendor             = "Palo Alto Networks"
    bundled_scale_unit = var.nva_scale_unit
    scale_unit         = var.nva_scale_unit
  }

  tags = local.common_tags
}

# Secondary region NVA
resource "azurerm_network_virtual_appliance" "secondary" {
  name                = "${local.resource_prefix}-nva-${local.regions.secondary.short_name}"
  resource_group_name = azurerm_resource_group.secondary.name
  location           = azurerm_resource_group.secondary.location
  virtual_hub_id     = data.azurerm_virtual_hub.secondary_hub.id

  sku {
    vendor             = "Palo Alto Networks"
    bundled_scale_unit = var.nva_scale_unit
    scale_unit         = var.nva_scale_unit
  }

  tags = local.common_tags
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
      next_hop     = azurerm_network_virtual_appliance.primary.id
    }
  }

  depends_on = [azurerm_network_virtual_appliance.primary]
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
      next_hop     = azurerm_network_virtual_appliance.secondary.id
    }
  }

  depends_on = [azurerm_network_virtual_appliance.secondary]
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