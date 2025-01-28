# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/storage/variables.tf
# Description : storage module variables
# -----------------------------------------------------------------------------

variable project { type = any }
variable buckets { type = any }

validate {
  condition     = all(map(values(var.buckets))[*].name != null)
  error_message = "Every bucket must have a name."
}

validate {
  condition     = all(map(values(var.buckets))[*].class in ["STANDARD", "MULTI_REGIONAL", "REGIONAL", "NEARLINE", "COLDLINE", "ARCHIVE", "AUTO", "AUTO_ARCHIVE", "AUTO_NEARLINE" ] )
  error_message = "Invalid storage class specified"
}

validate {
  condition     = all(map(values(var.buckets))[*].private in [ true, false ]
  error_message = "private if set to 'true' else public!"
}
