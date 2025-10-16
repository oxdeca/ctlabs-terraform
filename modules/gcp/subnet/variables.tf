# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/subnet/variables.tf
# Description : subnet module variables
# -----------------------------------------------------------------------------

variable project { 
  type = object({
    id     = string
    region = optional(string)
  })
}

variable subnets { 
  type = map(list(object({
    name           = string
    cidr           = string
    region         = optional(string)
    private_access = optional(bool, false)
    netflow        = optional(object({
      aggregate = optional(string, "INTERVAL_10_MIN")
      sampling  = optional(string, "0.5")
      metadata  = optional(string, "INCLUDE_ALL_METADATA")
    }), {})
  })))

  validation {
    condition     = alltrue(flatten([
      for net in var.subnets : [
        for sub in net: can(cidrhost(sub.cidr, 32))
      ]
    ]))
    error_message = "Not a valid CIDR address."
  }
}
