import pytest
import requests
import time
from testinfra.utils.ansible_runner import AnsibleRunner


@pytest.fixture(scope="session")
def host():
    """Testinfra host fixture for local system."""
    runner = AnsibleRunner(inventory="localhost,")
    return runner.get_host("localhost")


@pytest.fixture(scope="session")
def immich_api_client():
    """HTTP client for Immich API."""
    class ImmichClient:
        def __init__(self, base_url="http://localhost:2283", timeout=5):
            self.base_url = base_url
            self.timeout = timeout
            self.session = requests.Session()

        def get(self, endpoint, **kwargs):
            url = f"{self.base_url}{endpoint}"
            return self.session.get(url, timeout=self.timeout, **kwargs)

        def post(self, endpoint, **kwargs):
            url = f"{self.base_url}{endpoint}"
            return self.session.post(url, timeout=self.timeout, **kwargs)

        def ping(self):
            """Health check endpoint."""
            return self.get("/api/server/ping")

        def get_users(self):
            """Get all users (requires auth token in practice)."""
            return self.get("/api/admin/users")

        def get_albums(self):
            """Get all albums (requires auth token)."""
            return self.get("/api/albums")

        def is_ready(self, max_retries=30, delay=2):
            """Wait until API is ready."""
            for attempt in range(max_retries):
                try:
                    resp = self.ping()
                    if resp.status_code == 200 and resp.json().get("res") == "pong":
                        return True
                except Exception:
                    pass
                time.sleep(delay)
            return False

    return ImmichClient()


@pytest.fixture(scope="session", autouse=True)
def wait_for_immich(immich_api_client):
    """Auto-wait for Immich API to be ready at session start."""
    if not immich_api_client.is_ready():
        pytest.skip("Immich API not responding after timeout")
