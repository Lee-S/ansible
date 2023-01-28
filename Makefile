.PHONY: help

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ".:*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

setup: ## Install tools need to run playbook
	@sudo pacman --noconfirm -Sy archlinux-keyring chaotic-keyring
	@sudo pacman -Syu 
	@sudo pacman --noconfirm -Sy ansible
	ansible-galaxy collection install -r requirements.yml

run: ## Run the Ansible playbook
	@ANSIBLE_NOCOWS=1 ansible-playbook --verbose \
	--ask-become-pass --inventory localhost, \
	dotfiles.yaml
