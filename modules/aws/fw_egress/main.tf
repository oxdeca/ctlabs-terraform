# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/aws/fw_egress/main.tf
# Description : firewall egress module
# -----------------------------------------------------------------------------

data "aws_vpc" "net" {
  for_each = { for net in var.networks : net.name => net }

  tags = { Name = each.value.name }
}

resource "aws_default_security_group" "fw_egress" {
  for_each = { for net in var.networks : net.name => net }

  vpc_id = data.aws_vpc.net[each.value.name].id
  tags   = { Name = each.value.name }
}

resource "aws_security_group_rule" "egress" {
  for_each = { for rule in var.egress : rule.name => rule }

  security_group_id = aws_default_security_group.fw_egress[each.value.net].id

  type        = "egress"
  from_port   = each.value.port
  to_port     = each.value.port
  protocol    = each.value.proto
  cidr_blocks = each.value.dst
}
