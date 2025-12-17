# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/project/variables.tf
# Description : project module variables
# -----------------------------------------------------------------------------

variable project {
  type = object({
    id             = string                         # (*) project id
    billing        = string                         # (*) billing account
    name           = optional(string)               # (?) project name (defaults to project.id if not set)
    oid            = optional(string)               # (|) organization id (either oid or fid MUST be set)
    fid            = optional(string)               # (|) folder id
    zone           = optional(string)               # (?) gcp region.zone
    labels         = optional(map(string))          # (?) labels
    type           = optional(string, "standalone") # (?) standalone, host, service
    host_project   = optional(string)               # (?) host_project; only needed for type == service
    sa_delete      = optional(bool, true)           # (?) delete the default service account
    delete_policy  = optional(string, "ABANDON")    # (?) delete policy, ABANDON, PREVENT, or DELETE
    create_network = optional(bool, false)          # (?) create default network
    services       = optional(list(string), [       # (?) enable apis
      "compute.googleapis.com",
      "iam.googleapis.com",
      "cloudresourcemanager.googleapis.com"
    ])
    service_accounts = optional(list(object({       # (?) add service accounts to project
      id   = optional(string)
      name = optional(string)
      desc = optional(string)
    })), [])
    iam = optional(object({
      roles = optional(list(object({                # (?) create custom roles
        id    = optional(string)
        title = optional(string)
        perms = optional(list(string))
        desc  = optional(string)
      })), [])
      bindings = optional(list(object({             # (?) add project-level bindings
        role    = optional(string)
        members = optional(list(string))
      })), [])
    }), {})
  })

  validation {
    condition     = contains(["standalone", "host", "service"], var.project.type)
    error_message = "The project type must by one of 'standalone', 'host', or 'service'."
  }

  validation {
    condition     = contains(["ABANDON", "PREVENT", "DELETE"], var.project.policy)
    error_message = "The 'policy' attribute must be one of 'ABANDON', 'PREVENT', or 'DELETE'."
  }

  validation {
    condition     = var.project.type != "service" || (var.project.host_vpc != null && var.project.host_vpc != "")
    error_message = "If 'type' is 'service' the 'host_project' attribute must be set."
  }
}
