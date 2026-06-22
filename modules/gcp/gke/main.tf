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

  # Detect OS types across node pools
  has_linux   = anytrue([for p in var.gke.node_pools : !strcontains(coalesce(p.image_type, ""), "WINDOWS")])
  has_windows = anytrue([for p in var.gke.node_pools : strcontains(coalesce(p.image_type, ""), "WINDOWS")])

  # Ensure at least one Linux pool exists when Windows pools are defined.
  # GKE requires a Linux node pool to host system components.
  default_linux_pool = {
    name               = "default-pool"
    machine_type       = "e2-medium"
    node_count         = 1
    disk_size_gb       = 20
    disk_type          = "pd-standard"
    max_pods_per_node  = 32
    image_type         = "COS_CONTAINERD"
    windows_os_version = null
  }
  effective_node_pools = local.has_linux ? var.gke.node_pools : concat(var.gke.node_pools, [local.default_linux_pool])
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
resource "google_container_node_pool" "linux_pools" {
  for_each = {
    for pool in local.effective_node_pools : pool.name => pool
    if !strcontains(coalesce(pool.image_type, ""), "WINDOWS")
  }

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

resource "google_container_node_pool" "windows_pools" {
  for_each = {
    for pool in local.effective_node_pools : pool.name => pool
    if strcontains(coalesce(pool.image_type, ""), "WINDOWS")
  }

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

    shielded_instance_config {
      enable_integrity_monitoring = false
      enable_secure_boot          = false
    }

    dynamic "windows_node_config" {
      for_each = each.value.windows_os_version != null ? [1] : []
      content {
        osversion = each.value.windows_os_version
      }
    }
  }

  depends_on = [google_container_node_pool.linux_pools]
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
