# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/gcp/costs/main.tf
# Description : costs module
# -----------------------------------------------------------------------------

resource "null_resource" "tmp_dir" {
  provisioner "local-exec" {
    command = "rm -rf /tmp/costs && mkdir /tmp/costs && sleep 1"
  }
}

resource "local_file" "cost_resources" {
  for_each = { for vm in var.vms : vm.name => vm }

  filename = "/tmp/costs/resource-${each.value.name}.yml"
  content = <<-EOF
  region: ${var.project.region}
  project: ${var.project.id}
  instances:
    - name: ${each.value.name}
      type: ${each.value.type}
      spot: ${each.value.spot}

  EOF

  depends_on = [null_resource.tmp_dir]
}

resource "null_resource" "cost_estimation" {
  provisioner "local-exec" {
    command = "/usr/bin/gcosts calc -p /etc/gcosts/pricing.yml -d /tmp/costs/ -e /tmp/costs/costs.csv && rm -rf /tmp/costs"
  }

  depends_on = [local_file.cost_resources]
}

