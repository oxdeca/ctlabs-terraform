# -----------------------------------------------------------------------------
# File    : ctlabs-terraform/modules/gcp/gke/test/test_gke.py
# -----------------------------------------------------------------------------

def test_plan(tf_stack):
    assert tf_stack.has_changes == True
