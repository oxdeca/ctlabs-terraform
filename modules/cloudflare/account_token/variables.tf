# ------------------------------------------------------------------------------
# File : ctlabs-terraform/modules/cloudflare/account_token/variables.tf
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
