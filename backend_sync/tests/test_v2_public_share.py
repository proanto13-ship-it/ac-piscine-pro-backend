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


class SyncV2PublicShareTestCase(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp_dir.name) / "sync_v2_public_share.sqlite3"
        self.server = build_server(host="127.0.0.1", port=0, db_path=self.db_path)
        self.port = self.server.server_address[1]
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.store = self.server.RequestHandlerClass.store

        self.store.create_record(
            "organizations",
            {
                "id": "org_a",
                "organization_id": "org_a",
                "name": "HydrAzur Demo",
            },
        )
        self.store.create_record(
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

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.temp_dir.cleanup()

    def test_can_create_public_share_link_for_intervention_and_read_html(self):
        token = self._login()
        attachment = self.store.upsert_media_attachment(
          {
              "id": "media_1",
              "organization_id": "org_a",
              "intervention_id": "inter_1",
              "originalFileName": "photo.jpg",
              "mimeType": "image/jpeg",
          },
          b"fake-image-bytes",
        )
        self.store.create_record(
            "interventions",
            {
                "id": "inter_1",
                "organization_id": "org_a",
                "dateLabel": "17/04/2026",
                "technicianName": "Tech Demo",
                "clientRepresentative": "Mme Martin",
                "poolSummary": "Piscine 40 m3",
                "interventionSummary": "Controle complet et ajustement.",
                "recommendations": "Verification dans 7 jours.",
                "accessNotes": "Acces local technique.",
                "followUpLabel": "Suivi sous 7 jours",
                "estimateLabel": "120 EUR",
                "estimateApproved": True,
                "interventionCompleted": True,
                "followUpRequired": True,
                "attachments": [
                    {
                        "id": attachment["id"],
                        "remoteUrl": attachment["remoteUrl"],
                        "mimeType": attachment["mimeType"],
                        "localPath": "",
                        "uploadStatus": "uploaded",
                        "createdAtIso": attachment["createdAtIso"],
                    }
                ],
            },
        )

        status, body = self._request(
            "POST",
            "/v2/public-links",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            body=json.dumps(
                {
                    "resource_type": "intervention",
                    "resource_id": "inter_1",
                }
            ).encode("utf-8"),
        )
        self.assertEqual(status, 201)
        payload = json.loads(body)["data"]
        public_url = payload["publicUrl"]
        public_path = "/" + public_url.split("/", 3)[3]

        share_status, share_body, content_type = self._request(
            "GET",
            public_path,
            with_content_type=True,
        )
        self.assertEqual(share_status, 200)
        self.assertIn("text/html", content_type)
        self.assertIn("Controle complet et ajustement.", share_body)
        self.assertIn("Lecture seule", share_body)

        media_status, media_body, media_content_type = self._request(
            "GET",
            f"{public_path}/media/media_1",
            with_content_type=True,
            decode=False,
        )
        self.assertEqual(media_status, 200)
        self.assertEqual(media_body, b"fake-image-bytes")
        self.assertEqual(media_content_type, "image/jpeg")

    def test_expired_public_share_link_is_rejected(self):
        token = self._login()
        self.store.create_record(
            "financial_documents",
            {
                "id": "doc_1",
                "organization_id": "org_a",
                "documentNumber": "FAC-001",
                "title": "Facture entretien",
                "type": "invoice",
                "status": "sent",
                "items": [
                    {"label": "Entretien", "quantity": 1, "unitPrice": 120},
                ],
                "taxLabel": "TVA",
                "vatRate": 20,
            },
        )

        status, body = self._request(
            "POST",
            "/v2/public-links",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            body=json.dumps(
                {
                    "resource_type": "financial_document",
                    "resource_id": "doc_1",
                    "expires_at_iso": "2020-01-01T00:00:00Z",
                }
            ).encode("utf-8"),
        )
        self.assertEqual(status, 201)
        payload = json.loads(body)["data"]
        public_path = "/" + payload["publicUrl"].split("/", 3)[3]

        share_status, share_body = self._request("GET", public_path)
        self.assertEqual(share_status, 410)
        self.assertIn("expire", share_body.lower())

    def _login(self) -> str:
        status, body = self._request(
            "POST",
            "/v2/auth/login",
            headers={"Content-Type": "application/json"},
            body=json.dumps(
                {
                    "organization_id": "org_a",
                    "email": "admin@orga.test",
                    "password": "secret-a",
                }
            ).encode("utf-8"),
        )
        self.assertEqual(status, 200)
        return json.loads(body)["data"]["token"]

    def _request(self, method, path, *, headers=None, body=b"", with_content_type=False, decode=True):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        conn.request(method, path, headers=headers or {}, body=body)
        response = conn.getresponse()
        raw = response.read()
        content_type = response.getheader("Content-Type", "")
        conn.close()
        body_value = raw.decode("utf-8") if decode else raw
        if with_content_type:
            return response.status, body_value, content_type
        return response.status, body_value


if __name__ == "__main__":
    unittest.main()
