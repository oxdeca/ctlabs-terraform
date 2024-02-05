#!/bin/bash

# -----------------------------------------------------------------------------
# File        : ctlabs-terraform/lpic2/ppvm.sh
# Description : Post-Provisioning Script for centos 9 vm's
# -----------------------------------------------------------------------------

#
# COMMANDS
#
CP=/usr/bin/cp
GEM=/usr/bin/gem
GIT=/usr/bin/git
PIP=/usr/bin/pip3
DNF=/usr/bin/dnf
BASH=/bin/bash
ECHO=/usr/bin/echo
SCTL=/usr/bin/systemctl
CHMOD=/usr/bin/chmod
MKDIR=/usr/bin/mkdir
PYTHON=/usr/bin/python3
DOCKER=/usr/bin/docker
TOUCH=/usr/bin/touch


#
# GLOBALS
#
LAB="lpic2_207.c9"
PKGS=(
  'epel-release'
  'vim'
  'htop'
  'tmux'
  'git'
  'ruby'
  'irb'
  'graphviz'
  'podman-docker'
  'wireshark-cli'
  'tcpdump'
  'nc'
  'perf'
  'bpftrace'
)

GEMS=(
  'webrick'
  'sinatra'
  'rackup'
)

CTIMGS=(
  '/root/ctlabs/images/centos/c9/base'
  '/root/ctlabs/images/centos/c9/frr'
  '/root/ctlabs/images/misc/kali'
)

#
# FUNCTIONS
#
packages() {
	for p in "${PKGS[@]}"; do
    ${DNF} -y install "${p}"
  done
	#${DNF} -y install ${PKGS[*]}
	${GEM} install ${GEMS[*]}
  ${ECHO} "set paste" >> /etc/vimrc
  ${ECHO} 'if [ -f "/etc/bashrc.kali" ]; then . /etc/bashrc.kali; fi' >> /etc/bashrc
}

services() {
  ${SCTL} disable --now firewalld.service
}

aliases() {
  ${MKDIR} -vp /etc/ansible/facts.d
  ${ECHO} '
  alias vi="/usr/bin/vim"
  alias pva=". ~/virtenv/bin/activate"
  alias pve="deactivate"

  function enter() {
    docker exec -it ${1} bash
  }
  ' >> /root/.bashrc
}

tmux() {
cat > /root/.tmux.conf << EOF
unbind C-b
set -g prefix C-a
set -g default-terminal "screen-256color"
bind-key C-a last-window
bind a send-prefix
set-option -g allow-rename off
set -g base-index 1
set-window-option -g mode-keys vi
setw -g monitor-activity on
set -g mouse on
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# vim copy mode
bind P paste-buffer
bind-key -T copy-mode-vi v send-keys -X begin-selection
bind-key -T copy-mode-vi y send-keys -X copy-selection
bind-key -T copy-mode-vi r send-keys -X rectangle-toggle
# Update default binding of `Enter` to also use copy-pipe
unbind -T copy-mode-vi Enter
bind-key -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "xclip -selection c"
bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -in -selection clipboard"
bind-key -T prefix m set -g mouse\; display 'Mouse: #{?mouse,ON,OFF}'

# statusbar
set -g status-position bottom
set -g status-justify left
EOF

}

clone_repo() {
  cd /root/
  ${GIT} clone https://github.com/oxdeca/ctlabs.git
  ${MKDIR} -vp /tmp/public
  ${CP} ctlabs/images/centos/c9/base/bashrc.kali /etc/
}

ctimages() {
  ${TOUCH} /etc/containers/nodocker
  for d in "${CTIMGS[@]}"; do
    cd ${d}
    ${BASH} ./build.sh
  done
}

#
# MAIN
#
aliases
tmux
prerequisites
packages
services

clone_repo
ctimages
#ctlab ${LAB}

