# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/vm/main.tf
# Description : vm module
# -----------------------------------------------------------------------------

resource "google_compute_instance" "vm" {
  provider = google-beta

  for_each = { for vm in var.vms : vm.name => vm }

  project                   = var.project.id
  name                      = each.value.name
  machine_type              = each.value.type
  allow_stopping_for_update = true
  labels                    = each.value.labels

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
    startup-script = try( file("${each.value.script}"), "" )
  }

  dynamic scheduling {
    for_each = each.value.spot ? toset([1]) : toset([])
    content {
      preemptible                 = true
      automatic_restart           = false
      provisioning_model          = "SPOT"
      instance_termination_action = "DELETE"

      max_run_duration {
        seconds = try( each.value.lifespan * 3600, 14400)
      }
    }
  }
}

#resource "null_resource" "cost_estimation1" {
#  provisioner "local-exec" {
#    command = "echo 'For Cost Estimation check: https://cloudbilling.googleapis.com/v2beta/services'"
#  }
#}
