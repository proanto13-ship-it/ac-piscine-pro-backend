import base64
import json
import logging
import os
import sqlite3
import time
import traceback
from html import escape
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from mimetypes import guess_type
from uuid import uuid4
from typing import Optional, Tuple, Union
from urllib.parse import parse_qs, urlparse

from .auth import AuthContext, build_token, hash_password, parse_token
from .config import SyncV2Config, load_config
from .db import (
    DEFAULT_DB_PATH,
    RESOURCE_CONFIGS,
    ConflictError,
    SQLiteSyncV2Store,
    _string_value,
)
from .rate_limit import InMemoryRateLimiter, RateLimitRule
from .validation import (
    validate_email,
    validate_identifier,
    validate_optional_iso_datetime,
)


DEFAULT_CONFIG = load_config()
DEFAULT_HOST = DEFAULT_CONFIG.host
DEFAULT_PORT = DEFAULT_CONFIG.port
DEFAULT_DB = Path(os.getenv("SYNC_V2_DB", str(DEFAULT_DB_PATH)))
LOGGER = logging.getLogger("hydr.azur.sync.v2")

RESOURCE_ALIASES = {
    "organizations": "organizations",
    "users": "users",
    "clients": "clients",
    "subscriptions": "subscriptions",
    "entitlements": "entitlements",
    "interventions": "interventions",
    "financial_documents": "financial_documents",
    "financial-documents": "financial_documents",
}


def configure_logging(level_name: str) -> None:
    level = getattr(logging, level_name.upper(), logging.INFO)
    logging.basicConfig(
        level=level,
        format="%(message)s",
    )


def log_event(level: int, event: str, **fields: object) -> None:
    payload = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "level": logging.getLevelName(level),
        "event": event,
        **fields,
    }
    LOGGER.log(level, json.dumps(payload, ensure_ascii=False, sort_keys=True))


def authenticate_user(
    store: SQLiteSyncV2Store,
    *,
    organization_id: str,
    email: str,
    password: str,
) -> Tuple[str, dict]:
    resolved_organization_id = organization_id.strip()
    if resolved_organization_id:
        user = store.find_user_by_email(resolved_organization_id, email)
    else:
        user = store.find_unique_user_by_email(email)
    stored_password_hash = str(user.get("password_hash", "")).strip()
    if not stored_password_hash:
        raise PermissionError("Utilisateur non activable pour le login de dev.")
    if stored_password_hash != hash_password(password):
        raise PermissionError("Email, mot de passe ou organisation invalides.")

    token = build_token(
        user_id=user["id"],
        organization_id=user["organization_id"],
        email=str(user.get("email", "")),
    )
    return token, user


def resolve_auth_context(
    store: SQLiteSyncV2Store,
    authorization_header: str,
) -> Optional[AuthContext]:
    auth_header = authorization_header.strip()
    if not auth_header.lower().startswith("bearer "):
        return None

    token = auth_header.split(" ", 1)[1].strip()
    auth_context = parse_token(token)
    if auth_context is None:
        return None

    try:
        user = store.get_record("users", auth_context.user_id)
    except LookupError:
        return None

    if record_organization_id("users", user) != auth_context.organization_id:
        return None
    if str(user.get("email", "")).strip().lower() != auth_context.email.lower():
        return None
    return auth_context


def scoped_organization_id(
    auth_context: AuthContext,
    requested_organization_id: Optional[str],
) -> str:
    requested = (requested_organization_id or "").strip()
    if requested and requested != auth_context.organization_id:
        raise PermissionError("Acces cross-organization interdit.")
    return auth_context.organization_id


def assert_same_organization(
    auth_context: AuthContext,
    organization_id: str,
) -> None:
    if organization_id != auth_context.organization_id:
        raise PermissionError("Acces cross-organization interdit.")


def prepare_resource_payload(resource: str, payload: dict) -> dict:
    normalized = dict(payload)
    if resource == "users":
        password = str(normalized.pop("password", "")).strip()
        if password:
            normalized["password_hash"] = hash_password(password)
    return normalized


def record_organization_id(resource: str, record: dict) -> str:
    if resource == "organizations":
        return str(
            record.get("organization_id") or record.get("id") or "",
        ).strip()
    return str(record.get("organization_id") or "").strip()


def public_user(record: dict) -> dict:
    sanitized = dict(record)
    sanitized.pop("password", None)
    sanitized.pop("password_hash", None)
    return sanitized


def public_record(resource: str, record: dict) -> dict:
    if resource == "users":
        return public_user(record)
    return dict(record)


def normalized_user_role(record: dict) -> str:
    role = str(record.get("role", "")).strip().lower()
    if role in {"admin", "manager", "technician"}:
        return role
    return "technician"


def can_manage_team(role: str) -> bool:
    return role in {"admin", "manager"}


class SyncV2Handler(BaseHTTPRequestHandler):
    server_version = "HydrAzurSyncV2/0.1"
    store: SQLiteSyncV2Store
    config: SyncV2Config
    rate_limiter: InMemoryRateLimiter

    def _public_user(self, record: dict) -> dict:
        return public_user(record)

    def handle_one_request(self):
        self._request_id = uuid4().hex
        self._request_started_at = time.monotonic()
        self._response_status_code = None
        self._response_size_bytes = 0
        try:
            super().handle_one_request()
        except BrokenPipeError:
            log_event(
                logging.WARNING,
                "request_connection_closed",
                requestId=self._request_id,
                method=getattr(self, "command", ""),
                path=getattr(self, "path", ""),
                clientIp=self._client_ip(),
            )
        except Exception as error:  # pragma: no cover - safety net
            self._handle_unexpected_error(error)
        finally:
            if getattr(self, "path", None):
                self._log_request()

    def send_response(self, code, message=None):
        self._response_status_code = int(code)
        super().send_response(code, message)

    def do_OPTIONS(self):
        self.send_response(HTTPStatus.NO_CONTENT)
        self._set_common_headers()
        self.end_headers()

    def do_GET(self):
        if self._request_path == "/health":
            self._send_json(
                HTTPStatus.OK,
                {
                    "status": "ok",
                    "service": "hydr-azur-sync-v2",
                    "environment": self.config.environment,
                },
            )
            return

        if self._request_path == "/v2/health":
            self._send_json(
                HTTPStatus.OK,
                {
                    "status": "ok",
                    "service": "hydr-azur-sync-v2",
                    "environment": self.config.environment,
                    "config": self.config.to_public_dict(),
                    "storage": self.store.healthcheck(),
                    "resources": sorted(RESOURCE_CONFIGS.keys()),
                },
            )
            return

        if self._request_path.startswith("/v2/public/share/"):
            self._handle_public_share_get()
            return

        if self._request_path == "/v2/auth/me":
            auth_context = self._require_auth()
            if auth_context is None:
                return
            organization = public_record(
                "organizations",
                self.store.get_record("organizations", auth_context.organization_id),
            )
            billing_snapshot = self.store.resolve_billing_snapshot(
                auth_context.organization_id,
            )
            self._send_json(
                HTTPStatus.OK,
                {
                    "data": {
                        "user": self._public_user(
                            self.store.get_record("users", auth_context.user_id),
                        ),
                        "organization": organization,
                        "subscription": billing_snapshot.get("subscription"),
                        "entitlements": billing_snapshot.get("entitlements", []),
                        "billing": billing_snapshot,
                    },
                },
            )
            return

        if self._request_path == "/v2/team/members":
            auth_context = self._require_auth()
            if auth_context is None:
                return
            try:
                members = [
                    public_user(item)
                    for item in self.store.list_organization_users(
                        auth_context.organization_id,
                    )
                ]
                self._send_json(
                    HTTPStatus.OK,
                    {
                        "data": members,
                        "count": len(members),
                    },
                )
            except PermissionError as error:
                self._send_json(HTTPStatus.FORBIDDEN, {"message": str(error)})
            return

        if self._request_path == "/v2/team/invitations":
            auth_context = self._require_auth()
            if auth_context is None:
                return
            try:
                self._require_team_management(auth_context)
                invitations = self.store.list_team_invitations(
                    auth_context.organization_id,
                )
                self._send_json(
                    HTTPStatus.OK,
                    {
                        "data": invitations,
                        "count": len(invitations),
                    },
                )
            except PermissionError as error:
                self._send_json(HTTPStatus.FORBIDDEN, {"message": str(error)})
            return

        if self._request_path == "/v2/account/export":
            auth_context = self._require_auth()
            if auth_context is None:
                return
            try:
                exported = self.store.export_account_bundle(
                    organization_id=auth_context.organization_id,
                    user_id=auth_context.user_id,
                )
                exported["user"] = public_user(exported["user"])
                exported["users"] = [
                    public_user(item) for item in exported.get("users", [])
                ]
                self._send_json(
                    HTTPStatus.OK,
                    {"data": exported},
                )
            except LookupError as error:
                self._send_json(HTTPStatus.NOT_FOUND, {"message": str(error)})
            except PermissionError as error:
                self._send_json(HTTPStatus.FORBIDDEN, {"message": str(error)})
            return

        if self._request_path == "/v2/billing/plans":
            auth_context = self._require_auth()
            if auth_context is None:
                return
            plans = self.store.list_global_plans()
            self._send_json(
                HTTPStatus.OK,
                {
                    "data": plans,
                    "count": len(plans),
                },
            )
            return

        if self._request_path == "/v2/billing/entitlements":
            auth_context = self._require_auth()
            if auth_context is None:
                return
            self._send_json(
                HTTPStatus.OK,
                {
                    "data": self.store.resolve_billing_snapshot(
                        auth_context.organization_id,
                    ),
                },
            )
            return

        if self._request_path == "/v2/media":
            auth_context = self._require_auth()
            if auth_context is None:
                return
            try:
                requested_organization_id = self._query_value("organization_id")
                organization_id = scoped_organization_id(
                    auth_context,
                    requested_organization_id,
                )
                updated_after = self._query_value("updated_after")
                data = self.store.list_media_attachments(
                    organization_id,
                    updated_after=updated_after,
                )
                self._send_json(
                    HTTPStatus.OK,
                    {
                        "data": data,
                        "count": len(data),
                    },
                )
                return
            except ValueError as error:
                self._send_json(HTTPStatus.BAD_REQUEST, {"message": str(error)})
                return
            except PermissionError as error:
                self._send_json(HTTPStatus.FORBIDDEN, {"message": str(error)})
                return

        if self._request_path.startswith("/v2/media/") and self._request_path.endswith("/download"):
            auth_context = self._require_auth()
            if auth_context is None:
                return
            parts = [part for part in self._request_path.split("/") if part]
            if len(parts) != 4:
                self._send_not_found()
                return
            attachment_id = parts[2]
            try:
                attachment = self.store.get_media_attachment(attachment_id)
                assert_same_organization(
                    auth_context,
                    str(attachment.get("organization_id", "")),
                )
                file_path = self.store.media_attachment_path(attachment)
                if not file_path.exists():
                    raise LookupError("Fichier media introuvable sur disque.")
                mime_type = (
                    str(attachment.get("mimeType", "")).strip()
                    or guess_type(file_path.name)[0]
                    or "application/octet-stream"
                )
                self._send_bytes(
                    HTTPStatus.OK,
                    file_path.read_bytes(),
                    content_type=mime_type,
                    file_name=str(attachment.get("originalFileName", "")).strip(),
                )
                return
            except LookupError as error:
                self._send_json(HTTPStatus.NOT_FOUND, {"message": str(error)})
                return
            except PermissionError as error:
                self._send_json(HTTPStatus.FORBIDDEN, {"message": str(error)})
                return

        parsed = self._parse_resource_request()
        if parsed is None:
            self._send_not_found()
            return

        resource, record_id = parsed
        auth_context = self._require_auth()
        if auth_context is None:
            return
        try:
            if resource == "users":
                self._require_team_management(auth_context)
            if record_id is None:
                requested_organization_id = self._query_value("organization_id")
                organization_id = scoped_organization_id(
                    auth_context,
                    requested_organization_id,
                )
                updated_after = self._query_value("updated_after")
                data = self.store.list_records(
                    resource,
                    organization_id,
                    updated_after=updated_after,
                )
                self._send_json(
                    HTTPStatus.OK,
                    {
                        "data": [
                            public_record(resource, item) for item in data
                        ],
                        "count": len(data),
                    },
                )
                return

            item = self.store.get_record(resource, record_id)
            assert_same_organization(
                auth_context,
                record_organization_id(resource, item),
            )
            self._send_json(
                HTTPStatus.OK,
                {"data": public_record(resource, item)},
            )
        except ValueError as error:
            self._send_json(HTTPStatus.BAD_REQUEST, {"message": str(error)})
        except LookupError as error:
            self._send_json(HTTPStatus.NOT_FOUND, {"message": str(error)})
        except PermissionError as error:
            self._send_json(HTTPStatus.FORBIDDEN, {"message": str(error)})

    def do_POST(self):
        if self._request_path == "/v2/auth/login":
            if self._enforce_rate_limit(
                RateLimitRule(
                    "auth_login",
                    self.config.login_rate_limit_count,
                    self.config.rate_limit_window_seconds,
                ),
            ):
                return
            self._handle_login()
            return

        if self._request_path == "/v2/public-links":
            auth_context = self._require_auth()
            if auth_context is None:
                return
            try:
                payload = self._read_json_body()
                created = self.store.create_public_share_link(
                    organization_id=auth_context.organization_id,
                    resource_type=self._required_string(payload, "resource_type"),
                    resource_id=self._required_string(payload, "resource_id"),
                    expires_at_iso=str(
                        payload.get("expires_at_iso")
                        or payload.get("expiresAtIso")
                        or ""
                    ).strip(),
                    created_by_user_id=auth_context.user_id,
                )
                self._send_json(
                    HTTPStatus.CREATED,
                    {
                        "message": "Lien de partage cree.",
                        "data": {
                            **created,
                            "publicUrl": self._public_share_url(created["token"]),
                        },
                    },
                )
                return
            except ValueError as error:
                self._send_json(HTTPStatus.BAD_REQUEST, {"message": str(error)})
                return
            except PermissionError as error:
                self._send_json(HTTPStatus.FORBIDDEN, {"message": str(error)})
                return

        if self._request_path == "/v2/team/invitations":
            auth_context = self._require_auth()
            if auth_context is None:
                return
            try:
                current_user = self._require_team_management(auth_context)
                payload = self._read_json_body()
                created = self.store.create_team_invitation(
                    organization_id=auth_context.organization_id,
                    email=self._required_string(payload, "email"),
                    full_name=str(
                        payload.get("full_name")
                        or payload.get("fullName")
                        or payload.get("name")
                        or ""
                    ).strip(),
                    role=str(payload.get("role", "technician")),
                    invited_by_user_id=str(current_user.get("id", "")),
                )
                self._send_json(
                    HTTPStatus.CREATED,
                    {
                        "message": "Invitation equipe creee.",
                        "data": created,
                    },
                )
                return
            except ValueError as error:
                self._send_json(HTTPStatus.BAD_REQUEST, {"message": str(error)})
                return
            except PermissionError as error:
                self._send_json(HTTPStatus.FORBIDDEN, {"message": str(error)})
                return

        if self._request_path == "/v2/admin/subscriptions/assign":
            if self._enforce_rate_limit(
                RateLimitRule(
                    "admin_assign_subscription",
                    self.config.admin_rate_limit_count,
                    self.config.rate_limit_window_seconds,
                ),
            ):
                return
            self._handle_admin_assign_subscription()
            return

        if self._request_path == "/v2/billing/events/subscription-updated":
            if self._enforce_rate_limit(
                RateLimitRule(
                    "billing_event",
                    self.config.admin_rate_limit_count,
                    self.config.rate_limit_window_seconds,
                ),
            ):
                return
            self._handle_billing_subscription_updated()
            return

        if self._request_path == "/v2/billing/trial/start":
            auth_context = self._require_auth()
            if auth_context is None:
                return
            try:
                payload = self._read_json_body()
                plan_id = validate_identifier(
                    str(payload.get("plan_id", "pro")).strip() or "pro",
                    "plan_id",
                )
                subscription = self.store.start_trial(
                    organization_id=auth_context.organization_id,
                    plan_id=plan_id,
                )
                snapshot = self.store.resolve_billing_snapshot(
                    auth_context.organization_id,
                )
                self._send_json(
                    HTTPStatus.OK,
                    {
                        "message": "Essai gratuit active.",
                        "data": {
                            "subscription": subscription,
                            "snapshot": snapshot,
                        },
                    },
                )
                return
            except ValueError as error:
                self._send_json(HTTPStatus.BAD_REQUEST, {"message": str(error)})
                return
            except PermissionError as error:
                self._send_json(HTTPStatus.FORBIDDEN, {"message": str(error)})
                return

        if self._request_path == "/v2/billing/mobile/reconcile":
            auth_context = self._require_auth()
            if auth_context is None:
                return
            try:
                payload = self._read_json_body()
                reconciled = self._handle_mobile_billing_reconcile(
                    auth_context,
                    payload,
                )
                self._send_json(
                    HTTPStatus.OK,
                    {
                        "message": "Abonnement mobile reconcilie.",
                        "data": reconciled,
                    },
                )
                return
            except ValueError as error:
                self._send_json(HTTPStatus.BAD_REQUEST, {"message": str(error)})
                return
            except PermissionError as error:
                self._send_json(HTTPStatus.FORBIDDEN, {"message": str(error)})
                return

        if self._request_path == "/v2/media/upload":
            if self._enforce_rate_limit(
                RateLimitRule(
                    "media_upload",
                    self.config.upload_rate_limit_count,
                    self.config.rate_limit_window_seconds,
                ),
            ):
                return
            auth_context = self._require_auth()
            if auth_context is None:
                return
            try:
                file_bytes = self._read_binary_body()
                payload = {
                    "id": self.headers.get("X-Attachment-Id", "").strip(),
                    "client_id": self.headers.get("X-Client-Id", "").strip(),
                    "intervention_id": self.headers.get(
                        "X-Intervention-Id",
                        "",
                    ).strip(),
                    "originalFileName": self.headers.get(
                        "X-File-Name",
                        "",
                    ).strip(),
                    "mimeType": self.headers.get("X-Mime-Type", "").strip(),
                    "createdAtIso": self.headers.get(
                        "X-Created-At-Iso",
                        "",
                    ).strip(),
                }
                payload["organization_id"] = scoped_organization_id(
                    auth_context,
                    self.headers.get("X-Organization-Id", "").strip() or None,
                )
                created = self.store.upsert_media_attachment(payload, file_bytes)
                self._send_json(
                    HTTPStatus.CREATED,
                    {
                        "message": "Media televerse.",
                        "data": created,
                    },
                )
                return
            except ValueError as error:
                self._send_json(HTTPStatus.BAD_REQUEST, {"message": str(error)})
                return
            except PermissionError as error:
                self._send_json(HTTPStatus.FORBIDDEN, {"message": str(error)})
                return

        parsed = self._parse_resource_request()
        if parsed is None or parsed[1] is not None:
            self._send_not_found()
            return

        resource, _ = parsed
        try:
            payload = self._read_json_body()
            auth_context = None
            if self._is_public_create(resource):
                if not self.config.allow_public_bootstrap:
                    raise PermissionError(
                        "Creation publique desactivee pour cet environnement.",
                    )
            else:
                auth_context = self._require_auth()
                if auth_context is None:
                    return
                if resource == "users":
                    self._require_team_management(auth_context)

            payload = prepare_resource_payload(resource, payload)
            if auth_context is not None:
                payload["organization_id"] = scoped_organization_id(
                    auth_context,
                    self._payload_organization_id(payload),
                )

            created = self.store.create_record(resource, payload)
            self._send_json(
                HTTPStatus.CREATED,
                {
                    "message": f"{resource} cree.",
                    "data": public_record(resource, created),
                },
            )
        except ValueError as error:
            self._send_json(HTTPStatus.BAD_REQUEST, {"message": str(error)})
        except sqlite3.IntegrityError as error:
            self._send_json(
                HTTPStatus.CONFLICT,
                {"message": _integrity_error_message(error)},
            )
        except ConflictError as error:
            self._send_json(
                HTTPStatus.CONFLICT,
                {
                    "message": str(error),
                    "data": public_record(resource, error.current_record)
                    if error.current_record
                    else None,
                },
            )
        except PermissionError as error:
            self._send_json(HTTPStatus.FORBIDDEN, {"message": str(error)})

    def do_PUT(self):
        parsed = self._parse_resource_request()
        if parsed is None or parsed[1] is None:
            self._send_not_found()
            return

        resource, record_id = parsed
        auth_context = self._require_auth()
        if auth_context is None:
            return
        try:
            if resource == "users":
                self._require_team_management(auth_context)
            payload = self._read_json_body()
            existing = self.store.get_record(resource, record_id)
            assert_same_organization(
                auth_context,
                record_organization_id(resource, existing),
            )
            payload = prepare_resource_payload(resource, payload)
            requested_organization_id = self._payload_organization_id(payload)
            payload["organization_id"] = scoped_organization_id(
                auth_context,
                requested_organization_id or existing.get("organization_id"),
            )
            updated = self.store.update_record(resource, record_id, payload)
            self._send_json(
                HTTPStatus.OK,
                {
                    "message": f"{resource} mis a jour.",
                    "data": public_record(resource, updated),
                },
            )
        except ValueError as error:
            self._send_json(HTTPStatus.BAD_REQUEST, {"message": str(error)})
        except LookupError as error:
            self._send_json(HTTPStatus.NOT_FOUND, {"message": str(error)})
        except sqlite3.IntegrityError as error:
            self._send_json(
                HTTPStatus.CONFLICT,
                {"message": _integrity_error_message(error)},
            )
        except ConflictError as error:
            self._send_json(
                HTTPStatus.CONFLICT,
                {
                    "message": str(error),
                    "data": public_record(resource, error.current_record)
                    if error.current_record
                    else None,
                },
            )
        except PermissionError as error:
            self._send_json(HTTPStatus.FORBIDDEN, {"message": str(error)})

    def do_DELETE(self):
        if self._request_path == "/v2/account/me":
            if self._enforce_rate_limit(
                RateLimitRule(
                    "account_delete",
                    self.config.destructive_rate_limit_count,
                    self.config.rate_limit_window_seconds,
                ),
            ):
                return
            auth_context = self._require_auth()
            if auth_context is None:
                return
            try:
                result = self.store.delete_account(
                    organization_id=auth_context.organization_id,
                    user_id=auth_context.user_id,
                )
                self._send_json(
                    HTTPStatus.OK,
                    {
                        "message": "Compte supprime.",
                        "data": result,
                    },
                )
            except LookupError as error:
                self._send_json(HTTPStatus.NOT_FOUND, {"message": str(error)})
            except PermissionError as error:
                self._send_json(HTTPStatus.FORBIDDEN, {"message": str(error)})
            return

        parsed = self._parse_resource_request()
        if parsed is None or parsed[1] is None:
            self._send_not_found()
            return

        resource, record_id = parsed
        auth_context = self._require_auth()
        if auth_context is None:
            return
        try:
            if resource == "users":
                self._require_team_management(auth_context)
            existing = self.store.get_record(resource, record_id)
            assert_same_organization(
                auth_context,
                record_organization_id(resource, existing),
            )
            if resource in {"clients", "interventions", "financial_documents"}:
                deleted = self.store.soft_delete_record(resource, record_id)
                self._send_json(
                    HTTPStatus.OK,
                    {
                        "message": f"{resource} supprime logiquement.",
                        "data": public_record(resource, deleted),
                    },
                )
                return

            self.store.delete_record(resource, record_id)
            self._send_json(
                HTTPStatus.OK,
                {"message": f"{resource} supprime."},
            )
        except LookupError as error:
            self._send_json(HTTPStatus.NOT_FOUND, {"message": str(error)})
        except sqlite3.IntegrityError as error:
            self._send_json(
                HTTPStatus.CONFLICT,
                {"message": _integrity_error_message(error)},
            )
        except ConflictError as error:
            self._send_json(
                HTTPStatus.CONFLICT,
                {
                    "message": str(error),
                    "data": public_record(resource, error.current_record)
                    if error.current_record
                    else None,
                },
            )
        except PermissionError as error:
            self._send_json(HTTPStatus.FORBIDDEN, {"message": str(error)})

    def log_message(self, format, *args):
        return

    @property
    def _request_path(self) -> str:
        return urlparse(self.path).path.rstrip("/") or "/"

    def _parse_resource_request(self) -> Optional[Tuple[str, Optional[str]]]:
        path = self._request_path
        if not path.startswith("/v2/"):
            return None

        parts = [part for part in path.split("/") if part]
        if len(parts) < 2:
            return None
        if parts[0] != "v2":
            return None

        resource = RESOURCE_ALIASES.get(parts[1])
        if resource is None:
            return None

        record_id = parts[2] if len(parts) >= 3 else None
        if len(parts) > 3:
            return None
        return resource, record_id

    def _query_value(self, key: str) -> Optional[str]:
        values = parse_qs(urlparse(self.path).query).get(key)
        if not values:
            return None
        value = values[0].strip()
        return value or None

    def _read_json_body(self) -> dict:
        content_length = int(self.headers.get("Content-Length", "0"))
        if content_length <= 0:
            raise ValueError("Le body JSON est vide.")
        if content_length > self.config.max_json_bytes:
            raise ValueError("Le body JSON depasse la taille maximale autorisee.")
        raw = self.rfile.read(content_length).decode("utf-8")
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError as error:
            raise ValueError(f"JSON invalide: {error.msg}") from error
        if not isinstance(payload, dict):
            raise ValueError("Le body JSON doit etre un objet.")
        return payload

    def _read_binary_body(self) -> bytes:
        content_length = int(self.headers.get("Content-Length", "0"))
        if content_length <= 0:
            raise ValueError("Le body binaire est vide.")
        if content_length > self.config.max_upload_bytes:
            raise ValueError("Le fichier depasse la taille maximale autorisee.")
        return self.rfile.read(content_length)

    def _handle_login(self):
        try:
            payload = self._read_json_body()
            raw_organization_id = str(
                payload.get("organization_id")
                or payload.get("organizationId")
                or "",
            ).strip()
            organization_id = (
                validate_identifier(raw_organization_id, "organization_id")
                if raw_organization_id
                else ""
            )
            email = validate_email(self._required_string(payload, "email"))
            password = self._required_string(payload, "password")

            token, user = authenticate_user(
                self.store,
                organization_id=organization_id,
                email=email,
                password=password,
            )
            self._send_json(
                HTTPStatus.OK,
                {
                    "message": "Connexion reussie.",
                    "data": {
                        "token": token,
                        "user": public_user(user),
                    },
                },
            )
        except LookupError:
            self._send_json(
                HTTPStatus.UNAUTHORIZED,
                {"message": "Email, mot de passe ou organisation invalides."},
            )
        except PermissionError as error:
            self._send_json(HTTPStatus.UNAUTHORIZED, {"message": str(error)})
        except ValueError as error:
            self._send_json(HTTPStatus.BAD_REQUEST, {"message": str(error)})

    def _handle_admin_assign_subscription(self):
        try:
            self._require_admin_token()
            payload = self._read_json_body()
            organization_id = validate_identifier(
                self._required_string(payload, "organization_id"),
                "organization_id",
            )
            plan_id = validate_identifier(
                self._required_string(payload, "plan_id"),
                "plan_id",
            )
            status = str(payload.get("status", "active")).strip() or "active"
            started_at_iso = validate_optional_iso_datetime(
                str(payload.get("started_at_iso", "")).strip(),
                "started_at_iso",
            )
            ended_at_iso = validate_optional_iso_datetime(
                str(payload.get("ended_at_iso", "")).strip(),
                "ended_at_iso",
            )

            subscription = self.store.assign_subscription(
                organization_id=organization_id,
                plan_id=plan_id,
                status=status,
                started_at_iso=started_at_iso,
                ended_at_iso=ended_at_iso,
            )
            snapshot = self.store.resolve_billing_snapshot(organization_id)
            self._send_json(
                HTTPStatus.OK,
                {
                    "message": "Subscription affectee manuellement.",
                    "data": {
                        "subscription": subscription,
                        "snapshot": snapshot,
                    },
                },
            )
        except PermissionError as error:
            self._send_json(HTTPStatus.FORBIDDEN, {"message": str(error)})
        except ValueError as error:
            self._send_json(HTTPStatus.BAD_REQUEST, {"message": str(error)})

    def _handle_billing_subscription_updated(self):
        try:
            self._require_admin_token()
            payload = self._read_json_body()
            event_payload = (
                payload["data"] if isinstance(payload.get("data"), dict) else payload
            )
            organization_id = validate_identifier(
                self._required_string(
                    event_payload,
                    "organization_id",
                ),
                "organization_id",
            )
            plan_id = validate_identifier(
                self._required_string(event_payload, "plan_id"),
                "plan_id",
            )
            status = str(event_payload.get("status", "active")).strip() or "active"
            started_at_iso = validate_optional_iso_datetime(
                str(
                    event_payload.get("started_at_iso")
                    or event_payload.get("current_period_start")
                    or ""
                ).strip(),
                "started_at_iso",
            )
            ended_at_iso = validate_optional_iso_datetime(
                str(
                    event_payload.get("ended_at_iso")
                    or event_payload.get("current_period_end")
                    or ""
                ).strip(),
                "ended_at_iso",
            )

            subscription = self.store.assign_subscription(
                organization_id=organization_id,
                plan_id=plan_id,
                status=status,
                started_at_iso=started_at_iso,
                ended_at_iso=ended_at_iso,
                extra_payload={
                    "source": "billing_event",
                    "provider": str(event_payload.get("provider", "")).strip(),
                    "externalCustomerId": str(
                        event_payload.get("external_customer_id")
                        or event_payload.get("externalCustomerId")
                        or ""
                    ).strip(),
                    "externalSubscriptionId": str(
                        event_payload.get("external_subscription_id")
                        or event_payload.get("externalSubscriptionId")
                        or ""
                    ).strip(),
                    "billingEventType": str(
                        event_payload.get("event_type")
                        or event_payload.get("billingEventType")
                        or ""
                    ).strip(),
                },
            )
            snapshot = self.store.resolve_billing_snapshot(organization_id)
            self._send_json(
                HTTPStatus.OK,
                {
                    "message": "Evenement billing applique.",
                    "data": {
                        "subscription": subscription,
                        "snapshot": snapshot,
                    },
                },
            )
        except PermissionError as error:
            self._send_json(HTTPStatus.FORBIDDEN, {"message": str(error)})
        except ValueError as error:
            self._send_json(HTTPStatus.BAD_REQUEST, {"message": str(error)})

    def _handle_public_share_get(self):
        parts = [part for part in self._request_path.split("/") if part]
        if len(parts) < 4 or parts[0] != "v2" or parts[1] != "public" or parts[2] != "share":
            self._send_not_found()
            return

        token = parts[3]
        try:
            payload = self.store.resolve_public_share_payload(token)
            if len(parts) == 4:
                html = self._render_public_share_html(payload)
                self._send_bytes(
                    HTTPStatus.OK,
                    html.encode("utf-8"),
                    content_type="text/html; charset=utf-8",
                )
                return

            if (
                len(parts) == 6
                and parts[4] == "media"
                and _string_value(payload["link"], "resourceType") == "intervention"
            ):
                attachment_id = parts[5]
                attachments = payload.get("attachments", [])
                if not any(
                    _string_value(item, "id") == attachment_id for item in attachments
                ):
                    raise PermissionError("Ce media n est pas autorise par le lien.")
                attachment = self.store.get_media_attachment(attachment_id)
                file_path = self.store.media_attachment_path(attachment)
                if not file_path.exists():
                    raise LookupError("Fichier media introuvable sur disque.")
                mime_type = (
                    str(attachment.get("mimeType", "")).strip()
                    or guess_type(file_path.name)[0]
                    or "application/octet-stream"
                )
                self._send_bytes(
                    HTTPStatus.OK,
                    file_path.read_bytes(),
                    content_type=mime_type,
                    file_name=str(attachment.get("originalFileName", "")).strip(),
                )
                return

            self._send_not_found()
        except LookupError as error:
            self._send_json(HTTPStatus.NOT_FOUND, {"message": str(error)})
        except PermissionError as error:
            message = str(error)
            status = HTTPStatus.GONE if "expire" in message.lower() else HTTPStatus.FORBIDDEN
            self._send_json(status, {"message": message})

    def _public_share_url(self, token: str) -> str:
        default_host = f"{self.server.server_address[0]}:{self.server.server_address[1]}"
        host = self.headers.get("Host", "").strip() or default_host
        scheme = "https" if self.headers.get("X-Forwarded-Proto", "").strip() == "https" else "http"
        return f"{scheme}://{host}/v2/public/share/{token}"

    def _render_public_share_html(self, payload: dict) -> str:
        link = payload["link"]
        organization = payload["organization"]
        resource = payload["resource"]
        resource_type = _string_value(link, "resourceType")
        title = (
            f"Intervention - {_string_value(resource, 'dateLabel', 'createdAtIso')}"
            if resource_type == "intervention"
            else f"{_string_value(resource, 'title', 'documentNumber')}"
        )
        return f"""<!doctype html>
<html lang="fr">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{escape(title)}</title>
    <style>
      body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 0; background: #f4f7f9; color: #101828; }}
      .wrap {{ max-width: 840px; margin: 0 auto; padding: 24px; }}
      .card {{ background: #fff; border: 1px solid #e4e7ec; border-radius: 20px; padding: 24px; box-shadow: 0 8px 24px rgba(16,24,40,0.06); }}
      .eyebrow {{ color: #0f6e7c; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; font-size: 12px; }}
      h1 {{ margin: 8px 0 6px; font-size: 28px; }}
      h2 {{ margin-top: 28px; font-size: 18px; }}
      p, li {{ line-height: 1.55; }}
      .meta {{ color: #475467; margin-bottom: 18px; }}
      .pill {{ display: inline-block; padding: 6px 10px; border-radius: 999px; background: #ecfdf3; color: #027a48; font-weight: 700; font-size: 12px; }}
      .grid {{ display: grid; gap: 12px; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); }}
      .box {{ background: #f9fafb; border-radius: 16px; padding: 14px; border: 1px solid #eaecf0; }}
      .photos {{ display: grid; gap: 12px; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); }}
      .photos img {{ width: 100%; border-radius: 14px; border: 1px solid #d0d5dd; object-fit: cover; max-height: 220px; }}
      table {{ width: 100%; border-collapse: collapse; margin-top: 12px; }}
      th, td {{ text-align: left; padding: 10px 8px; border-bottom: 1px solid #eaecf0; }}
      th {{ color: #475467; font-size: 12px; text-transform: uppercase; letter-spacing: .04em; }}
      .totals {{ margin-top: 16px; }}
      .totals div {{ display: flex; justify-content: space-between; padding: 6px 0; }}
      .signature img {{ max-width: 260px; border: 1px solid #d0d5dd; border-radius: 12px; background: white; }}
      .footer {{ margin-top: 18px; color: #667085; font-size: 12px; }}
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="card">
        {self._render_public_share_body(organization, link, resource, payload.get("attachments", []))}
      </div>
    </div>
  </body>
</html>"""

    def _render_public_share_body(self, organization: dict, link: dict, resource: dict, attachments: list[dict]) -> str:
        resource_type = _string_value(link, "resourceType")
        company_name = escape(
            _string_value(
                organization,
                "companyName",
                "name",
            )
            or "HydrAzur Pro",
        )
        expires_at = _string_value(link, "expiresAtIso")
        expiration_block = (
            f'<div class="footer">Lien valable jusqu au {escape(expires_at)}</div>'
            if expires_at
            else '<div class="footer">Lien sans expiration definie.</div>'
        )
        if resource_type == "intervention":
            return self._render_public_intervention_body(
                company_name,
                resource,
                attachments,
                token=_string_value(link, "token"),
                expiration_block=expiration_block,
            )
        return self._render_public_financial_document_body(
            company_name,
            resource,
            expiration_block=expiration_block,
        )

    def _render_public_intervention_body(self, company_name: str, resource: dict, attachments: list[dict], *, token: str, expiration_block: str) -> str:
        photo_blocks = "".join(
            f'<img src="{escape(self._public_share_url(token) + "/media/" + _string_value(item, "id"))}" alt="Photo intervention" />'
            for item in attachments
        )
        signature = _string_value(resource, "signatureBase64")
        signature_block = (
            f'<div class="signature"><h2>Signature</h2><img src="data:image/png;base64,{escape(signature)}" alt="Signature" /></div>'
            if signature
            else ""
        )
        status_label = "Intervention realisee" if bool(resource.get("interventionCompleted")) else "Intervention a suivre"
        return f"""
        <div class="eyebrow">Rapport partage</div>
        <h1>{company_name}</h1>
        <p class="meta">{escape(_string_value(resource, "dateLabel"))} • {escape(status_label)}</p>
        <div class="pill">Lecture seule</div>
        <div class="grid">
          <div class="box"><strong>Technicien</strong><br />{escape(_string_value(resource, "technicianName"))}</div>
          <div class="box"><strong>Representant client</strong><br />{escape(_string_value(resource, "clientRepresentative"))}</div>
          <div class="box"><strong>Bassin</strong><br />{escape(_string_value(resource, "poolSummary"))}</div>
          <div class="box"><strong>Suivi</strong><br />{escape(_string_value(resource, "followUpLabel"))}</div>
        </div>
        <h2>Compte rendu</h2>
        <p>{escape(_string_value(resource, "interventionSummary")).replace(chr(10), "<br />")}</p>
        <h2>Recommandations</h2>
        <p>{escape(_string_value(resource, "recommendations")).replace(chr(10), "<br />")}</p>
        <h2>Acces et remarques</h2>
        <p>{escape(_string_value(resource, "accessNotes")).replace(chr(10), "<br />")}</p>
        {'<h2>Photos</h2><div class="photos">' + photo_blocks + '</div>' if photo_blocks else ''}
        {signature_block}
        {expiration_block}
        """

    def _render_public_financial_document_body(self, company_name: str, resource: dict, *, expiration_block: str) -> str:
        items = resource.get("items") if isinstance(resource.get("items"), list) else []
        subtotal = 0.0
        rows = "".join(
            self._render_public_financial_document_row(item)
            for item in items
            if isinstance(item, dict)
        )
        for item in items:
            if not isinstance(item, dict):
                continue
            quantity = float(item.get("quantity") or 0)
            unit_price = float(item.get("unitPrice") or 0)
            subtotal += quantity * unit_price
        tax_rate = float(resource.get("taxRate") or resource.get("vatRate") or 0)
        tax_amount = subtotal * (tax_rate / 100)
        total = subtotal + tax_amount
        deposit_amount = float(resource.get("depositAmount") or 0)
        amount_due = max(total - deposit_amount, 0)
        return f"""
        <div class="eyebrow">Document partage</div>
        <h1>{company_name}</h1>
        <p class="meta">{escape(_string_value(resource, 'title'))} • {escape(_string_value(resource, 'documentNumber'))}</p>
        <div class="pill">Lecture seule</div>
        <div class="grid">
          <div class="box"><strong>Date</strong><br />{escape(_string_value(resource, "dateLabel", "issuedAtIso"))}</div>
          <div class="box"><strong>Echeance</strong><br />{escape(_string_value(resource, "dueDateLabel", "dueAtIso"))}</div>
          <div class="box"><strong>Type</strong><br />{escape(_string_value(resource, "type"))}</div>
          <div class="box"><strong>Technicien</strong><br />{escape(_string_value(resource, "technicianName"))}</div>
        </div>
        <h2>Lignes</h2>
        <table>
          <thead>
            <tr><th>Libelle</th><th>Qté</th><th>PU</th><th>Total</th></tr>
          </thead>
          <tbody>{rows}</tbody>
        </table>
        <div class="totals">
          <div><span>Sous-total</span><strong>{escape(f"{subtotal:.2f}")}</strong></div>
          <div><span>{escape(_string_value(resource, "taxLabel"))}</span><strong>{escape(f"{tax_amount:.2f}")}</strong></div>
          <div><span>Total</span><strong>{escape(f"{total:.2f}")}</strong></div>
          <div><span>Reste du</span><strong>{escape(f"{amount_due:.2f}")}</strong></div>
        </div>
        <h2>Notes</h2>
        <p>{escape(_string_value(resource, "notes")).replace(chr(10), "<br />")}</p>
        {expiration_block}
        """

    def _render_public_financial_document_row(self, item: dict) -> str:
        quantity = float(item.get("quantity") or 0)
        unit_price = float(item.get("unitPrice") or 0)
        line_total = quantity * unit_price
        return (
            f"<tr><td>{escape(str(item.get('label', '')))}</td>"
            f"<td>{escape(str(item.get('quantity', '')))}</td>"
            f"<td>{escape(str(item.get('unitPrice', '')))}</td>"
            f"<td>{escape(f'{line_total:.2f}')}</td></tr>"
        )

    def _handle_mobile_billing_reconcile(
        self,
        auth_context: AuthContext,
        payload: dict,
    ) -> dict:
        provider = self._required_string(payload, "provider").strip().lower()
        if provider not in {"app_store", "play_store"}:
            raise ValueError("provider doit valoir app_store ou play_store.")

        purchases = payload.get("purchases")
        if not isinstance(purchases, list) or not purchases:
            raise ValueError("purchases doit contenir au moins un achat.")

        active_purchase = None
        transactions = []
        for raw_purchase in purchases:
            if not isinstance(raw_purchase, dict):
                raise ValueError("Chaque achat mobile doit etre un objet JSON.")
            product_id = validate_identifier(
                self._required_string(raw_purchase, "productId"),
                "productId",
            )
            purchase_id = validate_identifier(
                self._required_string(raw_purchase, "purchaseId"),
                "purchaseId",
            )
            platform = str(raw_purchase.get("platform", "")).strip().lower()
            if platform not in {"ios", "android"}:
                raise ValueError("platform doit valoir ios ou android.")
            purchase_status = str(raw_purchase.get("status", "")).strip().lower()
            if purchase_status not in {
                "purchased",
                "restored",
                "pending",
                "cancelled",
                "error",
            }:
                raise ValueError("status achat mobile invalide.")
            purchased_at_iso = validate_optional_iso_datetime(
                str(raw_purchase.get("transactionDateIso", "")).strip(),
                "transactionDateIso",
            ) or _utc_now_compact_iso()
            plan_id = _plan_id_for_mobile_product(self.config, product_id)
            original_purchase_id = str(
                raw_purchase.get("originalPurchaseId")
                or raw_purchase.get("originalPurchaseId".lower())
                or ""
            ).strip()

            transaction = self.store.upsert_billing_transaction(
                organization_id=auth_context.organization_id,
                user_id=auth_context.user_id,
                provider=provider,
                platform=platform,
                product_id=product_id,
                plan_id=plan_id,
                purchase_id=purchase_id,
                original_purchase_id=original_purchase_id,
                purchase_status=purchase_status,
                purchased_at_iso=purchased_at_iso,
                raw_payload=raw_purchase,
            )
            transactions.append(transaction)

            if purchase_status in {"purchased", "restored"}:
                if active_purchase is None or purchased_at_iso > str(
                    active_purchase["purchasedAtIso"],
                ):
                    active_purchase = transaction

        if active_purchase is None:
            raise ValueError(
                "Aucun achat actif achete/restaure n a ete fourni pour la reconciliation.",
            )

        subscription = self.store.assign_subscription(
            organization_id=auth_context.organization_id,
            plan_id=str(active_purchase["planId"]),
            status="active",
            started_at_iso=str(active_purchase["purchasedAtIso"]),
            extra_payload={
                "source": "mobile_billing",
                "provider": provider,
                "platform": str(active_purchase["platform"]),
                "productId": str(active_purchase["productId"]),
                "purchaseId": str(active_purchase["purchaseId"]),
                "originalPurchaseId": str(
                    active_purchase.get("originalPurchaseId", ""),
                ),
                "validationStatus": "client_reconciled_pending_store_server_validation",
                "updatedByUserId": auth_context.user_id,
            },
        )
        snapshot = self.store.resolve_billing_snapshot(auth_context.organization_id)
        return {
            "subscription": subscription,
            "snapshot": snapshot,
            "reconciliation": {
                "provider": provider,
                "acceptedPurchases": len(transactions),
                "activePurchaseId": active_purchase["purchaseId"],
                "planId": active_purchase["planId"],
            },
        }

    def _require_auth(self) -> Optional[AuthContext]:
        auth_context = self._parse_auth_context()
        if auth_context is None:
            self._send_json(
                HTTPStatus.UNAUTHORIZED,
                {"message": "Authentification requise."},
            )
            return None
        return auth_context

    def _parse_auth_context(self) -> Optional[AuthContext]:
        return resolve_auth_context(
            self.store,
            self.headers.get("Authorization", ""),
        )

    def _current_user_record(self, auth_context: AuthContext) -> dict:
        user = self.store.get_record("users", auth_context.user_id)
        assert_same_organization(
            auth_context,
            record_organization_id("users", user),
        )
        return user

    def _require_team_management(self, auth_context: AuthContext) -> dict:
        user = self._current_user_record(auth_context)
        if not can_manage_team(normalized_user_role(user)):
            raise PermissionError(
                "Permissions insuffisantes: admin ou manager requis.",
            )
        return user

    def _payload_organization_id(self, payload: dict) -> str:
        return str(
            payload.get("organization_id") or payload.get("organizationId") or "",
        ).strip()

    def _required_string(self, payload: dict, key: str) -> str:
        value = str(payload.get(key, "")).strip()
        if not value:
            raise ValueError(f"{key} est obligatoire.")
        return value

    def _is_public_create(self, resource: str) -> bool:
        return resource in {"organizations", "users"}

    def _require_admin_token(self) -> None:
        provided = self.headers.get("X-Admin-Token", "").strip()
        if not self.config.admin_token.strip() or provided != self.config.admin_token:
            raise PermissionError("Token admin invalide.")

    def _set_common_headers(self):
        self.send_header("Access-Control-Allow-Origin", self._allowed_origin())
        self.send_header(
            "Access-Control-Allow-Headers",
            "Content-Type, Authorization, x-api-key, "
            "X-Admin-Token, "
            "X-Attachment-Id, X-Client-Id, X-Intervention-Id, X-File-Name, "
            "X-Mime-Type, X-Created-At-Iso, X-Organization-Id",
        )
        self.send_header(
            "Access-Control-Allow-Methods",
            "GET, POST, PUT, DELETE, OPTIONS",
        )
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Request-Id", self._request_id)

    def _send_json(self, status: HTTPStatus, payload: dict):
        if int(status) >= 400 and "requestId" not in payload:
            payload = {**payload, "requestId": self._request_id}
        body = json.dumps(payload).encode("utf-8")
        self._response_size_bytes = len(body)
        self.send_response(status)
        self._set_common_headers()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_bytes(
        self,
        status: HTTPStatus,
        body: bytes,
        *,
        content_type: str,
        file_name: str = "",
    ):
        self._response_size_bytes = len(body)
        self.send_response(status)
        self._set_common_headers()
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        if file_name:
            self.send_header(
                "Content-Disposition",
                f'inline; filename="{file_name}"',
            )
        self.end_headers()
        self.wfile.write(body)

    def _send_not_found(self):
        self._send_json(HTTPStatus.NOT_FOUND, {"message": "Route inconnue."})

    def _allowed_origin(self) -> str:
        allowed_origins = self.config.allowed_origins
        if "*" in allowed_origins:
            return "*"
        request_origin = self.headers.get("Origin", "").strip()
        if request_origin and request_origin in allowed_origins:
            return request_origin
        return allowed_origins[0] if allowed_origins else "null"

    def _client_ip(self) -> str:
        forwarded = self.headers.get("X-Forwarded-For", "").strip()
        if forwarded:
            return forwarded.split(",")[0].strip()
        return str(self.client_address[0]) if self.client_address else "unknown"

    def _rate_limit_key(self, rule: RateLimitRule) -> str:
        return f"{rule.name}:{self._client_ip()}"

    def _enforce_rate_limit(self, rule: RateLimitRule) -> bool:
        allowed, retry_after = self.rate_limiter.check(
            self._rate_limit_key(rule),
            rule,
        )
        if allowed:
            return False
        self.send_response(HTTPStatus.TOO_MANY_REQUESTS)
        self._set_common_headers()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Retry-After", str(retry_after))
        payload = {
            "message": "Trop de requetes, reessayez plus tard.",
            "requestId": self._request_id,
            "retryAfterSeconds": retry_after,
        }
        body = json.dumps(payload).encode("utf-8")
        self._response_size_bytes = len(body)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
        log_event(
            logging.WARNING,
            "request_rate_limited",
            requestId=self._request_id,
            method=getattr(self, "command", ""),
            path=self._request_path,
            clientIp=self._client_ip(),
            rule=rule.name,
            retryAfterSeconds=retry_after,
        )
        return True

    def _handle_unexpected_error(self, error: Exception) -> None:
        log_event(
            logging.ERROR,
            "request_unhandled_exception",
            requestId=self._request_id,
            method=getattr(self, "command", ""),
            path=getattr(self, "path", ""),
            clientIp=self._client_ip(),
            errorType=type(error).__name__,
            errorMessage=str(error),
            traceback=traceback.format_exc(),
        )
        if not getattr(self, "wfile", None):
            return
        try:
            self._send_json(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                {"message": "Erreur interne du serveur."},
            )
        except Exception:
            pass

    def _log_request(self) -> None:
        try:
            auth_context = self._parse_auth_context()
        except Exception:
            auth_context = None
        duration_ms = round(
            max(0.0, time.monotonic() - getattr(self, "_request_started_at", time.monotonic()))
            * 1000,
            2,
        )
        log_event(
            logging.INFO,
            "http_request",
            requestId=self._request_id,
            method=getattr(self, "command", ""),
            path=self._request_path,
            query=urlparse(self.path).query if getattr(self, "path", "") else "",
            status=self._response_status_code or 0,
            durationMs=duration_ms,
            responseBytes=self._response_size_bytes,
            clientIp=self._client_ip(),
            organizationId=auth_context.organization_id if auth_context else "",
            userId=auth_context.user_id if auth_context else "",
        )


def _integrity_error_message(error: sqlite3.IntegrityError) -> str:
    raw = str(error).lower()
    if "foreign key" in raw:
        return "organization_id inconnu ou relation invalide."
    if "unique" in raw:
        return "Conflit de cle unique sur la ressource."
    return f"Conflit SQLite: {error}"


def _plan_id_for_mobile_product(config: SyncV2Config, product_id: str) -> str:
    normalized = product_id.strip()
    if normalized in {
        config.billing_ios_pro_product_id,
        config.billing_android_pro_product_id,
    }:
        return "pro"
    raise ValueError("productId mobile inconnu pour la configuration backend.")


def _utc_now_compact_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def build_server(
    host: Optional[str] = None,
    port: Optional[int] = None,
    db_path: Optional[Union[Path, str]] = None,
    config: Optional[SyncV2Config] = None,
) -> ThreadingHTTPServer:
    resolved_config = config or DEFAULT_CONFIG
    resolved_config.validate_or_raise()
    resolved_host = resolved_config.host if host is None else host
    resolved_port = resolved_config.port if port is None else port
    resolved_db_path = resolved_config.db_path if db_path is None else db_path
    store = SQLiteSyncV2Store(
        resolved_db_path,
        media_dir=resolved_config.media_dir,
        sqlite_busy_timeout_ms=resolved_config.sqlite_busy_timeout_ms,
        pro_trial_days=resolved_config.pro_trial_days,
    )
    store.initialize()

    handler = type(
        "ConfiguredSyncV2Handler",
        (SyncV2Handler,),
        {
            "store": store,
            "config": resolved_config,
            "rate_limiter": InMemoryRateLimiter(),
        },
    )
    return ThreadingHTTPServer((resolved_host, resolved_port), handler)


def main():
    configure_logging(DEFAULT_CONFIG.log_level)
    server = build_server(config=DEFAULT_CONFIG)
    log_event(
        logging.INFO,
        "server_started",
        environment=DEFAULT_CONFIG.environment,
        host=DEFAULT_CONFIG.host,
        port=DEFAULT_CONFIG.port,
        dbPath=str(DEFAULT_CONFIG.db_path),
        mediaDir=str(DEFAULT_CONFIG.media_dir),
        allowPublicBootstrap=DEFAULT_CONFIG.allow_public_bootstrap,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log_event(logging.INFO, "server_stopped", reason="keyboard_interrupt")
    finally:
        server.server_close()
