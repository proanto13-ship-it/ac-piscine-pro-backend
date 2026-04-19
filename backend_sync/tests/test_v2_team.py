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


class SyncV2TeamTestCase(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp_dir.name) / "sync_v2_team.sqlite3"
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
                    "id": "admin_a",
                    "organization_id": "org_a",
                    "email": "admin@orga.test",
                    "full_name": "Admin A",
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
                    "id": "tech_a",
                    "organization_id": "org_a",
                    "email": "tech@orga.test",
                    "full_name": "Tech A",
                    "role": "technician",
                    "password": "secret-tech",
                },
            ),
        )
        self.store.create_record(
            "users",
            prepare_resource_payload(
                "users",
                {
                    "id": "admin_b",
                    "organization_id": "org_b",
                    "email": "admin@orgb.test",
                    "full_name": "Admin B",
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

    def test_admin_can_invite_and_list_team(self):
        token = self._login("org_a", "admin@orga.test", "secret-a")

        invite_status, invite_body = self._request(
            "POST",
            "/v2/team/invitations",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            body=json.dumps(
                {
                    "email": "manager@orga.test",
                    "fullName": "Manager A",
                    "role": "manager",
                }
            ).encode("utf-8"),
        )
        self.assertEqual(invite_status, 201)
        invitation = json.loads(invite_body)["data"]
        self.assertEqual(invitation["status"], "pending")
        self.assertEqual(invitation["role"], "manager")

        members_status, members_body = self._request(
            "GET",
            "/v2/team/members",
            headers={"Authorization": f"Bearer {token}"},
        )
        self.assertEqual(members_status, 200)
        members = json.loads(members_body)["data"]
        self.assertEqual({item["email"] for item in members}, {"admin@orga.test", "tech@orga.test"})

        invitations_status, invitations_body = self._request(
            "GET",
            "/v2/team/invitations",
            headers={"Authorization": f"Bearer {token}"},
        )
        self.assertEqual(invitations_status, 200)
        invitations = json.loads(invitations_body)["data"]
        self.assertEqual(len(invitations), 1)
        self.assertEqual(invitations[0]["email"], "manager@orga.test")

    def test_technician_cannot_manage_team_but_can_view_members(self):
        token = self._login("org_a", "tech@orga.test", "secret-tech")

        members_status, _ = self._request(
            "GET",
            "/v2/team/members",
            headers={"Authorization": f"Bearer {token}"},
        )
        self.assertEqual(members_status, 200)

        invitations_status, _ = self._request(
            "GET",
            "/v2/team/invitations",
            headers={"Authorization": f"Bearer {token}"},
        )
        self.assertEqual(invitations_status, 403)

        invite_status, _ = self._request(
            "POST",
            "/v2/team/invitations",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            body=json.dumps(
                {
                    "email": "new@orga.test",
                    "role": "technician",
                }
            ).encode("utf-8"),
        )
        self.assertEqual(invite_status, 403)

        users_status, _ = self._request(
            "GET",
            "/v2/users",
            headers={"Authorization": f"Bearer {token}"},
        )
        self.assertEqual(users_status, 403)

    def test_team_members_are_scoped_to_current_organization(self):
        token = self._login("org_a", "admin@orga.test", "secret-a")

        members_status, members_body = self._request(
            "GET",
            "/v2/team/members",
            headers={"Authorization": f"Bearer {token}"},
        )
        self.assertEqual(members_status, 200)
        members = json.loads(members_body)["data"]
        self.assertNotIn("admin@orgb.test", {item["email"] for item in members})

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
