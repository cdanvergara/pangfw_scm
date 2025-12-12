# =============================================================================
# Output Values for Palo Alto Next Generation Firewall on Azure
# =============================================================================

# =============================================================================
# Resource Group Outputs
# =============================================================================

output "primary_resource_group_id" {
  description = "ID of the primary region resource group"
  value       = azurerm_resource_group.primary.id
}

output "primary_resource_group_name" {
  description = "Name of the primary region resource group"
  value       = azurerm_resource_group.primary.name
}

output "secondary_resource_group_id" {
  description = "ID of the secondary region resource group"
  value       = azurerm_resource_group.secondary.id
}

output "secondary_resource_group_name" {
  description = "Name of the secondary region resource group"
  value       = azurerm_resource_group.secondary.name
}

# =============================================================================
# Public IP Outputs
# =============================================================================

output "primary_ngfw_public_ip" {
  description = "Public IP address of the primary region NGFW"
  value       = azurerm_public_ip.primary_ngfw.ip_address
}

output "primary_ngfw_public_ip_id" {
  description = "ID of the primary region NGFW public IP"
  value       = azurerm_public_ip.primary_ngfw.id
}

output "secondary_ngfw_public_ip" {
  description = "Public IP address of the secondary region NGFW"
  value       = azurerm_public_ip.secondary_ngfw.ip_address
}

output "secondary_ngfw_public_ip_id" {
  description = "ID of the secondary region NGFW public IP"
  value       = azurerm_public_ip.secondary_ngfw.id
}

# =============================================================================
# NGFW Outputs
# =============================================================================

output "primary_ngfw_id" {
  description = "ID of the primary region Next Generation Firewall"
  value       = azurerm_palo_alto_next_generation_firewall_virtual_hub_strata_cloud_manager.primary.id
}

output "primary_ngfw_name" {
  description = "Name of the primary region Next Generation Firewall"
  value       = azurerm_palo_alto_next_generation_firewall_virtual_hub_strata_cloud_manager.primary.name
}

output "secondary_ngfw_id" {
  description = "ID of the secondary region Next Generation Firewall"
  value       = azurerm_palo_alto_next_generation_firewall_virtual_hub_strata_cloud_manager.secondary.id
}

output "secondary_ngfw_name" {
  description = "Name of the secondary region Next Generation Firewall"
  value       = azurerm_palo_alto_next_generation_firewall_virtual_hub_strata_cloud_manager.secondary.name
}

output "strata_cloud_manager_tenant" {
  description = "Strata Cloud Manager tenant name managing these firewalls"
  value       = var.strata_cloud_manager_tenant_name
}

# =============================================================================
# Virtual Network Appliance Outputs
# =============================================================================

output "primary_appliance_id" {
  description = "ID of the primary region Palo Alto Virtual Network Appliance"
  value       = azurerm_palo_alto_virtual_network_appliance.primary.id
}

output "primary_appliance_name" {
  description = "Name of the primary region Palo Alto Virtual Network Appliance"
  value       = azurerm_palo_alto_virtual_network_appliance.primary.name
}

output "secondary_appliance_id" {
  description = "ID of the secondary region Palo Alto Virtual Network Appliance"
  value       = azurerm_palo_alto_virtual_network_appliance.secondary.id
}

output "secondary_appliance_name" {
  description = "Name of the secondary region Palo Alto Virtual Network Appliance"
  value       = azurerm_palo_alto_virtual_network_appliance.secondary.name
}



# =============================================================================
# Routing Intent Outputs
# =============================================================================

output "primary_routing_intent_id" {
  description = "ID of the primary region routing intent"
  value       = azurerm_virtual_hub_routing_intent.primary.id
}

output "secondary_routing_intent_id" {
  description = "ID of the secondary region routing intent"
  value       = azurerm_virtual_hub_routing_intent.secondary.id
}

# =============================================================================
# Virtual WAN and Hub Outputs
# =============================================================================

output "virtual_wan_id" {
  description = "ID of the existing Virtual WAN"
  value       = data.azurerm_virtual_wan.existing_vwan.id
}

output "primary_virtual_hub_id" {
  description = "ID of the primary region Virtual Hub"
  value       = data.azurerm_virtual_hub.primary_hub.id
}

output "secondary_virtual_hub_id" {
  description = "ID of the secondary region Virtual Hub"
  value       = data.azurerm_virtual_hub.secondary_hub.id
}

# =============================================================================
# Monitoring Outputs
# =============================================================================

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace (if enabled)"
  value       = var.enable_monitoring ? azurerm_log_analytics_workspace.ngfw_monitoring[0].id : null
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace (if enabled)"
  value       = var.enable_monitoring ? azurerm_log_analytics_workspace.ngfw_monitoring[0].name : null
}

# =============================================================================
# Management Outputs
# =============================================================================

output "management_urls" {
  description = "Management URLs for the NGFWs"
  value = {
    primary_region   = "https://${azurerm_public_ip.primary_ngfw.ip_address}"
    secondary_region = "https://${azurerm_public_ip.secondary_ngfw.ip_address}"
  }
}

output "ssh_connection_strings" {
  description = "SSH connection strings for NGFW management"
  value = {
    primary_region   = "ssh admin@${azurerm_public_ip.primary_ngfw.ip_address}"
    secondary_region = "ssh admin@${azurerm_public_ip.secondary_ngfw.ip_address}"
  }
  sensitive = true
}

# =============================================================================
# Network Security Group Outputs
# =============================================================================

output "management_nsg_id" {
  description = "ID of the management Network Security Group (if created)"
  value       = var.create_management_nsg ? azurerm_network_security_group.ngfw_management[0].id : null
}

# =============================================================================
# Regional Information Outputs
# =============================================================================

output "deployment_regions" {
  description = "Information about the deployed regions"
  value = {
    primary = {
      name       = local.regions.primary.name
      short_name = local.regions.primary.short_name
    }
    secondary = {
      name       = local.regions.secondary.name
      short_name = local.regions.secondary.short_name
    }
  }
}

# =============================================================================
# Cost Management Outputs
# =============================================================================

output "resource_tags" {
  description = "Common tags applied to all resources"
  value       = local.common_tags
}

# =============================================================================
# Azure Portal Links
# =============================================================================

output "azure_portal_links" {
  description = "Direct links to Azure portal for resource management"
  value = {
    primary_resource_group   = "https://portal.azure.com/#@/resource${azurerm_resource_group.primary.id}"
    secondary_resource_group = "https://portal.azure.com/#@/resource${azurerm_resource_group.secondary.id}"
    primary_ngfw            = "https://portal.azure.com/#@/resource${azurerm_palo_alto_next_generation_firewall_virtual_hub_strata_cloud_manager.primary.id}"
    secondary_ngfw          = "https://portal.azure.com/#@/resource${azurerm_palo_alto_next_generation_firewall_virtual_hub_strata_cloud_manager.secondary.id}"
    virtual_wan             = "https://portal.azure.com/#@/resource${data.azurerm_virtual_wan.existing_vwan.id}"
    strata_cloud_manager    = "https://apps.paloaltonetworks.com/"
  }
}

# =============================================================================
# Summary Output
# =============================================================================

output "deployment_summary" {
  description = "Summary of the deployed infrastructure"
  value = {
    project_name               = var.project_name
    environment                = var.environment
    primary_region             = local.regions.primary.name
    secondary_region           = local.regions.secondary.name
    ngfw_count                 = 2
    virtual_appliance_count    = 2
    public_ips                 = 2
    monitoring_enabled         = var.enable_monitoring
    management_type            = "Strata Cloud Manager"
    strata_tenant              = var.strata_cloud_manager_tenant_name
  }
}