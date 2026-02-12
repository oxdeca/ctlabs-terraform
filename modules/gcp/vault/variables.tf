# -----------------------------------------------------------------------------
# File    : ctlabs-terraform/modules/gcp/vault/variables.tf
# License : MIT
# -----------------------------------------------------------------------------

variable "vault" {
  type = object({
    secrets = list(object({
      name = string
      path = string
    }))
    url        = string
    mount      = string
    env        = optional(string)
    approle    = optional(string)
    ssl_verify = optional(bool, true)
    gsm = optional(object({
      project   = optional(string)
      role_id   = optional(string)
      secret_id = optional(string)
    }), {})
  })
}
