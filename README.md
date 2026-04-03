# Immich Ansible — Mac Mini from scratch

Provisioning complet d'un Mac Mini vierge avec Immich, Docker, Tailscale, rclone et monitoring.

## Prérequis

- Mac Mini sous macOS (Apple Silicon M1/M2/M3)
- SSD externe branché et visible dans le Finder
- Connexion internet active

## Structure du projet

```
immich-ansible/
├── bootstrap.sh                          # Script d'amorçage (une seule fois)
├── site.yml                              # Playbook principal
├── inventory/
│   ├── hosts                             # Inventaire (localhost)
│   └── group_vars/
│       ├── all.yml                       # Variables globales
│       └── vault.yml                     # Secrets chiffrés (ansible-vault)
└── roles/
    ├── base/                             # Homebrew, outils système
    ├── securite/                         # Tailscale, Caddy, FileVault
    ├── stockage/                         # SSD, SMART, répertoires
    ├── docker/                           # Installation Docker
    ├── immich/                           # Déploiement Immich
    ├── acces/                            # Utilisateurs, 2FA
    ├── sauvegarde/                       # rclone, cron, Hetzner
    └── monitoring/                       # Health checks, alertes
```

## Installation (première fois)

```bash
# Sur le Mac Mini vierge, ouvrir le Terminal :
curl -fsSL https://votre-repo/bootstrap.sh | bash
```

## Configuration avant le premier lancement

```bash
# 1. Adapter inventory/group_vars/all.yml
# 2. Remplir et chiffrer les secrets
ansible-vault encrypt inventory/group_vars/vault.yml
# 3. Lancer
ansible-playbook site.yml --ask-vault-pass
```

## Commandes utiles

```bash
# Dry-run (vérifier sans appliquer)
ansible-playbook site.yml --check --ask-vault-pass

# Un seul rôle
ansible-playbook site.yml --tags sauvegarde --ask-vault-pass

# Lint
ansible-lint site.yml

# Éditer les secrets
ansible-vault edit inventory/group_vars/vault.yml
```
