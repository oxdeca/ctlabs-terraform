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


```hcl
project:
  id: ctlabs-dev-standalone

networks:
  - name    : net1
    routing : GLOBAL
    subnets:
      - name           : net1-sub1
        region         : us-east4
        cidr           : 10.10.0.0/24
        private_access : true
        stack          : IPV4

  - name    : net2
    routing : REGIONAL
    subnets:
      - name        : net2-sub2
        region      : us-central1
        cidr        : 10.20.0.0/24
        stack       : IPV4_IPV6
        ipv6_access : EXTERNAL
        ranges:
          - name : gke-pods-range
            cidr : 10.100.0.0/16
```

