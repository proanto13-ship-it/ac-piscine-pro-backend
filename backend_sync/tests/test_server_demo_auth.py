import http.client
import json
import sys
import threading
import unittest
from pathlib import Path

BACKEND_SYNC_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_SYNC_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_SYNC_DIR))

from server import SyncHandler, ThreadingHTTPServer  # noqa: E402


class LegacyServerDemoAuthTestCase(unittest.TestCase):
    def setUp(self):
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), SyncHandler)
        self.port = self.server.server_address[1]
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def test_health_exposes_v2_auth_support(self):
        status, body = self._request("GET", "/health")
        self.assertEqual(status, 200)
        payload = json.loads(body)
        self.assertEqual(payload["service"], "hydr-azur-sync")
        self.assertTrue(payload["v2Auth"])

    def test_demo_pro_login_and_me_and_billing(self):
        status, body = self._request(
            "POST",
            "/v2/auth/login",
            headers={"Content-Type": "application/json"},
            body=json.dumps(
                {
                    "email": "demo-pro@hydrazur.test",
                    "password": "demo1234",
                }
            ).encode("utf-8"),
        )
        self.assertEqual(status, 200)
        token = json.loads(body)["data"]["token"]

        me_status, me_body = self._request(
            "GET",
            "/v2/auth/me",
            headers={"Authorization": f"Bearer {token}"},
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

        billing_status, billing_body = self._request(
            "GET",
            "/v2/billing/entitlements",
            headers={"Authorization": f"Bearer {token}"},
        )
        self.assertEqual(billing_status, 200)
        billing_payload = json.loads(billing_body)["data"]
        self.assertEqual(billing_payload["subscription"]["planId"], "pro")

    def test_demo_free_login_works(self):
        status, body = self._request(
            "POST",
            "/v2/auth/login",
            headers={"Content-Type": "application/json"},
            body=json.dumps(
                {
                    "email": "demo-free@hydrazur.test",
                    "password": "demo1234",
                }
            ).encode("utf-8"),
        )
        self.assertEqual(status, 200)
        token = json.loads(body)["data"]["token"]
        self.assertTrue(token)

    def _request(self, method, path, *, headers=None, body=b""):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        conn.request(method, path, headers=headers or {}, body=body)
        response = conn.getresponse()
        raw = response.read().decode("utf-8")
        conn.close()
        return response.status, raw


if __name__ == "__main__":
    unittest.main()
