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
        self.assertTrue(payload["syncV2"])

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

    def test_demo_pro_sync_resources_and_media(self):
        token = self._login("demo-pro@hydrazur.test", "demo1234")

        client_payload = {
            "id": "client-demo-1",
            "name": "Client Démo",
            "phone": "0600000000",
            "email": "client@example.test",
            "address": "1 avenue de la Mer",
            "volume": 45,
            "treatment": "chlore",
            "bassinType": "Piscine",
            "revetement": "Liner",
            "filtration": "Sable",
            "equipements": "",
            "visitFrequencyDays": 14,
            "createdAtIso": "2026-04-19T08:00:00Z",
            "updatedAtIso": "2026-04-19T08:00:00Z",
            "version": 1,
            "deletedAtIso": "",
            "notes": "",
            "analyses": [],
        }
        status, body = self._request(
            "PUT",
            "/v2/clients/client-demo-1",
            headers=self._json_headers(token),
            body=json.dumps(client_payload).encode("utf-8"),
        )
        self.assertEqual(status, 200, body)

        intervention_payload = {
            "id": "intervention-demo-1",
            "client_id": "client-demo-1",
            "clientId": "client-demo-1",
            "clientName": "Client Démo",
            "title": "Intervention test",
            "createdAtIso": "2026-04-19T09:00:00Z",
            "updatedAtIso": "2026-04-19T09:00:00Z",
            "version": 1,
            "deletedAtIso": "",
            "attachments": [],
        }
        status, body = self._request(
            "PUT",
            "/v2/interventions/intervention-demo-1",
            headers=self._json_headers(token),
            body=json.dumps(intervention_payload).encode("utf-8"),
        )
        self.assertEqual(status, 200, body)

        document_payload = {
            "id": "document-demo-1",
            "client_id": "client-demo-1",
            "clientId": "client-demo-1",
            "clientName": "Client Démo",
            "documentNumber": "DEV-001",
            "createdAtIso": "2026-04-19T10:00:00Z",
            "updatedAtIso": "2026-04-19T10:00:00Z",
            "version": 1,
            "deletedAtIso": "",
        }
        status, body = self._request(
            "PUT",
            "/v2/financial-documents/document-demo-1",
            headers=self._json_headers(token),
            body=json.dumps(document_payload).encode("utf-8"),
        )
        self.assertEqual(status, 200, body)

        upload_headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "image/jpeg",
            "X-Attachment-Id": "attachment-demo-1",
            "X-Client-Id": "client-demo-1",
            "X-Intervention-Id": "intervention-demo-1",
            "X-File-Name": "photo-demo.jpg",
            "X-Mime-Type": "image/jpeg",
            "X-Created-At-Iso": "2026-04-19T10:15:00Z",
        }
        status, body = self._request(
            "POST",
            "/v2/media/upload",
            headers=upload_headers,
            body=b"demo-image-bytes",
        )
        self.assertEqual(status, 200, body)
        media_payload = json.loads(body)["data"]
        self.assertEqual(media_payload["id"], "attachment-demo-1")

        status, body = self._request(
            "GET",
            "/v2/clients?updated_after=2026-04-19T07:59:00Z",
            headers={"Authorization": f"Bearer {token}"},
        )
        self.assertEqual(status, 200, body)
        clients = json.loads(body)["data"]
        self.assertEqual(len(clients), 1)

        status, body = self._request(
            "GET",
            "/v2/interventions",
            headers={"Authorization": f"Bearer {token}"},
        )
        self.assertEqual(status, 200, body)
        interventions = json.loads(body)["data"]
        self.assertEqual(len(interventions), 1)

        status, body = self._request(
            "GET",
            "/v2/financial-documents",
            headers={"Authorization": f"Bearer {token}"},
        )
        self.assertEqual(status, 200, body)
        documents = json.loads(body)["data"]
        self.assertEqual(len(documents), 1)

        status, body = self._request(
            "GET",
            "/v2/media",
            headers={"Authorization": f"Bearer {token}"},
        )
        self.assertEqual(status, 200, body)
        media = json.loads(body)["data"]
        self.assertEqual(len(media), 1)
        self.assertEqual(media[0]["client_id"], "client-demo-1")

        status, body = self._request(
            "GET",
            "/v2/sync",
            headers={"Authorization": f"Bearer {token}"},
        )
        self.assertEqual(status, 200, body)
        sync_payload = json.loads(body)["payload"]
        self.assertEqual(len(sync_payload["clients"]), 1)
        self.assertEqual(
            sync_payload["clients"][0]["interventions"][0]["id"],
            "intervention-demo-1",
        )

    def _login(self, email, password):
        status, body = self._request(
            "POST",
            "/v2/auth/login",
            headers={"Content-Type": "application/json"},
            body=json.dumps({"email": email, "password": password}).encode("utf-8"),
        )
        self.assertEqual(status, 200, body)
        return json.loads(body)["data"]["token"]

    def _json_headers(self, token):
        return {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }

    def _request(self, method, path, *, headers=None, body=b""):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        conn.request(method, path, headers=headers or {}, body=body)
        response = conn.getresponse()
        raw = response.read().decode("utf-8")
        conn.close()
        return response.status, raw


if __name__ == "__main__":
    unittest.main()
