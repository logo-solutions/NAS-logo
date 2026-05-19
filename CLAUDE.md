# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Project Overview

**NAS-logo** is an Ansible-based provisioning system that turns a bare Mac Mini (Apple Silicon) into a complete personal media and document server. It's designed to be fully reproducible: `make install` on a fresh Mac Mini should create a production-ready system without manual intervention.

**Key goals:**
- Idempotent infrastructure-as-code for macOS
- Zero-knowledge backup to Hetzner (encrypted)
- Tailscale VPN for secure remote access
- Immich for photo management and backup
- Paperless-ngx for document digitization
- Automated monitoring and alerting
- Reproducible disaster recovery (re-running `make install` restores everything)

---

## Quick Commands

| Task | Command |
|------|---------|
| **First-time setup** | `make bootstrap` — install Homebrew, Ansible, system deps |
| **Dry-run** | `make dryrun` — preview all changes without applying |
| **Deploy everything** | `make install` — run full provisioning (needs vault password) |
| **System health check** | `make health` — verify all services are running |
| **Manual backup** | `make backup` — immediately backup NAS to Hetzner |
| **Restore from backup** | `make restore [VERSION=date]` — restore from a specific snapshot |
| **Lint playbooks** | `make lint` — validate YAML and Ansible syntax |
| **Single role** | `ansible-playbook -i inventory/hosts site.yml --tags immich` — deploy only Immich |

---

## Architecture

### Deployment Phases

1. **bootstrap.yml** — One-time system setup (Homebrew, Ansible, Python)
2. **preflight.yml** — Pre-deployment verification (SSD mounted, Hetzner reachable, Tailscale auth key valid)
3. **site.yml** — Main playbook: runs 17 roles in sequence to configure the entire stack

### Core Roles

**Foundation:**
- `base` — Homebrew packages, Python, CLI tools
- `stockage` — SSD mount validation, directory structure
- `docker` — Docker Desktop installation and daemon setup

**Services:**
- `immich` — Photo management (docker-compose, PostgreSQL, TypeORM)
- `paperless` — Document scanning and OCR
- `recherche` — Meilisearch (full-text search)
- `n8n` — Automation workflows
- `whisper` — Audio transcription
- `monitoring` — Prometheus, Grafana, cAdvisor
- `mail` — Email handling (Optional)

**Infrastructure:**
- `securite` — Tailscale VPN, firewall rules
- `acces` — Network access (SMB, SSH config)
- `gmail` — Gmail import automation
- `sauvegarde` — rclone backups to Hetzner
- `mutagen` — File sync daemon (if enabled)
- `personnes` — User-specific directory setup
- `smb` — SMB/NFS file shares

### Data Layout

Critical volumes on a real NAS:
- `/Volumes/logousb/SSD/NAS-LOGO-VOLUME/` — Working SSD (Immich assets, database, config)
- `/Volumes/NAS-LOGO-DATA/` — External HDD (archive, backups, long-term storage)
- `~/.nas-logo-vault-pass` — Vault password (required for deployment, git-ignored)
- `inventory/group_vars/vault.yml` — Encrypted secrets (AES-256)

---

## Key Files

| File | Purpose |
|------|---------|
| `site.yml` | Main playbook — orchestrates all 17 roles in order |
| `bootstrap.yml` | First-time system prep (Homebrew, Ansible, deps) |
| `preflight.yml` | Pre-deployment checks (SSD, network, auth keys) |
| `healthcheck.yml` | System health verification (all containers, mounts, backups) |
| `Makefile` | CLI interface to common tasks |
| `inventory/hosts` | Deployment target (always `localhost` on macOS) |
| `inventory/group_vars/all.yml` | Non-secret variables (versions, paths, timeouts) |
| `inventory/group_vars/vault.yml` | **Encrypted secrets** (Hetzner credentials, API keys) |
| `bootstrap.sh` | Bash script run before Ansible (installs Homebrew, etc.) |

---

## Secrets Management

All sensitive data is stored in `inventory/group_vars/vault.yml` and encrypted with ansible-vault (AES-256). To edit:

```bash
ansible-vault edit inventory/group_vars/vault.yml
```

You'll be prompted for the vault password (stored in `~/.nas-logo-vault-pass` on the NAS host).

**Never:**
- Commit unencrypted secrets
- Copy vault passwords into version control
- Print vault contents in logs

**Common secrets:**
- Hetzner SFTP credentials (for `sauvegarde` backups)
- Immich API keys
- Tailscale auth keys
- Gmail API credentials
- Database passwords

---

## Common Workflows

### Deploying a Single Service

To test or update just one role without running the whole playbook:

```bash
# Deploy only Immich (useful when debugging or updating versions)
ansible-playbook -i inventory/hosts site.yml --tags immich --vault-password-file ~/.nas-logo-vault-pass

# Deploy Immich + monitoring (related services together)
ansible-playbook -i inventory/hosts site.yml --tags immich,monitoring --vault-password-file ~/.nas-logo-vault-pass
```

### Checking Service Status

```bash
# SSH to the NAS and inspect Docker containers
ssh logo@100.113.214.55 "docker ps"

# Check Immich-specific logs
ssh logo@100.113.214.55 "docker logs immich_server"

# Monitor resource usage
ssh logo@100.113.214.55 "docker stats"
```

### Disaster Recovery

If the Mac Mini hardware fails:
1. Provision a new Mac Mini with the same external SSD attached
2. Run `make bootstrap && make install` (same command as initial setup)
3. All configuration and data restore automatically from Hetzner backups

To restore to a specific point-in-time:
```bash
make restore VERSION=20260415
```

---

## Testing & Validation

**Before deploying to production:**

1. **Syntax validation** — `make lint` checks all YAML and Ansible playbooks
2. **Dry-run preview** — `make dryrun` shows exactly what will change
3. **Single-role test** — `ansible-playbook -i inventory/hosts site.yml --tags <role>` to test one service

**After deployment:**

```bash
make health  # comprehensive system health check
```

This verifies:
- All Docker containers are running
- Mounts are accessible
- Tailscale is connected
- Backups are on schedule
- Monitoring dashboards are healthy

---

## Critical Constraints

1. **Vault password required** — Every `make install` or `make dryrun` needs `~/.nas-logo-vault-pass` readable. The password is NOT stored in git.

2. **SSD must be mounted** — Playbooks expect `/Volumes/logousb/SSD/NAS-LOGO-VOLUME/` to exist. If missing, `preflight` will fail loudly.

3. **Docker Desktop for Mac only** — Uses `colima` socket paths and macOS-specific networking. Linux Docker won't work.

4. **Apple Silicon requirement** — All Homebrew bottles are ARM64. Intel Macs would need different architecture assumptions.

5. **Idempotency is non-negotiable** — Roles must be safe to re-run. Avoid imperative commands; use Ansible modules with `state: present/absent`.

6. **Immich job queue must be empty before imports** — If import jobs are pending, new scans may fail with 500 errors. Check `make health` before running `make import`.

---

## When to Edit What

| File/Role | When to Edit | Common Changes |
|-----------|-------------|-----------------|
| `site.yml` | Adding/removing a service | Add role, add tags, change order |
| `roles/immich/` | Photo service logic | Version updates, docker-compose env vars, storage paths |
| `roles/sauvegarde/` | Backup strategy | Rotation policy, Hetzner credentials, rclone filters |
| `inventory/group_vars/all.yml` | Non-secret config | Service versions, paths, scheduling, resource limits |
| `inventory/group_vars/vault.yml` | API keys, passwords | Edit with `ansible-vault edit` |
| `Makefile` | Developer convenience | New shortcuts, common commands, help text |
| `bootstrap.sh` | First-time setup | Homebrew recipe, pre-Ansible checks |

---

## Architecture Decisions

**Why Ansible over Terraform/Helm?**
- Simpler for single-host macOS (no Kubernetes overhead)
- Idempotent, human-readable YAML
- Built-in secret management (ansible-vault)
- Native macOS support (Homebrew modules, launchd)

**Why not Docker Swarm/K8s?**
- This is a 1-machine home NAS, not a cluster
- Introduces operational complexity without benefit
- macOS has no native Swarm support

**Why external SSD for working data?**
- Mac Mini's internal SSD (256-512GB) is too small for photo library
- External SSD gives cheap, fast working storage
- HDD backup separate for long-term archival

**Why Hetzner Storage Box?**
- Zero-knowledge encryption (only we have decrypt keys)
- Cheap offsite backup ($4/month)
- SFTP access (works from anywhere)

---

## Troubleshooting

**"Permission denied" during `make install`**
- Ensure vault password file is readable: `chmod 600 ~/.nas-logo-vault-pass`
- Confirm you're running as the `logo` user

**"SSD not mounted" in preflight**
- Manually mount: `diskutil mount /Volumes/logousb/SSD/NAS-LOGO-VOLUME`
- Or check if drive is plugged in and formatted

**Docker container fails to start**
- SSH to NAS: `ssh logo@100.113.214.55 "docker logs <container>"`
- Re-run role: `ansible-playbook -i inventory/hosts site.yml --tags docker,<service>`

**Backup incomplete or stuck**
- Check Hetzner connection: `rclone ls hetzner:/`
- Verify credentials in vault.yml: `ansible-vault view inventory/group_vars/vault.yml`
- Check disk space: `df -h /Volumes/logousb/SSD/NAS-LOGO-VOLUME`

**Tailscale not connecting**
- Verify auth key hasn't expired: `ansible-vault view inventory/group_vars/vault.yml | grep tailscale`
- Check VPN status: `ssh logo@100.113.214.55 "tailscale status"`

---

## Remember

- **Idempotency first** — every role must be safe to re-run
- **Secrets in vault.yml** — never commit plaintext credentials
- **Test with dryrun** — always `make dryrun` before `make install`
- **Health checks after deploy** — `make health` verifies everything works
- **One SSD mount** — entire system depends on `/Volumes/logousb/SSD/NAS-LOGO-VOLUME`
- **Reproducible on fresh hardware** — the Ansible config is the source of truth
