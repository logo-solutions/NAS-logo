import pytest
from pytest_bdd import given, when, then, scenarios
import subprocess
import json

# Load all scenarios from feature file
scenarios("../features/immich_stack.feature")


# ============================================================================
# GIVEN steps
# ============================================================================

@given("Colima est actif")
def check_colima_active(host):
    """Verify Colima is running."""
    result = host.run("colima status")
    assert result.rc == 0
    assert "running" in result.stdout.lower()


@given("la stack Immich est démarrée")
def ensure_immich_running(host, immich_api_client):
    """Ensure Immich stack is up and responding."""
    assert immich_api_client.is_ready(), "Immich API did not respond in time"


@given("le rôle Immich a déjà été appliqué")
def immich_applied_once(host, immich_api_client):
    """Verify Immich role was already applied (API responsive)."""
    assert immich_api_client.is_ready(), "Immich not running from previous apply"


# ============================================================================
# WHEN steps
# ============================================================================

@when("le rôle Immich est appliqué")
def apply_immich_role(host):
    """Apply the Immich role via ansible-playbook."""
    result = host.run(
        "ansible-playbook -i localhost, roles/immich/molecule/default/converge.yml"
    )
    # Store result for idempotence check
    pytest.immich_apply_result = result


@when("le rôle Immich est appliqué à nouveau")
def apply_immich_role_again(host, immich_api_client):
    """Apply Immich role second time for idempotence test."""
    # Get container IDs before re-apply
    containers_before = host.run("docker ps --filter 'name=immich' -q").stdout.strip().split()

    result = host.run(
        "ansible-playbook -i localhost, roles/immich/molecule/default/converge.yml"
    )
    pytest.immich_reapply_result = result
    pytest.containers_before = containers_before


@when("je curl GET /api/server/ping")
def curl_ping_endpoint(immich_api_client):
    """Make HTTP GET request to /api/server/ping."""
    pytest.ping_response = immich_api_client.ping()


# ============================================================================
# THEN steps
# ============================================================================

@then('le container "immich-server" est running')
def check_server_container(host):
    """Verify immich-server container is running."""
    result = host.run("docker ps --filter 'name=immich-server' --filter 'status=running'")
    assert result.rc == 0
    assert "immich-server" in result.stdout


@then('le container "immich-postgres" est running')
def check_postgres_container(host):
    """Verify immich-postgres container is running."""
    result = host.run("docker ps --filter 'name=immich-postgres' --filter 'status=running'")
    assert result.rc == 0
    assert "immich-postgres" in result.stdout


@then('le container "immich-redis" est running')
def check_redis_container(host):
    """Verify immich-redis container is running."""
    result = host.run("docker ps --filter 'name=immich-redis' --filter 'status=running'")
    assert result.rc == 0
    assert "immich-redis" in result.stdout


@then("le code HTTP est 200")
def check_http_200():
    """Verify HTTP response code is 200."""
    assert pytest.ping_response.status_code == 200, \
        f"Expected HTTP 200, got {pytest.ping_response.status_code}"


@then('la réponse contient "pong"')
def check_pong_response():
    """Verify API response contains 'pong'."""
    data = pytest.ping_response.json()
    assert data.get("res") == "pong", f"Expected pong, got {data}"


@then('les 8 comptes existent: loic-perso, loic-immo, loic-pro, alban, ilan, mahaut, alice-perso, alice-prof')
def check_user_accounts(host, immich_api_client):
    """Verify all 8 user accounts exist in Immich database."""
    expected_users = [
        "loic-perso", "loic-immo", "loic-pro", "alban", "ilan",
        "mahaut", "alice-perso", "alice-prof"
    ]

    # Query Immich database directly (more reliable than API without auth)
    result = host.run(
        "docker exec immich-postgres psql -U postgres -d immich -t -c "
        "'SELECT login FROM users ORDER BY login;'"
    )
    assert result.rc == 0

    actual_users = [u.strip() for u in result.stdout.strip().split('\n') if u.strip()]

    for expected in expected_users:
        assert expected in actual_users, \
            f"User {expected} not found. Found: {actual_users}"


@then('l\'album "Famille" existe')
def check_famille_album(host):
    """Verify Famille album exists in database."""
    result = host.run(
        "docker exec immich-postgres psql -U postgres -d immich -t -c "
        "'SELECT name FROM albums WHERE name = \\'Famille\\';'"
    )
    assert result.rc == 0
    assert "Famille" in result.stdout, \
        f"Album 'Famille' not found. Output: {result.stdout}"


@then('l\'album "Famille" est partagé avec alban et ilan')
def check_album_shared(host):
    """Verify Famille album is shared with alban and ilan."""
    # Query album shares
    result = host.run(
        "docker exec immich-postgres psql -U postgres -d immich -t -c "
        "'SELECT u.login FROM album_users au "
        "JOIN users u ON au.user_id = u.id "
        "WHERE au.album_id = (SELECT id FROM albums WHERE name = \\'Famille\\') "
        "ORDER BY u.login;'"
    )
    assert result.rc == 0

    shared_with = [u.strip() for u in result.stdout.strip().split('\n') if u.strip()]

    assert "alban" in shared_with, f"Alban not in album shares: {shared_with}"
    assert "ilan" in shared_with, f"Ilan not in album shares: {shared_with}"


@then("aucun container n'est redémarré")
def check_no_restart_on_idempotence(host):
    """Verify containers were not restarted (same IDs) on second apply."""
    containers_after = host.run("docker ps --filter 'name=immich' -q").stdout.strip().split()

    # Container IDs should be the same if not restarted
    assert set(pytest.containers_before) == set(containers_after), \
        f"Containers changed. Before: {pytest.containers_before}, After: {containers_after}"


@then("l'API répond toujours")
def check_api_still_responds(immich_api_client):
    """Verify Immich API still responds after re-apply."""
    assert immich_api_client.is_ready(max_retries=10, delay=1), \
        "Immich API not responding after re-apply"
