# -----------------------------------------------------------------------------
# File: ctlabs-terraform/modules/cloudflare/dns/variables.tf
# -----------------------------------------------------------------------------

variable "account" {
  description = "The Cloudflare Account credentials"
  type = object({
    id = string
  })
}

variable "domain" {
  description = "The Cloudflare Domain (Site) details and its DNS records"
  type = object({
    id           = string
    name         = string
    parent       = optional(string)
    name_servers = list(string)
    
    records = optional(list(object({
      name     = string
      content  = optional(string)
      type     = optional(string, "A")
      ttl      = optional(number, 1)
      proxied  = optional(bool, false)
      priority = optional(number)
      comment  = optional(string)
      data = optional(object({
        flags = optional(number)
        tag   = optional(string)
        value = optional(string)
      }))
    })), [])
  })
}
