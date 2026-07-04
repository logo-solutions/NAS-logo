# Spec: NAS-logo — Provisioning Mac Mini NAS

## Objectif

Provisionner de façon **reproductible et idempotente** un Mac Mini vierge (Apple Silicon)
pour en faire un serveur de photos personnel accessible depuis n'importe où via VPN.

**Utilisateur :** logo (usage personnel + famille)

**Succès =** lancer `make install` sur un Mac Mini vierge et obtenir, sans intervention
manuelle supplémentaire :
- Immich fonctionnel et accessible via Tailscale
- Monitoring opérationnel (Prometheus + Grafana + alertes mobile)
- Sauvegarde automatique chiffrée vers Hetzner Storage Box
- Système entièrement reproductible (si le Mac Mini meurt, on re-run `make install`)

---

## Assumptions

> Corriger maintenant si faux, sinon je procède avec ces bases.

1. Mac Mini Apple Silicon (M1/M2/M3), macOS Ventura ou plus récent
2. SSD externe monté à `/Volumes/logousb/SSD/NAS-LOGO-VOLUME`
3. Connexion internet active pendant le provisioning
4. Docker Desktop for Mac (pas Docker Engine Linux)
5. Tailscale géré via authkey (pas d'interaction UI)
6. Pas de reverse proxy public — accès Tailscale uniquement
7. Un seul utilisateur macOS (logo) — pas de gestion multi-utilisateurs
8. Hetzner Storage Box déjà commandé (credentials à configurer)

---

## Tech Stack

| Composant       | Technologie                          | Version         |
|-----------------|--------------------------------------|-----------------|
| Automatisation  | Ansible                              | ≥ 2.15          |
| Photos          | Immich                               | `release` (latest stable) |
| Conteneurs      | Docker Desktop for Mac               | dernière        |
| Réseau VPN      | Tailscale                            | dernière        |
| Monitoring      | Prometheus + Grafana + cAdvisor      | dernière        |
| Alertes         | ntfy (push mobile)                   | self-hosted ou cloud |
| Sauvegarde      | rclone (backend : Hetzner SFTP)      | dernière        |
| Secrets         | ansible-vault (AES256)               | —               |

---

## Commandes

```bash
# Préparer l'environnement (une seule fois sur le Mac Mini vierge)
make bootstrap       # installe Homebrew, Ansible, dépendances

# Vérifier les prérequis avant de déployer
make preflight       # SSD monté, Hetzner joignable, Tailscale authkey valide

# Dry-run : voir ce qui va changer sans rien appliquer
make dryrun          # ansible-playbook site.yml --check --diff

# Installation complète
make install         # ansible-playbook site.yml --ask-vault-pass

# Vérifier l'état du système à tout moment
make health          # ansible-playbook healthcheck.yml

# Sauvegarde manuelle immédiate
make backup          # ansible-playbook site.yml --tags sauvegarde

# Linting
make lint            # ansible-lint site.yml

# Optionnel : Claude Code + MCP
make claude          # ansible-playbook claude.yml --ask-vault-pass
```

---

## Structure du projet

```
NAS-logo/
├── Makefile
├── SPEC.md                     ← ce fichier
├── PLAN.md                     ← plan de tâches (phase 2)
├── site.yml                    → playbook principal
├── bootstrap.yml               → étape 1 : Homebrew + outils
├── preflight.yml               → étape 2 : vérifications pré-déploiement
├── healthcheck.yml             → santé du système
├── claude.yml                  → optionnel : Claude Code + MCP
├── inventory/
│   ├── hosts                   → cible : localhost
│   └── group_vars/
│       ├── all.yml             → variables globales (pas de secrets)
│       └── vault.yml           → secrets chiffrés ansible-vault
└── roles/
    ├── base/                   → Homebrew, Python, Ansible deps
    ├── stockage/               → SSD mount check, arborescence
    ├── docker/                 → Docker Desktop installation
    ├── immich/                 → docker-compose.yml + .env Immich
    ├── monitoring/             → Prometheus + Grafana + cAdvisor + ntfy
    ├── sauvegarde/             → rclone config, dump PostgreSQL, cron
    ├── securite/               → Tailscale, FileVault, firewall macOS
    └── acces/                  → SSH hardening, utilisateurs
```

---

## Style Ansible

Chaque rôle suit cette convention :

```yaml
# roles/<nom>/tasks/main.yml

- name: "Installer rclone via Homebrew"          # nom explicite, verbe d'action
  community.general.homebrew:
    name: rclone
    state: present
  tags: [sauvegarde, rclone]                      # tags = nom du rôle + composant

- name: "Créer le répertoire de sauvegarde"
  ansible.builtin.file:
    path: "{{ ssd_mount_point }}/backups"
    state: directory
    mode: "0700"
  tags: [sauvegarde]
```

Règles :
- Modules FQCN (`ansible.builtin.*`, `community.general.*`)
- `changed_when` et `failed_when` explicites sur les `shell`/`command`
- Jamais de secret en clair — toujours `{{ vault_* }}`
- Templates Jinja2 dans `roles/<nom>/templates/*.j2`
- Handlers dans `roles/<nom>/handlers/main.yml`

---

## Stratégie de tests

- **ansible-lint** : sur tous les playbooks avant commit (`make lint`)
- **Molecule** : sur les rôles critiques (immich, sauvegarde, monitoring)
  - scénario `default` : converge + idempotence
  - scénario `preflight` : vérifie les prérequis sans appliquer
- **healthcheck.yml** : vérification post-déploiement
  - Immich répond sur `localhost:2283`
  - Grafana répond sur `localhost:3000`
  - rclone peut joindre Hetzner
  - SSD monté et espace disponible > 20%

---

## Boundaries

**Always :**
- Lancer `make lint` avant chaque commit
- Mettre les secrets dans `vault.yml`, jamais dans `all.yml`
- Tester l'idempotence : un double `make install` ne doit rien changer
- Committer la spec et le plan en même temps que le code

**Ask first :**
- Changer `ssd_mount_point` (impact sur toutes les données)
- Modifier la stratégie de rétention des sauvegardes
- Ajouter un nouveau service Docker (port, volume, impact réseau)
- Changer la version d'Immich (migration DB potentielle)

**Never :**
- Committer `vault.yml` déchiffré
- Utiliser `shell` ou `command` quand un module Ansible natif existe
- Exposer un port sur l'interface publique (tout passe par Tailscale)
- Supprimer des données du SSD ou de Hetzner dans un playbook

---

## Critères de succès

- [ ] `make bootstrap` s'exécute sur un Mac Mini vierge sans erreur
- [ ] `make preflight` détecte et signale tout prérequis manquant
- [ ] `make install` déploie l'ensemble en une seule commande
- [ ] Immich accessible sur `http://<tailscale-ip>:2283`
- [ ] Grafana accessible sur `http://<tailscale-ip>:3000`
- [ ] Une alerte ntfy arrive sur mobile si le disque dépasse 80%
- [ ] `make backup` s'exécute et un snapshot apparaît sur Hetzner
- [ ] Un second `make install` ne produit aucun changement (idempotence)
- [ ] `make health` passe au vert après déploiement

---

## Questions ouvertes

- [ ] ntfy : self-hosted sur le Mac Mini ou compte cloud ntfy.sh ?
- [ ] Grafana : dashboard custom ou import d'un dashboard communautaire (ex: ID 14282 pour cAdvisor) ?
- [ ] Immich machine learning : activer ou désactiver (gourmand en ressources) ?
- [ ] Accès depuis iOS : app Immich directement via Tailscale IP, ou alias DNS Tailscale ?
