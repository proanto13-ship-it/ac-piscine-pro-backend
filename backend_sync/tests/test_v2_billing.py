import http.client
import json
import os
import sys
import tempfile
import threading
import unittest
from pathlib import Path

BACKEND_SYNC_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_SYNC_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_SYNC_DIR))

from v2.app import build_server, prepare_resource_payload  # noqa: E402
from v2.config import load_config  # noqa: E402


class SyncV2BillingTestCase(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp_dir.name) / "sync_v2_billing.sqlite3"
        previous_trial_days = os.environ.get("SYNC_V2_PRO_TRIAL_DAYS")
        self.addCleanup(self._restore_trial_days, previous_trial_days)
        os.environ["SYNC_V2_PRO_TRIAL_DAYS"] = "7"
        self.server = build_server(
            host="127.0.0.1",
            port=0,
            db_path=self.db_path,
            config=load_config(),
        )
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

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.temp_dir.cleanup()

    def _restore_trial_days(self, previous_value):
        if previous_value is None:
            os.environ.pop("SYNC_V2_PRO_TRIAL_DAYS", None)
        else:
            os.environ["SYNC_V2_PRO_TRIAL_DAYS"] = previous_value

    def test_billing_snapshot_returns_seeded_plans_and_org_subscription(self):
        token = self._login("org_a", "a@example.test", "secret-a")

        self.store.create_record(
            "subscriptions",
            {
                "id": "sub_org_a",
                "organization_id": "org_a",
                "planId": "pro",
                "status": "active",
                "startedAtIso": "2026-04-17T10:00:00Z",
            },
        )
        self.store.create_record(
            "entitlements",
            {
                "id": "ent_org_a_cloud",
                "organization_id": "org_a",
                "flag": "cloudSync",
                "enabled": True,
            },
        )

        status, body = self._request(
            "GET",
            "/v2/billing/entitlements",
            headers={"Authorization": f"Bearer {token}"},
        )

        self.assertEqual(status, 200)
        payload = json.loads(body)["data"]
        self.assertEqual(payload["subscription"]["planId"], "pro")
        self.assertGreaterEqual(len(payload["plans"]), 2)
        self.assertIn("free", {item["id"] for item in payload["plans"]})
        self.assertIn("pro", {item["id"] for item in payload["plans"]})
        flags = {
            item["flag"]: item["enabled"] for item in payload["entitlements"]
        }
        self.assertTrue(flags["cloudSync"])

    def test_auth_me_returns_user_organization_and_billing_snapshot(self):
        token = self._login("", "a@example.test", "secret-a")

        assign_status, _ = self._request(
            "POST",
            "/v2/admin/subscriptions/assign",
            headers={
                "Content-Type": "application/json",
                "X-Admin-Token": "dev-admin-token",
            },
            body=json.dumps(
                {
                    "organization_id": "org_a",
                    "plan_id": "pro",
                    "status": "active",
                }
            ).encode("utf-8"),
        )
        self.assertEqual(assign_status, 200)

        status, body = self._request(
            "GET",
            "/v2/auth/me",
            headers={"Authorization": f"Bearer {token}"},
        )

        self.assertEqual(status, 200)
        payload = json.loads(body)["data"]
        self.assertEqual(payload["user"]["email"], "a@example.test")
        self.assertEqual(payload["organization"]["organization_id"], "org_a")
        self.assertEqual(payload["subscription"]["planId"], "pro")
        flags = {
            item["flag"]: item["enabled"] for item in payload["entitlements"]
        }
        self.assertTrue(flags["pdfExport"])
        self.assertTrue(flags["cloudSync"])
        self.assertTrue(flags["teamMembers"])
        self.assertTrue(flags["unlimitedClients"])

    def test_admin_can_assign_manual_subscription_for_pilot(self):
        status, body = self._request(
            "POST",
            "/v2/admin/subscriptions/assign",
            headers={
                "Content-Type": "application/json",
                "X-Admin-Token": "dev-admin-token",
            },
            body=json.dumps(
                {
                    "organization_id": "org_a",
                    "plan_id": "pro",
                    "status": "active",
                    "started_at_iso": "2026-04-17T10:00:00Z",
                    "ended_at_iso": "2026-05-17T10:00:00Z",
                }
            ).encode("utf-8"),
        )

        self.assertEqual(status, 200)
        payload = json.loads(body)["data"]
        self.assertEqual(payload["subscription"]["planId"], "pro")
        self.assertEqual(payload["subscription"]["endedAtIso"], "2026-05-17T10:00:00Z")
        self.assertEqual(payload["snapshot"]["subscription"]["status"], "active")
        flags = {
            item["flag"]: item["enabled"]
            for item in payload["snapshot"]["entitlements"]
        }
        self.assertTrue(flags["pdfExport"])
        self.assertTrue(flags["cloudSync"])
        self.assertTrue(flags["teamMembers"])
        self.assertTrue(flags["unlimitedClients"])

    def test_admin_endpoint_requires_admin_token(self):
        status, _ = self._request(
            "POST",
            "/v2/admin/subscriptions/assign",
            headers={"Content-Type": "application/json"},
            body=json.dumps(
                {
                    "organization_id": "org_a",
                    "plan_id": "pro",
                    "status": "active",
                }
            ).encode("utf-8"),
        )

        self.assertEqual(status, 403)

    def test_snapshot_marks_subscription_expired_when_end_date_is_past(self):
        token = self._login("org_a", "a@example.test", "secret-a")

        assign_status, _ = self._request(
            "POST",
            "/v2/admin/subscriptions/assign",
            headers={
                "Content-Type": "application/json",
                "X-Admin-Token": "dev-admin-token",
            },
            body=json.dumps(
                {
                    "organization_id": "org_a",
                    "plan_id": "pro",
                    "status": "active",
                    "started_at_iso": "2026-03-01T10:00:00Z",
                    "ended_at_iso": "2026-04-01T10:00:00Z",
                }
            ).encode("utf-8"),
        )
        self.assertEqual(assign_status, 200)

        status, body = self._request(
            "GET",
            "/v2/billing/entitlements",
            headers={"Authorization": f"Bearer {token}"},
        )

        self.assertEqual(status, 200)
        payload = json.loads(body)["data"]
        self.assertEqual(payload["subscription"]["status"], "expired")

    def test_trial_start_endpoint_creates_trial_subscription_when_enabled(self):
        token = self._login("org_a", "a@example.test", "secret-a")

        status, body = self._request(
            "POST",
            "/v2/billing/trial/start",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            body=json.dumps({"plan_id": "pro"}).encode("utf-8"),
        )

        self.assertEqual(status, 200)
        payload = json.loads(body)["data"]
        self.assertEqual(payload["subscription"]["status"], "trial")
        self.assertTrue(payload["subscription"]["trialUsed"])
        self.assertEqual(payload["snapshot"]["subscription"]["status"], "trial")
        self.assertEqual(payload["snapshot"]["subscription"]["plan"]["trialDays"], 7)

    def test_trial_start_endpoint_refuses_second_trial(self):
        token = self._login("org_a", "a@example.test", "secret-a")
        first_status, _ = self._request(
            "POST",
            "/v2/billing/trial/start",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            body=json.dumps({"plan_id": "pro"}).encode("utf-8"),
        )
        self.assertEqual(first_status, 200)

        second_status, body = self._request(
            "POST",
            "/v2/billing/trial/start",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            body=json.dumps({"plan_id": "pro"}).encode("utf-8"),
        )

        self.assertEqual(second_status, 400)
        self.assertIn("essai", body.lower())

    def test_snapshot_keeps_canceled_status_while_access_end_date_is_future(self):
        token = self._login("org_a", "a@example.test", "secret-a")

        assign_status, _ = self._request(
            "POST",
            "/v2/admin/subscriptions/assign",
            headers={
                "Content-Type": "application/json",
                "X-Admin-Token": "dev-admin-token",
            },
            body=json.dumps(
                {
                    "organization_id": "org_a",
                    "plan_id": "pro",
                    "status": "canceled",
                    "started_at_iso": "2026-04-01T10:00:00Z",
                    "ended_at_iso": "2099-05-01T10:00:00Z",
                }
            ).encode("utf-8"),
        )
        self.assertEqual(assign_status, 200)

        status, body = self._request(
            "GET",
            "/v2/billing/entitlements",
            headers={"Authorization": f"Bearer {token}"},
        )

        self.assertEqual(status, 200)
        payload = json.loads(body)["data"]
        self.assertEqual(payload["subscription"]["status"], "canceled")

    def test_snapshot_exposes_past_due_status(self):
        token = self._login("org_a", "a@example.test", "secret-a")

        assign_status, _ = self._request(
            "POST",
            "/v2/admin/subscriptions/assign",
            headers={
                "Content-Type": "application/json",
                "X-Admin-Token": "dev-admin-token",
            },
            body=json.dumps(
                {
                    "organization_id": "org_a",
                    "plan_id": "pro",
                    "status": "past_due",
                    "started_at_iso": "2026-04-01T10:00:00Z",
                    "ended_at_iso": "2099-05-01T10:00:00Z",
                }
            ).encode("utf-8"),
        )
        self.assertEqual(assign_status, 200)

        status, body = self._request(
            "GET",
            "/v2/billing/entitlements",
            headers={"Authorization": f"Bearer {token}"},
        )

        self.assertEqual(status, 200)
        payload = json.loads(body)["data"]
        self.assertEqual(payload["subscription"]["status"], "past_due")

    def test_billing_event_endpoint_updates_subscription_from_provider_event(self):
        status, body = self._request(
            "POST",
            "/v2/billing/events/subscription-updated",
            headers={
                "Content-Type": "application/json",
                "X-Admin-Token": "dev-admin-token",
            },
            body=json.dumps(
                {
                    "provider": "mock-web",
                    "event_type": "subscription.updated",
                    "organization_id": "org_a",
                    "plan_id": "pro",
                    "status": "active",
                    "started_at_iso": "2026-04-17T10:00:00Z",
                    "ended_at_iso": "2026-05-17T10:00:00Z",
                    "external_customer_id": "cus_org_a",
                    "external_subscription_id": "sub_org_a_provider",
                }
            ).encode("utf-8"),
        )

        self.assertEqual(status, 200)
        payload = json.loads(body)["data"]
        self.assertEqual(payload["subscription"]["planId"], "pro")
        self.assertEqual(payload["subscription"]["provider"], "mock-web")
        self.assertEqual(
            payload["subscription"]["externalSubscriptionId"],
            "sub_org_a_provider",
        )

    def test_mobile_billing_reconcile_updates_subscription_from_native_purchase(self):
        token = self._login("org_a", "a@example.test", "secret-a")

        status, body = self._request(
            "POST",
            "/v2/billing/mobile/reconcile",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            body=json.dumps(
                {
                    "provider": "app_store",
                    "purchases": [
                        {
                            "provider": "app_store",
                            "platform": "ios",
                            "productId": "com.hydrazur.pro.monthly",
                            "purchaseId": "ios_tx_001",
                            "status": "purchased",
                            "transactionDateIso": "2026-04-17T10:00:00Z",
                            "serverVerificationData": "signed-receipt",
                        }
                    ],
                }
            ).encode("utf-8"),
        )

        self.assertEqual(status, 200)
        payload = json.loads(body)["data"]
        self.assertEqual(payload["subscription"]["planId"], "pro")
        self.assertEqual(payload["subscription"]["provider"], "app_store")
        self.assertEqual(payload["snapshot"]["subscription"]["planId"], "pro")
        self.assertEqual(payload["reconciliation"]["acceptedPurchases"], 1)

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
