# NAS-logo — URLs & Accès

IP Tailscale : `100.113.214.55`

## Services

| Service | URL | Identifiants |
|---|---|---|
| Immich (photos) | http://100.113.214.55:2283 | loicgourmelon@gmail.com / `NasLogo2026!` |
| Paperless (docs) | http://100.113.214.55:8010 | admin / voir vault |
| n8n (automation) | http://100.113.214.55:5679 | loicgourmelon@gmail.com |
| Grafana (monitoring) | http://100.113.214.55:3000 | admin / voir vault |
| Prometheus | http://100.113.214.55:9090 | — |
| cAdvisor | http://100.113.214.55:8080 | — |
| Alertmanager | http://100.113.214.55:9093 | — |
| ntfy (alertes) | http://100.113.214.55:8090 | topic : nas-logo |
| Meilisearch UI | http://100.113.214.55:7701 | — |
| Meilisearch API | http://100.113.214.55:7700 | clé : voir vault |
| Whisper API | http://100.113.214.55:8020 | — |

## Accès SSH

```
ssh logo@100.113.214.55
```

## SMB (partage fichiers)

```
smb://100.113.214.55/NAS-logo
```

Comptes : alban / ilan / alice (mots de passe dans vault.yml)

## Sauvegarde Hetzner

```
sftp://u575742@88.99.49.100
```
