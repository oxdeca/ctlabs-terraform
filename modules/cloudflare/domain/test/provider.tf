# ------------------------------------------------------------------------------
# File: ctlabs-terraform/modules/cloudflare/domain/test/provider.tf
# ------------------------------------------------------------------------------

terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    vault = {
      source = "hashicorp/vault"
    }
  }
}

# The Cloudflare token is minted by the test module (test_cloudflare_domain.py) and
# stashed in the Vault cubbyhole, which is scoped to the caller's Vault token. Reading
# it as an ephemeral resource keeps it out of the Terraform state and plan. The Vault
# provider is configured from the standard VAULT_* environment variables.
ephemeral "vault_generic_secret" "cloudflare" {
  path = "cubbyhole/cloudflare"
}

# The Vault provider mints an ephemeral child token for its reads by default; a
# cubbyhole is scoped to the token that wrote it, so the child would see an empty
# cubbyhole. Address/token/namespace still come from the VAULT_* environment.
provider "vault" {
  skip_child_token = true
}

provider "cloudflare" {
  api_token = ephemeral.vault_generic_secret.cloudflare.data["account_token"]
}
