# ------------------------------------------------------------------------------
# File : ctlabs-terraform/modules/cloudflare/domain/variables.tf
# ------------------------------------------------------------------------------

variable account {
  description = "The Cloudflare Account details"
  type = object({
    id = string
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

    features      = optional(map(any), {})
    settings      = optional(any, {})
  })
}
