# GCP Workload Identity Federation Module

Terraform equivalent of `ctlabs-terraform/scripts/gcp_wif_setup.py` (the
"One-time GCP Setup" half of
[`ctlabs.docs.vault.gcp.wif.md`](file:///root/ctlabs/docs/ctlabs.docs.vault.gcp.wif.md)) - a
workload identity pool + OIDC provider that trusts Vault's `identity/oidc`
signer, plus the impersonated service account and its IAM bindings. The
script remains useful for ad-hoc/one-off setup from an operator desktop; this
module is for pools/providers that should live in Terraform state alongside
everything else they support (e.g. Atlantis/CI runners).

The Vault side (issuer, signing key, role/`client_id`, looking up the `sub`
claim to bind) is **not** covered here - see the doc above and
`ctlabs-tools`' `vault-auth jwt` / `vault_oidc_setup.py`.

## What it creates

| Resource                                      | Purpose                                                               |
|-----------------------------------------------|-----------------------------------------------------------------------|
| `google_iam_workload_identity_pool`           | The pool (one per project, reusable across providers)                 |
| `google_iam_workload_identity_pool_provider`  | OIDC provider trusting Vault as issuer                                |
| `google_service_account` (optional)           | The impersonated runner SA (skip with `service_account.create=false`) |
| `google_project_iam_member`                   | Project roles granted to that SA                                      |
| `google_service_account_iam_member`           | `roles/iam.workloadIdentityUser`, scoped per Vault `sub` claim        |

## Configuration

```hcl
# <root>/main.tf
locals { config = yamldecode(file("./config.yml")) }

module "wif" {
  source = "../modules/gcp/wif"
  wif    = local.config.wif
}
```

```yaml
# <root>/config.yml
wif:
  project: my-project
  provider:
    issuer: "https://vdb1.ctlabs.internal:8200/v1/identity/oidc"  # Vault's real iss claim, printed by vault_oidc_setup.py
  subjects:
    - "3f2c1a9e-....-....-....-............"  # Vault entity id ('sub' claim), looked up per ctlabs.docs.vault.gcp.wif.md step 4
```

`pool.id`/`provider.id` default to `ctlabs-vault-pool`/`vault-provider` (same
defaults as `gcp_wif_setup.py`). Outputs `audience`, `service_account_email`,
`pool_name`, `provider_name` feed directly into the ctlabs Terraform editor's
WIF fields / the Vault role's `client_id`.

### Reusing an existing service account

```yaml
wif:
  project: my-project
  provider:
    issuer: "https://vdb1.ctlabs.internal:8200/v1/identity/oidc"
  service_account:
    create: false
    email: existing-runner@my-project.iam.gserviceaccount.com
  subjects: ["3f2c1a9e-....-....-....-............"]
```

### No-discovery mode

If Vault isn't internet-reachable, GCP can't fetch its discovery/JWKS
documents. Pass the JWKS JSON directly instead (re-apply whenever Vault's
signing key rotates):

```yaml
wif:
  provider:
    issuer:    "https://vdb1.ctlabs.internal:8200/v1/identity/oidc"
    jwks_json: '{"keys":[...]}'
```

## Why no `test/`

Workload identity pools are **soft-deleted for 30 days** on destroy - a
create/destroy pytest cycle would burn the pool id and block re-running the
test for a month (the same reason `gcp_wif_setup.py --cleanup` never deletes
the pool by default, and why `modules/gcp/sandbox`/`modules/gcp/project` also
ship without a `test/`). Validate changes with `terraform validate` /
`terraform plan` against a scratch config instead.
