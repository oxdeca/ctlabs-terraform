# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/service_account/main.tf
# Description : service account module
# -----------------------------------------------------------------------------

resource "google_service_account" "sa" {
  for_each = { for sa in var.service_accounts : sa.name => sa }

  account_id   = each.value.id
  display_name = try( each.value.name, null )
  description  = try( each.value.desc, null )
}
