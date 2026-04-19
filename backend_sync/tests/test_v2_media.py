import http.client
import json
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from typing import Optional

BACKEND_SYNC_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_SYNC_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_SYNC_DIR))

from v2.app import build_server, prepare_resource_payload  # noqa: E402


class SyncV2MediaTestCase(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp_dir.name) / "sync_v2_media.sqlite3"
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
            "organizations",
            {
                "id": "org_b",
                "organization_id": "org_b",
                "name": "Org B",
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
            "users",
            prepare_resource_payload(
                "users",
                {
                    "id": "user_b",
                    "organization_id": "org_b",
                    "email": "b@example.test",
                    "full_name": "User B",
                    "role": "admin",
                    "password": "secret-b",
                },
            ),
        )

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.temp_dir.cleanup()

    def test_media_upload_list_download_are_scoped_by_organization(self):
        token_a = self._login("org_a", "a@example.test", "secret-a")
        token_b = self._login("org_b", "b@example.test", "secret-b")

        upload_status, upload_body, _ = self._request(
            "POST",
            "/v2/media/upload",
            body=b"jpeg-bytes",
            headers={
                "Authorization": f"Bearer {token_a}",
                "Content-Type": "image/jpeg",
                "X-Attachment-Id": "media_1",
                "X-Client-Id": "client_a",
                "X-Intervention-Id": "intervention_a",
                "X-File-Name": "photo-a.jpg",
                "X-Mime-Type": "image/jpeg",
                "X-Created-At-Iso": "2026-04-17T10:00:00Z",
            },
        )
        self.assertEqual(upload_status, 201)
        uploaded_media = json.loads(upload_body)["data"]
        self.assertEqual(uploaded_media["organization_id"], "org_a")
        self.assertEqual(uploaded_media["downloadPath"], "/v2/media/media_1/download")

        list_a_status, list_a_body, _ = self._request(
            "GET",
            "/v2/media",
            headers={"Authorization": f"Bearer {token_a}"},
        )
        self.assertEqual(list_a_status, 200)
        list_a_payload = json.loads(list_a_body)
        self.assertEqual(list_a_payload["count"], 1)
        self.assertEqual(list_a_payload["data"][0]["id"], "media_1")

        list_b_status, list_b_body, _ = self._request(
            "GET",
            "/v2/media",
            headers={"Authorization": f"Bearer {token_b}"},
        )
        self.assertEqual(list_b_status, 200)
        list_b_payload = json.loads(list_b_body)
        self.assertEqual(list_b_payload["count"], 0)

        download_status, download_body, download_headers = self._request(
            "GET",
            "/v2/media/media_1/download",
            headers={"Authorization": f"Bearer {token_a}"},
            expect_binary=True,
        )
        self.assertEqual(download_status, 200)
        self.assertEqual(download_body, b"jpeg-bytes")
        self.assertEqual(
            download_headers.get("Content-Type"),
            "image/jpeg",
        )

        forbidden_status, forbidden_body, _ = self._request(
            "GET",
            "/v2/media/media_1/download",
            headers={"Authorization": f"Bearer {token_b}"},
        )
        self.assertEqual(forbidden_status, 403)
        self.assertIn("cross-organization", forbidden_body)

    def _login(self, organization_id: str, email: str, password: str) -> str:
        status, body, _ = self._request(
            "POST",
            "/v2/auth/login",
            body=json.dumps(
                {
                    "organization_id": organization_id,
                    "email": email,
                    "password": password,
                }
            ).encode("utf-8"),
            headers={"Content-Type": "application/json"},
        )
        self.assertEqual(status, 200)
        return json.loads(body)["data"]["token"]

    def _request(
        self,
        method: str,
        path: str,
        *,
        body: bytes = b"",
        headers: Optional[dict[str, str]] = None,
        expect_binary: bool = False,
    ):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        conn.request(method, path, body=body, headers=headers or {})
        response = conn.getresponse()
        response_body = response.read()
        response_headers = {key: value for key, value in response.getheaders()}
        conn.close()
        if expect_binary:
            return response.status, response_body, response_headers
        return response.status, response_body.decode("utf-8"), response_headers


if __name__ == "__main__":
    unittest.main()
