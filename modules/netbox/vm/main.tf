# -----------------------------------------------------------------------------
# Date  : 2023-01-16-01-WS
# File  : terraform/modules/vm/netbox.tf
# Desc  : Inventory Created VM's
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    netbox = {
      source  = "e-breuninger/netbox"
      version = "~> 3.9.0"
    }
  }
}

data "netbox_cluster" "cluster" {
  name = var.netbox.cluster
}

data "netbox_vlan" "vlan" {
  for_each = { for vm in var.vms : vm.name => vm }

  vid = try( each.value.nic_vlan, var.defaults.vm.nic_vlan )
}

data "netbox_device_role" "role" {
  for_each = { for vm in var.vms : vm.name => vm }

  name = try( each.value.role, var.defaults.vm.role )
}

data "netbox_platform" "platform" {
  for_each = { for vm in  var.vms : vm.name => vm }

  name = try( each.value.platform, var.defaults.vm.platform )
}


resource "netbox_virtual_machine" "vm" {
  for_each = { for vm in var.vms : vm.name => vm }

  cluster_id    = data.netbox_cluster.cluster.id
  site_id       = data.netbox_cluster.cluster.site_id
  role_id       = data.netbox_device_role.role[each.value.name].id
  platform_id   = data.netbox_platform.platform[each.value.name].id
  name          = each.value.name
  vcpus         = try( each.value.cpu,           var.defaults.vm.cpu       )
  memory_mb     = try( each.value.mem,           var.defaults.vm.mem       )
  disk_size_gb  = try( each.value.disk_size,     var.defaults.vm.disk_size )
  comments      = try( each.value.comment,       var.defaults.vm.comment   )
  description   = try( each.value.desc,          var.defaults.vm.desc      )
  custom_fields = try( each.value.custom_fields, var.defaults.vm.custom_fields  )
  tags          = try( concat( each.value.tags, var.defaults.vm.tags), var.defaults.vm.tags )
}

resource "netbox_interface" "nic" {
  for_each = { for vm in var.vms : vm.name => vm }

  virtual_machine_id = netbox_virtual_machine.vm[each.value.name].id
  name               = try( each.value.ipv4_nic, var.defaults.vm.ipv4_nic )
  enabled            = try( each.value.ipv4_nic.enabled, true )
  mode               = try( each.value.ipv4_nic.mode,    "access" )
  untagged_vlan      = data.netbox_vlan.vlan[each.value.name].id
  #mac_address        = try( var.vm_nic_mac,     ""       )
}

resource "netbox_ip_address" "ip" {
  for_each = { for vm in var.vms : vm.name => vm }

  ip_address   = join( "", [each.value.ipv4_addr, "/", each.value.ipv4_mask] )
  interface_id = netbox_interface.nic[each.value.name].id
  object_type  = "virtualization.vminterface"
  status       = try( each.value.ipv4_status, "active" )
  dns_name     = join( "", [each.value.host, ".", each.value.domain] )
  description  = try( each.value.ipv4_desc, "" )
  tags         = try( each.value.ipv4_tags, [] )
}

resource "netbox_primary_ip" "prime_ip" {
  for_each = { for vm in var.vms : vm.name => vm }

  ip_address_id      = netbox_ip_address.ip[each.value.name].id
  virtual_machine_id = netbox_virtual_machine.vm[each.value.name].id
}