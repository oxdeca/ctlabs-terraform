# ------------------------------------------------------------------------------
# File : ctlabs-terraform/modules/cloudflare/account_token/main.tf
# ------------------------------------------------------------------------------

locals {
  tokens = {
    for t in var.account.tokens : t.name => t
  }
  perms = {
    account = {
      for p in data.cloudflare_account_api_token_permission_groups_list.account.result: p.name => p.id
    }
    zone = {
      for p in data.cloudflare_account_api_token_permission_groups_list.zone.result: p.name => p.id
    }
  }
}

# ------------------------------------------------------------------------------

data "cloudflare_account_api_token_permission_groups_list" "account" {
  account_id = var.account.id
  scope      = "com.cloudflare.api.account"
}

data "cloudflare_account_api_token_permission_groups_list" "zone" {
  account_id = var.account.id
  scope      = "com.cloudflare.api.account.zone"
}

# ------------------------------------------------------------------------------

resource "cloudflare_account_token" "token" {
  for_each = local.tokens

  account_id = var.account.id
  name       = each.value.name

  policies = [{
    effect = "allow"
    
    permission_groups = [
      for p in each.value.perms : {
        # try() attempts to find the key; if it fails, it returns the error message
        # This makes debugging YAML typos much easier
        id = try(
          each.value.scope == "account" ? local.perms.account[p] : local.perms.zone[p],
          "ERROR: Permission '${p}' not found in ${each.value.scope} scope"
        )
      }
    ]

    resources = jsonencode({
      (each.value.scope == "zone" ? 
        "com.cloudflare.api.account.zone.${var.account.zone_id}" : 
        "com.cloudflare.api.account.${var.account.id}") = "*"
    })
  }]

  # Safety check: Ensure no "ERROR" strings made it into the IDs
  lifecycle {
    precondition {
      condition = alltrue([
        for p in each.value.perms : !startswith(
          try(each.value.scope == "account" ? local.perms.account[p] : local.perms.zone[p], "ERROR"), 
          "ERROR"
        )
      ])
      error_message = "One or more permissions in your YAML for '${each.key}' are invalid. Please check the spelling against Cloudflare's permission names."
    }
  }
}
