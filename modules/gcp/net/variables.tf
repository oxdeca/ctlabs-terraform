# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/net/variables.tf
# Description : net module variables
# -----------------------------------------------------------------------------

variable project { 
  type = object({
    id = string
  })
}

variable networks {
  type = list(object({
    name         = string
    desc         = optional(string)
    subnets      = optional(bool, false)
    routing_mode = optional(string, "REGIONAL")
  }))

  validation {
    condition     = alltrue([
      for net in var.networks : contains(["REGIONAL", "GLOBAL"], net.routing_mode)
    ])
    error_message = "routing_mode must be 'REGIONAL' or 'GLOBAL'."
  }
}