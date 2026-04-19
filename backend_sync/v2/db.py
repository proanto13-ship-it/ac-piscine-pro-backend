import json
import mimetypes
import secrets
import shutil
import sqlite3
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterator, Optional, Union
from uuid import uuid4

from .validation import (
    sanitize_filename,
    validate_email,
    validate_identifier,
    validate_mime_type,
    validate_optional_identifier,
    validate_optional_iso_datetime,
)

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
DEFAULT_DB_PATH = DATA_DIR / "sync_v2_dev.sqlite3"
MEDIA_DIR = DATA_DIR / "media"
SCHEMA_VERSION = 2


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


@dataclass(frozen=True)
class ResourceConfig:
    table_name: str
    summary_fields: tuple[str, ...]


class ConflictError(ValueError):
    def __init__(self, message: str, *, current_record: Optional[dict] = None):
        super().__init__(message)
        self.current_record = current_record


RESOURCE_CONFIGS = {
    "organizations": ResourceConfig("organizations", ("name",)),
    "users": ResourceConfig("users", ("email", "full_name", "role")),
    "clients": ResourceConfig("clients", ("display_name",)),
    "plans": ResourceConfig("plans", ("display_name", "client_limit")),
    "subscriptions": ResourceConfig("subscriptions", ("plan_id", "status")),
    "entitlements": ResourceConfig("entitlements", ("flag", "enabled")),
    "interventions": ResourceConfig(
        "interventions",
        ("client_id", "scheduled_at_iso", "status"),
    ),
    "financial_documents": ResourceConfig(
        "financial_documents",
        ("client_id", "document_number", "document_type", "status"),
    ),
}


class SQLiteSyncV2Store:
    def __init__(
        self,
        db_path: Union[Path, str] = DEFAULT_DB_PATH,
        media_dir: Optional[Union[Path, str]] = None,
        sqlite_busy_timeout_ms: int = 5000,
        pro_trial_days: int = 0,
    ):
        self.db_path = Path(db_path)
        self.media_dir = (
            Path(media_dir) if media_dir is not None else self.db_path.parent / "media"
        )
        self.sqlite_busy_timeout_ms = max(1000, int(sqlite_busy_timeout_ms))
        self.pro_trial_days = max(0, int(pro_trial_days))

    def initialize(self) -> None:
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self.media_dir.mkdir(parents=True, exist_ok=True)
        with self.connection() as conn:
            conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS organizations (
                    id TEXT PRIMARY KEY,
                    organization_id TEXT NOT NULL UNIQUE,
                    name TEXT NOT NULL DEFAULT '',
                    created_at_iso TEXT NOT NULL,
                    updated_at_iso TEXT NOT NULL,
                    payload_json TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS users (
                    id TEXT PRIMARY KEY,
                    organization_id TEXT NOT NULL,
                    email TEXT NOT NULL DEFAULT '',
                    full_name TEXT NOT NULL DEFAULT '',
                    role TEXT NOT NULL DEFAULT '',
                    created_at_iso TEXT NOT NULL,
                    updated_at_iso TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    FOREIGN KEY (organization_id) REFERENCES organizations (organization_id)
                );

                CREATE TABLE IF NOT EXISTS team_invitations (
                    id TEXT PRIMARY KEY,
                    organization_id TEXT NOT NULL,
                    email TEXT NOT NULL DEFAULT '',
                    full_name TEXT NOT NULL DEFAULT '',
                    role TEXT NOT NULL DEFAULT 'technician',
                    status TEXT NOT NULL DEFAULT 'pending',
                    created_at_iso TEXT NOT NULL,
                    updated_at_iso TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    FOREIGN KEY (organization_id) REFERENCES organizations (organization_id)
                );

                CREATE TABLE IF NOT EXISTS clients (
                    id TEXT PRIMARY KEY,
                    organization_id TEXT NOT NULL,
                    display_name TEXT NOT NULL DEFAULT '',
                    created_at_iso TEXT NOT NULL,
                    updated_at_iso TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    FOREIGN KEY (organization_id) REFERENCES organizations (organization_id)
                );

                CREATE TABLE IF NOT EXISTS plans (
                    id TEXT PRIMARY KEY,
                    organization_id TEXT NOT NULL,
                    display_name TEXT NOT NULL DEFAULT '',
                    client_limit INTEGER,
                    created_at_iso TEXT NOT NULL,
                    updated_at_iso TEXT NOT NULL,
                    payload_json TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS subscriptions (
                    id TEXT PRIMARY KEY,
                    organization_id TEXT NOT NULL,
                    plan_id TEXT NOT NULL DEFAULT 'free',
                    status TEXT NOT NULL DEFAULT 'active',
                    created_at_iso TEXT NOT NULL,
                    updated_at_iso TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    FOREIGN KEY (organization_id) REFERENCES organizations (organization_id)
                );

                CREATE TABLE IF NOT EXISTS entitlements (
                    id TEXT PRIMARY KEY,
                    organization_id TEXT NOT NULL,
                    flag TEXT NOT NULL DEFAULT '',
                    enabled TEXT NOT NULL DEFAULT 'false',
                    created_at_iso TEXT NOT NULL,
                    updated_at_iso TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    FOREIGN KEY (organization_id) REFERENCES organizations (organization_id)
                );

                CREATE TABLE IF NOT EXISTS interventions (
                    id TEXT PRIMARY KEY,
                    organization_id TEXT NOT NULL,
                    client_id TEXT NOT NULL DEFAULT '',
                    scheduled_at_iso TEXT NOT NULL DEFAULT '',
                    status TEXT NOT NULL DEFAULT '',
                    created_at_iso TEXT NOT NULL,
                    updated_at_iso TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    FOREIGN KEY (organization_id) REFERENCES organizations (organization_id)
                );

                CREATE TABLE IF NOT EXISTS financial_documents (
                    id TEXT PRIMARY KEY,
                    organization_id TEXT NOT NULL,
                    client_id TEXT NOT NULL DEFAULT '',
                    document_number TEXT NOT NULL DEFAULT '',
                    document_type TEXT NOT NULL DEFAULT '',
                    status TEXT NOT NULL DEFAULT '',
                    created_at_iso TEXT NOT NULL,
                    updated_at_iso TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    FOREIGN KEY (organization_id) REFERENCES organizations (organization_id)
                );

                CREATE TABLE IF NOT EXISTS media_attachments (
                    id TEXT PRIMARY KEY,
                    organization_id TEXT NOT NULL,
                    client_id TEXT NOT NULL DEFAULT '',
                    intervention_id TEXT NOT NULL DEFAULT '',
                    original_file_name TEXT NOT NULL DEFAULT '',
                    mime_type TEXT NOT NULL DEFAULT 'application/octet-stream',
                    relative_path TEXT NOT NULL,
                    created_at_iso TEXT NOT NULL,
                    updated_at_iso TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    FOREIGN KEY (organization_id) REFERENCES organizations (organization_id)
                );

                CREATE TABLE IF NOT EXISTS public_share_links (
                    id TEXT PRIMARY KEY,
                    organization_id TEXT NOT NULL,
                    token TEXT NOT NULL UNIQUE,
                    resource_type TEXT NOT NULL,
                    resource_id TEXT NOT NULL,
                    expires_at_iso TEXT NOT NULL DEFAULT '',
                    created_at_iso TEXT NOT NULL,
                    updated_at_iso TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    FOREIGN KEY (organization_id) REFERENCES organizations (organization_id)
                );

                CREATE TABLE IF NOT EXISTS billing_transactions (
                    id TEXT PRIMARY KEY,
                    organization_id TEXT NOT NULL,
                    user_id TEXT NOT NULL DEFAULT '',
                    provider TEXT NOT NULL DEFAULT '',
                    platform TEXT NOT NULL DEFAULT '',
                    product_id TEXT NOT NULL DEFAULT '',
                    plan_id TEXT NOT NULL DEFAULT '',
                    purchase_id TEXT NOT NULL,
                    original_purchase_id TEXT NOT NULL DEFAULT '',
                    purchase_status TEXT NOT NULL DEFAULT '',
                    purchased_at_iso TEXT NOT NULL DEFAULT '',
                    created_at_iso TEXT NOT NULL,
                    updated_at_iso TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    UNIQUE(provider, purchase_id),
                    FOREIGN KEY (organization_id) REFERENCES organizations (organization_id)
                );

                CREATE INDEX IF NOT EXISTS idx_users_organization_id
                ON users (organization_id);

                CREATE INDEX IF NOT EXISTS idx_team_invitations_organization_id
                ON team_invitations (organization_id);

                CREATE INDEX IF NOT EXISTS idx_clients_organization_id
                ON clients (organization_id);

                CREATE INDEX IF NOT EXISTS idx_plans_organization_id
                ON plans (organization_id);

                CREATE INDEX IF NOT EXISTS idx_subscriptions_organization_id
                ON subscriptions (organization_id);

                CREATE INDEX IF NOT EXISTS idx_entitlements_organization_id
                ON entitlements (organization_id);

                CREATE INDEX IF NOT EXISTS idx_interventions_organization_id
                ON interventions (organization_id);

                CREATE INDEX IF NOT EXISTS idx_financial_documents_organization_id
                ON financial_documents (organization_id);

                CREATE INDEX IF NOT EXISTS idx_media_attachments_organization_id
                ON media_attachments (organization_id);

                CREATE INDEX IF NOT EXISTS idx_media_attachments_intervention_id
                ON media_attachments (intervention_id);

                CREATE INDEX IF NOT EXISTS idx_public_share_links_token
                ON public_share_links (token);

                CREATE INDEX IF NOT EXISTS idx_billing_transactions_organization_id
                ON billing_transactions (organization_id);

                CREATE INDEX IF NOT EXISTS idx_billing_transactions_provider_purchase
                ON billing_transactions (provider, purchase_id);
                """
            )
            conn.execute(f"PRAGMA user_version = {SCHEMA_VERSION}")
        self._seed_default_plans()

    @contextmanager
    def connection(self) -> Iterator[sqlite3.Connection]:
        conn = sqlite3.connect(
            self.db_path,
            timeout=self.sqlite_busy_timeout_ms / 1000,
        )
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        conn.execute(f"PRAGMA busy_timeout = {self.sqlite_busy_timeout_ms}")
        conn.execute("PRAGMA journal_mode = WAL")
        conn.execute("PRAGMA synchronous = NORMAL")
        try:
            yield conn
            conn.commit()
        finally:
            conn.close()

    def healthcheck(self) -> dict:
        with self.connection() as conn:
            conn.execute("SELECT 1").fetchone()
            user_version = conn.execute("PRAGMA user_version").fetchone()[0]
        return {
            "status": "ok",
            "dbPath": str(self.db_path),
            "mediaDir": str(self.media_dir),
            "schemaVersion": user_version,
            "sqliteBusyTimeoutMs": self.sqlite_busy_timeout_ms,
        }

    def list_records(
        self,
        resource: str,
        organization_id: Optional[str] = None,
        updated_after: Optional[str] = None,
    ) -> list[dict]:
        config = self._config_for(resource)
        query = f"SELECT * FROM {config.table_name}"
        params: list[str] = []
        if organization_id:
            query += " WHERE organization_id = ?"
            params.append(organization_id)
        if updated_after:
            query += " AND" if params else " WHERE"
            query += " updated_at_iso > ?"
            params.append(updated_after)
        query += " ORDER BY updated_at_iso DESC, id ASC"

        with self.connection() as conn:
            rows = conn.execute(query, params).fetchall()
        return [self._row_to_record(row) for row in rows]

    def get_record(self, resource: str, record_id: str) -> dict:
        config = self._config_for(resource)
        with self.connection() as conn:
            row = conn.execute(
                f"SELECT * FROM {config.table_name} WHERE id = ?",
                (record_id,),
            ).fetchone()
        if row is None:
            raise LookupError(f"{resource} {record_id} introuvable.")
        return self._row_to_record(row)

    def find_user_by_email(self, organization_id: str, email: str) -> dict:
        normalized_email = email.strip().lower()
        if not normalized_email:
            raise LookupError("Utilisateur introuvable.")

        with self.connection() as conn:
            row = conn.execute(
                """
                SELECT * FROM users
                WHERE organization_id = ? AND lower(email) = ?
                ORDER BY created_at_iso ASC, id ASC
                LIMIT 1
                """,
                (organization_id, normalized_email),
            ).fetchone()
        if row is None:
            raise LookupError("Utilisateur introuvable.")
        return self._row_to_record(row)

    def find_unique_user_by_email(self, email: str) -> dict:
        normalized_email = email.strip().lower()
        if not normalized_email:
            raise LookupError("Utilisateur introuvable.")

        with self.connection() as conn:
            rows = conn.execute(
                """
                SELECT * FROM users
                WHERE lower(email) = ?
                ORDER BY created_at_iso ASC, id ASC
                LIMIT 2
                """,
                (normalized_email,),
            ).fetchall()
        if not rows:
            raise LookupError("Utilisateur introuvable.")
        if len(rows) > 1:
            raise ValueError(
                "Plusieurs espaces correspondent a cet email. "
                "Precisez l organisation si necessaire.",
            )
        return self._row_to_record(rows[0])

    def list_global_plans(self) -> list[dict]:
        with self.connection() as conn:
            rows = conn.execute(
                """
                SELECT * FROM plans
                WHERE organization_id = ?
                ORDER BY updated_at_iso DESC, id ASC
                """,
                ("global",),
            ).fetchall()
        return [self._row_to_record(row) for row in rows]

    def list_organization_users(self, organization_id: str) -> list[dict]:
        with self.connection() as conn:
            rows = conn.execute(
                """
                SELECT * FROM users
                WHERE organization_id = ?
                ORDER BY created_at_iso ASC, id ASC
                """,
                (organization_id,),
            ).fetchall()
        return [self._row_to_record(row) for row in rows]

    def list_team_invitations(self, organization_id: str) -> list[dict]:
        with self.connection() as conn:
            rows = conn.execute(
                """
                SELECT * FROM team_invitations
                WHERE organization_id = ?
                ORDER BY created_at_iso DESC, id ASC
                """,
                (organization_id,),
            ).fetchall()
        return [self._row_to_team_invitation(row) for row in rows]

    def create_team_invitation(
        self,
        *,
        organization_id: str,
        email: str,
        full_name: str,
        role: str,
        invited_by_user_id: str,
    ) -> dict:
        normalized_email = validate_email(email)

        normalized_role = _normalize_team_role(role)
        now = utc_now_iso()

        existing_user = None
        try:
            existing_user = self.find_user_by_email(organization_id, normalized_email)
        except LookupError:
            existing_user = None
        if existing_user is not None:
            raise ValueError("Un membre existe deja avec cet email.")

        for invitation in self.list_team_invitations(organization_id):
            if (
                _string_value(invitation, "email").lower() == normalized_email
                and _string_value(invitation, "status") == "pending"
            ):
                raise ValueError(
                    "Une invitation en attente existe deja pour cet email."
                )

        invitation_id = str(uuid4())
        payload = {
            "id": invitation_id,
            "organization_id": organization_id,
            "email": normalized_email,
            "fullName": full_name.strip(),
            "role": normalized_role,
            "status": "pending",
            "invitedByUserId": invited_by_user_id,
            "createdAtIso": now,
            "updatedAtIso": now,
        }

        with self.connection() as conn:
            conn.execute(
                """
                INSERT INTO team_invitations (
                    id, organization_id, email, full_name, role, status,
                    created_at_iso, updated_at_iso, payload_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    invitation_id,
                    organization_id,
                    normalized_email,
                    full_name.strip(),
                    normalized_role,
                    "pending",
                    now,
                    now,
                    json.dumps(payload, ensure_ascii=False),
                ),
            )
        return self.get_team_invitation(invitation_id)

    def get_team_invitation(self, invitation_id: str) -> dict:
        with self.connection() as conn:
            row = conn.execute(
                "SELECT * FROM team_invitations WHERE id = ?",
                (invitation_id,),
            ).fetchone()
        if row is None:
            raise LookupError(f"team_invitation {invitation_id} introuvable.")
        return self._row_to_team_invitation(row)

    def create_public_share_link(
        self,
        *,
        organization_id: str,
        resource_type: str,
        resource_id: str,
        expires_at_iso: str = "",
        created_by_user_id: str = "",
    ) -> dict:
        normalized_resource_type = resource_type.strip()
        if normalized_resource_type not in {"intervention", "financial_document"}:
            raise ValueError(
                "resource_type doit valoir intervention ou financial_document."
            )
        normalized_resource_id = validate_identifier(resource_id, "resource_id")
        expires_at_iso = validate_optional_iso_datetime(
            expires_at_iso,
            "expires_at_iso",
        )

        resource_name = (
            "interventions"
            if normalized_resource_type == "intervention"
            else "financial_documents"
        )
        record = self.get_record(resource_name, normalized_resource_id)
        if _string_value(record, "organization_id") != organization_id:
            raise PermissionError("Acces cross-organization interdit.")
        if _string_value(record, "deletedAt", "deletedAtIso"):
            raise ValueError("Impossible de partager une ressource supprimee.")

        link_id = str(uuid4())
        token = secrets.token_urlsafe(24)
        now = utc_now_iso()
        payload = {
            "id": link_id,
            "organization_id": organization_id,
            "token": token,
            "resourceType": normalized_resource_type,
            "resourceId": normalized_resource_id,
            "expiresAtIso": expires_at_iso,
            "createdByUserId": created_by_user_id.strip(),
            "createdAtIso": now,
            "updatedAtIso": now,
        }

        with self.connection() as conn:
            conn.execute(
                """
                INSERT INTO public_share_links (
                    id, organization_id, token, resource_type, resource_id,
                    expires_at_iso, created_at_iso, updated_at_iso, payload_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    link_id,
                    organization_id,
                    token,
                    normalized_resource_type,
                    normalized_resource_id,
                    expires_at_iso,
                    now,
                    now,
                    json.dumps(payload, ensure_ascii=False),
                ),
            )
        return self.get_public_share_link_by_token(token)

    def get_public_share_link_by_token(self, token: str) -> dict:
        normalized_token = token.strip()
        if not normalized_token:
            raise LookupError("Lien de partage introuvable.")
        with self.connection() as conn:
            row = conn.execute(
                "SELECT * FROM public_share_links WHERE token = ?",
                (normalized_token,),
            ).fetchone()
        if row is None:
            raise LookupError("Lien de partage introuvable.")
        return self._row_to_public_share_link(row)

    def list_public_share_links(self, organization_id: str) -> list[dict]:
        with self.connection() as conn:
            rows = conn.execute(
                """
                SELECT * FROM public_share_links
                WHERE organization_id = ?
                ORDER BY created_at_iso DESC, id ASC
                """,
                (organization_id,),
            ).fetchall()
        return [self._row_to_public_share_link(row) for row in rows]

    def resolve_public_share_payload(self, token: str) -> dict:
        link = self.get_public_share_link_by_token(token)
        if _is_share_link_expired(link):
            raise PermissionError("Ce lien de partage a expire.")

        organization = self.get_record(
            "organizations",
            _string_value(link, "organization_id"),
        )

        if _string_value(link, "resourceType") == "intervention":
            resource = self.get_record(
                "interventions",
                _string_value(link, "resourceId"),
            )
            if _string_value(resource, "deletedAt", "deletedAtIso"):
                raise LookupError("La ressource partagee n est plus disponible.")
            attachments = [
                item
                for item in ((resource.get("attachments") or []) if isinstance(resource.get("attachments"), list) else [])
                if not _string_value(item, "deletedAt", "deletedAtIso")
            ]
            return {
                "link": link,
                "organization": organization,
                "resource": resource,
                "attachments": attachments,
            }

        resource = self.get_record(
            "financial_documents",
            _string_value(link, "resourceId"),
        )
        if _string_value(resource, "deletedAt", "deletedAtIso"):
            raise LookupError("La ressource partagee n est plus disponible.")
        return {
            "link": link,
            "organization": organization,
            "resource": resource,
            "attachments": [],
        }

    def get_current_subscription(self, organization_id: str) -> Optional[dict]:
        subscriptions = self.list_records("subscriptions", organization_id)
        if not subscriptions:
            return None
        subscriptions.sort(
            key=lambda item: (
                _status_priority(item.get("status")),
                item.get("updated_at_iso", ""),
            ),
            reverse=True,
        )
        return subscriptions[0]

    def assign_subscription(
        self,
        *,
        organization_id: str,
        plan_id: str,
        status: str,
        started_at_iso: str = "",
        ended_at_iso: str = "",
        extra_payload: Optional[dict] = None,
    ) -> dict:
        organization_id = validate_identifier(organization_id, "organization_id")
        plan_id = validate_identifier(plan_id, "plan_id")

        normalized_status = status.strip().lower() or "active"
        if normalized_status not in {
            "trial",
            "active",
            "past_due",
            "canceled",
            "expired",
            "inactive",
        }:
            raise ValueError(
                "status doit valoir trial, active, past_due, canceled, expired ou inactive.",
            )
        if normalized_status == "inactive":
            normalized_status = "expired"

        available_plan_ids = {plan["id"] for plan in self.list_global_plans()}
        if plan_id not in available_plan_ids:
            raise ValueError("plan_id inconnu.")

        existing = self.get_current_subscription(organization_id)
        record_id = (
            _string_value(existing or {}, "id")
            or f"subscription_{organization_id}"
        )
        payload = {
            "id": record_id,
            "organization_id": organization_id,
            "planId": plan_id,
            "status": normalized_status,
            "startedAtIso": validate_optional_iso_datetime(
                started_at_iso,
                "started_at_iso",
            ),
            "endedAtIso": validate_optional_iso_datetime(
                ended_at_iso,
                "ended_at_iso",
            ),
            "updatedAtIso": utc_now_iso(),
            "source": "manual_admin",
        }
        if extra_payload:
            payload.update(extra_payload)
        if existing is None:
            return self.create_record("subscriptions", payload)
        return self.update_record("subscriptions", record_id, payload)

    def start_trial(
        self,
        *,
        organization_id: str,
        plan_id: str,
    ) -> dict:
        organization_id = validate_identifier(organization_id, "organization_id")
        plan_id = validate_identifier(plan_id, "plan_id")
        plan = self.get_record("plans", plan_id)
        trial_days = _int_value(plan, "trialDays", "trial_days")
        if trial_days <= 0:
            raise ValueError("Aucun essai gratuit n est active pour ce plan.")

        existing = self.get_current_subscription(organization_id)
        if existing is not None:
            if _bool_value(existing.get("trialUsed")):
                raise ValueError("L essai gratuit a deja ete utilise.")
            current_status = _effective_subscription_status(existing)
            if current_status in {"trial", "active", "canceled"}:
                raise ValueError(
                    "Un abonnement avec acces est deja actif pour cette organisation.",
                )

        now = datetime.now(timezone.utc).replace(microsecond=0)
        end_at = now + timedelta(days=trial_days)
        return self.assign_subscription(
            organization_id=organization_id,
            plan_id=plan_id,
            status="trial",
            started_at_iso=now.isoformat().replace("+00:00", "Z"),
            ended_at_iso=end_at.isoformat().replace("+00:00", "Z"),
            extra_payload={
                "trialDays": trial_days,
                "trialUsed": True,
                "source": "self_service_trial",
            },
        )

    def upsert_billing_transaction(
        self,
        *,
        organization_id: str,
        user_id: str,
        provider: str,
        platform: str,
        product_id: str,
        plan_id: str,
        purchase_id: str,
        original_purchase_id: str,
        purchase_status: str,
        purchased_at_iso: str,
        raw_payload: dict,
    ) -> dict:
        now = utc_now_iso()
        record_id = f"{provider}:{purchase_id}"
        payload = {
            "id": record_id,
            "organization_id": organization_id,
            "userId": user_id,
            "provider": provider,
            "platform": platform,
            "productId": product_id,
            "planId": plan_id,
            "purchaseId": purchase_id,
            "originalPurchaseId": original_purchase_id,
            "purchaseStatus": purchase_status,
            "purchasedAtIso": purchased_at_iso,
            "createdAtIso": now,
            "updatedAtIso": now,
            "rawPayload": raw_payload,
        }
        with self.connection() as conn:
            conn.execute(
                """
                INSERT INTO billing_transactions (
                    id, organization_id, user_id, provider, platform,
                    product_id, plan_id, purchase_id, original_purchase_id,
                    purchase_status, purchased_at_iso, created_at_iso,
                    updated_at_iso, payload_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(provider, purchase_id) DO UPDATE SET
                    organization_id = excluded.organization_id,
                    user_id = excluded.user_id,
                    platform = excluded.platform,
                    product_id = excluded.product_id,
                    plan_id = excluded.plan_id,
                    original_purchase_id = excluded.original_purchase_id,
                    purchase_status = excluded.purchase_status,
                    purchased_at_iso = excluded.purchased_at_iso,
                    updated_at_iso = excluded.updated_at_iso,
                    payload_json = excluded.payload_json
                """,
                (
                    record_id,
                    organization_id,
                    user_id,
                    provider,
                    platform,
                    product_id,
                    plan_id,
                    purchase_id,
                    original_purchase_id,
                    purchase_status,
                    purchased_at_iso,
                    now,
                    now,
                    json.dumps(payload, ensure_ascii=False),
                ),
            )
        return payload

    def resolve_billing_snapshot(self, organization_id: str) -> dict:
        plans = self.list_global_plans()
        subscription = self.get_current_subscription(organization_id)
        if subscription is None:
            subscription = {
                "id": f"{organization_id}_free",
                "organization_id": organization_id,
                "planId": "free",
                "status": "active",
                "startedAtIso": "",
                "endedAtIso": "",
                "updatedAtIso": "",
            }
        subscription = {
            **subscription,
            "status": _effective_subscription_status(subscription),
        }

        entitlement_overrides = self.list_records("entitlements", organization_id)
        plan_map = {plan["id"]: plan for plan in plans}
        plan = plan_map.get(
            str(subscription.get("planId") or subscription.get("plan_id") or "free"),
        ) or _default_plan_payload("free")

        entitlements = _merge_entitlements(
            plan.get("entitlements", []),
            [item for item in entitlement_overrides if not _string_value(item, "deletedAt", "deletedAtIso")],
        )

        return {
            "plans": plans,
            "subscription": {
                **subscription,
                "plan": plan,
                "entitlements": entitlements,
            },
            "entitlements": entitlements,
        }

    def export_account_bundle(self, *, organization_id: str, user_id: str) -> dict:
        user = self.get_record("users", user_id)
        if _string_value(user, "organization_id") != organization_id:
            raise PermissionError("Acces cross-organization interdit.")

        organization = self.get_record("organizations", organization_id)
        return {
            "exportedAtIso": utc_now_iso(),
            "organization": organization,
            "user": user,
            "users": self.list_organization_users(organization_id),
            "teamInvitations": self.list_team_invitations(organization_id),
            "publicShareLinks": self.list_public_share_links(organization_id),
            "clients": self.list_records("clients", organization_id),
            "interventions": self.list_records("interventions", organization_id),
            "financialDocuments": self.list_records(
                "financial_documents",
                organization_id,
            ),
            "billing": self.resolve_billing_snapshot(organization_id),
            "mediaAttachments": self.list_media_attachments(organization_id),
        }

    def delete_account(self, *, organization_id: str, user_id: str) -> dict:
        user = self.get_record("users", user_id)
        if _string_value(user, "organization_id") != organization_id:
            raise PermissionError("Acces cross-organization interdit.")

        users = self.list_organization_users(organization_id)
        organization_deleted = len(users) <= 1
        media_directory = self.media_dir / organization_id

        with self.connection() as conn:
            conn.execute("DELETE FROM users WHERE id = ?", (user_id,))
            if organization_deleted:
                conn.execute(
                    "DELETE FROM public_share_links WHERE organization_id = ?",
                    (organization_id,),
                )
                conn.execute(
                    "DELETE FROM team_invitations WHERE organization_id = ?",
                    (organization_id,),
                )
                conn.execute(
                    "DELETE FROM media_attachments WHERE organization_id = ?",
                    (organization_id,),
                )
                conn.execute(
                    "DELETE FROM financial_documents WHERE organization_id = ?",
                    (organization_id,),
                )
                conn.execute(
                    "DELETE FROM interventions WHERE organization_id = ?",
                    (organization_id,),
                )
                conn.execute(
                    "DELETE FROM clients WHERE organization_id = ?",
                    (organization_id,),
                )
                conn.execute(
                    "DELETE FROM entitlements WHERE organization_id = ?",
                    (organization_id,),
                )
                conn.execute(
                    "DELETE FROM subscriptions WHERE organization_id = ?",
                    (organization_id,),
                )
                conn.execute(
                    "DELETE FROM organizations WHERE organization_id = ?",
                    (organization_id,),
                )

        if organization_deleted and media_directory.exists():
            shutil.rmtree(media_directory, ignore_errors=True)

        return {
            "deletedUserId": user_id,
            "organizationId": organization_id,
            "organizationDeleted": organization_deleted,
            "remainingUsersCount": 0 if organization_deleted else len(users) - 1,
        }

    def create_record(self, resource: str, payload: dict) -> dict:
        config = self._config_for(resource)
        normalized = self._normalize_payload(resource, payload)
        with self.connection() as conn:
            conn.execute(
                self._insert_sql(config.table_name),
                self._record_to_values(resource, normalized),
            )
        return self.get_record(resource, normalized["id"])

    def update_record(self, resource: str, record_id: str, payload: dict) -> dict:
        config = self._config_for(resource)
        existing = self.get_record(resource, record_id)
        normalized = self._normalize_payload(
            resource,
            payload,
            record_id=record_id,
            existing=existing,
        )
        with self.connection() as conn:
            result = conn.execute(
                self._update_sql(config.table_name),
                self._record_to_update_values(resource, normalized) + [record_id],
            )
        if result.rowcount == 0:
            raise LookupError(f"{resource} {record_id} introuvable.")
        return self.get_record(resource, record_id)

    def delete_record(self, resource: str, record_id: str) -> None:
        config = self._config_for(resource)
        with self.connection() as conn:
            result = conn.execute(
                f"DELETE FROM {config.table_name} WHERE id = ?",
                (record_id,),
            )
        if result.rowcount == 0:
            raise LookupError(f"{resource} {record_id} introuvable.")

    def soft_delete_record(self, resource: str, record_id: str) -> dict:
        existing = self.get_record(resource, record_id)
        deleted_at = utc_now_iso()
        normalized = self._normalize_payload(
            resource,
            {
                **existing,
                "deletedAt": existing.get("deletedAt") or deleted_at,
                "updatedAt": deleted_at,
                "version": (_int_value(existing, "version") or 1) + 1,
            },
            record_id=record_id,
            existing=existing,
        )
        with self.connection() as conn:
            result = conn.execute(
                self._update_sql(self._config_for(resource).table_name),
                self._record_to_update_values(resource, normalized) + [record_id],
            )
        if result.rowcount == 0:
            raise LookupError(f"{resource} {record_id} introuvable.")
        return self.get_record(resource, record_id)

    def list_media_attachments(
        self,
        organization_id: str,
        *,
        updated_after: Optional[str] = None,
    ) -> list[dict]:
        query = """
            SELECT * FROM media_attachments
            WHERE organization_id = ?
        """
        params: list[str] = [organization_id]
        if updated_after:
            query += " AND updated_at_iso > ?"
            params.append(updated_after)
        query += " ORDER BY updated_at_iso DESC, id ASC"

        with self.connection() as conn:
            rows = conn.execute(query, params).fetchall()
        return [self._row_to_media_attachment(row) for row in rows]

    def get_media_attachment(self, attachment_id: str) -> dict:
        with self.connection() as conn:
            row = conn.execute(
                "SELECT * FROM media_attachments WHERE id = ?",
                (attachment_id,),
            ).fetchone()
        if row is None:
            raise LookupError(f"media_attachment {attachment_id} introuvable.")
        return self._row_to_media_attachment(row)

    def upsert_media_attachment(self, payload: dict, file_bytes: bytes) -> dict:
        if not isinstance(payload, dict):
            raise ValueError("Le body metadata media doit etre un objet.")
        if not file_bytes:
            raise ValueError("Le fichier media est vide.")

        attachment_id = validate_identifier(
            _string_value(payload, "id") or str(uuid4()),
            "id",
        )
        organization_id = validate_identifier(
            _string_value(
                payload,
                "organization_id",
                "organizationId",
            ),
            "organization_id",
        )
        client_id = validate_optional_identifier(
            _string_value(payload, "client_id", "clientId"),
            "client_id",
        )
        intervention_id = validate_optional_identifier(
            _string_value(
                payload,
                "intervention_id",
                "interventionId",
            ),
            "intervention_id",
        )

        original_file_name = (
            sanitize_filename(
                _string_value(payload, "originalFileName", "file_name", "fileName"),
                f"{attachment_id}.bin",
            )
        )
        mime_type = validate_mime_type(
            _string_value(payload, "mimeType", "mime_type"),
        )
        self._assert_related_record_same_organization(
            "clients",
            client_id,
            organization_id,
            "client_id",
            must_exist=False,
        )
        self._assert_related_record_same_organization(
            "interventions",
            intervention_id,
            organization_id,
            "intervention_id",
            must_exist=False,
        )
        extension = _media_extension(mime_type, original_file_name)
        relative_path = f"{organization_id}/{attachment_id}{extension}"
        absolute_path = self.media_dir / relative_path
        absolute_path.parent.mkdir(parents=True, exist_ok=True)
        absolute_path.write_bytes(file_bytes)

        now = utc_now_iso()
        created_at_iso = (
            validate_optional_iso_datetime(
                _string_value(payload, "createdAtIso", "created_at_iso"),
                "createdAtIso",
            )
            or now
        )
        normalized = {
            **payload,
            "id": attachment_id,
            "organization_id": organization_id,
            "client_id": client_id,
            "intervention_id": intervention_id,
            "originalFileName": original_file_name,
            "mimeType": mime_type,
            "relativePath": relative_path,
            "fileSize": len(file_bytes),
            "createdAtIso": created_at_iso,
            "updatedAtIso": now,
        }

        values = [
            attachment_id,
            organization_id,
            normalized["client_id"],
            normalized["intervention_id"],
            original_file_name,
            mime_type,
            relative_path,
            created_at_iso,
            now,
            json.dumps(normalized, ensure_ascii=False),
        ]

        with self.connection() as conn:
            conn.execute(
                """
                INSERT INTO media_attachments (
                    id, organization_id, client_id, intervention_id,
                    original_file_name, mime_type, relative_path,
                    created_at_iso, updated_at_iso, payload_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    organization_id = excluded.organization_id,
                    client_id = excluded.client_id,
                    intervention_id = excluded.intervention_id,
                    original_file_name = excluded.original_file_name,
                    mime_type = excluded.mime_type,
                    relative_path = excluded.relative_path,
                    created_at_iso = excluded.created_at_iso,
                    updated_at_iso = excluded.updated_at_iso,
                    payload_json = excluded.payload_json
                """,
                values,
            )
        return self.get_media_attachment(attachment_id)

    def media_attachment_path(self, attachment: Union[str, dict]) -> Path:
        record = (
            self.get_media_attachment(attachment)
            if isinstance(attachment, str)
            else attachment
        )
        relative_path = _string_value(record, "relativePath", "relative_path")
        if not relative_path:
            raise LookupError("Le media ne contient pas de chemin de fichier.")
        return self.media_dir / relative_path

    def _normalize_payload(
        self,
        resource: str,
        payload: dict,
        *,
        record_id: Optional[str] = None,
        existing: Optional[dict] = None,
    ) -> dict:
        if not isinstance(payload, dict):
            raise ValueError("Le body JSON doit etre un objet.")

        normalized = dict(existing or {})
        normalized.update(payload)

        normalized_id = (
            record_id
            or _string_value(payload, "id")
            or _string_value(existing or {}, "id")
            or str(uuid4())
        )
        normalized_id = validate_identifier(normalized_id, "id")
        organization_id = self._resolve_organization_id(
            resource,
            normalized,
            record_id=normalized_id,
        )
        now = utc_now_iso()
        created_at_iso = (
            validate_optional_iso_datetime(
                _string_value(normalized, "created_at_iso", "createdAtIso"),
                "createdAtIso",
            )
            or now
        )
        payload_updated_at_iso = (
            validate_optional_iso_datetime(
                _string_value(
                    normalized,
                    "updated_at_iso",
                    "updatedAtIso",
                    "updatedAt",
                ),
                "updatedAtIso",
            )
            or created_at_iso
        )
        existing_updated_at_iso = _string_value(
            existing or {},
            "updated_at_iso",
            "updatedAtIso",
            "updatedAt",
        )
        payload_version = _int_value(normalized, "version") or 1
        existing_version = _int_value(existing or {}, "version") or 0

        if resource == "users":
            normalized["email"] = validate_email(
                _string_value(normalized, "email"),
            )
        elif resource == "interventions":
            normalized["client_id"] = validate_optional_identifier(
                _string_value(normalized, "client_id", "clientId"),
                "client_id",
            )
            self._assert_related_record_same_organization(
                "clients",
                normalized["client_id"],
                organization_id,
                "client_id",
            )
        elif resource == "financial_documents":
            normalized["client_id"] = validate_optional_identifier(
                _string_value(normalized, "client_id", "clientId"),
                "client_id",
            )
            self._assert_related_record_same_organization(
                "clients",
                normalized["client_id"],
                organization_id,
                "client_id",
            )

        if existing is not None:
            if payload_version < existing_version:
                raise ConflictError(
                    "Conflit de version: une version plus recente existe deja.",
                    current_record=existing,
                )
            if (
                payload_version == existing_version
                and _is_older_or_equal(
                    payload_updated_at_iso,
                    existing_updated_at_iso,
                )
                and _payload_changed(existing, normalized)
            ):
                raise ConflictError(
                    "Conflit de synchronisation: la ressource distante est plus recente.",
                    current_record=existing,
                )

        normalized["id"] = normalized_id
        normalized["organization_id"] = organization_id
        normalized["created_at_iso"] = created_at_iso
        normalized["updated_at_iso"] = _max_iso(payload_updated_at_iso, now)
        normalized["updatedAtIso"] = normalized["updated_at_iso"]
        normalized["updatedAt"] = normalized["updated_at_iso"]
        normalized["version"] = max(payload_version, existing_version + 1 if existing is not None else 1)
        normalized["deletedAt"] = _string_value(
            normalized,
            "deletedAt",
            "deleted_at_iso",
            "deletedAtIso",
        )
        return normalized

    def _resolve_organization_id(
        self,
        resource: str,
        payload: dict,
        *,
        record_id: str,
    ) -> str:
        if resource == "plans":
            return "global"
        organization_id = validate_optional_identifier(
            _string_value(
                payload,
                "organization_id",
                "organizationId",
            ),
            "organization_id",
        )
        if organization_id:
            return organization_id
        if resource == "organizations":
            return validate_identifier(record_id, "organization_id")
        raise ValueError("organization_id est obligatoire pour cette ressource.")

    def _assert_related_record_same_organization(
        self,
        resource: str,
        record_id: str,
        organization_id: str,
        field_name: str,
        *,
        must_exist: bool = True,
    ) -> None:
        if not record_id:
            return
        try:
            related = self.get_record(resource, record_id)
        except LookupError:
            if must_exist:
                raise
            return
        related_organization_id = _string_value(
            related,
            "organization_id",
            "organizationId",
        )
        if related_organization_id != organization_id:
            raise ValueError(
                f"{field_name} doit appartenir a la meme organization.",
            )

    def _record_to_values(self, resource: str, record: dict) -> list[str]:
        config = self._config_for(resource)
        summary_values = [
            _extract_summary_value(record, resource, field)
            for field in config.summary_fields
        ]
        return [
            record["id"],
            record["organization_id"],
            *summary_values,
            record["created_at_iso"],
            record["updated_at_iso"],
            json.dumps(record, ensure_ascii=False),
        ]

    def _record_to_update_values(self, resource: str, record: dict) -> list[str]:
        config = self._config_for(resource)
        summary_values = [
            _extract_summary_value(record, resource, field)
            for field in config.summary_fields
        ]
        return [
            record["organization_id"],
            *summary_values,
            record["created_at_iso"],
            record["updated_at_iso"],
            json.dumps(record, ensure_ascii=False),
        ]

    def _insert_sql(self, table_name: str) -> str:
        if table_name == "organizations":
            summary_columns = "name"
        elif table_name == "users":
            summary_columns = "email, full_name, role"
        elif table_name == "clients":
            summary_columns = "display_name"
        elif table_name == "plans":
            summary_columns = "display_name, client_limit"
        elif table_name == "subscriptions":
            summary_columns = "plan_id, status"
        elif table_name == "entitlements":
            summary_columns = "flag, enabled"
        elif table_name == "interventions":
            summary_columns = "client_id, scheduled_at_iso, status"
        elif table_name == "financial_documents":
            summary_columns = "client_id, document_number, document_type, status"
        else:
            raise ValueError(f"Table non supportee: {table_name}")

        return (
            f"INSERT INTO {table_name} "
            f"(id, organization_id, {summary_columns}, created_at_iso, updated_at_iso, payload_json) "
            "VALUES (?, ?, "
            + ", ".join("?" for _ in summary_columns.split(", "))
            + ", ?, ?, ?)"
        )

    def _update_sql(self, table_name: str) -> str:
        if table_name == "organizations":
            set_clause = "organization_id = ?, name = ?, created_at_iso = ?, updated_at_iso = ?, payload_json = ?"
        elif table_name == "users":
            set_clause = "organization_id = ?, email = ?, full_name = ?, role = ?, created_at_iso = ?, updated_at_iso = ?, payload_json = ?"
        elif table_name == "clients":
            set_clause = "organization_id = ?, display_name = ?, created_at_iso = ?, updated_at_iso = ?, payload_json = ?"
        elif table_name == "plans":
            set_clause = "organization_id = ?, display_name = ?, client_limit = ?, created_at_iso = ?, updated_at_iso = ?, payload_json = ?"
        elif table_name == "subscriptions":
            set_clause = "organization_id = ?, plan_id = ?, status = ?, created_at_iso = ?, updated_at_iso = ?, payload_json = ?"
        elif table_name == "entitlements":
            set_clause = "organization_id = ?, flag = ?, enabled = ?, created_at_iso = ?, updated_at_iso = ?, payload_json = ?"
        elif table_name == "interventions":
            set_clause = "organization_id = ?, client_id = ?, scheduled_at_iso = ?, status = ?, created_at_iso = ?, updated_at_iso = ?, payload_json = ?"
        elif table_name == "financial_documents":
            set_clause = "organization_id = ?, client_id = ?, document_number = ?, document_type = ?, status = ?, created_at_iso = ?, updated_at_iso = ?, payload_json = ?"
        else:
            raise ValueError(f"Table non supportee: {table_name}")
        return f"UPDATE {table_name} SET {set_clause} WHERE id = ?"

    def _config_for(self, resource: str) -> ResourceConfig:
        config = RESOURCE_CONFIGS.get(resource)
        if config is None:
            raise ValueError(f"Ressource non supportee: {resource}")
        return config

    def _seed_default_plans(self) -> None:
        for payload in (
            _default_plan_payload("free"),
            _default_plan_payload("pro", trial_days=self.pro_trial_days),
        ):
            existing = None
            try:
                existing = self.get_record("plans", payload["id"])
            except LookupError:
                existing = None

            if existing is None:
                self.create_record("plans", payload)
            continue

    def _row_to_record(self, row: sqlite3.Row) -> dict:
        payload = json.loads(row["payload_json"])
        payload["id"] = row["id"]
        payload["organization_id"] = row["organization_id"]
        payload["created_at_iso"] = row["created_at_iso"]
        payload["updated_at_iso"] = row["updated_at_iso"]
        payload["updatedAtIso"] = row["updated_at_iso"]
        payload["updatedAt"] = row["updated_at_iso"]
        payload["version"] = _int_value(payload, "version") or 1
        payload["deletedAt"] = _string_value(
            payload,
            "deletedAt",
            "deleted_at_iso",
            "deletedAtIso",
        )
        return payload

    def _row_to_media_attachment(self, row: sqlite3.Row) -> dict:
        payload = json.loads(row["payload_json"])
        payload["id"] = row["id"]
        payload["organization_id"] = row["organization_id"]
        payload["client_id"] = row["client_id"]
        payload["intervention_id"] = row["intervention_id"]
        payload["originalFileName"] = row["original_file_name"]
        payload["mimeType"] = row["mime_type"]
        payload["relativePath"] = row["relative_path"]
        payload["createdAtIso"] = row["created_at_iso"]
        payload["updatedAtIso"] = row["updated_at_iso"]
        payload["updatedAt"] = row["updated_at_iso"]
        payload["version"] = _int_value(payload, "version") or 1
        payload["deletedAt"] = _string_value(
            payload,
            "deletedAt",
            "deleted_at_iso",
            "deletedAtIso",
        )
        payload["downloadPath"] = f"/v2/media/{row['id']}/download"
        payload["remoteUrl"] = payload.get("remoteUrl") or payload["downloadPath"]
        return payload

    def _row_to_team_invitation(self, row: sqlite3.Row) -> dict:
        payload = json.loads(row["payload_json"])
        payload["id"] = row["id"]
        payload["organization_id"] = row["organization_id"]
        payload["email"] = row["email"]
        payload["fullName"] = row["full_name"]
        payload["role"] = row["role"]
        payload["status"] = row["status"]
        payload["createdAtIso"] = row["created_at_iso"]
        payload["updatedAtIso"] = row["updated_at_iso"]
        payload["updatedAt"] = row["updated_at_iso"]
        return payload

    def _row_to_public_share_link(self, row: sqlite3.Row) -> dict:
        payload = json.loads(row["payload_json"])
        payload["id"] = row["id"]
        payload["organization_id"] = row["organization_id"]
        payload["token"] = row["token"]
        payload["resourceType"] = row["resource_type"]
        payload["resourceId"] = row["resource_id"]
        payload["expiresAtIso"] = row["expires_at_iso"]
        payload["createdAtIso"] = row["created_at_iso"]
        payload["updatedAtIso"] = row["updated_at_iso"]
        payload["updatedAt"] = row["updated_at_iso"]
        return payload


def _string_value(payload: dict, *keys: str) -> str:
    for key in keys:
        value = payload.get(key)
        if value is not None and str(value).strip():
            return str(value).strip()
    return ""


def _int_value(payload: dict, *keys: str) -> int:
    for key in keys:
        value = payload.get(key)
        if value is None:
            continue
        try:
            return int(value)
        except (TypeError, ValueError):
            continue
    return 0


def _normalize_team_role(raw: str) -> str:
    normalized = raw.strip().lower()
    if normalized not in {"admin", "manager", "technician"}:
        raise ValueError("role doit valoir admin, manager ou technician.")
    return normalized


def _is_share_link_expired(link: dict) -> bool:
    expires_at = _parse_iso(_string_value(link, "expiresAtIso", "expires_at_iso"))
    if expires_at is None:
        return False
    return expires_at <= datetime.now(timezone.utc)


def _parse_iso(value: str) -> Optional[datetime]:
    raw = (value or "").strip()
    if not raw:
        return None
    try:
        parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def _max_iso(left_iso: str, right_iso: str) -> str:
    left = _parse_iso(left_iso)
    right = _parse_iso(right_iso)
    if left is None:
        return right_iso
    if right is None:
        return left_iso
    return left_iso if left >= right else right_iso


def _is_older_or_equal(left_iso: str, right_iso: str) -> bool:
    left = _parse_iso(left_iso)
    right = _parse_iso(right_iso)
    if left is None or right is None:
        return True
    return left <= right


def _payload_changed(existing: dict, candidate: dict) -> bool:
    ignored_keys = {
        "updated_at_iso",
        "updatedAtIso",
        "updatedAt",
        "version",
    }

    def normalize(payload: dict) -> dict:
        return {
            key: value
            for key, value in payload.items()
            if key not in ignored_keys
        }

    return normalize(existing) != normalize(candidate)


def _extract_summary_value(payload: dict, resource: str, field: str) -> str:
    aliases = {
        ("organizations", "name"): ("name", "companyName"),
        ("users", "email"): ("email",),
        ("users", "full_name"): ("full_name", "fullName", "name"),
        ("users", "role"): ("role",),
        ("clients", "display_name"): ("display_name", "displayName", "name"),
        ("plans", "display_name"): ("display_name", "displayName", "name"),
        ("plans", "client_limit"): ("client_limit", "clientLimit"),
        ("subscriptions", "plan_id"): ("plan_id", "planId"),
        ("subscriptions", "status"): ("status",),
        ("entitlements", "flag"): ("flag",),
        ("entitlements", "enabled"): ("enabled",),
        ("interventions", "client_id"): ("client_id", "clientId"),
        ("interventions", "scheduled_at_iso"): (
            "scheduled_at_iso",
            "scheduledAtIso",
            "createdAtIso",
        ),
        ("interventions", "status"): ("status",),
        ("financial_documents", "client_id"): ("client_id", "clientId"),
        ("financial_documents", "document_number"): (
            "document_number",
            "documentNumber",
            "number",
        ),
        ("financial_documents", "document_type"): (
            "document_type",
            "documentType",
            "type",
        ),
        ("financial_documents", "status"): ("status",),
    }
    return _string_value(payload, *aliases.get((resource, field), (field,)))


def _media_extension(mime_type: str, original_file_name: str) -> str:
    guessed_from_name = Path(original_file_name).suffix
    if guessed_from_name:
        return guessed_from_name

    guessed = mimetypes.guess_extension(mime_type, strict=False)
    if guessed:
        return guessed
    return ".bin"


def _default_plan_payload(plan_id: str, *, trial_days: int = 0) -> dict:
    now = utc_now_iso()
    if plan_id == "pro":
        return {
            "id": "pro",
            "organization_id": "global",
            "displayName": "Pro",
            "clientLimit": None,
            "trialDays": max(0, int(trial_days)),
            "entitlements": [
                {"flag": "unlimitedClients", "enabled": True},
                {"flag": "pdfExport", "enabled": True},
                {"flag": "teamMembers", "enabled": True},
                {"flag": "cloudSync", "enabled": True},
            ],
            "createdAtIso": now,
            "updatedAtIso": now,
            "version": 1,
        }

    return {
        "id": "free",
        "organization_id": "global",
        "displayName": "Free",
        "clientLimit": 10,
        "trialDays": 0,
        "entitlements": [
            {"flag": "unlimitedClients", "enabled": False},
            {"flag": "pdfExport", "enabled": False},
            {"flag": "teamMembers", "enabled": False},
            {"flag": "cloudSync", "enabled": False},
        ],
        "createdAtIso": now,
        "updatedAtIso": now,
        "version": 1,
    }


def _merge_entitlements(
    plan_entitlements: list,
    override_entitlements: list[dict],
) -> list[dict]:
    resolved = {
        str(item.get("flag")): {
            "flag": str(item.get("flag")),
            "enabled": bool(item.get("enabled")),
        }
        for item in plan_entitlements
    }
    for item in override_entitlements:
        flag = _string_value(item, "flag")
        if not flag:
            continue
        resolved[flag] = {
            "flag": flag,
            "enabled": _bool_value(item.get("enabled")),
        }
    return list(resolved.values())


def _bool_value(value: object) -> bool:
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


def _effective_subscription_status(subscription: dict) -> str:
    status = _string_value(subscription, "status").lower() or "expired"
    started_at_iso = _string_value(subscription, "startedAtIso", "started_at_iso")
    ended_at_iso = _string_value(subscription, "endedAtIso", "ended_at_iso")
    now = datetime.now(timezone.utc)
    if status == "inactive":
        status = "expired"

    started_at = _parse_iso(started_at_iso)
    if started_at is not None and started_at > now:
        return status
    ended_at = _parse_iso(ended_at_iso)
    if ended_at is not None and ended_at <= now:
        return "expired"
    if status in {"trial", "active", "past_due", "canceled", "expired"}:
        return status
    return "expired"


def _status_priority(raw_status: object) -> int:
    normalized = str(raw_status or "").strip().lower()
    if normalized == "trial":
        return 5
    if normalized == "active":
        return 4
    if normalized == "past_due":
        return 3
    if normalized == "canceled":
        return 2
    if normalized in {"expired", "inactive"}:
        return 1
    return 0
