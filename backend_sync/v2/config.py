import os
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse


BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
DEFAULT_DB_PATH = DATA_DIR / "sync_v2_dev.sqlite3"
DEFAULT_AUTH_SECRET = "hydr-azur-sync-v2-dev-secret"
DEFAULT_ADMIN_TOKEN = "dev-admin-token"
DEFAULT_PORT = 8000


def _parse_bool(raw: str, default: bool) -> bool:
    normalized = (raw or "").strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False
    return default


def _parse_int(raw: str, default: int) -> int:
    try:
        value = int((raw or "").strip())
    except (TypeError, ValueError):
        return default
    return value if value > 0 else default


def _first_env(*keys: str, default: str = "") -> str:
    for key in keys:
        value = os.getenv(key)
        if value is not None and value.strip():
            return value.strip()
    return default


def resolve_auth_secret() -> str:
    return _first_env(
        "SYNC_V2_AUTH_SECRET",
        "AUTH_SECRET",
        "JWT_SECRET",
        default=DEFAULT_AUTH_SECRET,
    )


def resolve_admin_token() -> str:
    return _first_env(
        "SYNC_V2_ADMIN_TOKEN",
        "ADMIN_SEED_TOKEN",
        default=DEFAULT_ADMIN_TOKEN,
    )


def resolve_db_path() -> Path:
    raw = _first_env(
        "SYNC_V2_DB",
        "SYNC_V2_DATABASE_URL",
        "DATABASE_URL",
        default=str(DEFAULT_DB_PATH),
    )
    if "://" not in raw:
        return Path(raw).expanduser()

    parsed = urlparse(raw)
    scheme = parsed.scheme.strip().lower()
    if scheme != "sqlite":
        raise RuntimeError(
            "DATABASE_URL non supporte pour le moment. "
            "Utilisez un chemin SQLite ou une URL sqlite:///...",
        )

    if parsed.netloc and parsed.netloc not in {"", "localhost"}:
        path = f"//{parsed.netloc}{parsed.path}"
    else:
        path = parsed.path
    if not path:
        raise RuntimeError("DATABASE_URL sqlite invalide.")
    if path.startswith("//") and not parsed.netloc:
        path = path[1:]
    return Path(path).expanduser()


@dataclass(frozen=True)
class SyncV2Config:
    environment: str
    host: str
    port: int
    db_path: Path
    media_dir: Path
    auth_secret: str
    admin_token: str
    allowed_origins: tuple[str, ...]
    allow_public_bootstrap: bool
    max_json_bytes: int
    max_upload_bytes: int
    sqlite_busy_timeout_ms: int
    login_rate_limit_count: int
    admin_rate_limit_count: int
    destructive_rate_limit_count: int
    upload_rate_limit_count: int
    rate_limit_window_seconds: int
    log_level: str
    billing_ios_pro_product_id: str
    billing_android_pro_product_id: str
    pro_trial_days: int
    demo_seed_enabled: bool

    @property
    def is_prod(self) -> bool:
        return self.environment == "prod"

    @property
    def is_public_env(self) -> bool:
        return self.environment in {"staging", "prod"}

    def validate_or_raise(self) -> None:
        if not self.host.strip():
            raise RuntimeError("SYNC_V2_HOST ne peut pas etre vide.")
        if self.port <= 0 or self.port > 65535:
            raise RuntimeError("SYNC_V2_PORT doit etre compris entre 1 et 65535.")
        if self.max_json_bytes <= 0:
            raise RuntimeError("SYNC_V2_MAX_JSON_BYTES doit etre strictement positif.")
        if self.max_upload_bytes <= 0:
            raise RuntimeError("SYNC_V2_MAX_UPLOAD_BYTES doit etre strictement positif.")
        if self.sqlite_busy_timeout_ms <= 0:
            raise RuntimeError("SYNC_V2_SQLITE_BUSY_TIMEOUT_MS doit etre strictement positif.")
        if self.is_public_env and self.auth_secret == DEFAULT_AUTH_SECRET:
            raise RuntimeError(
                "SYNC_V2_AUTH_SECRET/AUTH_SECRET doit etre configure explicitement en staging/prod.",
            )
        if self.is_public_env and self.admin_token == DEFAULT_ADMIN_TOKEN:
            raise RuntimeError(
                "SYNC_V2_ADMIN_TOKEN/ADMIN_SEED_TOKEN doit etre configure explicitement en staging/prod.",
            )

    def to_public_dict(self) -> dict:
        return {
            "environment": self.environment,
            "host": self.host,
            "port": self.port,
            "allowPublicBootstrap": self.allow_public_bootstrap,
            "demoSeedEnabled": self.demo_seed_enabled,
            "allowedOrigins": list(self.allowed_origins),
            "maxJsonBytes": self.max_json_bytes,
            "maxUploadBytes": self.max_upload_bytes,
            "sqliteBusyTimeoutMs": self.sqlite_busy_timeout_ms,
            "rateLimits": {
                "windowSeconds": self.rate_limit_window_seconds,
                "login": self.login_rate_limit_count,
                "admin": self.admin_rate_limit_count,
                "destructive": self.destructive_rate_limit_count,
                "upload": self.upload_rate_limit_count,
            },
            "billingProducts": {
                "iosProProductId": self.billing_ios_pro_product_id,
                "androidProProductId": self.billing_android_pro_product_id,
            },
            "billing": {
                "proTrialDays": self.pro_trial_days,
            },
        }


def load_config() -> SyncV2Config:
    environment = _first_env("SYNC_V2_ENV", "APP_ENV", default="dev").lower()
    if environment not in {"dev", "staging", "prod"}:
        environment = "dev"

    db_path = resolve_db_path()
    media_dir = Path(os.getenv("SYNC_V2_MEDIA_DIR", str(db_path.parent / "media")))
    allowed_origins_raw = _first_env(
        "SYNC_V2_ALLOWED_ORIGINS",
        "CORS_ALLOWED_ORIGINS",
        default="*",
    )
    allowed_origins = tuple(
        origin.strip()
        for origin in allowed_origins_raw.split(",")
        if origin.strip()
    ) or ("*",)

    return SyncV2Config(
        environment=environment,
        host=_first_env("SYNC_V2_HOST", "HOST", default="0.0.0.0"),
        port=_parse_int(
            _first_env("SYNC_V2_PORT", "PORT", default=str(DEFAULT_PORT)),
            DEFAULT_PORT,
        ),
        db_path=db_path,
        media_dir=media_dir,
        auth_secret=resolve_auth_secret(),
        admin_token=resolve_admin_token(),
        allowed_origins=allowed_origins,
        allow_public_bootstrap=_parse_bool(
            _first_env("SYNC_V2_ALLOW_PUBLIC_BOOTSTRAP", default=""),
            default=environment != "prod",
        ),
        max_json_bytes=_parse_int(
            os.getenv("SYNC_V2_MAX_JSON_BYTES", "262144"),
            262144,
        ),
        max_upload_bytes=_parse_int(
            os.getenv("SYNC_V2_MAX_UPLOAD_BYTES", "10485760"),
            10485760,
        ),
        sqlite_busy_timeout_ms=_parse_int(
            os.getenv("SYNC_V2_SQLITE_BUSY_TIMEOUT_MS", "5000"),
            5000,
        ),
        login_rate_limit_count=_parse_int(
            os.getenv("SYNC_V2_RATE_LIMIT_LOGIN", "10"),
            10,
        ),
        admin_rate_limit_count=_parse_int(
            os.getenv("SYNC_V2_RATE_LIMIT_ADMIN", "30"),
            30,
        ),
        destructive_rate_limit_count=_parse_int(
            os.getenv("SYNC_V2_RATE_LIMIT_DESTRUCTIVE", "10"),
            10,
        ),
        upload_rate_limit_count=_parse_int(
            os.getenv("SYNC_V2_RATE_LIMIT_UPLOAD", "20"),
            20,
        ),
        rate_limit_window_seconds=_parse_int(
            os.getenv("SYNC_V2_RATE_LIMIT_WINDOW_SECONDS", "60"),
            60,
        ),
        log_level=(os.getenv("SYNC_V2_LOG_LEVEL", "INFO") or "INFO").strip().upper(),
        billing_ios_pro_product_id=(
            os.getenv(
                "SYNC_V2_BILLING_IOS_PRO_PRODUCT_ID",
                "com.hydrazur.pro.monthly",
            )
            or ""
        ).strip(),
        billing_android_pro_product_id=(
            os.getenv(
                "SYNC_V2_BILLING_ANDROID_PRO_PRODUCT_ID",
                "com.hydrazur.pro.monthly",
            )
            or ""
        ).strip(),
        pro_trial_days=_parse_int(os.getenv("SYNC_V2_PRO_TRIAL_DAYS", "0"), 0),
        demo_seed_enabled=_parse_bool(
            _first_env("SYNC_V2_DEMO_SEED_ENABLED", "DEMO_SEED_ENABLED", default=""),
            default=environment == "dev",
        ),
    )
