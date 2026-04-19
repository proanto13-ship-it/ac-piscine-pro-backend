import http.client
import json
import sys
import tempfile
import threading
import unittest
from pathlib import Path

BACKEND_SYNC_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_SYNC_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_SYNC_DIR))

from v2.app import build_server  # noqa: E402
from v2.config import SyncV2Config  # noqa: E402
from v2_seed_demo import seed_demo_dataset  # noqa: E402


class RenderStagingV2TestCase(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp_dir.name) / "render_staging.sqlite3"
        self.media_dir = Path(self.temp_dir.name) / "media"
        self.config = SyncV2Config(
            environment="staging",
            host="127.0.0.1",
            port=8000,
            db_path=self.db_path,
            media_dir=self.media_dir,
            auth_secret="render-staging-secret",
            admin_token="render-admin-token",
            allowed_origins=("https://ac-piscine-pro-backend.onrender.com",),
            allow_public_bootstrap=False,
            max_json_bytes=4096,
            max_upload_bytes=1024 * 1024,
            sqlite_busy_timeout_ms=2000,
            login_rate_limit_count=10,
            admin_rate_limit_count=10,
            destructive_rate_limit_count=10,
            upload_rate_limit_count=10,
            rate_limit_window_seconds=60,
            log_level="INFO",
            billing_ios_pro_product_id="com.hydrazur.pro.monthly",
            billing_android_pro_product_id="com.hydrazur.pro.monthly",
            pro_trial_days=0,
            demo_seed_enabled=True,
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
        seed_demo_dataset(self.server.RequestHandlerClass.store)

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.temp_dir.cleanup()

    def test_render_staging_health_and_demo_logins(self):
        status, body = self._request("GET", "/health")
        self.assertEqual(status, 200)
        payload = json.loads(body)
        self.assertEqual(payload["service"], "hydr-azur-sync-v2")

        demo_pro_token = self._login("demo-pro@hydrazur.test", "demo1234")
        demo_free_token = self._login("demo-free@hydrazur.test", "demo1234")
        self.assertTrue(demo_pro_token)
        self.assertTrue(demo_free_token)

        me_status, me_body = self._request(
            "GET",
            "/v2/auth/me",
            headers={"Authorization": f"Bearer {demo_pro_token}"},
        )
        self.assertEqual(me_status, 200)
        me_payload = json.loads(me_body)["data"]
        self.assertEqual(me_payload["subscription"]["planId"], "pro")
        flags = {
            item["flag"]: item["enabled"] for item in me_payload["entitlements"]
        }
        self.assertTrue(flags["pdfExport"])
        self.assertTrue(flags["cloudSync"])
        self.assertTrue(flags["teamMembers"])
        self.assertTrue(flags["unlimitedClients"])

    def _login(self, email: str, password: str) -> str:
        status, body = self._request(
            "POST",
            "/v2/auth/login",
            headers={"Content-Type": "application/json"},
            body=json.dumps(
                {
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
        conn.close()
        return response.status, raw


if __name__ == "__main__":
    unittest.main()
