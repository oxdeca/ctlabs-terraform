# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/aws/net/main.tf
# Description : net module
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "igw" {
  for_each = { for net in var.networks : net.name => net }

  vpc_id = aws_vpc.net[each.value.name].id
}

resource "aws_vpc" "net" {
  for_each = { for net in var.networks : net.name => net }

  cidr_block = each.value.cidr
  tags       = { Name = each.value.name }
}

###resource "aws_route_table" "default" {
###  for_each = { for net in var.networks : net.name => net }
###
###  route {
###    cidr_block = "0.0.0.0/0"
###    gateway_id = aws_internet_gateway.igw[each.value.name].id
###  }
###
###  vpc_id = aws_vpc.net[each.value.name].id
###  tags   = { Name = each.value.name }
###}
###
###resource "aws_route" "default" {
###  for_each = { for net in var.networks : net.name => net }
###
###  route_table_id         = aws_internet_gateway.igw[each.value.name].id
###  destination_cidr_block = "0.0.0.0/0"
###  gateway_id             = aws_internet_gateway.igw[each.value.name].id
###}


###resource "aws_security_group" "ssh" {
###  for_each = { for net in var.networkss : net.name => net }
###
###  vpc_id = aws_vpc.net[each.value.name].id
###
###  ingress {
###    from_port   = 22
###    to_port     = 22
###    protocol    = "tcp"
###    cidr_blocks = ["0.0.0.0/0"]
###  }
###
###  egress {
###    from_port   = 0
###    to_port     = 0
###    protocol    = "-1"
###    cidr_blocks = ["0.0.0.0/0"]
###  }
###}
###