import json
import os
import base64
import hashlib
import hmac
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse
from typing import Optional


BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
STORAGE_FILE = DATA_DIR / "sync_store.json"
V2_STORAGE_FILE = DATA_DIR / "sync_v2_store.json"
V2_MEDIA_DIR = Path(
    (
        os.getenv("SYNC_RENDER_MEDIA_DIR")
        or os.getenv("SYNC_V2_MEDIA_DIR")
        or str(DATA_DIR / "render_media")
    ).strip()
)
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


def ensure_v2_storage() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    V2_MEDIA_DIR.mkdir(parents=True, exist_ok=True)
    if not V2_STORAGE_FILE.exists():
        V2_STORAGE_FILE.write_text(
            json.dumps(
                {
                    "updatedAt": "",
                    "organizations": {},
                },
                indent=2,
            ),
            encoding="utf-8",
        )


def read_store() -> dict:
    ensure_storage()
    return json.loads(STORAGE_FILE.read_text(encoding="utf-8"))


def read_v2_store() -> dict:
    ensure_v2_storage()
    return json.loads(V2_STORAGE_FILE.read_text(encoding="utf-8"))


def write_store(payload: dict) -> dict:
    ensure_storage()
    store = {
        "updatedAt": utc_now_iso(),
        "payload": payload,
    }
    STORAGE_FILE.write_text(json.dumps(store, indent=2), encoding="utf-8")
    return store


def write_v2_store(store: dict) -> dict:
    ensure_v2_storage()
    store["updatedAt"] = _now_z()
    V2_STORAGE_FILE.write_text(json.dumps(store, indent=2), encoding="utf-8")
    return store


def extract_api_key(headers) -> str:
    auth = headers.get("Authorization", "")
    if auth.lower().startswith("bearer "):
        return auth.split(" ", 1)[1].strip()
    return headers.get("x-api-key", "").strip()


def _path(raw_path: str) -> str:
    return urlparse(raw_path).path.rstrip("/") or "/"


def _query_params(raw_path: str) -> dict[str, list[str]]:
    return parse_qs(urlparse(raw_path).query)


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


def _blank_sync_payload(account: dict) -> dict:
    return {
        "clients": [],
        "pricingSettings": {},
        "companyProfile": account.get("companyProfile", {}),
        "teamMembers": [],
        "cloudSyncSettings": {},
        "workspaceSettings": account.get("workspaceSettings", {}),
    }


def _blank_org_sync_state(account: dict) -> dict:
    return {
        "updatedAt": "",
        "lastPayload": _blank_sync_payload(account),
        "clients": {},
        "interventions": {},
        "financialDocuments": {},
        "media": {},
    }


def _ensure_org_sync_state(store: dict, account: dict) -> dict:
    organizations = store.setdefault("organizations", {})
    org_id = account["organizationId"]
    if org_id not in organizations:
        organizations[org_id] = _blank_org_sync_state(account)
    return organizations[org_id]


def _resource_store_key(route_key: str) -> Optional[str]:
    mapping = {
        "clients": "clients",
        "interventions": "interventions",
        "financial-documents": "financialDocuments",
        "financial_documents": "financialDocuments",
        "media": "media",
    }
    return mapping.get(route_key)


def _resource_label(resource_key: str) -> str:
    labels = {
        "clients": "Client",
        "interventions": "Intervention",
        "financialDocuments": "Document",
        "media": "Média",
    }
    return labels.get(resource_key, "Ressource")


def _parse_iso(value: str) -> Optional[datetime]:
    normalized = (value or "").strip()
    if not normalized:
        return None
    try:
        if normalized.endswith("Z"):
            normalized = normalized[:-1] + "+00:00"
        return datetime.fromisoformat(normalized)
    except ValueError:
        return None


def _is_newer_than(record: dict, since_iso: str) -> bool:
    normalized_since = (since_iso or "").strip()
    if not normalized_since:
        return True
    since_at = _parse_iso(normalized_since)
    if since_at is None:
        return True
    candidates = [
        str(record.get("updatedAtIso") or ""),
        str(record.get("updated_at_iso") or ""),
        str(record.get("updatedAt") or ""),
        str(record.get("createdAtIso") or ""),
    ]
    for candidate in candidates:
        updated_at = _parse_iso(candidate)
        if updated_at is not None:
            return updated_at > since_at
    return True


def _deep_copy(payload: dict) -> dict:
    return json.loads(json.dumps(payload))


def _normalize_record_timestamp(record: dict) -> str:
    for field in ("updatedAtIso", "updated_at_iso", "updatedAt", "createdAtIso"):
        value = str(record.get(field, "")).strip()
        if value:
            return value
    return _now_z()


def _normalize_v2_record(
    resource_key: str,
    account: dict,
    payload: dict,
    *,
    record_id: Optional[str] = None,
    existing: Optional[dict] = None,
) -> dict:
    normalized = _deep_copy(existing or {})
    normalized.update(_deep_copy(payload))

    final_id = str(record_id or normalized.get("id") or "").strip()
    if not final_id:
        raise ValueError("Identifiant de ressource manquant.")

    updated_at_iso = _normalize_record_timestamp(normalized)
    normalized["id"] = final_id
    normalized["organization_id"] = account["organizationId"]
    normalized["updatedAtIso"] = updated_at_iso
    normalized["updated_at_iso"] = updated_at_iso
    normalized.setdefault("createdAtIso", updated_at_iso)
    try:
        normalized["version"] = int(normalized.get("version") or 1)
    except (TypeError, ValueError):
        normalized["version"] = 1
    normalized.setdefault("deletedAt", normalized.get("deletedAtIso", ""))
    normalized.setdefault("deletedAtIso", normalized.get("deletedAt", ""))

    if resource_key == "clients":
        normalized.setdefault("display_name", normalized.get("name", ""))
        normalized.setdefault("interventions", [])
        normalized.setdefault("financialDocuments", [])

    return normalized


def _public_record(resource_key: str, record: dict) -> dict:
    public_record = _deep_copy(record)
    if resource_key == "media":
        public_record.pop("filePath", None)
    return public_record


def _rebuild_last_payload(org_state: dict, account: dict) -> None:
    clients = []
    clients_records = list(org_state["clients"].values())
    clients_records.sort(
        key=lambda item: str(item.get("updatedAtIso", "")),
        reverse=False,
    )
    for client_record in clients_records:
        client_payload = _deep_copy(client_record)
        client_id = str(client_record.get("id") or "")
        interventions = [
            _deep_copy(item)
            for item in org_state["interventions"].values()
            if str(item.get("client_id") or item.get("clientId") or "") == client_id
        ]
        interventions.sort(key=lambda item: str(item.get("updatedAtIso", "")))
        for intervention in interventions:
            intervention_id = str(intervention.get("id") or "")
            attachments = [
                _public_record("media", item)
                for item in org_state["media"].values()
                if str(item.get("intervention_id") or item.get("interventionId") or "")
                == intervention_id
            ]
            attachments.sort(key=lambda item: str(item.get("updatedAtIso", "")))
            intervention["attachments"] = attachments
            intervention["photoPaths"] = []
        documents = [
            _deep_copy(item)
            for item in org_state["financialDocuments"].values()
            if str(item.get("client_id") or item.get("clientId") or "") == client_id
        ]
        documents.sort(key=lambda item: str(item.get("updatedAtIso", "")))
        client_payload["interventions"] = interventions
        client_payload["financialDocuments"] = documents
        clients.append(client_payload)

    org_state["lastPayload"] = {
        "clients": clients,
        "pricingSettings": {},
        "companyProfile": account.get("companyProfile", {}),
        "teamMembers": [],
        "cloudSyncSettings": {},
        "workspaceSettings": account.get("workspaceSettings", {}),
    }


def _upsert_v2_record(
    account: dict,
    resource_key: str,
    payload: dict,
    *,
    record_id: Optional[str] = None,
) -> dict:
    store = read_v2_store()
    org_state = _ensure_org_sync_state(store, account)
    records = org_state[resource_key]
    existing = None
    requested_id = str(record_id or payload.get("id") or "").strip()
    if requested_id:
        existing = records.get(requested_id)
    normalized = _normalize_v2_record(
        resource_key,
        account,
        payload,
        record_id=requested_id or None,
        existing=existing,
    )
    records[normalized["id"]] = normalized
    org_state["updatedAt"] = normalized["updatedAtIso"]
    _rebuild_last_payload(org_state, account)
    write_v2_store(store)
    return normalized


def _list_v2_records(account: dict, resource_key: str, since_iso: str = "") -> list[dict]:
    store = read_v2_store()
    org_state = _ensure_org_sync_state(store, account)
    records = [
        _public_record(resource_key, item)
        for item in org_state[resource_key].values()
        if _is_newer_than(item, since_iso)
    ]
    records.sort(key=lambda item: str(item.get("updatedAtIso", "")))
    return records


def _get_v2_record(account: dict, resource_key: str, record_id: str) -> Optional[dict]:
    store = read_v2_store()
    org_state = _ensure_org_sync_state(store, account)
    record = org_state[resource_key].get(record_id)
    if record is None:
        return None
    return _public_record(resource_key, record)


def _save_v2_media(account: dict, headers, body: bytes) -> dict:
    attachment_id = (headers.get("X-Attachment-Id") or "").strip()
    if not attachment_id:
        raise ValueError("Identifiant de pièce jointe manquant.")
    file_name = (headers.get("X-File-Name") or f"{attachment_id}.bin").strip()
    safe_name = "".join(
        char if char.isalnum() or char in "._-" else "_"
        for char in file_name
    ) or f"{attachment_id}.bin"
    org_dir = V2_MEDIA_DIR / account["organizationId"]
    org_dir.mkdir(parents=True, exist_ok=True)
    target = org_dir / f"{attachment_id}_{safe_name}"
    target.write_bytes(body)

    now_iso = _now_z()
    payload = {
        "id": attachment_id,
        "organization_id": account["organizationId"],
        "client_id": (headers.get("X-Client-Id") or "").strip(),
        "intervention_id": (headers.get("X-Intervention-Id") or "").strip(),
        "originalFileName": safe_name,
        "mimeType": (headers.get("X-Mime-Type") or "application/octet-stream").strip(),
        "createdAtIso": (headers.get("X-Created-At-Iso") or now_iso).strip() or now_iso,
        "updatedAtIso": now_iso,
        "updated_at_iso": now_iso,
        "version": 1,
        "deletedAt": "",
        "deletedAtIso": "",
        "downloadPath": f"/v2/media/{attachment_id}/download",
        "remoteUrl": f"/v2/media/{attachment_id}/download",
        "filePath": str(target),
    }
    return _upsert_v2_record(account, "media", payload, record_id=attachment_id)


class SyncHandler(BaseHTTPRequestHandler):
    server_version = "HydrAzurSync/1.0"

    def do_OPTIONS(self):
        self.send_response(HTTPStatus.NO_CONTENT)
        self._set_common_headers()
        self.end_headers()

    def do_GET(self):
        route = _path(self.path)
        query = _query_params(self.path)
        if route == "/health":
            v2_store = read_v2_store()
            self._send_json(
                HTTPStatus.OK,
                {
                    "status": "ok",
                    "service": "hydr-azur-sync",
                    "v2Auth": True,
                    "syncV2": True,
                    "routes": ["sync", "v2-auth", "v2-billing", "v2-sync"],
                    "updatedAt": read_store().get("updatedAt", ""),
                    "v2UpdatedAt": v2_store.get("updatedAt", ""),
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
                    "syncV2": True,
                    "routes": ["sync", "v2-auth", "v2-billing", "v2-sync"],
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

        if route == "/v2/sync":
            account = self._require_demo_session()
            if account is None:
                return
            store = read_v2_store()
            org_state = _ensure_org_sync_state(store, account)
            self._send_json(
                HTTPStatus.OK,
                {
                    "message": "Synchronisation cloud récupérée.",
                    "updatedAt": org_state.get("updatedAt", ""),
                    "payload": org_state.get("lastPayload", _blank_sync_payload(account)),
                },
            )
            return

        media_prefix = "/v2/media/"
        if route.startswith(media_prefix) and route.endswith("/download"):
            account = self._require_demo_session()
            if account is None:
                return
            attachment_id = route[len(media_prefix) : -len("/download")].strip("/")
            if not attachment_id:
                self._send_not_found()
                return
            store = read_v2_store()
            org_state = _ensure_org_sync_state(store, account)
            record = org_state["media"].get(attachment_id)
            if record is None:
                self._send_not_found()
                return
            file_path = Path(str(record.get("filePath") or ""))
            if not file_path.exists():
                self._send_not_found()
                return
            self._send_binary(
                HTTPStatus.OK,
                file_path.read_bytes(),
                str(record.get("mimeType") or "application/octet-stream"),
            )
            return

        v2_collection_key, v2_record_id = self._match_v2_resource(route)
        if v2_collection_key is not None:
            account = self._require_demo_session()
            if account is None:
                return
            if v2_record_id:
                record = _get_v2_record(account, v2_collection_key, v2_record_id)
                if record is None:
                    self._send_not_found()
                    return
                self._send_json(HTTPStatus.OK, {"data": record})
                return

            since_iso = (query.get("updated_after") or [""])[0]
            records = _list_v2_records(account, v2_collection_key, since_iso=since_iso)
            self._send_json(
                HTTPStatus.OK,
                {
                    "data": records,
                    "updatedAt": read_v2_store().get("updatedAt", ""),
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

        if route == "/v2/sync":
            account = self._require_demo_session()
            if account is None:
                return
            try:
                payload = self._read_json_body()
            except ValueError as error:
                self._send_json(HTTPStatus.BAD_REQUEST, {"message": str(error)})
                return
            sync_payload = payload.get("payload") if isinstance(payload, dict) and isinstance(payload.get("payload"), dict) else payload
            if not isinstance(sync_payload, dict):
                self._send_json(
                    HTTPStatus.BAD_REQUEST,
                    {"message": "Le payload de synchronisation est invalide."},
                )
                return
            store = read_v2_store()
            org_state = _ensure_org_sync_state(store, account)
            org_state["lastPayload"] = _deep_copy(sync_payload)
            org_state["updatedAt"] = _now_z()
            write_v2_store(store)
            self._send_json(
                HTTPStatus.OK,
                {
                    "ok": True,
                    "updatedAt": org_state["updatedAt"],
                    "payload": org_state["lastPayload"],
                },
            )
            return

        if route == "/v2/media/upload":
            account = self._require_demo_session()
            if account is None:
                return
            content_length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(content_length) if content_length > 0 else b""
            try:
                record = _save_v2_media(account, self.headers, body)
            except ValueError as error:
                self._send_json(HTTPStatus.BAD_REQUEST, {"message": str(error)})
                return
            self._send_json(
                HTTPStatus.OK,
                {
                    "message": "Média synchronisé.",
                    "data": _public_record("media", record),
                },
            )
            return

        v2_collection_key, v2_record_id = self._match_v2_resource(route)
        if v2_collection_key is not None and not v2_record_id:
            account = self._require_demo_session()
            if account is None:
                return
            try:
                payload = self._read_json_body()
            except ValueError as error:
                self._send_json(HTTPStatus.BAD_REQUEST, {"message": str(error)})
                return
            if not isinstance(payload, dict):
                self._send_json(
                    HTTPStatus.BAD_REQUEST,
                    {"message": "Le body JSON doit être un objet."},
                )
                return
            try:
                record = _upsert_v2_record(account, v2_collection_key, payload)
            except ValueError as error:
                self._send_json(HTTPStatus.BAD_REQUEST, {"message": str(error)})
                return
            self._send_json(
                HTTPStatus.OK,
                {
                    "message": f"{_resource_label(v2_collection_key)} synchronisé.",
                    "data": _public_record(v2_collection_key, record),
                },
            )
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

    def do_PUT(self):
        route = _path(self.path)
        v2_collection_key, v2_record_id = self._match_v2_resource(route)
        if v2_collection_key is None or not v2_record_id:
            self._send_not_found()
            return

        account = self._require_demo_session()
        if account is None:
            return

        try:
            payload = self._read_json_body()
        except ValueError as error:
            self._send_json(HTTPStatus.BAD_REQUEST, {"message": str(error)})
            return

        if not isinstance(payload, dict):
            self._send_json(
                HTTPStatus.BAD_REQUEST,
                {"message": "Le body JSON doit être un objet."},
            )
            return

        try:
            record = _upsert_v2_record(
                account,
                v2_collection_key,
                payload,
                record_id=v2_record_id,
            )
        except ValueError as error:
            self._send_json(HTTPStatus.BAD_REQUEST, {"message": str(error)})
            return

        self._send_json(
            HTTPStatus.OK,
            {
                "message": f"{_resource_label(v2_collection_key)} synchronisé.",
                "data": _public_record(v2_collection_key, record),
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
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, OPTIONS")
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

    def _send_binary(self, status: HTTPStatus, payload: bytes, content_type: str):
        self.send_response(status)
        self._set_common_headers()
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

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

    def _match_v2_resource(self, route: str) -> tuple[Optional[str], Optional[str]]:
        if not route.startswith("/v2/"):
            return None, None
        raw_segments = [segment for segment in route.split("/") if segment]
        if len(raw_segments) < 2 or raw_segments[0] != "v2":
            return None, None
        collection = raw_segments[1]
        resource_key = _resource_store_key(collection)
        if resource_key is None:
            return None, None
        if len(raw_segments) == 2:
            return resource_key, None
        if len(raw_segments) == 3:
            return resource_key, raw_segments[2]
        return None, None


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
        "POST /v2/auth/login, GET /v2/auth/me, GET /v2/billing/entitlements, "
        "GET /v2/clients, PUT /v2/clients/{id}, GET /v2/interventions, "
        "PUT /v2/interventions/{id}, GET /v2/financial-documents, "
        "PUT /v2/financial-documents/{id}, GET /v2/media, POST /v2/media/upload"
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
