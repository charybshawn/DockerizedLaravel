# Laravel Deployer - Ansible Makefile
# Provides convenient shortcuts for common operations

.PHONY: help deploy update remove setup

# Default target
help:
	@echo "Laravel Deployer - Ansible Version"
	@echo ""
	@echo "Usage:"
	@echo "  make setup                     Setup inventory files from examples"
	@echo "  make deploy SITE=name DOMAIN=domain.com REPO=git-url"
	@echo "  make update SITE=name"
	@echo "  make remove SITE=name"
	@echo ""
	@echo "Examples:"
	@echo "  make deploy SITE=blog DOMAIN=blog.example.com REPO=https://github.com/user/blog.git"
	@echo "  make deploy SITE=api DOMAIN=api.example.com REPO=git@github.com:company/api.git BRANCH=production SSL=true"
	@echo "  make update SITE=blog BRANCH=develop"
	@echo "  make remove SITE=blog KEEP_DB=true"
	@echo ""
	@echo "Optional parameters:"
	@echo "  BRANCH=branch-name            Git branch (default: main)"
	@echo "  SSL=true                      Enable SSL/HTTPS"
	@echo "  FORCE=true                    Force deployment/removal"
	@echo "  KEEP_DB=true                  Keep database when removing"
	@echo "  KEEP_FILES=true               Backup files when removing"

# Setup inventory files from examples
setup:
	@if [ ! -f inventory/hosts.yml ]; then \
		cp inventory/hosts.yml.example inventory/hosts.yml; \
		echo "Created inventory/hosts.yml - please edit with your server details"; \
	else \
		echo "inventory/hosts.yml already exists"; \
	fi
	@if [ ! -f inventory/group_vars/all.yml ]; then \
		cp inventory/group_vars/all.yml.example inventory/group_vars/all.yml; \
		echo "Created inventory/group_vars/all.yml - please review default settings"; \
	else \
		echo "inventory/group_vars/all.yml already exists"; \
	fi

# Deploy a Laravel site
deploy:
	@if [ -z "$(SITE)" ] || [ -z "$(DOMAIN)" ] || [ -z "$(REPO)" ]; then \
		echo "Error: SITE, DOMAIN, and REPO are required"; \
		echo "Usage: make deploy SITE=name DOMAIN=domain.com REPO=git-url"; \
		exit 1; \
	fi
	ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml \
		-e site_name=$(SITE) \
		-e domain=$(DOMAIN) \
		-e github_repo=$(REPO) \
		$(if $(BRANCH),-e github_branch=$(BRANCH)) \
		$(if $(SSL),-e ssl_enabled=$(SSL)) \
		$(if $(FORCE),-e force_deploy=$(FORCE))

# Update an existing site
update:
	@if [ -z "$(SITE)" ]; then \
		echo "Error: SITE is required"; \
		echo "Usage: make update SITE=name"; \
		exit 1; \
	fi
	ansible-playbook -i inventory/hosts.yml playbooks/update.yml \
		-e site_name=$(SITE) \
		$(if $(BRANCH),-e github_branch=$(BRANCH))

# Remove a site
remove:
	@if [ -z "$(SITE)" ]; then \
		echo "Error: SITE is required"; \
		echo "Usage: make remove SITE=name"; \
		exit 1; \
	fi
	ansible-playbook -i inventory/hosts.yml playbooks/remove.yml \
		-e site_name=$(SITE) \
		$(if $(KEEP_DB),-e keep_database=$(KEEP_DB)) \
		$(if $(KEEP_FILES),-e keep_files=$(KEEP_FILES)) \
		$(if $(FORCE),-e force_remove=$(FORCE))

# Check Ansible syntax
check:
	ansible-playbook --syntax-check -i inventory/hosts.yml playbooks/deploy.yml
	ansible-playbook --syntax-check -i inventory/hosts.yml playbooks/update.yml
	ansible-playbook --syntax-check -i inventory/hosts.yml playbooks/remove.yml

# List available sites on target server
list:
	ansible webservers -i inventory/hosts.yml -m shell -a "ls -la /var/www/ | grep ^d"