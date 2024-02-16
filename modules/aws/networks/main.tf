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

resource "aws_default_route_table" "default" {
  for_each = { for net in var.networks : net.name => net }
  default_route_table_id = aws_vpc.net[each.value.name].main_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw[each.value.name].id
  }

  tags   = { Name = each.value.name }
}


