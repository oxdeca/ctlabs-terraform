# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/firewall/variables.tf
# Description : firewall module variables
# -----------------------------------------------------------------------------

variable project  { type = any }
variable firewall { type = any } 
#variable egress { type    = any     }
#variable action { default = "allow" }
#variable log    { default = true    }
