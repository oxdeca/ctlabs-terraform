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

resource "google_service_account_key" "sa_key" {
  for_each = { for sa in var.service_accounts : sa.name => sa if sa.key == true }

  service_account_id = google_service_account.sa[each.value.name].name
  public_key_type = "TYPE_X509_PEM_FILE"
}

#output  "service_account_key" {
#  for_each = { for sa in var.service_accounts : sa.name => sa if sa_key == true }
#
#  value = google_service_account_key.sa_key[each.value.name].private_key
#}
