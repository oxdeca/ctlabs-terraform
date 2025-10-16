# GCP Project Module

## Example

```yml
---

# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/prj/gcp/config.yml
# Description : default project configuration for gcp with regular vpc
# -----------------------------------------------------------------------------

project:
  name       : <GCP_PROJECT_ID> with regular VPC
  id         : <GCP_PROJECT_ID>
  oid        : <ORGANIZATION_ID>
  bilact     : <BILLING_ACCOUNT_ID>
  policy     : ABANDON
  type       : regular
  region     : us-west1
  zone       : us-west1-c
  labels:
    ctlabs : GCP_PROJECT
    vpc    : regular
    env    : dev
```

```yml
---

# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/prj/gcp/config.yml
# Description : default project configuration for gcp as host vpc
# -----------------------------------------------------------------------------

project:
  name       : <GCP_PROJECT_ID> with host vpc
  id         : <GCP_PROJECT_ID>
  oid        : <ORGANIZATION_ID>
  bilact     : <BILLING_ACCOUNT_ID>
  policy     : ABANDON
  type       : host
  region     : us-west1
  zone       : us-west1-c
  labels:
    ctlabs : GCP_PROJECT
    vpc    : host
    env    : dev
```

```yml
---

# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/prj/gcp/config.yml
# Description : default project configuration for gcp as service vpc
# -----------------------------------------------------------------------------

project:
  name       : <GCP_PROJECT_ID> with regular VPC
  id         : <GCP_PROJECT_ID>
  oid        : <ORGANIZATION_ID>
  bilact     : <BILLING_ACCOUNT_ID>
  policy     : ABANDON
  type       : service
  host_vpc   : <GCP_HOST_PROJECT_ID>
  region     : us-west1
  zone       : us-west1-c
  labels:
    ctlabs : GCP_PROJECT
    vpc    : service
    env    : dev
```

```hcl
# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/prj/gcp/main.tf
# Description : terraform configuration to provision project
# -----------------------------------------------------------------------------

locals { config  = yamldecode( file("./config.yml") ) }


module "prj" {
  source  = "github.com/oxdeca/ctlabs-terraform/modules/gcp/project?ref=dev"

  project = local.config.project
}
```