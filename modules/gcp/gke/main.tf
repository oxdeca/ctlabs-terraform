# -----------------------------------------------------------------------------
# File    : ctlabs-terraform/modules/gcp/gke/main.tf
# -----------------------------------------------------------------------------

locals {
  defaults = {
    labels = {
      module = "ctlabs-terraform-module-gke"
    }
    sa_prefix = "gke-"
  }
  services = [
    "container.googleapis.com",
    "compute.googleapis.com",
  ]
}

module "services" {
  source = "../services"

  services = local.services
  project  = { id = var.gke.project }
}

# -----------------------------------------------------------------------------
# Service Accounts
# -----------------------------------------------------------------------------

resource "google_service_account" "sa" {
  project      = var.gke.project
  account_id   = "${local.defaults.sa_prefix}${var.gke.name}"
  display_name = try(var.gke.name, null)
  description  = try(var.gke.desc, null)
}

# -----------------------------------------------------------------------------
# GKE Control Plane (Cluster)
# -----------------------------------------------------------------------------
resource "google_container_cluster" "primary" {
  name                      = var.gke.name
  location                  = var.gke.location
  project                   = var.gke.project
  network                   = var.gke.network
  subnetwork                = var.gke.subnetwork
  enable_autopilot          = var.gke.autopilot ? true : null
  remove_default_node_pool  = var.gke.autopilot ? null : true
  initial_node_count        = var.gke.autopilot ? null : 1
  default_max_pods_per_node = var.gke.autopilot ? null : 32
  deletion_protection       = var.gke.deletion_protection

  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  dynamic "node_config" {
    for_each = var.gke.autopilot ? [] : [1]
    content {
      service_account = google_service_account.sa.email
    }
  }

  # 1. VPC-Native Routing (Connects the Pods /23 and Services /26)
  dynamic "ip_allocation_policy" {
    for_each = var.gke.pods_range_name != null ? [1] : []
    content {
      cluster_secondary_range_name  = var.gke.pods_range_name
      services_secondary_range_name = var.gke.svcs_range_name
    }
  }

  # 2. Private Cluster Setup (Connects the Master /28)
  dynamic "private_cluster_config" {
    for_each = var.gke.master_cidr != null ? [1] : []
    content {
      enable_private_nodes    = true
      enable_private_endpoint = false
      master_ipv4_cidr_block  = var.gke.master_cidr
    }
  }

}

# -----------------------------------------------------------------------------
# GKE Managed Node Pools
# -----------------------------------------------------------------------------
resource "google_container_node_pool" "pools" {
  for_each = { for pool in var.gke.node_pools : pool.name => pool }

  name              = each.value.name
  cluster           = google_container_cluster.primary.name
  location          = var.gke.location
  project           = var.gke.project
  node_count        = each.value.node_count
  max_pods_per_node = each.value.max_pods_per_node

  node_config {
    service_account = google_service_account.sa.email
    machine_type    = each.value.machine_type
    disk_size_gb    = each.value.disk_size_gb
    disk_type       = each.value.disk_type
    image_type      = each.value.image_type
  }
}

# -----------------------------------------------------------------------------
# GKE OUTPUTS
# -----------------------------------------------------------------------------
output "cluster_name" {
  description = "The name of the GKE cluster."
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "The IP address of the cluster control plane."
  value       = google_container_cluster.primary.endpoint
}

output "ca_certificate" {
  description = "The cluster CA certificate (base64 encoded)."
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}
