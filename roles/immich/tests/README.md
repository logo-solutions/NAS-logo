# Tests BDD pour le rôle Immich

## Setup

Installer les dépendances:
```bash
pip install -r ../../requirements-test.txt
```

## Lancer les tests

### Via Molecule (recommandé)
```bash
# Lancer tous les tests (converge + verify)
cd roles/immich
molecule test --driver-name none

# Ou juste verifier si stack déjà up
molecule verify

# Ou juste converge (apply role)
molecule converge
```

### Via pytest directement
```bash
cd roles/immich/tests
pytest -v

# Ou avec output BDD
pytest -v --gherkin-terminal-reporter
```

## Scénarios testés

1. **Stack Docker démarre** — Vérifie que immich-server, immich-postgres, immich-redis tournent
2. **API Immich répond** — GET `/api/server/ping` → HTTP 200 + `{"res":"pong"}`
3. **Comptes utilisateurs** — Les 8 comptes (loic-perso, loic-immo, loic-pro, alban, ilan, mahaut, alice-perso, alice-prof) existent en BD
4. **Album Famille partagé** — L'album "Famille" existe et est partagé avec alban et ilan
5. **Idempotence** — Relancer le rôle ne redémarre pas les containers

## Architecture

- `features/immich_stack.feature` — Scénarios Gherkin (BDD)
- `steps/test_immich.py` — Step definitions pytest-bdd
- `conftest.py` — Fixtures Testinfra + API client
- `pytest.ini` — Config pytest

## Pré-requis pour les tests

- Colima actif et Docker accessible
- Immich stack déjà déployée (ou `molecule converge` la lance)
- Port 2283 accessible sur localhost
- PostgreSQL accessible via `docker exec`
