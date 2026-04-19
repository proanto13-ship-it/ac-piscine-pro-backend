import json
import os
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
STORAGE_FILE = DATA_DIR / "sync_store.json"
DEFAULT_HOST = os.getenv("SYNC_HOST", "0.0.0.0")
DEFAULT_PORT = int(os.getenv("SYNC_PORT", "8787"))
API_KEY = os.getenv("SYNC_API_KEY", "").strip()


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


class SyncHandler(BaseHTTPRequestHandler):
    server_version = "HydrAzurSync/1.0"

    def do_OPTIONS(self):
        self.send_response(HTTPStatus.NO_CONTENT)
        self._set_common_headers()
        self.end_headers()

    def do_GET(self):
        if self.path == "/health":
            self._send_json(
                HTTPStatus.OK,
                {
                    "status": "ok",
                    "service": "hydr-azur-sync",
                    "updatedAt": read_store().get("updatedAt", ""),
                },
            )
            return

        if self.path != "/sync":
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
        if self.path != "/sync":
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


def main():
    ensure_storage()
    server = ThreadingHTTPServer((DEFAULT_HOST, DEFAULT_PORT), SyncHandler)
    print(f"HydrAzur Sync en ecoute sur http://{DEFAULT_HOST}:{DEFAULT_PORT}")
    print("Routes disponibles: GET /health, GET /sync, POST /sync")
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
