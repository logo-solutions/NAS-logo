INVENTORY := inventory/hosts
VAULT_PASS_FILE := $(HOME)/.nas-logo-vault-pass
BECOME_PASS_FILE := $(HOME)/.nas-logo-become-pass
VAULT_ARGS := --vault-password-file $(VAULT_PASS_FILE) --become-password-file $(BECOME_PASS_FILE)

.PHONY: bootstrap preflight dryrun install health backup lint claude

bootstrap: ## Étape 1 : Homebrew + Ansible + dépendances système
	bash bootstrap.sh

preflight: ## Étape 2a : Vérifications pré-déploiement (SSD, Hetzner, Tailscale)
	ansible-playbook -i $(INVENTORY) preflight.yml

dryrun: ## Étape 2b : Dry-run complet avec diff
	ansible-playbook -i $(INVENTORY) site.yml $(VAULT_ARGS) --check --diff

install: ## Étape 3 : Installation complète
	ansible-playbook -i $(INVENTORY) site.yml $(VAULT_ARGS)

health: ## Vérification de l'état du système
	ansible-playbook -i $(INVENTORY) healthcheck.yml

backup: ## Sauvegarde manuelle immédiate
	ansible-playbook -i $(INVENTORY) site.yml $(VAULT_ARGS) --tags sauvegarde

lint: ## Lint tous les playbooks
	ansible-lint site.yml bootstrap.yml preflight.yml healthcheck.yml

claude: ## Optionnel : Claude Code + MCP
	ansible-playbook -i $(INVENTORY) claude.yml $(VAULT_ARGS)

help: ## Afficher cette aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
