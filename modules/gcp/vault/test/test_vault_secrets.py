# -----------------------------------------------------------------------------
# File    : ctlabs-terraform/modules/gcp/vault/test/test_vault_secrets.py
# License : MIT
# -----------------------------------------------------------------------------

import jq
import os
import pytest
import subprocess
from   ctlabs_tools.pytest.helper import Terraform, Ansible
from   jinja2 import Environment, FileSystemLoader

@pytest.fixture(scope="session")
def plan(wd="."):
  tf = Terraform(use_vault=True)

  tf.init()
  return tf.plan()

#def test_plan1(plan):
#  tf = Terraform()
#
#  tfplan = tf.show_plan()
#  secrets = jq.compile('.prior_state.values.root_module.child_modules[].resources[] | select(.name=="secrets") | .values.data').input(text=json.dumps(tfplan)).all()
#  assert len(secrets) == 2
#  #print(secrets)
#  assert len(secrets[0].keys()) > 0
#  assert len(secrets[1].keys()) > 0
#  assert plan.returncode == 0
#
#  tf.cleanup() 


def test_plan(plan):
  print(plan.stdout)
  # 1. Combine both streams just in case
  all_logs = (plan.stdout or "") + (plan.stderr or "")

  assert plan.returncode == 0

  # 2. Use a partial match to ignore the ANSI color codes (\x1b[...) 
  # and the specific stream (stdout vs stderr)
  expected_log = 'vault_kv_secret_v2.secrets["netbox"]: Opening...'
    
  assert expected_log in all_logs, f"Could not find lifecycle log in:\n{all_logs}"
  
  # Check for the closing phase too
  assert 'Closing...' in all_logs

  print("Verified: Ephemeral lifecycle successful.")
