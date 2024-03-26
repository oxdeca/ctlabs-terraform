# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/vpc_connector/main.tf
# Description : vpc access connector module
# -----------------------------------------------------------------------------

resource "google_vpc_access_connector" "con_shared" {
  for_each = { for connector in connectors : connector.name => connector }

  name  = each.value.name
  subnet {
    name = each.value.subnet
  }
  machine_type = each.value.vm_type
}
