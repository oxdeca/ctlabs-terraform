# -----------------------------------------------------------------------------
# File: ctlabs-terraform/modules/cloudflare/dns/main.tf
# -----------------------------------------------------------------------------

locals {
  dns_record = {
    for r in var.domain.records:
      "${r.type}_${r.name}_${replace(var.domain.name, ".", "_")}_${md5(jsonencode({
        name = r.name
        type = r.type
        conent = coalesce(r.content, try(r.data.value, null), "")
      }))}" => r
  }
}

resource "cloudflare_dns_record" "record" {
  for_each = local.dns_records

  zone_id  = var.domain.id
  name     = each.value.name
  type     = each.value.type
  content  = each.value.content
  ttl      = each.value.ttl
  proxied  = each.value.proxied
  priority = each.value.priority
  comment  = each.value.comment
  data     = each.value.data
}

data "cloudflare_zone" "parent" {
  count = var.domain.parent != null ? 1 : 0

  filter = {
    account = {
      id = var.account.id
    }
    name = var.domain.parent
  }
}

resource "cloudflare_dns_record" "delegation" {
  count = var.domain.parent != null ? 2 : 0

  zone_id = data.cloudflare_zone.parent[0].id
  name    = var.domain.name
  type    = "NS"
  content = var.domain.name_servers[cound.index]
  ttl     = 300
  comment = "Managed by Terraform: Delegation for ${var.domain.name}"
}
