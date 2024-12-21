# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/vm/main.tf
# Description : vm module
# -----------------------------------------------------------------------------

locals {
  defaults = {
    "disk" = { 
      "type" = "pd-standard", 
      "size" = "10" 
      "mode" = "READ_WRITE",
    },
    "spot" = { 
      "lifespan" = 2, 
      "action"   = "STOP" 
    },
    "dns" = {
      "ttl" = 600,
    }
    "type"       = "e2-micro",
    "oslogin"    = false,
    "nat"        = false,
    "nested"     = false,
    "protected"  = false,
    "update"     = true,
    "sa_prefix"  = "gce-",
    "sa_postfix" = "@${var.project.id}.iam.gserviceaccount.com",
    "metadata"   = {
      enable-oslogin = false
      startup-script = ""
    }
  }
  disks = flatten( [ for vm in var.vms : [ for dk, dv in vm.disks : merge( { vm_id = vm.name, disk_id = dk }, dv ) ] ] )
}

resource "google_service_account" "sa" {
  for_each = { for vm in var.vms : vm.name => vm }

  account_id   = "${local.defaults.sa_prefix}${each.value.name}"
  display_name = try( each.value.name, null )
  description  = try( each.value.desc, null )
}


resource "google_compute_disk" "attached" {
  for_each = { for disk in local.disks : "${disk.vm_id}-${disk.disk_id}" => disk if ! startswith( disk.disk_id, "boot" ) } 
  name     = "${each.value.vm_id}-${each.value.disk_id}"
  type     = try( each.value.type, local.defaults.disk["type"] )
  size     = try( each.value.size, local.defaults.disk["size"] )
  labels   = try( each.value.labels, {} )

  # as removing/changing a disk configurations isn't expected to happen often and
  # because a disk configuration change(rename, reduce size) recreates a disk 
  # attached disks are protected by having 'lifecycle.prevent_destroy' set to true (see google_comput_disk resource above)
  # i.e. adding disks can be done with this module, but changes/deletes need to be done manually (or by setting below lifecycle.prevent_destroy = false)
  # 
  # Thus changing/removing disks is a manual task that would work as follows:
  # 1. add a new disk
  # 2. copy the data from the old disk to the new one (if needed)
  # 3. make sure the disks isn't used by the OS anymore or deconfigure it on the OS-level
  # 4. umount disk in the OS
  # 5. remove the old disk from the terraform configuration
  # 6. run terraform to update its state
  lifecycle {
    prevent_destroy = false
  }
}

resource "google_compute_instance" "vm" {
  provider = google-beta

  for_each = { for vm in var.vms : vm.name => vm }

  project                   = var.project.id
  name                      = each.value.name
  hostname                  = try( "${each.value.name}.${each.value.domain}", null )
  machine_type              = try( each.value.type, local.defaults.type )
  allow_stopping_for_update = try( each.value.update, local.defaults.update )
  deletion_protection       = try( each.value.protected, local.defaults.protected )
  labels                    = try( each.value.labels, {} )
  tags                      = try( each.value.tags, [] )

  boot_disk {
    device_name  = "${each.value.name}-boot"
    initialize_params {
      image = each.value.image
      type  = try( each.value.disks.boot.type, null )
      size  = try( each.value.disks.boot.size, null )
    }
  }

  dynamic attached_disk {
    for_each = { for dk,dv in each.value.disks: "${each.value.name}-${dk}" => dv if ! startswith( dk, "boot" ) }
    content {
      device_name = "${attached_disk.key}"
      source      = "${attached_disk.key}"
      mode        = try( attached_disk.value.mode, local.defaults.disk.mode )
    }
  } 

  lifecycle {
    ignore_changes = [metadata_startup_script]
  }

  network_interface {
    subnetwork = try( var.project.vpc_type, "") == "service" ? "projects/${var.project.shared_vpc}/${each.value.net}" : each.value.net
    network_ip = try( each.value.ipv4, null )

    dynamic access_config {
      for_each = try( each.value.nat, local.defaults.nat ) ? toset([1]) : toset([])
      content {
      }
    }
  }

  advanced_machine_features {
    enable_nested_virtualization = try( each.value.nested, local.defaults.nested )
  }

  metadata = merge({
      enable-oslogin = try( each.value.oslogin, local.defaults.oslogin )
      startup-script = try( file("${each.value.script}"), "" )
    }, try( each.value.metadata, {} ) )

  dynamic service_account {
    for_each = try(each.value.name, null) != null ? toset([1]) : toset([])
    content {
      email  = try( each.value.service_account.email, "${local.defaults.sa_prefix}${each.value.name}${local.defaults.sa_postfix}" )
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

resource "google_dns_record_set" "rr" {
  for_each = { for vm in var.vms : vm.name => vm if try(vm.domain, null) != null }

  managed_zone = replace( each.value.domain, ".", "-" )
  name         = "${each.value.name}.${each.value.domain}."
  project      = try( var.project.vpc_type, null ) == "service" ? var.project.shared_vpc : var.project.id
  type         = "A"
  ttl          = try( each.value.dns.ttl, local.defaults.dns.ttl)
  rrdatas      = [google_compute_instance.vm[each.key].network_interface.0.network_ip]

  depends_on = [google_compute_instance.vm]
}

#
# atm, this works only for /24 prefix, and is too complicated
# i.e. ip = a.b.c.d 
# reverse zone = c.b.a.in-addr.arpa
#
#resource "google_dns_record_set" "ptr" {
#  for_each = { for vm in var.vms : vm.name => vm if try(vm.domain, null) != null }
#
#  managed_zone = join("-", concat(["reverse"], reverse(slice(split(".", google_compute_instance.vm[each.key].network_interface.0.network_ip), 0, 3))))
#  name         = join("", concat( slice( reverse( split(".", google_compute_instance.vm[each.key].network_interface.0.network_ip) ), 0, 1 ), concat( ["."], [join( ".", concat( reverse( slice( split(".", google_compute_instance.vm[each.key].network_interface.0.network_ip), 0, 3 ) ), ["in-addr.arpa."] ) )] ) ) )
#  project      = try( var.project.vpc_type, null ) == "service" ? var.project.shared_vpc : var.project.id
#  type         = "PTR"
#  ttl          = try( each.value.dns.ttl, local.defaults.dns.ttl)
#  rrdatas      = ["${each.value.name}.${each.value.domain}."]
#
#  depends_on = [google_compute_instance.vm]
#}

#resource "null_resource" "cost_estimation1" {
#  provisioner "local-exec" {
#    command = "echo 'For Cost Estimation check: https://cloudbilling.googleapis.com/v2beta/services'"
#  }
#}


resource "google_dns_record_set" "ptr" {
  for_each = { for vm in var.vms : vm.name => vm if try(vm.domain, null) != null }

  managed_zone = element(reverse(split(".", google_compute_instance.vm[each.key].network_interface.0.network_ip)), 0)
  name         = join(".", reverse(split(".", google_compute_instance.vm[each.key].network_interface.0.network_ip)), "in-addr.arpa")
  project      = try( var.project.vpc_type, null ) == "service" ? var.project.shared_vpc : var.project.id
  type         = "PTR"
  ttl          = try( each.value.dns.ttl, local.defaults.dns.ttl)
  rrdatas      = ["${each.value.name}.${each.value.domain}."]
  
  depends_on = [google_compute_instance.vm]
}