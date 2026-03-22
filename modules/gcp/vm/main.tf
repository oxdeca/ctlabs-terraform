# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/vm/main.tf
# Description : vm module
# -----------------------------------------------------------------------------

locals {
  defaults = {
    labels = {
      module = "ctlabs-terraform-module-gcp-vm"
    }
    sa_prefix = "gce-"
    disks = {
      boot = {
        size   = 20
        path   = "/"
        fstype = "xfs"
        type   = "pd-standard"
      }
    }
  }

  blk_fs    = ["xfs", "ext4", "ntfs"]
  blk_disks = flatten([for vm in var.vms : [for dk, dv in merge( local.defaults.disks, vm.disks) : merge({ vm_id = vm.name, disk_id = dk, zone = vm.zone }, dv) if contains(local.blk_fs, try(dv.fstype, ""))]])
  buckets   = flatten([for vm in var.vms : [for dk, dv in try(vm.disks, {}) : merge({ vm_id = vm.name, disk_id = dk, zone = vm.zone }, dv) if try(dv.stype, null) == "bucket"]])
}

# -----------------------------------------------------------------------------
# Service Accounts
# -----------------------------------------------------------------------------

resource "google_service_account" "sa" {
  for_each = { for vm in var.vms : vm.name => vm }

  project      = var.project.id
  account_id   = "${local.defaults.sa_prefix}${each.value.name}"
  display_name = try(each.value.name, null)
  description  = try(each.value.desc, null)
}

# -----------------------------------------------------------------------------
# Disks
# -----------------------------------------------------------------------------

resource "google_compute_disk" "disks" {
  for_each = { for disk in local.blk_disks : "${disk.vm_id}-${disk.disk_id}" => disk if !startswith(disk.disk_id, "boot") }

  project = var.project.id
  name    = "${each.value.vm_id}-${each.value.disk_id}"
  type    = each.value.type
  size    = each.value.size
  zone    = each.value.zone
  labels  = merge(local.defaults.labels, try(each.value.labels, {}))

  lifecycle {
    prevent_destroy = false
  }
}

resource "google_compute_attached_disk" "attached_disks" {
  for_each = { for disk in local.blk_disks : "${disk.vm_id}-${disk.disk_id}" => disk if !startswith(disk.disk_id, "boot") }

  project     = var.project.id
  device_name = google_compute_disk.disks[each.key].name
  disk        = google_compute_disk.disks[each.key].id
  instance    = google_compute_instance.vm[each.value.vm_id].id
}


# -----------------------------------------------------------------------------
# Virtual Machines
# -----------------------------------------------------------------------------

resource "google_compute_instance" "vm" {
  provider = google-beta

  for_each = { for vm in var.vms : vm.name => vm }

  project                   = var.project.id
  name                      = each.value.name
  hostname                  = (each.value.domain != null ? "${each.value.name}.${each.value.domain}" : null)
  machine_type              = each.value.type
  zone                      = each.value.zone
  allow_stopping_for_update = each.value.restart
  deletion_protection       = each.value.protected
  labels                    = merge(local.defaults.labels, try(each.value.labels, {}))
  tags                      = distinct(try(each.value.tags, []))

  boot_disk {
    device_name = "${each.value.name}-boot"
    initialize_params {
      image = each.value.image
      type  = try( each.value.disks.boot.type, local.defaults.disks.boot.type )
      size  = try( each.value.disks.boot.size, local.defaults.disks.boot.size )
    }
  }

  lifecycle {
    ignore_changes = [metadata.startup_script, attached_disk, metadata.ssh-keys]
  }

  network_interface {
    subnetwork         = each.value.network
    #subnetwork_project = try(var.project.host_project, null)
    network_ip         = each.value.ipv4

    dynamic "access_config" {
      for_each = each.value.nat ? toset([each.key]) : toset([])
      content {
        nat_ip = google_compute_address.nat_ip[each.key].address
      }
    }

  }

  advanced_machine_features {
    enable_nested_virtualization = each.value.nested
  }

  shielded_instance_config {
    enable_vtpm = each.value.vtpm
  }

  metadata = strcontains(each.value.image, "windows") ? {
    startup-script    = "${path.module}/scripts/windows.ps1"
    ctlabs_base_disks = jsonencode([for dk, dv in merge( local.defaults.disks, vm.disks) : merge({ name = "${each.value.name}-${dk}" }, dv) if !startswith(dk, "boot")])
    labels            = jsonencode(merge(local.defaults.labels, try(each.value.labels, {})))
    } : {
    enable-oslogin    = each.value.oslogin
    startup-script    = "${path.module}/scripts/linux.sh.tpl"
    ctlabs_base_disks = jsonencode([for dk, dv in merge( local.defaults.disks, vm.disks) : merge({ name = try(dv.type, null) == "bucket" ? dk : "${each.value.name}-${dk}", fstype = dv.fstype }, dv) if !startswith(dk, "boot")])
    ssh-keys          = each.value.ssh_keys
    labels            = jsonencode(merge(local.defaults.labels, try(each.value.labels, {})))
  }

  service_account {
    email  = google_service_account.sa[each.value.name].email
    scopes = concat(["cloud-platform"], try(each.value.service_account.scopes, []))
  }

  dynamic "scheduling" {

    for_each = each.value.spot
    content {
      preemptible                 = true
      automatic_restart           = false
      provisioning_model          = "SPOT"
      instance_termination_action = each.value.spot.action

      max_run_duration {
        seconds = each.value.spot.ttl * 3600
      }
    }
  }
}

# -----------------------------------------------------------------------------
# NAT
# -----------------------------------------------------------------------------
resource "google_compute_address" "nat_ip" {
  for_each     = { for vm in var.vms : vm.name => vm if vm.nat }
  name         = each.key
  project      = var.project.id
  region       = replace(each.value.zone, "/-[a-z]$/", "")
  address_type = "EXTERNAL"
  labels       = merge(local.defaults.labels, try(each.value.labels, {}))
}

# -----------------------------------------------------------------------------
# DNS
# -----------------------------------------------------------------------------
resource "google_dns_record_set" "rr" {
  for_each = { for vm in var.vms : vm.name => vm if vm.domain != null }

  managed_zone = replace(each.value.domain, ".", "-")
  name         = "${each.value.name}.${each.value.domain}."
  project      = try( var.project.host_project, var.project.id )
  type         = "A"
  ttl          = each.value.dns_ttl
  rrdatas      = [google_compute_instance.vm[each.key].network_interface[0].network_ip]
}
