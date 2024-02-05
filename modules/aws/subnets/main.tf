# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/aws/subnet/main.tf
# Description : subnet module
# -----------------------------------------------------------------------------

data "aws_vpc" "net" {
  for_each = { for sub in var.subnets : sub.net => sub }

  tags = { Name = each.value.net }
}

resource "aws_subnet" "sub" {
  for_each = { for sub in var.subnets : sub.name => sub }

  vpc_id            = data.aws_vpc.net[each.value.net].id
  cidr_block        = each.value.cidr
  availability_zone = var.project.zone
  tags              = { Name = each.value.name }
}

#resource "aws_internet_gateway" "igw" {
#  for_each = { for net in var.subnets : net.name => net }
#
#  vpc_id = data.aws_vpc.net[each.value.net].id
#}
#
#resource "aws_route_table" "default" {
#  for_each = { for sub in var.subnets : sub.name => sub }
#
#  vpc_id = data.aws_vpc.net[each.value.net].id
#  #subnet_ids = [aws.subnet.sub[each.value.name].id]
#  #gateway_id = aws_internet_gateway.igw[each.value.net].id
#}
#
#resource "aws_route" "default" {
#  for_each = { for net in var.subnets : net.name => net }
#
#  route_table_id         = aws_route_table.default[each.value.net].id
#  destination_cidr_block = "0.0.0.0/0"
#  gateway_id             = aws_internet_gateway.igw[each.value.net].id
#}

###resource "aws_route_table_association" "subnet_association" {
###  for_each = { for sub in var.subnets : sub.name => sub }
###
###  subnet_id      = aws_subnet.sub[each.value.name].id
###  route_table_id = data.aws_vpc.net[each.value.net].main_route_table_id
###  #route_table_id = aws_route_table.subnet[each.value.name].id
###}
###
###data "aws_internet_gateway" "gw" {
###  for_each = { for sub in var.subnets : sub.net => sub }
###  
###  filter {
###    name   = "attachment.vpc-id"
###    values = [data.aws_vpc.net[each.value.net].id]
###  }
###}
###
###resource "aws_route" "igw" {
###  for_each = { for sub in var.subnets : sub.name => sub }
###
###  route_table_id         = data.aws_vpc.net[each.value.net].main_route_table_id
###  destination_cidr_block = "0.0.0.0/0"
###  gateway_id             = data.aws_internet_gateway.gw[each.value.net].id
###}
#data "aws_route_table" "route" {
#  for_each = { for sub in var.subnets : sub.name => sub }
#  subnet_id = aws_subnet.sub[each.value.name].id
#}

#resource "aws_route_table" "subnet" {
#  for_each = { for sub in var.subnets : sub.name => sub }
#
#  vpc_id = data.aws_vpc.net[each.value.net].id
#  route {
#    cidr_block = "0.0.0.0/0"
#    gateway_id = data.aws_internet_gateway.gw[each.value.net].id
#  }
#
#}