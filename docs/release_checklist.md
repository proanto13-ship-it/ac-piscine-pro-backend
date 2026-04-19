# Release Checklist

## Avant la release

- Verifier la version applicative dans `pubspec.yaml`
- Lancer `flutter pub get`
- Lancer `flutter analyze`
- Lancer `flutter test`
- Lancer `python3 -m unittest backend_sync.tests.test_v2_auth backend_sync.tests.test_v2_media backend_sync.tests.test_v2_conflicts backend_sync.tests.test_v2_billing backend_sync.tests.test_v2_account`

## Smoke tests terrain

- Login V2
- Onboarding entreprise
- Creation d un client
- Creation d une intervention
- Ajout d au moins une photo
- Generation PDF
- Push sync puis pull sync
- Redemarrage et verification de la persistence
- Verification du paywall Free/Pro
- Verification de l export compte/donnees

## Stabilite et tracabilite

- Verifier que les logs applicatifs sont bien produits
- Verifier qu une erreur non capturee est enregistree dans les logs
- Verifier les evenements traces :
  - `login_success` / `login_failed`
  - `sync_prepare`
  - `sync_push`
  - `sync_pull`
  - `client_created`
  - `intervention_created`
  - `pdf_generated`
  - `paywall_opened`

## Backend V2

- Verifier `GET /v2/health`
- Verifier le login `POST /v2/auth/login`
- Verifier le snapshot billing `GET /v2/billing/entitlements`
- Verifier l export compte `GET /v2/account/export`
- Verifier la suppression de compte `DELETE /v2/account/me`

## Limitations connues

- Pas de SaaS de monitoring branche pour l instant
- Les logs restent locaux tant qu aucun collecteur distant n est configure
- Le billing reste en mode mock/dev ou activation manuelle
