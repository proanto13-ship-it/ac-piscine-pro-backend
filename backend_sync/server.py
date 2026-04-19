import json
import os
import base64
import hashlib
import hmac
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse
from typing import Optional


BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
STORAGE_FILE = DATA_DIR / "sync_store.json"
DEFAULT_HOST = (os.getenv("HOST") or os.getenv("SYNC_HOST") or "0.0.0.0").strip()
DEFAULT_PORT = int(os.getenv("PORT") or os.getenv("SYNC_PORT") or "8000")
API_KEY = os.getenv("SYNC_API_KEY", "").strip()
AUTH_SECRET = (
    os.getenv("AUTH_SECRET")
    or os.getenv("JWT_SECRET")
    or os.getenv("SYNC_V2_AUTH_SECRET")
    or "hydr-azur-render-staging-secret"
).strip()

FREE_ENTITLEMENTS = [
    {"flag": "unlimitedClients", "enabled": False},
    {"flag": "pdfExport", "enabled": False},
    {"flag": "teamMembers", "enabled": False},
    {"flag": "cloudSync", "enabled": False},
]

PRO_ENTITLEMENTS = [
    {"flag": "unlimitedClients", "enabled": True},
    {"flag": "pdfExport", "enabled": True},
    {"flag": "teamMembers", "enabled": True},
    {"flag": "cloudSync", "enabled": True},
]

PLANS = [
    {
        "id": "free",
        "displayName": "Free",
        "clientLimit": 10,
        "trialDays": 0,
        "entitlements": FREE_ENTITLEMENTS,
    },
    {
        "id": "pro",
        "displayName": "Pro",
        "clientLimit": None,
        "trialDays": 0,
        "entitlements": PRO_ENTITLEMENTS,
    },
]

DEMO_ACCOUNTS = {
    "demo-pro@hydrazur.test": {
        "id": "demo-user-admin",
        "organizationId": "demo-pro-hydrazur",
        "organizationName": "HydrAzur Pro Demo",
        "email": "demo-pro@hydrazur.test",
        "password": "demo1234",
        "fullName": "Demo Admin",
        "role": "admin",
        "planId": "pro",
        "status": "active",
        "entitlements": PRO_ENTITLEMENTS,
        "companyProfile": {
            "companyName": "HydrAzur Pro Demo",
            "phone": "+33 4 92 10 24 40",
            "email": "contact@hydrazur-demo.test",
            "address": "18 avenue des Lauriers, 06270 Villeneuve-Loubet",
            "countryCode": "FR",
            "localeCode": "fr-FR",
            "currencyCode": "EUR",
            "businessRegistrationLabel": "SIRET",
            "businessRegistrationValue": "81234567800019",
            "taxRegistrationValue": "FR12812345678",
        },
        "workspaceSettings": {
            "localeCode": "fr-FR",
            "currencyCode": "EUR",
            "countryCode": "FR",
            "timeZoneId": "Europe/Paris",
            "unitSystem": "metric",
        },
    },
    "demo-free@hydrazur.test": {
        "id": "demo-user-free",
        "organizationId": "demo-free-hydrazur",
        "organizationName": "HydrAzur Free Demo",
        "email": "demo-free@hydrazur.test",
        "password": "demo1234",
        "fullName": "Demo Free",
        "role": "admin",
        "planId": "free",
        "status": "active",
        "entitlements": FREE_ENTITLEMENTS,
        "companyProfile": {
            "companyName": "HydrAzur Free Demo",
            "phone": "+33 4 92 10 24 41",
            "email": "contact@hydrazur-free.test",
            "address": "6 avenue des Pins, 06160 Antibes",
            "countryCode": "FR",
            "localeCode": "fr-FR",
            "currencyCode": "EUR",
            "businessRegistrationLabel": "SIRET",
            "businessRegistrationValue": "81234567800027",
            "taxRegistrationValue": "FR42812345678",
        },
        "workspaceSettings": {
            "localeCode": "fr-FR",
            "currencyCode": "EUR",
            "countryCode": "FR",
            "timeZoneId": "Europe/Paris",
            "unitSystem": "metric",
        },
    },
}


def should_start_v2() -> bool:
    explicit_backend = (
        os.getenv("HYDRAZUR_BACKEND_VERSION")
        or os.getenv("SYNC_BACKEND_VERSION")
        or ""
    ).strip().lower()
    return explicit_backend == "v2"


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def ensure_storage() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if not STORAGE_FILE.exists():
        STORAGE_FILE.write_text(
            json.dumps(
                {
                    "updatedAt": "",
                    "payload": {
                        "clients": [],
                        "pricingSettings": {},
                        "companyProfile": {},
                        "teamMembers": [],
                        "cloudSyncSettings": {},
                    },
                },
                indent=2,
            ),
            encoding="utf-8",
        )


def read_store() -> dict:
    ensure_storage()
    return json.loads(STORAGE_FILE.read_text(encoding="utf-8"))


def write_store(payload: dict) -> dict:
    ensure_storage()
    store = {
        "updatedAt": utc_now_iso(),
        "payload": payload,
    }
    STORAGE_FILE.write_text(json.dumps(store, indent=2), encoding="utf-8")
    return store


def extract_api_key(headers) -> str:
    auth = headers.get("Authorization", "")
    if auth.lower().startswith("bearer "):
        return auth.split(" ", 1)[1].strip()
    return headers.get("x-api-key", "").strip()


def _path(raw_path: str) -> str:
    return urlparse(raw_path).path.rstrip("/") or "/"


def _now_z() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace(
        "+00:00", "Z")


def _plan_by_id(plan_id: str) -> dict:
    for plan in PLANS:
        if plan["id"] == plan_id:
            return plan
    return PLANS[0]


def _build_subscription_payload(account: dict) -> dict:
    return {
        "id": f"{account['organizationId']}_{account['planId']}",
        "organization_id": account["organizationId"],
        "planId": account["planId"],
        "status": account["status"],
        "startedAtIso": "",
        "endedAtIso": "",
        "updatedAtIso": _now_z(),
        "plan": _plan_by_id(account["planId"]),
        "entitlements": account["entitlements"],
    }


def _build_user_payload(account: dict) -> dict:
    return {
        "id": account["id"],
        "organization_id": account["organizationId"],
        "email": account["email"],
        "fullName": account["fullName"],
        "role": account["role"],
        "updatedAtIso": _now_z(),
    }


def _build_organization_payload(account: dict) -> dict:
    return {
        "id": account["organizationId"],
        "organization_id": account["organizationId"],
        "name": account["organizationName"],
        "companyProfile": account["companyProfile"],
        "workspaceSettings": account["workspaceSettings"],
        "updatedAtIso": _now_z(),
    }


def _build_billing_snapshot(account: dict) -> dict:
    return {
        "plans": PLANS,
        "subscription": _build_subscription_payload(account),
        "entitlements": account["entitlements"],
    }


def _token_for_account(account: dict) -> str:
    payload = {
        "email": account["email"],
        "user_id": account["id"],
        "organization_id": account["organizationId"],
    }
    payload_bytes = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    payload_b64 = base64.urlsafe_b64encode(payload_bytes).decode("ascii").rstrip("=")
    signature = hmac.new(
        AUTH_SECRET.encode("utf-8"),
        payload_b64.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    return f"{payload_b64}.{signature}"


def _account_from_token(token: str) -> Optional[dict]:
    normalized = token.strip()
    if not normalized or "." not in normalized:
        return None
    payload_b64, signature = normalized.rsplit(".", 1)
    expected_signature = hmac.new(
        AUTH_SECRET.encode("utf-8"),
        payload_b64.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(signature, expected_signature):
        return None
    try:
        padding = "=" * ((4 - len(payload_b64) % 4) % 4)
        payload = json.loads(
            base64.urlsafe_b64decode((payload_b64 + padding).encode("ascii"))
        )
    except Exception:
        return None
    email = str(payload.get("email", "")).strip().lower()
    account = DEMO_ACCOUNTS.get(email)
    if account is None:
        return None
    if account["organizationId"] != str(payload.get("organization_id", "")).strip():
        return None
    if account["id"] != str(payload.get("user_id", "")).strip():
        return None
    return account


def _log_auth_event(event: str, **fields) -> None:
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    payload = {"event": event, **fields}
    print(f"[{timestamp}] AUTH {json.dumps(payload, ensure_ascii=False)}")


class SyncHandler(BaseHTTPRequestHandler):
    server_version = "HydrAzurSync/1.0"

    def do_OPTIONS(self):
        self.send_response(HTTPStatus.NO_CONTENT)
        self._set_common_headers()
        self.end_headers()

    def do_GET(self):
        route = _path(self.path)
        if route == "/health":
            self._send_json(
                HTTPStatus.OK,
                {
                    "status": "ok",
                    "service": "hydr-azur-sync",
                    "v2Auth": True,
                    "routes": ["sync", "v2-auth", "v2-billing"],
                    "updatedAt": read_store().get("updatedAt", ""),
                },
            )
            return

        if route == "/v2/health":
            self._send_json(
                HTTPStatus.OK,
                {
                    "status": "ok",
                    "service": "hydr-azur-sync",
                    "v2Auth": True,
                    "routes": ["sync", "v2-auth", "v2-billing"],
                },
            )
            return

        if route == "/v2/auth/me":
            account = self._require_demo_session()
            if account is None:
                return
            self._send_json(
                HTTPStatus.OK,
                {
                    "data": {
                        "user": _build_user_payload(account),
                        "organization": _build_organization_payload(account),
                        "subscription": _build_subscription_payload(account),
                        "entitlements": account["entitlements"],
                    },
                },
            )
            return

        if route == "/v2/billing/entitlements":
            account = self._require_demo_session()
            if account is None:
                return
            self._send_json(
                HTTPStatus.OK,
                {
                    "data": _build_billing_snapshot(account),
                },
            )
            return

        if route != "/sync":
            self._send_not_found()
            return

        if not self._is_authorized():
            self._send_unauthorized()
            return

        store = read_store()
        self._send_json(
            HTTPStatus.OK,
            {
                "message": "Payload cloud charge.",
                "updatedAt": store.get("updatedAt", ""),
                "payload": store.get("payload", {}),
            },
        )

    def do_POST(self):
        route = _path(self.path)
        if route == "/v2/auth/login":
            try:
                payload = self._read_json_body()
                email = str(payload.get("email", "")).strip().lower()
                password = str(payload.get("password", "")).strip()
                organization_id = str(
                    payload.get("organizationId") or payload.get("organization_id") or ""
                ).strip()
                if not email or not password:
                    self._send_json(
                        HTTPStatus.BAD_REQUEST,
                        {"message": "email et password sont obligatoires."},
                    )
                    return
                account = DEMO_ACCOUNTS.get(email)
                if account is None:
                    _log_auth_event(
                        "auth_login_failed",
                        email=email,
                        organizationId=organization_id,
                        reason="user_not_found",
                    )
                    self._send_json(
                        HTTPStatus.UNAUTHORIZED,
                        {"message": "Email, mot de passe ou organisation invalides."},
                    )
                    return
                if organization_id and organization_id != account["organizationId"]:
                    _log_auth_event(
                        "auth_login_failed",
                        email=email,
                        organizationId=organization_id,
                        reason="organization_mismatch",
                    )
                    self._send_json(
                        HTTPStatus.UNAUTHORIZED,
                        {"message": "Email, mot de passe ou organisation invalides."},
                    )
                    return
                if password != account["password"]:
                    _log_auth_event(
                        "auth_login_failed",
                        email=email,
                        organizationId=organization_id or account["organizationId"],
                        reason="invalid_credentials",
                    )
                    self._send_json(
                        HTTPStatus.UNAUTHORIZED,
                        {"message": "Email, mot de passe ou organisation invalides."},
                    )
                    return
                token = _token_for_account(account)
                self._send_json(
                    HTTPStatus.OK,
                    {
                        "message": "Connexion reussie.",
                        "data": {
                            "token": token,
                            "user": _build_user_payload(account),
                        },
                    },
                )
                return
            except ValueError as error:
                _log_auth_event("auth_login_rejected", reason=str(error))
                self._send_json(HTTPStatus.BAD_REQUEST, {"message": str(error)})
                return

        if route != "/sync":
            self._send_not_found()
            return

        if not self._is_authorized():
            self._send_unauthorized()
            return

        try:
            payload = self._read_json_body()
        except ValueError as error:
            self._send_json(
                HTTPStatus.BAD_REQUEST,
                {"message": str(error)},
            )
            return

        if not isinstance(payload, dict):
            self._send_json(
                HTTPStatus.BAD_REQUEST,
                {"message": "Le body JSON doit etre un objet."},
            )
            return

        if not isinstance(payload.get("clients"), list):
            self._send_json(
                HTTPStatus.BAD_REQUEST,
                {"message": "Le payload doit contenir une liste clients."},
            )
            return

        store = write_store(payload)
        self._send_json(
            HTTPStatus.OK,
            {
                "message": f"Synchronisation enregistree ({len(payload.get('clients', []))} clients).",
                "updatedAt": store["updatedAt"],
            },
        )

    def log_message(self, format, *args):
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] {self.address_string()} - {format % args}")

    def _is_authorized(self) -> bool:
        if not API_KEY:
            return True
        return extract_api_key(self.headers) == API_KEY

    def _read_json_body(self):
        content_length = int(self.headers.get("Content-Length", "0"))
        if content_length <= 0:
            raise ValueError("Le body JSON est vide.")
        raw = self.rfile.read(content_length).decode("utf-8")
        try:
            return json.loads(raw)
        except json.JSONDecodeError as error:
            raise ValueError(f"JSON invalide: {error.msg}") from error

    def _set_common_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, x-api-key")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Cache-Control", "no-store")

    def _send_json(self, status: HTTPStatus, payload: dict):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self._set_common_headers()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_not_found(self):
        self._send_json(HTTPStatus.NOT_FOUND, {"message": "Route inconnue."})

    def _send_unauthorized(self):
        self._send_json(
            HTTPStatus.UNAUTHORIZED,
            {"message": "Cle API invalide ou manquante."},
        )

    def _require_demo_session(self):
        auth = self.headers.get("Authorization", "")
        if not auth.lower().startswith("bearer "):
            self._send_json(
                HTTPStatus.UNAUTHORIZED,
                {"message": "Session invalide ou manquante."},
            )
            return None
        token = auth.split(" ", 1)[1].strip()
        account = _account_from_token(token)
        if account is None:
            self._send_json(
                HTTPStatus.UNAUTHORIZED,
                {"message": "Session invalide ou expiree."},
            )
            return None
        return account


def main():
    if should_start_v2():
        print("HydrAzur staging/prod detecte: routage automatique vers la V2.")
        from v2.app import main as v2_main

        v2_main()
        return

    ensure_storage()
    server = ThreadingHTTPServer((DEFAULT_HOST, DEFAULT_PORT), SyncHandler)
    print(f"HydrAzur Sync en ecoute sur http://{DEFAULT_HOST}:{DEFAULT_PORT}")
    print(
        "Routes disponibles: GET /health, GET /sync, POST /sync, "
        "POST /v2/auth/login, GET /v2/auth/me, GET /v2/billing/entitlements"
    )
    if API_KEY:
        print("Authentification active via Authorization: Bearer <token> ou x-api-key")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nArret du serveur.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
