# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/vm/main.tf
# Description : vm module
# -----------------------------------------------------------------------------

resource "google_compute_instance" "vm" {
  for_each = { for vm in var.vms : vm.name => vm }

  project                   = var.project.id
  name                      = each.value.name
  machine_type              = each.value.type
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = each.value.image
    }
  }

  network_interface {
    subnetwork = each.value.net

    dynamic access_config {
      for_each = each.value.nat ? toset([1]) : toset([])
      content {
      }
    }
  }

  metadata = {
    enable-oslogin = true
  }
  
  metadata_startup_script = try( file("${each.value.script}"), "" )

}

