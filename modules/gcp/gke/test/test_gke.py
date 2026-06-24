# -----------------------------------------------------------------------------
# File    : ctlabs-terraform/modules/gcp/gke/test/test_gke.py
# -----------------------------------------------------------------------------

def test_clusters_provisioned(tf_stack):
    endpoints = tf_stack.search_state("outputs.endpoints.value")
    assert endpoints is not None, "No endpoints output found in state"
    assert "pub-cluster-01" in endpoints, "Public cluster missing from endpoints"
    assert endpoints["pub-cluster-01"] != "", "Public cluster endpoint is empty"
    assert "prv-cluster-01" in endpoints, "Private cluster missing from endpoints"
    assert endpoints["prv-cluster-01"] != "", "Private cluster endpoint is empty"

def test_cluster_names_match(tf_stack):
    names = tf_stack.search_state(
        "values.root_module.child_modules[].resources[?type=='google_container_cluster'].values.name[]"
    )
    assert names is not None
    assert "pub-cluster-01" in names
    assert "prv-cluster-01" in names

def test_custom_service_account(tf_stack):
    sas = tf_stack.search_state(
        "values.root_module.child_modules[].resources[?type=='google_service_account'].values.email[]"
    )
    assert sas is not None
    assert len(sas) >= 2
    for sa in sas:
        assert sa != "", "Service account email is empty"
