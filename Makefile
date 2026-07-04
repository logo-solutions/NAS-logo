INVENTORY := inventory/hosts
VAULT_PASS_FILE := $(HOME)/.nas-logo-vault-pass
BECOME_PASS_FILE := $(HOME)/.nas-logo-become-pass
VAULT_ARGS := --vault-password-file $(VAULT_PASS_FILE) --become-password-file $(BECOME_PASS_FILE)

.PHONY: bootstrap preflight dryrun install health backup lint claude tailscale-test scan-disks resilience scan import reboot

bootstrap: ## Étape 1 : Homebrew + Ansible + dépendances système
	bash bootstrap.sh

preflight: ## Étape 2a : Vérifications pré-déploiement (SSD, Hetzner, Tailscale)
	ansible-playbook -i $(INVENTORY) preflight.yml

dryrun: ## Étape 2b : Dry-run complet avec diff
	ansible-playbook -i $(INVENTORY) site.yml $(VAULT_ARGS) --check --diff

install: ## Étape 3 : Installation complète
	ansible-playbook -i $(INVENTORY) site.yml $(VAULT_ARGS)

health: ## Vérification de l'état du système
	ansible-playbook -i $(INVENTORY) healthcheck.yml $(VAULT_ARGS)

backup: ## Sauvegarde Immich COMPLÈTE (conforme état de l'art: DB + FILES + CONFIG + checksums 3-2-1)
	bash bin/immich-backup-complete.sh

restore-list: ## Lister les versions de sauvegarde disponibles
	ssh logo@100.113.214.55 "/usr/local/bin/nas-logo-restore.sh --list"

restore-dry: ## Simuler une restauration (dry-run)
	ssh logo@100.113.214.55 "/usr/local/bin/nas-logo-restore.sh --dry-run"

restore: ## Restaurer depuis Hetzner (current). VERSION=20260413 pour une date précise
	ssh logo@100.113.214.55 "/usr/local/bin/nas-logo-restore.sh $(if $(VERSION),--version $(VERSION),)"

lint: ## Lint tous les playbooks
	ansible-lint site.yml bootstrap.yml preflight.yml healthcheck.yml

claude: ## Optionnel : Claude Code + MCP
	ansible-playbook -i $(INVENTORY) claude.yml $(VAULT_ARGS)

gmail-dry: ## Simuler l'import Gmail (dry-run, sans modifier la boite)
	ssh logo@100.113.214.55 "python3 /usr/local/bin/nas-logo-gmail-fetch.py --dry-run"

gmail-run: ## Lancer l'import Gmail maintenant (production)
	ssh logo@100.113.214.55 "python3 /usr/local/bin/nas-logo-gmail-fetch.py"

tailscale-test: ## Tester l'accès Tailscale depuis ce laptop (hors réseau interne)
	ansible-playbook tailscale-test.yml

resilience: ## Déployer arrêt propre + watchdog mounts + n8n PostgreSQL
	ansible-playbook -i $(INVENTORY) site.yml $(VAULT_ARGS) --tags resilience,n8n

scan-disks: ## Scanner les disques de sauvegarde pour détecter les copies OS accidentelles
	ansible-playbook -i $(INVENTORY) scan-disks.yml $(VAULT_ARGS)

maintenance-on: ## Suspendre les sauvegardes (mode maintenance)
	ansible -i $(INVENTORY) macmini -m ansible.builtin.file -a "path=/tmp/nas-logo-maintenance state=touch" $(VAULT_ARGS)
	@echo "Mode maintenance ON — sauvegardes suspendues"

maintenance-off: ## Reprendre les sauvegardes
	ansible -i $(INVENTORY) macmini -m ansible.builtin.file -a "path=/tmp/nas-logo-maintenance state=absent" $(VAULT_ARGS)
	@echo "Mode maintenance OFF — sauvegardes reprises"

scan: ## Analyser une source — SHA-1 dedup preview sans import (SOURCE=/path/to/source)
	@[ -n "$(SOURCE)" ] || (echo "Usage: make scan SOURCE=/path/to/source"; exit 1)
	bash bin/immich-import.sh "$(SOURCE)" --scan-only

import: ## Importer une source (SOURCE=/path [GOOGLE=1] [NO_HETZNER=1])
	@[ -n "$(SOURCE)" ] || (echo "Usage: make import SOURCE=/path/to/source [GOOGLE=1] [NO_HETZNER=1]"; exit 1)
	bash bin/immich-import.sh "$(SOURCE)" $(if $(GOOGLE),--google) $(if $(NO_HETZNER),--no-hetzner)

reboot: ## Arrêt gracieux : services docker-compose, Colima, flush disque, puis reboot
	bash bin/graceful-shutdown.sh

help: ## Afficher cette aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
