### Overview
This is an ansible repos used for setting up devices on my home lab.  These are mainly running various Linux distos. Lets start with setting up tasks for only PopOS 24.04 Cosmic.  We will implement this in stages. 

### Usage
The idea is that after a clean install you check out this repo and run the playbook and it automates as many tasks as possible.  

### Prerequisites
This repo is already checked out, and python and ansible are installed.   TODO: Make a doc for these steps later.  Bitwarden in Firefox, copy ssh keys, install vcode, python, ansible

### Step 1
Create an ansible roll to run on localhost to mount my UGREEN nas, and update fstab.  The dns is nas.local and the username is lee.   What is best practice for retrieving credentials abd storing them to pass to fstab?

### Step 2 
Install some standard packages:

  - anacron
  - autojump
  - btop
  - dconf-editor
  - fzf
  - hardinfo
  - htop
  - inxi
  - kitty
  - lm-sensors
  - restic
  - ripgrep
  - silversearcher-ag
  - snapd
  - solaar
  - stress
  - thefuck
  - tmux
  - tree
  - ubuntu-restricted-extras
  - vim
  - yubikey-manager


