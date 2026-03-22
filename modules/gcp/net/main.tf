# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/network/main.tf
# Description : network module
# -----------------------------------------------------------------------------

locals {
  # Map networks by name for the network resource for_each loop
  network_map = { for net in var.network : net.name => net }

  # Flatten the nested subnets list into a single level list so we can iterate over it easily
  flattened_subnets = flatten([
    for net in var.network : [
      for sub in coalesce(net.subnets, []) : merge(sub, {
        network_name = net.name
      })
    ]
  ])

  # Create a map with a unique key for each subnet (network_name + region + subnet_name)
  subnet_map = { for sub in local.flattened_subnets : "${sub.network_name}-${sub.region}-${sub.name}" => sub }
}

# -----------------------------------------------------------------------------
# Networks
# -----------------------------------------------------------------------------
resource "google_compute_network" "network" {
  for_each = local.network_map

  project                         = var.project.id
  name                            = each.value.name
  description                     = each.value.desc
  auto_create_subnetworks         = each.value.auto_subnets
  routing_mode                    = each.value.routing
  delete_default_routes_on_create = each.value.delete_routes
  mtu                             = each.value.mtu
}

# -----------------------------------------------------------------------------
# Subnets
# -----------------------------------------------------------------------------
resource "google_compute_subnetwork" "subnet" {
  for_each = local.subnet_map

  project                   = var.project.id
  network                   = google_compute_network.network[each.value.network_name].id
  name                      = each.value.name
  region                    = each.value.region
  ip_cidr_range             = each.value.cidr
  description               = each.value.desc
  purpose                   = each.value.purpose
  role                      = each.value.role
  private_ip_google_access  = each.value.private_access
  
  # Dual-stack / IPv6 configurations
  stack_type                = each.value.stack
  ipv6_access_type          = each.value.ipv6_access

  # Secondary ranges (e.g., for GKE)
  dynamic "secondary_ip_range" {
    for_each = each.value.ranges != null ? each.value.ranges : []
    content {
      range_name    = secondary_ip_range.value.name
      ip_cidr_range = secondary_ip_range.value.cidr
    }
  }
}