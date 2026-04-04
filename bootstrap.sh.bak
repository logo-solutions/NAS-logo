#!/bin/bash
# bootstrap.sh — à exécuter une seule fois sur le Mac Mini vierge
# Usage : curl -fsSL https://votre-repo/bootstrap.sh | bash

set -euo pipefail

echo "==> Installation de Homebrew..."
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "==> Installation d'Ansible..."
brew install ansible ansible-lint

echo "==> Clonage du projet Ansible..."
if [ ! -d "$HOME/immich-ansible" ]; then
  git clone https://votre-repo/immich-ansible.git "$HOME/immich-ansible"
fi

cd "$HOME/immich-ansible"

echo "==> Déchiffrement du vault et lancement du provisioning..."
echo "Chemin de votre SSD (ex: /Volumes/MonSSD) :"
read -r SSD_PATH

ansible-playbook site.yml \
  -i inventory/hosts \
  --ask-vault-pass \
  -e "ssd_mount_point=${SSD_PATH}"

echo "==> Bootstrap terminé."
