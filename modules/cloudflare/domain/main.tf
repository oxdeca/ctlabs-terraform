# ------------------------------------------------------------------------------
# File : ctlabs-terraform/modules/cloudflare/domain/main.tf
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Domain (aka zone/site in cloudflare)
# ------------------------------------------------------------------------------
resource "cloudflare_zone" "domain" {
  account = {
    id = var.account.id
  }
  name   = var.domain.name
  type   = var.domain.type
  paused = var.domain.paused
}

# ------------------------------------------------------------------------------
# Zone Subscription (For Paid Plans)
# ------------------------------------------------------------------------------
resource "cloudflare_zone_subscription" "subscription" {
  count = var.domain.plan != "free" ? 1 : 0

  zone_id = cloudflare_zone.domain.id

  rate_plan = {
    id = var.domain.plan
  }
}

# ------------------------------------------------------------------------------
# Zone Settings
# ------------------------------------------------------------------------------
resource "cloudflare_zone_setting" "settings" {
  for_each = var.domain.dns_settings

  zone_id    = cloudflare_zone.domain.id
  setting_id = each.key
  value      = can(tostring(each.value)) ? tostring(each.value) : jsondecode(each.value)
}

# ------------------------------------------------------------------------------
# Universal SSL
# ------------------------------------------------------------------------------
resource "cloudflare_universal_ssl_setting" "universal_ssl" {
  zone_id = var.cloudflare_zone.domain.id
  enabled = var.domain.universal_ssl
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "id" {
  value = cloudflare_zone.domain.id
}

output "domain" {
  value = cloudflare_zone.domain.name
}

output "name_servers" {
  value = cloudflare_zone.domain.name_servers
}
