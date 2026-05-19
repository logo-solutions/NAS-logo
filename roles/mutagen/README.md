# Rôle Mutagen

Synchronisation performante et bidirectionnelle entre macOS et la VM Colima via Mutagen.

## Problème

- **VirtioFS** : CPU/RAM très lourd, ralentit le Mac
- **NFS** : Bloqué par restrictions sandbox macOS Sequoia
- **SSHFS** : Plus simple mais moins performant que Mutagen

## Solution : Mutagen

File synchronization ultra-rapide :
- Sync bidirectionnelle en temps réel
- Basée sur des checksums, pas copie complète
- Performance proche de native (~70-90%)
- Compatible Colima et Docker Compose

## Architecture

```
macOS
  /Volumes/NAS-LOGO-DATA
          ↓
    Mutagen daemon
          ↓
    Docker volume
          ↓
Colima VM
  /mnt/photos ← Immich/Paperless lisent ici
```

## Variables

| Variable | Défaut | Description |
|----------|--------|-------------|
| `use_mutagen` | `true` | Activer Mutagen |
| `mutagen_mount_path` | `/mnt/photos` | Point de montage dans Colima |
| `mutagen_session_name` | `nas-photos` | Nom de la session |
| `mutagen_ignore_patterns` | `.DS_Store, .git, ...` | Fichiers ignorés lors de la sync |

## Utilisation

### Installer

```bash
make install --tags mutagen
```

### Vérifier l'état

```bash
mutagen list
mutagen status nas-photos
mutagen monitor nas-photos  # Affichage live
```

### Arrêter/Redémarrer

```bash
mutagen terminate nas-photos
mutagen daemon run  # Relancer après
```

### Logs

```bash
tail -f /var/log/mutagen.log
tail -f /var/log/mutagen-error.log
```

## Dépendances

- Homebrew (pour installer Mutagen)
- Docker/Colima en cours d'exécution
- SSH accès à Colima (automatique)

## Notes de Performance

| Opération | Performance | Notes |
|-----------|-------------|-------|
| Lecture | 70-90% native | Excellent |
| Écriture | 70-90% native | Excellent |
| Latence sync | <100ms | Temps réel |
| CPU overhead | ~5% | Très faible |
| RAM overhead | ~30MB | Négligeable |

Comparé à VirtioFS qui peut utiliser 50%+ CPU et 500MB+ RAM sur gros volumes.

## Troubleshooting

### Sync bloquée

```bash
mutagen terminate nas-photos
mutagen create --name nas-photos --sync-mode two-way-resolved /Volumes/NAS-LOGO-DATA docker://colima/nas-photos
```

### Fichiers pas synchronisés

Vérifier que le fichier n'est pas dans `mutagen_ignore_patterns` :

```bash
grep ignore roles/mutagen/defaults/main.yml
```

### Mutagen ne redémarre pas au boot

Vérifier LaunchAgent :

```bash
launchctl list | grep mutagen
cat ~/Library/LaunchAgents/com.nas-logo.mutagen.plist
```

## Voir aussi

- [Mutagen Documentation](https://mutagen.io/)
- [macOS Sequoia NFS Restrictions](#)
- [Comparaison VirtioFS vs SSHFS vs Mutagen](#)
