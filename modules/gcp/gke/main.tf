# -----------------------------------------------------------------------------
# File    : ctlabs-terraform/modules/gcp/gke/main.tf
# License : MIT
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# GKE Control Plane (Cluster)
# -----------------------------------------------------------------------------
resource "google_container_cluster" "primary" {
  name     = var.gke.name
  project  = var.gke.project
  location = var.gke.location

  network    = var.gke.network
  subnetwork = var.gke.subnetwork

  # Best Practice: We delete the default pool created by GCP and manage
  # node pools natively via the google_container_node_pool resource below.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Workload Identity is the modern standard for Pod-to-GCP authentication.
  # Highly recommended even for minimum clusters.
  workload_identity_config {
    workload_pool = "${var.gke.project}.svc.id.goog"
  }
}

# -----------------------------------------------------------------------------
# GKE Managed Node Pools
# -----------------------------------------------------------------------------
resource "google_container_node_pool" "pools" {
  for_each = { for pool in var.gke.node_pools : pool.name => pool }

  name       = each.value.name
  project    = var.gke.project
  location   = var.gke.location
  cluster    = google_container_cluster.primary.name
  node_count = each.value.node_count

  node_config {
    machine_type = each.value.machine_type
    disk_size_gb = each.value.disk_size_gb
    disk_type    = each.value.disk_type

    # Standard minimum OAuth scopes required for the nodes to function
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
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
