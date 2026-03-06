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
      type  = optional(string, "data") # Defaults to "data" if omitted
    }))
    
    # Global Config
    url         = string
    mount       = string
    tls_verify  = optional(bool, true)
    
    # Optional explicitly forced auth method
    auth_method = optional(string) 
    
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

  # Validation: Catch YAML typos in secret types immediately
  validation {
    condition = alltrue([
      for s in var.vault.secrets : contains(["data", "ephemeral"], s.type)
    ])
    error_message = "The 'type' for each secret must be either 'data' or 'ephemeral'."
  }

  # Validation: Ensure a supported auth method is selected (if provided)
  validation {
    condition     = var.vault.auth_method == null ? true : contains(["token", "k8s", "gcp"], var.vault.auth_method)
    error_message = "The auth_method must be 'token', 'k8s', or 'gcp'."
  }
}
