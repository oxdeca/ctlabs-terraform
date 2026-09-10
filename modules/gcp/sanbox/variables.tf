# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/sandbox/variables.tf
# Description : sandbox platform module variables
# -----------------------------------------------------------------------------

variable "sandbox" {
  type = object({
    name    = string                      # (*) folder display name (e.g. sandbox)
    billing = string                      # (*) existing billing account id; linked once to every pool project at creation
    budget  = optional(number, 100)       # (?) folder-scoped budget limit in USD (covers all pool members)
    oid     = optional(string)            # (|) organization id (either oid or fid MUST be set)
    fid     = optional(string)            # (|) parent folder id
    iam_bindings = optional(list(object({ # (?) extra bindings applied on the sandbox folder
      role    = string
      members = list(string)
    })), [])
    projects       = optional(number, 5)              # (?) number of leasable sandbox projects in the pool
    project_prefix = optional(string, "sandbox-pool") # (?) pool project id prefix; members are <prefix>-01..NN (max ~20 chars)
    pool_labels    = optional(map(string), {})        # (?) extra labels merged onto every pool project (state label is always forced)
    delete_policy  = optional(string, "PREVENT")      # (?) google_project deletion_policy for pool members (PREVENT keeps the pool intact)
    sweeper = optional(object({                       # (?) TTL sweeper: Cloud Scheduler -> Cloud Function that disables services
      project   = string                              #     and marks expired leases 'disabled'. null = no sweeper.
      schedule  = optional(string, "0 2 * * *")       # (?) cron schedule (default: daily 02:00 UTC)
      time_zone = optional(string, "UTC")             # (?) scheduler time zone
      region    = optional(string, "us-central1")     # (?) GCP region hosting the sweeper function + scheduler
    }), null)
  })

  validation {
    condition     = var.sandbox.oid != null || var.sandbox.fid != null
    error_message = "Either 'oid' (organization id) or 'fid' (parent folder id) must be set."
  }

  validation {
    condition     = var.sandbox.budget != null && var.sandbox.budget > 0
    error_message = "The 'budget' amount must be greater than zero."
  }

  validation {
    condition     = var.sandbox.projects != null && var.sandbox.projects >= 1 && var.sandbox.projects <= 50
    error_message = "The pool 'projects' count must be between 1 and 50."
  }

  validation {
    condition     = var.sandbox.project_prefix != null && can(regex("^[a-z][a-z0-9-]*$", var.sandbox.project_prefix)) && length(var.sandbox.project_prefix) <= 20
    error_message = "The 'project_prefix' must start with a lowercase letter, contain [a-z0-9-], and be <= 20 chars so pool ids stay <= 30."
  }
}
