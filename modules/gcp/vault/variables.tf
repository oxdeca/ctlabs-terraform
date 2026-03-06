# -----------------------------------------------------------------------------
# File    : ctlabs-terraform/modules/gcp/vault/variables.tf
# License : MIT
# -----------------------------------------------------------------------------

variable "vault" {
  type = object({
    # Secret Definitions
    secrets = list(object({
      name  = string
      path  = string
      mount = optional(string)
      type  = optional(string, "data")
    }))
    
    # Global Config
    url         = string
    mount       = string
    tls_verify  = optional(bool, true)
    
    # Kubernetes Auth Settings
    k8s = optional(object({
      role       = string
      mount_path = optional(string, "kubernetes")
      jwt_path   = optional(string, "/var/run/secrets/kubernetes.io/serviceaccount/token")
    }))

    # GCP Auth Settings
    gcp = optional(object({
      role       = string
      mount_path = optional(string, "gcp")
    }))
  })

  validation {
    condition = alltrue([
      for s in var.vault.secrets : contains(["data", "ephemeral"], s.type)
    ])
    error_message = "The 'type' for each secret must be either 'data' or 'ephemeral'."
  }
}
