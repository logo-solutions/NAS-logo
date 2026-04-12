#!/bin/bash
# bootstrap.sh — Prépare l'environnement sur un Mac Mini vierge
# Usage : bash bootstrap.sh
set -euo pipefail

echo "==> NAS-logo bootstrap" >&2

# 1. Homebrew
if ! command -v brew &>/dev/null; then
  echo "==> Installation de Homebrew..." >&2
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Apple Silicon : ajouter brew au PATH
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "==> Homebrew déjà installé" >&2
fi

# 2. Ansible
if ! command -v ansible &>/dev/null; then
  echo "==> Installation d'Ansible..." >&2
  brew install ansible
else
  echo "==> Ansible déjà installé ($(ansible --version | head -1))" >&2
fi

# 3. ansible-lint (optionnel, pour make lint)
if ! command -v ansible-lint &>/dev/null; then
  echo "==> Installation d'ansible-lint..." >&2
  brew install ansible-lint
fi

# 4. Collections Ansible
echo "==> Installation des collections Ansible..." >&2
ansible-galaxy collection install community.general community.docker ansible.posix --upgrade

echo "==> Bootstrap terminé. Lancez : make preflight" >&2
