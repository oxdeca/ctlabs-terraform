#!/bin/bash

# -----------------------------------------------------------------------------
# File : ctlabs-terraform/modules/gcp/scripts/linux.sh
# -----------------------------------------------------------------------------

install() {
  if [ -f /usr/bin/dnf ]; then
      dnf -y install python3 python3-pip python3-requests
  elif [ -f /usr/bin/yum ]; then
      yum -y install python3 python3-pip python3-requests
  fi
}

configure() {
  if [ ! -f /etc/sudoers.d/01_ansible ]; then
    echo 'ansible ALL = NOPASSWD:ALL' > /etc/sudoers.d/01_ansible
  fi
}


install
configure