.PHONY: bootstrap preflight dryrun install claude health lint test help

INVENTORY = -i inventory/hosts
VAULT     = --ask-vault-pass

help:
	@echo ""
	@echo "  Projet Immich — Mac Mini"
	@echo ""
	@echo "  make bootstrap    Étape 1 : prépare l'environnement (lint, Molecule, Docker, SSH)"
	@echo "  make preflight    Étape 2a : vérifie les prérequis machine (SSD, Hetzner, macOS)"
	@echo "  make dryrun       Étape 2b : dry-run complet avec diff"
	@echo "  make install      Étape 3 : installation complète"
	@echo "  make claude       Étape 4 : environnement Claude Code + MCP (optionnel)"
	@echo "  make health       Health check — disponible à tout moment"
	@echo "  make lint         Valider les playbooks avec ansible-lint"
	@echo "  make test         Lancer Molecule sur tous les rôles"
	@echo ""

bootstrap:
	@echo "==> Étape 1 — Bootstrap environnement..."
	ansible-playbook $(INVENTORY) bootstrap.yml

preflight:
	@echo "==> Étape 2a — Vérification des prérequis..."
	ansible-playbook $(INVENTORY) preflight.yml $(VAULT)

dryrun:
	@echo "==> Étape 2b — Dry-run avec diff..."
	ansible-playbook $(INVENTORY) site.yml --check --diff $(VAULT)

install:
	@echo "==> Étape 3 — Installation complète..."
	ansible-playbook $(INVENTORY) site.yml $(VAULT)

claude:
	@echo "==> Étape 4 — Environnement Claude Code + MCP (optionnel)..."
	ansible-playbook $(INVENTORY) claude.yml $(VAULT)

health:
	@echo "==> Health check..."
	ansible-playbook $(INVENTORY) healthcheck.yml $(VAULT)

lint:
	@echo "==> Lint..."
	ansible-lint bootstrap.yml preflight.yml site.yml claude.yml healthcheck.yml

test:
	@echo "==> Tests Molecule..."
	cd roles/immich && molecule test
	cd roles/sauvegarde && molecule test
	cd roles/monitoring && molecule test
