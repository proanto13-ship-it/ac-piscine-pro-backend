import sys
import tempfile
import unittest
from pathlib import Path

BACKEND_SYNC_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_SYNC_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_SYNC_DIR))

from v2.app import (  # noqa: E402
    assert_same_organization,
    authenticate_user,
    prepare_resource_payload,
    public_user,
    resolve_auth_context,
    scoped_organization_id,
)
from v2.db import SQLiteSyncV2Store  # noqa: E402


class SyncV2AuthTestCase(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp_dir.name) / "sync_v2_test.sqlite3"
        self.store = SQLiteSyncV2Store(self.db_path)
        self.store.initialize()

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_auth_and_organization_isolation(self):
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

        user_a = self.store.create_record(
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

        token_a, logged_user_a = authenticate_user(
            self.store,
            organization_id="org_a",
            email="a@example.test",
            password="secret-a",
        )
        auth_context_a = resolve_auth_context(
            self.store,
            f"Bearer {token_a}",
        )

        self.assertIsNotNone(auth_context_a)
        self.assertEqual(auth_context_a.organization_id, "org_a")
        self.assertEqual(auth_context_a.user_id, "user_a")
        self.assertEqual(logged_user_a["organization_id"], "org_a")

        sanitized_user = public_user(user_a)
        self.assertNotIn("password", sanitized_user)
        self.assertNotIn("password_hash", sanitized_user)

        self.store.create_record(
            "clients",
            {
                "id": "client_a",
                "organization_id": "org_a",
                "display_name": "Piscine A",
            },
        )
        client_b = self.store.create_record(
            "clients",
            {
                "id": "client_b",
                "organization_id": "org_b",
                "display_name": "Piscine B",
            },
        )

        clients_a = self.store.list_records(
            "clients",
            scoped_organization_id(auth_context_a, None),
        )
        self.assertEqual(len(clients_a), 1)
        self.assertEqual(clients_a[0]["id"], "client_a")
        self.assertEqual(clients_a[0]["organization_id"], "org_a")

        with self.assertRaises(PermissionError):
            scoped_organization_id(auth_context_a, "org_b")

        with self.assertRaises(PermissionError):
            assert_same_organization(auth_context_a, client_b["organization_id"])

    def test_authenticate_user_without_org_when_email_is_unique(self):
        self.store.create_record(
            "organizations",
            {
                "id": "org_unique",
                "organization_id": "org_unique",
                "name": "Org Unique",
            },
        )
        self.store.create_record(
            "users",
            prepare_resource_payload(
                "users",
                {
                    "id": "user_unique",
                    "organization_id": "org_unique",
                    "email": "unique@example.test",
                    "full_name": "User Unique",
                    "role": "admin",
                    "password": "secret-unique",
                },
            ),
        )

        token, logged_user = authenticate_user(
            self.store,
            organization_id="",
            email="unique@example.test",
            password="secret-unique",
        )

        auth_context = resolve_auth_context(self.store, f"Bearer {token}")
        self.assertIsNotNone(auth_context)
        self.assertEqual(auth_context.organization_id, "org_unique")
        self.assertEqual(logged_user["organization_id"], "org_unique")


if __name__ == "__main__":
    unittest.main()
