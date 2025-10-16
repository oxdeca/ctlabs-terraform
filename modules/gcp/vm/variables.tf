# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/vm/variables.tf
# Description : vm module variables
# -----------------------------------------------------------------------------

#variable vms     { type = any }
variable project { type = any }
variable netbox  { type = any }

variable vms {
  type = list(object({
    name      = string
    type      = optional(string, "e2-micro")
    oslogin   = optional(bool, false)
    nat       = optional(bool, false)
    nested    = optional(bool, false)
    vtpm      = optional(bool, true)
    protected = optional(bool, false)
    restart   = optional(bool, false)
    spot = optional(object({
      lifespan = optional(number, 8)
      action   = optional(string, "STOP")
    }))
    dns = optional(object({
      ttl = optional(number, 600)
    }))
    disks = optional(map(object({
      type     = optional(string, "pd-ssd")
      fstype   = optional(string, "xfs")
      size     = optional(number, 20)
      path     = optional(string, "/mnt")
      opts     = optional(string, "defaults")
      mode     = optional(string, "READ_WRITE")
      detached = optional(bool, false)
    })))
  }))
}
