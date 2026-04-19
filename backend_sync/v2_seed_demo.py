from __future__ import annotations

import argparse
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

from v2.auth import hash_password
from v2.config import load_config
from v2.db import DEFAULT_DB_PATH, SQLiteSyncV2Store


TRANSPARENT_PNG = bytes.fromhex(
    "89504E470D0A1A0A0000000D4948445200000001000000010804000000B51C0C02"
    "0000000B4944415478DA63FCFF1F0003030200EF979EAB0000000049454E44AE42"
    "6082"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Seed demo data for the HydrAzur Sync V2 backend.",
    )
    parser.add_argument(
        "--db",
        default="",
        help="SQLite database path to seed.",
    )
    parser.add_argument(
        "--org-id",
        default="demo-pro-hydrazur",
        help="Organization id for the Pro demo tenant.",
    )
    parser.add_argument(
        "--email",
        default="demo-pro@hydrazur.test",
        help="Login email for the Pro demo user.",
    )
    parser.add_argument(
        "--password",
        default="demo1234",
        help="Login password for the demo user.",
    )
    parser.add_argument(
        "--free-org-id",
        default="demo-free-hydrazur",
        help="Organization id for the Free demo tenant.",
    )
    parser.add_argument(
        "--free-email",
        default="demo-free@hydrazur.test",
        help="Login email for the Free demo user.",
    )
    parser.add_argument(
        "--free-password",
        default="demo1234",
        help="Login password for the Free demo user.",
    )
    return parser.parse_args()


def main() -> None:
    config = load_config()
    app_env = config.environment
    if app_env in {"prod", "production"}:
        raise SystemExit(
            "Le seed demo V2 est desactive en production (APP_ENV=prod)."
        )
    if app_env == "staging" and not config.demo_seed_enabled:
        raise SystemExit(
            "Le seed demo V2 est desactive en staging. "
            "Activez DEMO_SEED_ENABLED=true pour semer les comptes de demonstration."
        )

    args = parse_args()
    db_path = Path(args.db).expanduser() if args.db else config.db_path
    store = SQLiteSyncV2Store(db_path=db_path)
    store.initialize()

    seed_demo_dataset(
        store,
        org_id=args.org_id.strip(),
        email=args.email.strip().lower(),
        password=args.password,
        free_org_id=args.free_org_id.strip(),
        free_email=args.free_email.strip().lower(),
        free_password=args.free_password,
    )

    print("Demo seed ready.")
    print(f"Database: {db_path.resolve()}")
    print(f"Pro Organization ID: {args.org_id.strip()}")
    print(f"Pro Email: {args.email.strip().lower()}")
    print(f"Pro Password: {args.password}")
    print(f"Free Organization ID: {args.free_org_id.strip()}")
    print(f"Free Email: {args.free_email.strip().lower()}")
    print(f"Free Password: {args.free_password}")


def seed_demo_dataset(
    store: SQLiteSyncV2Store,
    *,
    org_id: str = "demo-pro-hydrazur",
    email: str = "demo-pro@hydrazur.test",
    password: str = "demo1234",
    free_org_id: str = "demo-free-hydrazur",
    free_email: str = "demo-free@hydrazur.test",
    free_password: str = "demo1234",
) -> None:
    anchor = datetime.now(timezone.utc).replace(microsecond=0)
    user_id = "demo-user-admin"
    free_user_id = "demo-user-free"

    upsert_record(
        store,
        "organizations",
        {
            "id": org_id,
            "organization_id": org_id,
            "name": "HydrAzur Pilotage",
            "companyProfile": {
                "companyName": "HydrAzur Pilotage",
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
            "updatedAtIso": iso(anchor),
        },
    )

    upsert_record(
        store,
        "users",
        {
            "id": user_id,
            "organization_id": org_id,
            "email": email,
            "fullName": "Demo Admin",
            "role": "admin",
            "password_hash": hash_password(password),
            "updatedAtIso": iso(anchor),
        },
    )

    store.assign_subscription(
        organization_id=org_id,
        plan_id="pro",
        status="active",
        started_at_iso=iso(anchor - timedelta(days=30)),
        ended_at_iso="",
        extra_payload={"source": "demo_seed"},
    )

    upsert_record(
        store,
        "organizations",
        {
            "id": free_org_id,
            "organization_id": free_org_id,
            "name": "HydrAzur Découverte",
            "companyProfile": {
                "companyName": "HydrAzur Découverte",
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
            "updatedAtIso": iso(anchor),
        },
    )

    upsert_record(
        store,
        "users",
        {
            "id": free_user_id,
            "organization_id": free_org_id,
            "email": free_email,
            "fullName": "Demo Free",
            "role": "admin",
            "password_hash": hash_password(free_password),
            "updatedAtIso": iso(anchor),
        },
    )

    client_records = [
        {
            "id": "demo_client_villa_azur",
            "name": "Villa Azur",
            "phone": "+33 6 80 12 45 67",
            "email": "maison@villa-azur.test",
            "address": "14 allee des Mimosas, 06800 Cagnes-sur-Mer",
            "volume": 52,
            "treatment": "Electrolyse au sel",
            "notes": "Client pilote pour les demonstrations terrain.",
            "createdAtIso": iso(anchor - timedelta(days=120)),
        },
        {
            "id": "demo_client_residence_oliviers",
            "name": "Residence Les Oliviers",
            "phone": "+33 4 93 44 55 66",
            "email": "syndic@oliviers-demo.test",
            "address": "3 impasse des Oliviers, 06160 Antibes",
            "volume": 96,
            "treatment": "Chlore liquide",
            "notes": "Bassin collectif representatif.",
            "createdAtIso": iso(anchor - timedelta(days=200)),
        },
        {
            "id": "demo_client_bastide_mimosas",
            "name": "Bastide des Mimosas",
            "phone": "+33 6 72 90 34 10",
            "email": "accueil@bastide-demo.test",
            "address": "92 chemin des Mimosas, 06560 Valbonne",
            "volume": 38,
            "treatment": "Brome",
            "notes": "Bon support pour les photos avant/apres.",
            "createdAtIso": iso(anchor - timedelta(days=90)),
        },
        {
            "id": "demo_client_hotel_rivage",
            "name": "Hotel Le Rivage",
            "phone": "+33 4 97 12 20 20",
            "email": "technique@rivage-demo.test",
            "address": "7 boulevard du Littoral, 06220 Vallauris",
            "volume": 124,
            "treatment": "UV + chlore",
            "notes": "Reference B2B pour les essais de sync.",
            "createdAtIso": iso(anchor - timedelta(days=260)),
        },
    ]

    for record in client_records:
        upsert_record(
            store,
            "clients",
            {
                **record,
                "organization_id": org_id,
                "updatedAtIso": record["createdAtIso"],
                "version": 1,
            },
        )

    intervention_specs = [
        (
            "demo_int_villa_azur_01",
            "demo_client_villa_azur",
            "Clara Martin",
            anchor - timedelta(days=35),
            "completed",
            "Nettoyage du prefiltre et verification PAC.",
        ),
        (
            "demo_int_villa_azur_02",
            "demo_client_villa_azur",
            "Yanis Rossi",
            anchor - timedelta(days=8),
            "completed",
            "Traitement preventif anti-calcaire.",
        ),
        (
            "demo_int_oliviers_01",
            "demo_client_residence_oliviers",
            "Clara Martin",
            anchor - timedelta(days=21),
            "completed",
            "Mise en route printemps et controles securite.",
        ),
        (
            "demo_int_oliviers_02",
            "demo_client_residence_oliviers",
            "Yanis Rossi",
            anchor - timedelta(days=5),
            "completed",
            "Recalage consigne pompe doseuse.",
        ),
        (
            "demo_int_mimosas_01",
            "demo_client_bastide_mimosas",
            "Clara Martin",
            anchor - timedelta(days=16),
            "completed",
            "Nettoyage cartouche et ajustement brome.",
        ),
        (
            "demo_int_mimosas_02",
            "demo_client_bastide_mimosas",
            "Yanis Rossi",
            anchor - timedelta(days=2),
            "completed",
            "Controle apres orage et correction pH.",
        ),
        (
            "demo_int_rivage_01",
            "demo_client_hotel_rivage",
            "Clara Martin",
            anchor - timedelta(days=11),
            "completed",
            "Audit local technique et calibration Redox.",
        ),
    ]

    for intervention_id, client_id, technician_name, created_at, status, summary in intervention_specs:
        upsert_record(
            store,
            "interventions",
            {
                "id": intervention_id,
                "organization_id": org_id,
                "clientId": client_id,
                "technicianName": technician_name,
                "scheduledAtIso": iso(created_at),
                "createdAtIso": iso(created_at),
                "updatedAtIso": iso(created_at),
                "status": status,
                "summary": summary,
                "version": 1,
            },
        )

    document_specs = [
        (
            "demo_doc_villa_azur_01",
            "demo_client_villa_azur",
            "FAC-2026-004",
            "invoice",
            "sent",
            anchor - timedelta(days=8),
        ),
        (
            "demo_doc_oliviers_01",
            "demo_client_residence_oliviers",
            "DEV-2026-003",
            "quote",
            "approved",
            anchor - timedelta(days=6),
        ),
        (
            "demo_doc_rivage_01",
            "demo_client_hotel_rivage",
            "DEV-2026-005",
            "quote",
            "sent",
            anchor - timedelta(days=10),
        ),
    ]

    for document_id, client_id, number, document_type, status, created_at in document_specs:
        upsert_record(
            store,
            "financial_documents",
            {
                "id": document_id,
                "organization_id": org_id,
                "clientId": client_id,
                "documentNumber": number,
                "documentType": document_type,
                "status": status,
                "title": f"Document demo {number}",
                "createdAtIso": iso(created_at),
                "updatedAtIso": iso(created_at),
                "version": 1,
            },
        )

    media_specs = [
        (
            "demo_media_local_technique",
            "demo_client_villa_azur",
            "demo_int_villa_azur_01",
            "local-technique.png",
            anchor - timedelta(days=35),
        ),
        (
            "demo_media_pompe_filtres",
            "demo_client_villa_azur",
            "demo_int_villa_azur_02",
            "pompe-filtres.png",
            anchor - timedelta(days=8),
        ),
        (
            "demo_media_bassin_eau",
            "demo_client_residence_oliviers",
            "demo_int_oliviers_01",
            "bassin-eau.png",
            anchor - timedelta(days=21),
        ),
    ]

    for media_id, client_id, intervention_id, file_name, created_at in media_specs:
        store.upsert_media_attachment(
            {
                "id": media_id,
                "organization_id": org_id,
                "clientId": client_id,
                "interventionId": intervention_id,
                "originalFileName": file_name,
                "mimeType": "image/png",
                "createdAtIso": iso(created_at),
                "updatedAtIso": iso(created_at),
                "version": 1,
            },
            TRANSPARENT_PNG,
        )


def upsert_record(store: SQLiteSyncV2Store, resource: str, payload: dict) -> dict:
    try:
        store.get_record(resource, payload["id"])
    except LookupError:
        return store.create_record(resource, payload)
    return store.update_record(resource, payload["id"], payload)


def iso(value: datetime) -> str:
    return value.replace(microsecond=0).isoformat()


if __name__ == "__main__":
    main()
