import http.client
import json
import socketserver
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from unittest import mock

BACKEND_SYNC_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_SYNC_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_SYNC_DIR))

from v2.app import build_server, prepare_resource_payload  # noqa: E402
from v2.config import SyncV2Config, load_config  # noqa: E402
from v2.db import SQLiteSyncV2Store  # noqa: E402


class SyncV2ProductionReadyTestCase(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp_dir.name) / "sync_v2_prod_ready.sqlite3"
        self.media_dir = Path(self.temp_dir.name) / "media"
        self.config = SyncV2Config(
            environment="staging",
            host="127.0.0.1",
            port=8788,
            db_path=self.db_path,
            media_dir=self.media_dir,
            auth_secret="test-secret",
            admin_token="test-admin-token",
            allowed_origins=("http://localhost:3000",),
            allow_public_bootstrap=False,
            max_json_bytes=4096,
            max_upload_bytes=1024 * 1024,
            sqlite_busy_timeout_ms=2000,
            login_rate_limit_count=2,
            admin_rate_limit_count=5,
            destructive_rate_limit_count=5,
            upload_rate_limit_count=5,
            rate_limit_window_seconds=60,
            log_level="INFO",
            billing_ios_pro_product_id="com.hydrazur.pro.monthly",
            billing_android_pro_product_id="com.hydrazur.pro.monthly",
            pro_trial_days=7,
            demo_seed_enabled=False,
        )
        self.server = build_server(
            host="127.0.0.1",
            port=0,
            db_path=self.db_path,
            config=self.config,
        )
        self.port = self.server.server_address[1]
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

        store = SQLiteSyncV2Store(self.db_path, media_dir=self.media_dir)
        store.initialize()
        store.create_record(
            "organizations",
            {
                "id": "org_a",
                "organization_id": "org_a",
                "name": "Org A",
            },
        )
        store.create_record(
            "organizations",
            {
                "id": "org_b",
                "organization_id": "org_b",
                "name": "Org B",
            },
        )
        store.create_record(
            "users",
            prepare_resource_payload(
                "users",
                {
                    "id": "admin_a",
                    "organization_id": "org_a",
                    "email": "admin@orga.test",
                    "full_name": "Admin A",
                    "role": "admin",
                    "password": "secret-a",
                },
            ),
        )
        store.create_record(
            "clients",
            {
                "id": "client_b",
                "organization_id": "org_b",
                "display_name": "Piscine B",
            },
        )

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.temp_dir.cleanup()

    def test_healthcheck_exposes_environment_and_storage_status(self):
        status, body, _ = self._request("GET", "/health")
        self.assertEqual(status, 200)
        simple_payload = json.loads(body)
        self.assertEqual(simple_payload["status"], "ok")
        self.assertEqual(simple_payload["environment"], "staging")

        status, body, _ = self._request("GET", "/v2/health")
        self.assertEqual(status, 200)
        payload = json.loads(body)
        self.assertEqual(payload["environment"], "staging")
        self.assertEqual(payload["storage"]["status"], "ok")
        self.assertEqual(payload["storage"]["schemaVersion"], 2)
        self.assertFalse(payload["config"]["allowPublicBootstrap"])

    def test_login_is_rate_limited_after_repeated_failures(self):
        for _ in range(2):
            status, _, _ = self._request(
                "POST",
                "/v2/auth/login",
                headers={"Content-Type": "application/json"},
                body=json.dumps(
                    {
                        "organization_id": "org_a",
                        "email": "admin@orga.test",
                        "password": "wrong-password",
                    }
                ).encode("utf-8"),
            )
            self.assertEqual(status, 401)

        status, body, headers = self._request(
            "POST",
            "/v2/auth/login",
            headers={"Content-Type": "application/json"},
            body=json.dumps(
                {
                    "organization_id": "org_a",
                    "email": "admin@orga.test",
                    "password": "wrong-password",
                }
            ).encode("utf-8"),
        )
        self.assertEqual(status, 429)
        self.assertIn("Retry-After", headers)
        self.assertIn("retryAfterSeconds", json.loads(body))

    def test_cross_org_client_reference_is_rejected(self):
        token = self._login("org_a", "admin@orga.test", "secret-a")
        status, body, _ = self._request(
            "POST",
            "/v2/interventions",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            body=json.dumps(
                {
                    "id": "inter_cross_org",
                    "organization_id": "org_a",
                    "client_id": "client_b",
                    "scheduledAtIso": "2026-04-17T10:00:00Z",
                    "status": "scheduled",
                }
            ).encode("utf-8"),
        )
        self.assertEqual(status, 400)
        self.assertIn("meme organization", json.loads(body)["message"])

    def test_public_bootstrap_can_be_disabled(self):
        status, body, _ = self._request(
            "POST",
            "/v2/organizations",
            headers={"Content-Type": "application/json"},
            body=json.dumps(
                {
                    "id": "org_new",
                    "organization_id": "org_new",
                    "name": "Org New",
                }
            ).encode("utf-8"),
        )
        self.assertEqual(status, 403)
        self.assertIn("desactivee", json.loads(body)["message"])

    def test_load_config_supports_public_staging_env_aliases(self):
        with mock.patch.dict(
            "os.environ",
            {
                "APP_ENV": "staging",
                "PORT": "8123",
                "DATABASE_URL": "sqlite:////tmp/hydrazur-staging.sqlite3",
                "AUTH_SECRET": "staging-auth-secret",
                "ADMIN_SEED_TOKEN": "staging-admin-token",
                "CORS_ALLOWED_ORIGINS": "https://app.hydrazur.test,https://admin.hydrazur.test",
                "DEMO_SEED_ENABLED": "true",
            },
            clear=False,
        ):
            config = load_config()

        self.assertEqual(config.environment, "staging")
        self.assertEqual(config.port, 8123)
        self.assertEqual(
            config.db_path,
            Path("/tmp/hydrazur-staging.sqlite3"),
        )
        self.assertEqual(config.auth_secret, "staging-auth-secret")
        self.assertEqual(config.admin_token, "staging-admin-token")
        self.assertEqual(
            config.allowed_origins,
            ("https://app.hydrazur.test", "https://admin.hydrazur.test"),
        )
        self.assertTrue(config.demo_seed_enabled)

    def _login(self, organization_id: str, email: str, password: str) -> str:
        status, body, _ = self._request(
            "POST",
            "/v2/auth/login",
            headers={"Content-Type": "application/json"},
            body=json.dumps(
                {
                    "organization_id": organization_id,
                    "email": email,
                    "password": password,
                }
            ).encode("utf-8"),
        )
        self.assertEqual(status, 200)
        return json.loads(body)["data"]["token"]

    def _request(self, method, path, *, headers=None, body=b""):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        conn.request(method, path, headers=headers or {}, body=body)
        response = conn.getresponse()
        raw = response.read().decode("utf-8")
        response_headers = {key: value for key, value in response.getheaders()}
        conn.close()
        return response.status, raw, response_headers


if __name__ == "__main__":
    unittest.main()
