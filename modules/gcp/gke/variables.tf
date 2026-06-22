# -----------------------------------------------------------------------------
# File    : ctlabs-terraform/modules/gcp/gke/variables.tf
# -----------------------------------------------------------------------------

variable "gke" {
  description = "Configuration object for the minimal GKE Cluster"
  type = object({
    project             = string
    location            = string
    name                = string
    network             = optional(string, "default")
    subnetwork          = optional(string, "default")
    autopilot           = optional(bool, false)
    deletion_protection = optional(bool, false)
    pods_range_name     = optional(string)
    svcs_range_name     = optional(string)
    master_cidr         = optional(string)

    # Node Pool Definitions
    node_pools = optional(list(object({
      name              = string
      machine_type      = optional(string, "e2-medium")
      node_count        = optional(number, 1)
      disk_size_gb      = optional(number, 20)
      disk_type         = optional(string, "pd-standard")
      max_pods_per_node = optional(number, 32)
      image_type        = optional(string, "COS_CONTAINERD")
    })), [
      {
        name         = "default-pool"
        machine_type = "e2-medium"
        node_count   = 1
        disk_size_gb = 20
        disk_type    = "pd-standard"
        image_type   = "COS_CONTAINERD"
      }
    ])
  })
}
