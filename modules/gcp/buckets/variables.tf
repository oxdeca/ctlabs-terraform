# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/storage/variables.tf
# Description : storage module variables
# -----------------------------------------------------------------------------

variable project { type = any }
variable "buckets" {
  type        = any
  description = "Configuration for GCP buckets."

  validation {
    condition     = all(map(keys(var.buckets))[*].name != null, map(keys(var.buckets))[*].class in ["STANDARD", "NEARLINE", "COLDLINE", "MULTI_REGIONAL", "REGIONAL", "ARCHIVE", "AUTO"])
    error_message = "Every bucket must have a 'name' and a valid 'class'."
  }
}