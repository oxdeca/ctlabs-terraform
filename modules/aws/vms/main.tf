# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/modules/aws/vm/main.tf
# Description : vm module
# -----------------------------------------------------------------------------

data "aws_subnet" "sub" {
  for_each = { for vm in var.vms : vm.name => vm }

  tags = { Name = each.value.net }
}

resource "aws_key_pair" "ssh-key" {
  key_name   = var.ssh.name
  public_key = var.ssh.pub
}

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
