# -----------------------------------------------------------------------------
# File    : ctlabs-terraform/modules/gcp/vault/main.tf
# License : MIT
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Hashicorp Vault - login
# -----------------------------------------------------------------------------
#
provider "vault" {
  address         = var.vault.url
  skip_tls_verify = !var.vault.ssl_verify

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


# -----------------------------------------------------------------------------
# Google Secret Manager (GSM) - get approle credentials
# -----------------------------------------------------------------------------
#
#ephemeral "google_secret_manager_secret_version" "role_id" {
#  secret  = var.vault.gsm.role_id
#  project = var.vault.gsm.project
#}
#
#ephemeral "google_secret_manager_secret_version" "secret_id" {
#  secret  = var.vault.gsm.secret_id
#  project = var.vault.gsm.project
#}

# -----------------------------------------------------------------------------
# Hashicorp Vault - login
# -----------------------------------------------------------------------------
#
#provider "vault" {
#  address = var.vault.url
#  skip_tls_verify = !var.vault.ssl_verify
#
#  auth_login {
#    path = "auth/${var.vault.approle}/login"
#    parameters = {
#      role_id   = ephemeral.google_secret_manager_secret_version.role_id.secret_data
#      secret_id = ephemeral.google_secret_manager_secret_version.secret_id.secret_data
#    }
#  }
#}
