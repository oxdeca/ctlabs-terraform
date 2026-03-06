# -----------------------------------------------------------------------------
# File    : ctlabs-terraform/modules/gcp/vault/main.tf
# License : MIT
# -----------------------------------------------------------------------------

locals {
  # 1. Check if the standard K8s JWT file exists (proves we are in a Pod)
  jwt_path = try(var.vault.k8s.jwt_path, "/var/run/secrets/kubernetes.io/serviceaccount/token")
  is_k8s   = fileexists(local.jwt_path)

  # 2. Smart Auth Routing (Picks the first non-null value)
  auth_method = coalesce(
    var.vault.auth_method,                                # 1. Explicit override in YAML
    local.is_k8s && var.vault.k8s != null ? "k8s" : null, # 2. Auto-detect Kubernetes environment
    var.vault.gcp != null ? "gcp" : null,                 # 3. Auto-detect GCP configuration
    "token"                                               # 4. Fallback to local VAULT_TOKEN env var
  )
}

# -----------------------------------------------------------------------------
# Provider Configuration & Login
# -----------------------------------------------------------------------------
provider "vault" {
  address         = var.vault.url
  skip_tls_verify = !var.vault.tls_verify

  # 1. Kubernetes Auth (e.g., for Atlantis pods)
  dynamic "auth_login" {
    for_each = local.auth_method == "k8s" ? [1] : []
    content {
      path = "auth/${var.vault.k8s.mount_path}/login"
      parameters = {
        role = var.vault.k8s.role
        jwt  = file(local.jwt_path)
      }
    }
  }

  # 2. GCP Auth (e.g., for Cloud Build or Compute Engine)
  dynamic "auth_login" {
    for_each = local.auth_method == "gcp" ? [1] : []
    content {
      path = "auth/${var.vault.gcp.mount_path}/login"
      parameters = {
        role = var.vault.gcp.role
        # The Vault provider automatically fetches the JWT from the GCP Metadata server.
      }
    }
  }

  # Note on "token" auth: If local.auth_method == "token", both dynamic blocks 
  # are skipped, and the provider natively looks for the VAULT_TOKEN env var.
}


# -----------------------------------------------------------------------------
# Read Secrets (Data strictly for Resources)
# -----------------------------------------------------------------------------
data "vault_kv_secret_v2" "secrets" {
  for_each = { 
    for secret in var.vault.secrets : secret.name => secret 
    if secret.type == "data" 
  }

  # CHANGED: coalesce skips nulls and grabs the default
  mount = coalesce(each.value.mount, var.vault.mount)
  name  = each.value.path
}

# -----------------------------------------------------------------------------
# Read Secrets (Ephemeral strictly for Providers)
# -----------------------------------------------------------------------------
ephemeral "vault_kv_secret_v2" "ephemeral_secrets" {
  for_each = { 
    for secret in var.vault.secrets : secret.name => secret 
    if secret.type == "ephemeral" 
  }

  # CHANGED: coalesce skips nulls and grabs the default
  mount = coalesce(each.value.mount, var.vault.mount)
  name  = each.value.path
}

# -----------------------------------------------------------------------------
# Output
# -----------------------------------------------------------------------------
output "secrets" {
  description = "Standard sensitive secrets (type: data) for use in standard resources."
  value       = { for key, secret in data.vault_kv_secret_v2.secrets : key => secret.data }
  sensitive   = true
}

output "ephemeral_secrets" {
  description = "Ephemeral secrets (type: ephemeral) strictly for provider configurations."
  value       = { for key, secret in ephemeral.vault_kv_secret_v2.ephemeral_secrets : key => secret.data }
  ephemeral   = true
}
