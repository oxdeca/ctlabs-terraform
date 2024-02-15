# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/aws/vm/main.tf
# Description : vm module
# -----------------------------------------------------------------------------

data "aws_subnet" "sub" {
  for_each = { for vm in var.vms : vm.name => vm }

  tags = { Name = each.value.net }
}

#data "aws_vpc" "net" {
#  for_each = { for  vm in var.vms : vm.net => vm }
#
#  tags = { Name = data.aws_subnet.sub[each.value.net].name }
#}

#data "aws_security_group" "ssh" {
#  for_each = { for vm in var.vms : vm.net => vm }
#
#  vpc_id = data.aws_vpc.net[each.value.net].id
#}

resource "aws_key_pair" "ssh-key" {
  key_name   = var.ssh.name
  public_key = var.ssh.pub
}

###resource "aws_network_interface" "nic" {
###  for_each = { for vm in var.vms : vm.name => vm }
###
###  subnet_id       = data.aws_subnet.sub[each.value.net].id
###  tags            = { Name = "${each.value.name}_eth0" }
####  security_groups = [data.aws_security_group.ssh[each.value.net].id]
###}

#resource "aws_security_group" "sg_ssh" {
#  for_each = { for net in data.aws_vpc.net : net.name => net }
#
#  vpc_id   = data.aws_vpc.net[each.value.name].id
#
#  ingress = {
#    from_port   = 22
#    to_port     = 22
#    protocol    = "tcp"
#    cidr_blocks = ["0.0.0.0/0"]
#    #cidr_blocks = [data.aws_subnet.sub[each.value.name].cidr, "0.0.0.0/0"]
#  }
#}

resource "aws_instance" "vm" {
  for_each = { for vm in var.vms : vm.name => vm }

  instance_type               = each.value.type
  #vpc_security_group_ids      = [aws_security_group.sg_ssh.id]
  ami                         = each.value.image
  key_name                    = var.ssh.name
  user_data                   = file( try("${each.value.script}", "" ) )
  tags                        = { Name = each.value.name }
  subnet_id                   = data.aws_subnet.sub[each.value.name].id
  associate_public_ip_address = true

#  network_interface {
#    network_interface_id = aws_network_interface.nic[each.value.name].id
#    device_index         = 0
#  }
}
