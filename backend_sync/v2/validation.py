import re
from datetime import datetime, timezone


IDENTIFIER_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$")
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def validate_identifier(value: str, field_name: str) -> str:
    normalized = (value or "").strip()
    if not normalized:
        raise ValueError(f"{field_name} est obligatoire.")
    if not IDENTIFIER_RE.fullmatch(normalized):
        raise ValueError(
            f"{field_name} doit utiliser uniquement lettres, chiffres, ., _, : ou -.",
        )
    return normalized


def validate_optional_identifier(value: str, field_name: str) -> str:
    normalized = (value or "").strip()
    if not normalized:
        return ""
    return validate_identifier(normalized, field_name)


def validate_email(value: str, field_name: str = "email") -> str:
    normalized = (value or "").strip().lower()
    if not normalized:
        raise ValueError(f"{field_name} est obligatoire.")
    if not EMAIL_RE.fullmatch(normalized):
        raise ValueError(f"{field_name} n est pas une adresse email valide.")
    return normalized


def validate_optional_iso_datetime(value: str, field_name: str) -> str:
    normalized = (value or "").strip()
    if not normalized:
        return ""
    try:
        parsed = datetime.fromisoformat(normalized.replace("Z", "+00:00"))
    except ValueError as error:
        raise ValueError(f"{field_name} doit etre une date ISO-8601 valide.") from error
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return (
        parsed.astimezone(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def sanitize_filename(value: str, fallback: str) -> str:
    normalized = (value or "").strip().replace("\\", "/").split("/")[-1]
    cleaned = "".join(ch for ch in normalized if 32 <= ord(ch) < 127).strip()
    return cleaned or fallback


def validate_mime_type(value: str, field_name: str = "mimeType") -> str:
    normalized = (value or "").strip().lower()
    if not normalized:
        return "application/octet-stream"
    if "/" not in normalized or any(ch in normalized for ch in "\r\n\t"):
        raise ValueError(f"{field_name} est invalide.")
    return normalized
