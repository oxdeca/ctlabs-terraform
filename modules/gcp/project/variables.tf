# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/project/variables.tf
# Description : project module variables
# -----------------------------------------------------------------------------

#
# required:
#   - project.id
#   - project.bilact
#   - either project.oid or project.fid
#   - if project.type == 'service': requires project.host_project
# 
# defaults given:
#   - project.vpc_type
#   - project.sa_delete
#
# optional:
#   - project.name (defaults to project.id if not given)
#   - project.labels
#   - prroject.delete_policy

variable project {
  type = object({
    id       = string                        # (*) project id
    bilact   = string                        # (*) billing account
    name     = optional(string)              # (?) project name (defaults to project.id if not set)
    oid      = optional(string)              # (|) organization id (either oid or fid MUST be set)
    fid      = optional(string)              # (|) folder id
    policy   = optional(string, "ABANDON")   # (?) delete policy, ABANDON, PREVENT, or DELETE
    zone     = optional(string)              # (?) gcp region.zone
    labels   = optional(map(string))         # (?) labels
    type     = optional(string, "regular")   # (?) regular, host, service vpc
    host_vpc = optional(string)              # (?) host_project_id; only needed for type == service
  })

  validation {
    condition     = contains(["regular", "host", "service"], var.project.type)
    error_message = "The project type must by one of 'regular', 'host', or 'service'."
  }

  validation {
    condition     = contains(["ABANDON", "PREVENT", "DELETE"], var.project.policy)
    error_message = "The 'policy' attribute must be one of 'ABANDON', 'PREVENT', or 'DELETE'."
  }

  validation {
    condition     = var.project.type != "service" || (var.project.host_vpc != null && var.project.host_vpc != "")
    error_message = "If 'type' is 'service' the 'host_vpc' attribute must be set to a non-empty string."
  }
}
