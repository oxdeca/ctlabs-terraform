# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/aws/net/main.tf
# Description : net module
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "igw" {
  for_each = { for net in var.networks : net.name => net }

  vpc_id = aws_vpc.net[each.value.name].id
  tags   = { Name = each.value.name }
}

resource "aws_vpc" "net" {
  for_each = { for net in var.networks : net.name => net }

  cidr_block = each.value.cidr
  tags       = { Name = each.value.name }
}

#resource "aws_route_table" "default" {
#  for_each = { for net in var.networks : net.name => net }
#  #default_route_table_id = aws_vpc.net[each.value.name].id
#
#  route {
#    cidr_block = "0.0.0.0/0"
#    gateway_id = aws_internet_gateway.igw[each.value.name].id
#  }
#
#  vpc_id = aws_vpc.net[each.value.name].id
#  tags   = { Name = each.value.name }
#}

resource "aws_default_route_table" "default" {
  for_each = { for net in var.networks : net.name => net }
  default_route_table_id = aws_vpc.net[each.value.name].main_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw[each.value.name].id
  }

  tags   = { Name = each.value.name }
}

###resource "aws_route" "default" {
###  for_each = { for net in var.networks : net.name => net }
###
###  route_table_id         = aws_internet_gateway.igw[each.value.name].id
###  destination_cidr_block = "0.0.0.0/0"
###  gateway_id             = aws_internet_gateway.igw[each.value.name].id
###}


resource "aws_default_security_group" "default" {
  for_each = { for net in var.networks : net.name => net }

  vpc_id = aws_vpc.net[each.value.name].id

  dynamic "ingress" {
    for_each = var.firewall.ingress

    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.proto
      cidr_blocks = ingress.value.src
    }
  }

  dynamic "egress" {
    for_each = var.firewall.egress

    content {
      from_port   = egress.value.port
      to_port     = egress.value.port
      protocol    = egress.value.proto
      cidr_blocks = egress.value.dst
    }
  }
}

