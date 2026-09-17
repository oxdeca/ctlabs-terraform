# -----------------------------------------------------------------------------
# File    : ctlabs-terraform/modules/cloudflare/domain/test/test_cf_domain.py
# License : MIT
# -----------------------------------------------------------------------------

import os
import pytest
import yaml
from ctlabs_tools.pytest.helper import ConfTest

@pytest.fixture(scope="session")
def loaded_yaml_config():
    with open("config.yml", "r") as f:
        return yaml.safe_load(f)

@pytest.fixture(scope="session")
def deployed_rulesets(tf_stack_plan):
    root_res  = tf_stack.search_state("values.root_module.resources") or []
    child_res = tf_stack.search_state("values.root_module.child_modules[].resources[]") or []
    all_res   = root_res + child_res

    rulesets_by_phase = {}
    for r in all_res:
        if r.get("type") == "cloudflare_ruleset" and "values" in r:
            # Grab the phase name directly from the resource attributes
            phase_name = r["values"].get("phase")
            if phase_name:
                rulesets_by_phase[phase_name] = r["values"]
                
    return rulesets_by_phase


# -----------------------------------------------------------------------------
# Tests
# -----------------------------------------------------------------------------

def test_plan_structure(tf_stack_plan):
    """Basic sanity check: Ensure the plan generated resource changes."""
    assert tf_stack.has_changes == True, "Expected the Terraform plan to have changes, but it was a no-op."

