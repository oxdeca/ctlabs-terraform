# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/net/variables.tf
# Description : net module variables
# -----------------------------------------------------------------------------

variable "project" {
  description = "The project configuration object"
  type = object({
    id = string
  })
}

variable "network" {
  description = "A list of networks and their associated subnets to create"
  type = list(object({
    name          = string
    desc          = optional(string)
    routing       = optional(string, "REGIONAL")
    auto_subnets  = optional(bool, false)
    delete_routes = optional(bool, false)
    mtu           = optional(number, 1460)
    
    subnets = optional(list(object({
      name           = string
      region         = string
      cidr           = string
      desc           = optional(string)
      purpose        = optional(string)
      role           = optional(string)
      private_access = optional(bool, true)
      stack          = optional(string, "IPV4_ONLY")
      ipv6_access    = optional(string)
      
      ranges = optional(list(object({
        name = string
        cidr = string
      })), [])
    })), [])
  }))
  default = []

  validation {
    condition = alltrue([
      for net in var.network : contains(["REGIONAL", "GLOBAL"], net.routing)
    ])
    error_message = "The 'routing' attribute for all networks must be either 'REGIONAL' or 'GLOBAL'."
  }

  validation {
    condition = alltrue(flatten([
      for net in var.network : [
        for sub in coalesce(net.subnets, []) : contains(["IPV4_ONLY", "IPV4_IPV6"], sub.stack)
      ]
    ]))
    error_message = "The 'stack' attribute in all subnets must be either 'IPV4_ONLY' or 'IPV4_IPV6'."
  }
}
