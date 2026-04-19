import sys
import tempfile
import unittest
from pathlib import Path

BACKEND_SYNC_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_SYNC_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_SYNC_DIR))

from v2.db import ConflictError, SQLiteSyncV2Store  # noqa: E402


class SyncV2ConflictTestCase(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp_dir.name) / "sync_v2_conflicts.sqlite3"
        self.store = SQLiteSyncV2Store(self.db_path)
        self.store.initialize()
        self.store.create_record(
            "organizations",
            {
                "id": "org_a",
                "organization_id": "org_a",
                "name": "Org A",
            },
        )

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_rejects_stale_update_and_keeps_newer_version(self):
        created = self.store.create_record(
            "clients",
            {
                "id": "client_a",
                "organization_id": "org_a",
                "display_name": "Piscine A",
                "name": "Piscine A",
                "version": 3,
                "updatedAt": "2026-04-17T12:00:00+00:00",
            },
        )
        self.assertEqual(created["version"], 3)

        with self.assertRaises(ConflictError):
            self.store.update_record(
                "clients",
                "client_a",
                {
                    "id": "client_a",
                    "organization_id": "org_a",
                    "display_name": "Piscine A stale",
                    "name": "Piscine A stale",
                    "version": 2,
                    "updatedAt": "2026-04-17T11:00:00+00:00",
                },
            )

        current = self.store.get_record("clients", "client_a")
        self.assertEqual(current["name"], "Piscine A")
        self.assertEqual(current["version"], 3)

    def test_soft_delete_sets_deleted_at_and_bumps_version(self):
        created = self.store.create_record(
            "clients",
            {
                "id": "client_b",
                "organization_id": "org_a",
                "display_name": "Piscine B",
                "name": "Piscine B",
                "version": 1,
            },
        )

        deleted = self.store.soft_delete_record("clients", "client_b")
        self.assertTrue(deleted["deletedAt"])
        self.assertGreaterEqual(deleted["version"], created["version"] + 1)


if __name__ == "__main__":
    unittest.main()
