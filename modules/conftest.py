import os
import pytest
from ctlabs_tools.pytest.helper import Terraform, Ansible, ConfTest
from ctlabs_tools.vault.core    import HashiVault

def pytest_addoption(parser):
    parser.addoption("-I", "--interactive", action="store_true", default=False, help="Enable interactive retry loops on failures")

@pytest.fixture(scope="session")
def is_interactive(request):
    return request.config.getoption("--interactive")

@pytest.fixture(scope="session")
def vault_auth():
    return HashiVault()

@pytest.fixture(scope="module")
def wd(request):
    return os.path.dirname(os.path.abspath(str(request.fspath)))

@pytest.fixture(scope="module")
def tf(is_interactive, vault_auth, wd):
    t = Terraform(wd=wd, interactive=is_interactive, auth_callback=vault_auth.ensure_valid_token)
    yield t
    t.cleanup()

@pytest.fixture(scope="module")
def tf_stack(tf, is_interactive, vault_auth, wd):
    tf.init()
    tf.plan()
    has_changes = tf.has_changes()

    if has_changes:
        policy_dir = os.path.join(wd, "policy")
        if os.path.isdir(policy_dir):
            print("\n[CONFTEST] Evaluating Terraform plan against Rego policies...")
            policy_checker = ConfTest(wd=wd, input="tfplan.json", interactive=is_interactive, auth_callback=vault_auth.ensure_valid_token)
            policy_checker.run(ns="main")

    tf.show_changes()
    tf.apply()
    tf.has_changes = has_changes
    yield tf
    tf.cleanup()
    print("")
    tf.destroy()
