# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/storage/variables.tf
# Description : storage module variables
# -----------------------------------------------------------------------------

variable project { type = any }
variable buckets {
  type        = any
  description = "Configuration for GCP buckets."

  validation {
    condition     = all(map(keys(var.buckets))[*].name != null)
    error_message = "Every bucket must have a 'name' field."
  }

  validation {
    condition     = all(map(keys(var.buckets))[*].class in toset(["STANDARD", "NEARLINE", "COLDLINE", "MULTI_REGIONAL", "REGIONAL", "ARCHIVE", "AUTO"])

    error_message = "Invalid storage class specified."
  }
}