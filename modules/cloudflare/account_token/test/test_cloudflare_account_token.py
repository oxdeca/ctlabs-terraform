# -----------------------------------------------------------------------------
# File    : ctlabs-terraform/modules/cloudflare/account_token/test/test_cf_account_token.py
# License : MIT
# -----------------------------------------------------------------------------

import pytest
import yaml
from ctlabs_tools.pytest.helper import ConfTest

@pytest.fixture(scope="session")
def loaded_yaml_config():
    """Loads the config.yml file so it can be used as the source of truth."""
    with open("config.yml", "r") as f:
        return yaml.safe_load(f)

def get_tf_resources(tf_stack, resource_type):
    """
    Safely extracts resources from Terraform state, regardless of whether
    they are in the root module or a child module, bypassing JMESPath limits.
    """
    # 1. Grab from root module
    root_res = tf_stack.search_state("values.root_module.resources") or []
    # 2. Grab from child modules
    child_res = tf_stack.search_state("values.root_module.child_modules[].resources[]") or []

    # 3. Combine and filter by type
    all_res = root_res + child_res
    return {
        r["values"]["name"]: r["values"]
        for r in all_res
        if r.get("type") == resource_type and "values" in r and "name" in r.get("values", {})
    }


# -----------------------------------------------------------------------------
# Tests
# -----------------------------------------------------------------------------

def test_plan_structure(tf_stack):
    """Basic sanity check: Ensure the plan generated resource changes."""
    assert tf_stack.has_changes == True, "Expected the Terraform plan to have changes, but it was a no-op."
