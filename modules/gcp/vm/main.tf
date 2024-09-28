# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/vm/main.tf
# Description : vm module
# -----------------------------------------------------------------------------

locals {
  defaults = {
    "disk" = { 
      "type" = "pd-standard", 
      "size" = "10" 
    },
    "spot" = { 
      "lifespan" = 2, 
      "action"   = "DELETE" 
    },
    "nat"    = false,
    "nested" = false,
  }
  disks = flatten( [ for vm in var.vms : [ for dk, dv in vm.disks : merge( { vm_id = vm.name, disk_id = dk }, dv ) ] ] )
}

resource "random_integer" "ri" {
  min = 1000
  max = 9999
  for_each = { for disk in local.disks : "${disk.vm_id}-${disk.disk_id}" => disk }
  keepers = {
    name = each.value.disk_id
    type = try( each.value.type, null )
    size = try( each.value.size, null )
  }
}

resource "google_compute_disk" "attached" {
  for_each = { for disk in local.disks : "${disk.vm_id}-${disk.disk_id}" => disk if ! startswith( disk.disk_id, "boot" ) } 
  #name     = "${each.value.vm_id}-${random_integer.ri[each.key].result}-${each.value.name}"
  name     = "${each.value.vm_id}-${each.value.disk_id}"
  type     = try( each.value.type, local.defaults.disk["type"] )
  size     = try( each.value.size, local.defaults.disk["size"] )
  #zone     = var.zone
  #labels   = var.labels


  # as removing/changing a disk configurations isn't expected to happen often and
  # because a disk configuration change recreates a disk 
  # attached disks are protected by having lifecycle.prevent_destroy set to true (see google_comput_disk resource above)
  # i.e. adding disks can be done with this module, but changes/deletes need to be done manually (or by setting below lifecycle.prevent_destroy = false)
  # 
  # Thus changing/removing disks is a manual task that would work as follows:
  # 1. add a new disk
  # 2. copy the data from the old disk to the new one (if needed)
  # 3. detach the old disk from the vm manually
  # 4. delete the old disk manually
  # 5. remove the old disk from the configuration
  # 6. run terraform to update its state
  lifecycle {
    prevent_destroy = true
  }
}

resource "google_compute_instance" "vm" {
  provider = google-beta

  for_each = { for vm in var.vms : vm.name => vm }

  project                   = var.project.id
  name                      = each.value.name
  machine_type              = each.value.type
  allow_stopping_for_update = true
  labels                    = each.value.labels

  boot_disk {
    #device_name  = "${each.value.name}-${random_integer.ri["${each.value.name}-boot"].result}-boot"
    device_name  = "${each.value.name}-boot"
    initialize_params {
      image = each.value.image
      type  = try( each.value.disks.boot.type, null )
      size  = try( each.value.disks.boot.size, null )
      #type  = try( each.value.disks[index(each.value.disks.*.name, "boot")].type, null )
      #size  = try( each.value.disks[index(each.value.disks.*.name, "boot")].size, null )
    }
  }

  dynamic attached_disk {
    for_each = { for dk,dv in each.value.disks: "${each.value.name}-${dk}" => dv if ! startswith( dk, "boot" ) }
    content {
      #device_name = "${each.value.name}-${random_integer.ri[attached_disk.key].result}-${attached_disk.value.name}"
      #source      = "${each.value.name}-${random_integer.ri[attached_disk.key].result}-${attached_disk.value.name}"
      device_name = "${attached_disk.key}"
      source      = "${attached_disk.key}"
      mode        = try( attached_disk.value.mode, "READ_WRITE" )
    }
  } 

  lifecycle {
    ignore_changes = [metadata_startup_script]
  }

  network_interface {
    subnetwork = each.value.net

    dynamic access_config {
      for_each = try( each.value.nat, local.defaults.nat ) ? toset([1]) : toset([])
      content {
      }
    }
  }

  advanced_machine_features {
    enable_nested_virtualization = try( each.value.nested, local.defaults.nested )
  }

  metadata = {
    enable-oslogin = true
    startup-script = try( file("${each.value.script}"), "" )
  }

  dynamic service_account {
    for_each = try(each.value.service_account, null) != null ? toset([1]) : toset([])
    content {
      email  = try( each.value.service_account.email, null )
      scopes = concat( ["cloud-platform"], try( each.value.service_account.scopes, [] ))
    }
  }

  dynamic scheduling {
    for_each = try( each.value.spot, null ) != null ? toset([1]) : toset([])
    content {
      preemptible                 = true
      automatic_restart           = false
      provisioning_model          = "SPOT"
      instance_termination_action = try( each.value.spot.action, local.defaults.spot.action )

      max_run_duration {
        seconds = try( each.value.spot.lifespan * 3600, local.defaults.spot.lifespan * 3600, 14400 )
      }
    }
  }

  depends_on = [google_compute_disk.attached]
}

#resource "null_resource" "cost_estimation1" {
#  provisioner "local-exec" {
#    command = "echo 'For Cost Estimation check: https://cloudbilling.googleapis.com/v2beta/services'"
#  }
#}
