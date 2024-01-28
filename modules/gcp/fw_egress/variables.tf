# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/fw_egress/variables.tf
# Description : fw_egress module variables
# -----------------------------------------------------------------------------

variable egress { type    = any     }
variable action { default = "allow" }
variable log    { default = true    }
