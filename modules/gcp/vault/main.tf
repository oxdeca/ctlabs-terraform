# -----------------------------------------------------------------------------
# File    : ctlabs-terraform/modules/gcp/vault/main.tf
# License : MIT
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Hashicorp Vault - login
# -----------------------------------------------------------------------------
#
provider "vault" {
  address = var.vault.url

  auth_login_gcp {
    role = var.vault.gcp_auth_role
  }
}

# -----------------------------------------------------------------------------
# Hashicorp Vault - read secrets
# -----------------------------------------------------------------------------
#
ephemeral "vault_kv_secret_v2" "secrets" {
  for_each = { for secret in var.vault.secrets : secret.name => secret }

  mount = try(each.value.mount, var.vault.mount)
  name  = each.value.path
}

# -----------------------------------------------------------------------------
# Output
# -----------------------------------------------------------------------------
#
output "secrets" {
  value     = { for key, secret in ephemeral.vault_kv_secret_v2.secrets : key => secret.data }
  ephemeral = true
}
