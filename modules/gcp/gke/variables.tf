# -----------------------------------------------------------------------------
# File    : ctlabs-terraform/modules/gcp/gke/variables.tf
# License : MIT
# -----------------------------------------------------------------------------

variable "gke" {
  description = "Configuration object for the minimal GKE Cluster"
  type = object({
    project    = string
    location   = string
    name       = string
    network    = optional(string, "default")
    subnetwork = optional(string, "default")

    # Node Pool Definitions
    node_pools = optional(list(object({
      name         = string
      machine_type = optional(string, "e2-medium")
      node_count   = optional(number, 1)
      disk_size_gb = optional(number, 20)
      disk_type    = optional(string, "pd-standard")
    })), [
      # Fallback to a single minimal node pool if none is provided in YAML
      {
        name         = "default-pool"
        machine_type = "e2-medium"
        node_count   = 1
        disk_size_gb = 20
        disk_type    = "pd-standard"
      }
    ])
  })
}
