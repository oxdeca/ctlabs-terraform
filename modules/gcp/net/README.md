# GCP Network Module

## Examples

```yml
---

# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/prj/gcp/config.yml
# Description : project configuration for gcp
# -----------------------------------------------------------------------------

project:
  ... # project details

networks:
  - name         : net1
    routing_mode : GLOBAL
    desc         : network used for dev

  - name: net2
    desc: network used for test

  - name: net3
    desc: network used for prod
```

```hcl
# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/prj/gcp/main.tf
# Description : terraform configuration to provision service project
# -----------------------------------------------------------------------------

locals { config  = yamldecode( file("./config.yml") ) }

module "prj" {
  source  = "github.com/oxdeca/ctlabs-terraform/modules/gcp/project?ref=dev"

  project = local.config.project
}

module "net" {
  source  = "github.com/oxdeca/ctlabs-terraform/modules/gcp/net?ref=dev"

  project  = local.config.project
  networks = local.config.networks
}
```
