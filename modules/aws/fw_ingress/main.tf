# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/aws/fw_ingress/main.tf
# Description : firewall ingress module
# -----------------------------------------------------------------------------

data "aws_vpc" "net" {
  for_each = { for net in var.networks : net.name => net }

  tags = { Name = each.value.name }
}

resource "aws_default_security_group" "fw_ingress" {
  for_each = { for net in var.networks : net.name => net }

  vpc_id = data.aws_vpc.net[each.value.name].id
  tags   = { Name = each.value.name }
}

resource "aws_security_group_rule" "ingress" {
  for_each = { for rule in var.ingress : rule.name => rule }

  security_group_id = aws_default_security_group.fw_ingress[each.value.net].id

  type        = "ingress"
  from_port   = each.value.port
  to_port     = each.value.port
  protocol    = each.value.proto
  cidr_blocks = each.value.src
}
