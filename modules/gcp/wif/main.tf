# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/wif/main.tf
# Description : GCP Workload Identity Federation pool/provider, trusting a
#               Vault identity/oidc token exchange (see
#               ctlabs/docs/ctlabs.docs.vault.gcp.wif.md for the Vault side).
# -----------------------------------------------------------------------------

locals {
  defaults = {
    apis = [
      "iam.googleapis.com",
      "sts.googleapis.com",
      "iamcredentials.googleapis.com",
    ]
  }

  sa_email = var.wif.service_account.create ? google_service_account.runner[0].email : var.wif.service_account.email

  audience = "//iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${var.wif.pool.id}/providers/${var.wif.provider.id}"
}

data "google_project" "this" {
  project_id = var.wif.project
}

resource "google_project_service" "apis" {
  for_each = var.wif.enable_apis ? toset(local.defaults.apis) : toset([])

  project = var.wif.project
  service = each.value
}

resource "google_iam_workload_identity_pool" "pool" {
  project                   = var.wif.project
  workload_identity_pool_id = var.wif.pool.id
  display_name              = var.wif.pool.display_name
  description               = try(var.wif.pool.desc, null)

  depends_on = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "provider" {
  project                            = var.wif.project
  workload_identity_pool_id          = google_iam_workload_identity_pool.pool.workload_identity_pool_id
  workload_identity_pool_provider_id = var.wif.provider.id
  attribute_mapping                  = var.wif.provider.attribute_mapping

  oidc {
    issuer_uri        = var.wif.provider.issuer
    allowed_audiences = var.wif.provider.allowed_audiences
    jwks_json         = try(var.wif.provider.jwks_json, null)
  }
}

resource "google_service_account" "runner" {
  count = var.wif.service_account.create ? 1 : 0

  project      = var.wif.project
  account_id   = var.wif.service_account.id
  display_name = var.wif.service_account.display_name

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "runner_roles" {
  for_each = var.wif.service_account.create ? toset(var.wif.service_account.roles) : toset([])

  project = var.wif.project
  role    = each.value
  member  = "serviceAccount:${google_service_account.runner[0].email}"
}

# Scoped to a single subject each - never bind the whole pool (principalSet://.../*)
# to an impersonation role, see ctlabs.docs.vault.gcp.wif.md step 4.
resource "google_service_account_iam_member" "wif_binding" {
  for_each = toset(var.wif.subjects)

  service_account_id = "projects/${var.wif.project}/serviceAccounts/${local.sa_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${var.wif.pool.id}/subject/${each.value}"
}

output "audience" {
  description = "WIF provider resource name - the ctlabs 'audience' value / Vault OIDC role 'client_id'."
  value       = local.audience
}

output "service_account_email" {
  description = "Impersonated service account email."
  value       = local.sa_email
}

output "pool_name" {
  description = "Fully qualified workload identity pool resource name."
  value       = google_iam_workload_identity_pool.pool.name
}

output "provider_name" {
  description = "Fully qualified workload identity pool provider resource name."
  value       = google_iam_workload_identity_pool_provider.provider.name
}
