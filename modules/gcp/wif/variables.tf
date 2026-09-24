# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/wif/variables.tf
# Description : wif module variables
# -----------------------------------------------------------------------------

variable wif {
  type = object({
    project     = string                                   # (*) GCP project id hosting the pool/provider
    enable_apis = optional(bool, true)                      # (?) enable iam/sts/iamcredentials APIs
    pool = optional(object({
      id           = optional(string, "ctlabs-vault-pool")  # (?) workload identity pool id
      display_name = optional(string, "CTLabs Vault OIDC Pool")
      desc         = optional(string)                       # (?) pool description
    }), {})
    provider = object({
      id                = optional(string, "vault-provider")  # (?) provider id
      issuer            = string                              # (*) full OIDC issuer, incl. Vault's "/v1/identity/oidc" suffix
      attribute_mapping = optional(map(string), { "google.subject" = "assertion.sub" })
      jwks_json         = optional(string)                    # (?) raw JWKS JSON; omit to use issuer discovery
      allowed_audiences = optional(list(string))              # (?) defaults to the provider's own resource name
    })
    service_account = optional(object({
      create       = optional(bool, true)                    # (?) create the impersonated service account
      id           = optional(string, "terraform-runner")     # (?) account_id, only used when create = true
      email        = optional(string)                         # (|) existing SA email, required when create = false
      display_name = optional(string, "Terraform Runner (WIF)")
      roles        = optional(list(string), ["roles/editor"]) # (?) project roles granted, only when create = true
    }), {})
    subjects = list(string) # (*) Vault identity/oidc 'sub' claims allowed to impersonate the service account
  })

  validation {
    condition     = var.wif.service_account.create || try(var.wif.service_account.email, null) != null
    error_message = "wif.service_account.email is required when wif.service_account.create is false."
  }

  validation {
    condition     = length(var.wif.subjects) > 0
    error_message = "wif.subjects must list at least one Vault 'sub' claim to bind."
  }
}
