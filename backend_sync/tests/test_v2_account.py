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

from v2.app import build_server, prepare_resource_payload  # noqa: E402


class SyncV2AccountTestCase(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp_dir.name) / "sync_v2_account.sqlite3"
        self.server = build_server(host="127.0.0.1", port=0, db_path=self.db_path)
        self.port = self.server.server_address[1]
        self.thread = threading.Thread(
            target=self.server.serve_forever,
            daemon=True,
        )
        self.thread.start()
        self.store = self.server.RequestHandlerClass.store

        self.store.create_record(
            "organizations",
            {
                "id": "org_a",
                "organization_id": "org_a",
                "name": "Org A",
            },
        )
        self.store.create_record(
            "users",
            prepare_resource_payload(
                "users",
                {
                    "id": "user_a",
                    "organization_id": "org_a",
                    "email": "a@example.test",
                    "full_name": "User A",
                    "role": "admin",
                    "password": "secret-a",
                },
            ),
        )
        self.store.create_record(
            "clients",
            {
                "id": "client_a",
                "organization_id": "org_a",
                "display_name": "Piscine A",
            },
        )

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.temp_dir.cleanup()

    def test_account_export_returns_scoped_data(self):
        token = self._login("org_a", "a@example.test", "secret-a")

        status, body = self._request(
          "GET",
          "/v2/account/export",
          headers={"Authorization": f"Bearer {token}"},
        )

        self.assertEqual(status, 200)
        payload = json.loads(body)["data"]
        self.assertEqual(payload["user"]["id"], "user_a")
        self.assertEqual(payload["organization"]["organization_id"], "org_a")
        self.assertEqual(len(payload["clients"]), 1)
        self.assertNotIn("password_hash", payload["user"])

    def test_delete_account_removes_org_when_last_user(self):
        token = self._login("org_a", "a@example.test", "secret-a")

        status, body = self._request(
          "DELETE",
          "/v2/account/me",
          headers={"Authorization": f"Bearer {token}"},
        )

        self.assertEqual(status, 200)
        payload = json.loads(body)["data"]
        self.assertTrue(payload["organizationDeleted"])
        self.assertEqual(self.store.list_records("clients", "org_a"), [])
        with self.assertRaises(LookupError):
            self.store.get_record("organizations", "org_a")

    def _login(self, organization_id: str, email: str, password: str) -> str:
        status, body = self._request(
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
        conn.close()
        return response.status, raw


if __name__ == "__main__":
    unittest.main()
