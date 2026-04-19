import base64
import hashlib
import hmac
import json
from dataclasses import dataclass
from typing import Optional

from .config import resolve_auth_secret

AUTH_SECRET = resolve_auth_secret()


@dataclass(frozen=True)
class AuthContext:
    user_id: str
    organization_id: str
    email: str


def hash_password(password: str) -> str:
    normalized = password.strip()
    if not normalized:
        raise ValueError("password est obligatoire.")
    digest = hashlib.sha256()
    digest.update(AUTH_SECRET.encode("utf-8"))
    digest.update(b":")
    digest.update(normalized.encode("utf-8"))
    return digest.hexdigest()


def build_token(*, user_id: str, organization_id: str, email: str) -> str:
    payload = {
        "user_id": user_id,
        "organization_id": organization_id,
        "email": email,
    }
    payload_bytes = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    payload_b64 = _b64_encode(payload_bytes)
    signature = hmac.new(
        AUTH_SECRET.encode("utf-8"),
        payload_b64.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    return f"{payload_b64}.{signature}"


def parse_token(token: str) -> Optional[AuthContext]:
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
        payload = json.loads(_b64_decode(payload_b64))
    except (json.JSONDecodeError, ValueError):
        return None

    user_id = str(payload.get("user_id", "")).strip()
    organization_id = str(payload.get("organization_id", "")).strip()
    email = str(payload.get("email", "")).strip()
    if not user_id or not organization_id or not email:
        return None

    return AuthContext(
        user_id=user_id,
        organization_id=organization_id,
        email=email,
    )


def _b64_encode(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode("ascii").rstrip("=")


def _b64_decode(value: str) -> bytes:
    padding = "=" * ((4 - len(value) % 4) % 4)
    return base64.urlsafe_b64decode((value + padding).encode("ascii"))
