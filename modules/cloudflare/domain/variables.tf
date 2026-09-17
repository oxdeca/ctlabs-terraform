# ------------------------------------------------------------------------------
# File : ctlabs-terraform/modules/cloudflare/domain/variables.tf
# ------------------------------------------------------------------------------

variable account {
  type = object({
    id      = string
    zone_id = string
    tokens = list(object({
      name  = string
      scope = string
      perms = list(string)
    }))
  })
}


variable domain {
  description = "Configuration for the Cloudflare Zone and it features/settings"
  type = object({
    name          = string
    plan          = optional(string, "free")
    type          = optional(string, "full")
    paused        = optional(bool, false)
    universal_ssl = optional(bool, true)

    features      = optional(any {})
    settings      = optional(any {})
  })
}
