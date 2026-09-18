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

@pytest.fixture(scope="module")
def deployed_rulesets(tf_stack):
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


def _deployed(tf_stack):
    """All resources from the root and (one level of) child modules in state."""
    root_res  = tf_stack.search_state("values.root_module.resources") or []
    child_res = tf_stack.search_state("values.root_module.child_modules[].resources[]") or []
    return root_res + child_res


# -----------------------------------------------------------------------------
# Tests
#
# These assert against the *deployed state*, so the suite is idempotent: it passes
# both on a fresh apply and on a re-run where the resources already exist (plan is
# a no-op) — e.g. when destruction was skipped during an interactive run.
# -----------------------------------------------------------------------------

def test_zone_deployed(tf_stack, loaded_yaml_config):
    zones = [r for r in _deployed(tf_stack) if r.get("type") == "cloudflare_zone"]
    assert len(zones) == 1, "Expected exactly one cloudflare_zone in state."
    assert zones[0]["values"]["name"] == loaded_yaml_config["domain"]["name"]


def test_zone_settings_deployed(tf_stack, loaded_yaml_config):
    settings = {
        r["values"]["setting_id"]: r["values"]["value"]
        for r in _deployed(tf_stack)
        if r.get("type") == "cloudflare_zone_setting"
    }
    assert set(settings) == set(loaded_yaml_config["domain"]["settings"])


def test_dns_records_deployed(tf_stack, loaded_yaml_config):
    records = [r["values"] for r in _deployed(tf_stack) if r.get("type") == "cloudflare_dns_record"]
    assert len(records) == len(loaded_yaml_config["dns"]), "Unexpected number of DNS records in state."

    # `type` is optional in config and defaults to "A" (dns module variable), so
    # apply the same default here when selecting the expected records.
    a_records = [r for r in records if r["type"] == "A"]
    expected_a = {d["content"] for d in loaded_yaml_config["dns"] if d.get("type", "A") == "A"}
    assert {r["content"] for r in a_records} == expected_a
    assert all(not r["proxied"] for r in a_records), "A records use private targets, so they must not be proxied."


def test_ruleset_deployed(deployed_rulesets, loaded_yaml_config):
    assert set(deployed_rulesets) == set(loaded_yaml_config["rulesets"])
