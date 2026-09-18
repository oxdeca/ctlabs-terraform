# -----------------------------------------------------------------------------
# File    : ctlabs-terraform/modules/cloudflare/domain/test/conftest.py
# License : MIT
#
# Mints a short-lived Cloudflare API token for the test session, stashes it in the
# Vault cubbyhole and revokes it afterwards. Terraform reads it back with an
# ephemeral vault_generic_secret (see provider.tf) so it never touches state.
# -----------------------------------------------------------------------------

import os
from datetime import datetime, timedelta, timezone

import pytest

from ctlabs_tools.pytest.helper  import Terraform
from ctlabs_tools.vault.core     import HashiVault
from ctlabs_tools.cloudflare     import Cloudflare
from ctlabs_tools.cloudflare.mixins.tokens import ZONE_SCOPE

# Account-resource token carrying the zone-scoped permissions the domain stack needs.
# (The zone being managed does not exist yet at mint time, so it must be account-wide.)
CF_PERMISSIONS = [
    "Zone Write",
    "Zone Read",
    "DNS Write",
    "DNS Read",
    "Zone Settings Write",
    "Zone Settings Read",
    "SSL and Certificates Write",
    "SSL and Certificates Read",
    "Zone Transform Rules Write",
    "Zone Transform Rules Read",
    "Dynamic URL Redirects Write",
    "Dynamic URL Redirects Read",
]

CUBBYHOLE_PATH = "cloudflare"


@pytest.fixture(scope="session")
def cf_token(vault_auth):
    """Mint -> stash in cubbyhole -> yield -> clear cubbyhole -> revoke."""
    secret = vault_auth.read_secret(path="cloudflare", mount_point="kvv2")
    if not secret:
        pytest.fail("No Cloudflare credentials at kvv2/cloudflare")

    creator = Cloudflare(
        token=secret["account_token"],
        account_id=secret["account_id"],
        zone_id=secret.get("zone_id", ""),
        vault=vault_auth,
    )

    minted = creator.create_scoped_token(
        name="ctlabs-domain-test",
        permissions=CF_PERMISSIONS,
        scope="account",
        permission_scope=ZONE_SCOPE,
        expires_on=(datetime.now(timezone.utc) + timedelta(hours=2)).strftime("%Y-%m-%dT%H:%M:%SZ"),
    )

    ephemeral = Cloudflare(
        token=minted["value"],
        account_id=creator.account_id,
        zone_id=creator.zone_id,
        vault=vault_auth,
    )
    ephemeral.store_cubbyhole(path=CUBBYHOLE_PATH)

    os.environ["TF_VAR_cloudflare_account_id"] = creator.account_id
    if creator.zone_id:
        os.environ["TF_VAR_cloudflare_zone_id"] = creator.zone_id

    try:
        yield minted
    finally:
        ephemeral.clear_cubbyhole(path=CUBBYHOLE_PATH)
        creator.revoke_token(minted["id"])
        os.environ.pop("TF_VAR_cloudflare_account_id", None)
        os.environ.pop("TF_VAR_cloudflare_zone_id", None)


@pytest.fixture(scope="module")
def tf(is_interactive, vault_auth, wd, cf_token):
    """Same as the shared `tf` fixture, but guarantees the CF token is minted first."""
    t = Terraform(wd=wd, interactive=is_interactive, auth_callback=vault_auth.ensure_valid_token)
    yield t
    t.cleanup()
