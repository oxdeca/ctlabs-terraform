# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/vm/variables.tf
# Description : vm module variables
# -----------------------------------------------------------------------------

variable "project" {
  description = "The project configuration object"
  type = object({
    id = string
  })
}

variable vms {
  type = list(object({
    name      = string
    image     = string
    domain    = string
    network   = string
    zone      = string
    ipv4      = optional(string)
    type      = optional(string, "e2-micro")
    nat       = optional(bool, false)
    nested    = optional(bool, false)
    protected = optional(bool, false)
    oslogin   = optional(bool, false)
    vtpm      = optional(bool, true)
    restart   = optional(bool, false)
    ssh_keys  = optional(string)
    labels    = optional(map(string))
    tags      = optional(list(string))
    spot = optional(object({
      ttl    = optional(number, 8)  # in hours
      action = optional(string, "STOP")
    }))
    dns = optional(object({
      ttl = optional(number, 600)
    }))
    disks = optional(map(object({
      type     = optional(string, "pd-ssd")
      size     = optional(number, 20)
      path     = optional(string, "/mnt")
      opts     = optional(string, "defaults")
      fstype   = optional(string, "xfs")
      mode     = optional(string, "READ_WRITE")
      detached = optional(bool, false)
    })))
  }))
}
