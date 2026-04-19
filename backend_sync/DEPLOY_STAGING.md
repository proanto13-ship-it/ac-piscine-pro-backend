# Deploy Staging

Objectif : deployer la V2 sur un service public HTTPS pour TestFlight, sans dependre d un backend local Mac.

## 1. Variables d environnement

Exemple de base : [backend_sync/.env.staging.example](/Users/ac/ac_piscine_pro copie/backend_sync/.env.staging.example)

Variables minimales :

- `APP_ENV=staging`
- `PORT=8000`
- `DATABASE_URL=sqlite:////data/hydrazur/sync_v2_staging.sqlite3`
- `SYNC_V2_MEDIA_DIR=/data/hydrazur/media`
- `AUTH_SECRET=...`
- `ADMIN_SEED_TOKEN=...`
- `CORS_ALLOWED_ORIGINS=https://staging.hydrazur.app`
- `DEMO_SEED_ENABLED=true` uniquement le temps du seed demo

Notes :

- aucun secret ne doit etre committe
- pour ce patch, `DATABASE_URL` supporte SQLite (`sqlite:///...`) ou un chemin SQLite simple
- PostgreSQL n est pas encore supporte ici ; pour le staging, utilisez un volume persistant SQLite + media

## 2. Demarrage du serveur

Commande minimale :

```bash
cd backend_sync
python3 v2_server.py
```

Commande Render recommandee :

```bash
python3 v2_server.py
```

Correction directe pour le service Render actuel :

- URL publique : `https://ac-piscine-pro-backend.onrender.com`
- symptome legacy : `/health` repond avec `service = hydr-azur-sync`
- symptome V2 attendu : `/health` repond avec `service = hydr-azur-sync-v2`

Si `POST /v2/auth/login` renvoie `404`, le service Render lance encore le backend legacy.

Dans ce cas :

1. remplacez la Start Command Render par :

```bash
python3 v2_server.py
```

2. ou gardez `python3 server.py` mais avec `APP_ENV=staging`

3. redeployez le service

4. relancez le seed demo

Compatibilite :

- si Render utilise encore `python3 server.py`, le fichier [backend_sync/server.py](/Users/ac/ac_piscine_pro copie/backend_sync/server.py) bascule maintenant automatiquement vers la V2 quand `APP_ENV=staging` ou `APP_ENV=prod`
- en `dev`, `python3 server.py` garde le backend legacy historique

Le serveur ecoute sur :

- `0.0.0.0`
- le port fourni par `PORT`
- fallback : `8000`

## 3. Initialisation de la base

Au premier demarrage :

- la base SQLite est creee si elle n existe pas
- les tables sont initialisees automatiquement
- le dossier media est cree automatiquement

Aucune migration manuelle n est necessaire pour ce patch.

## 4. Seed des comptes de demonstration

Activer temporairement :

```bash
export DEMO_SEED_ENABLED=true
```

Puis lancer :

```bash
cd backend_sync
python3 v2_seed_demo.py
```

Exemple Render :

```bash
APP_ENV=staging DEMO_SEED_ENABLED=true python3 v2_seed_demo.py
```

Comptes crees :

- `demo-pro@hydrazur.test` / `demo1234`
- `demo-free@hydrazur.test` / `demo1234`

Organisations :

- `demo-pro-hydrazur`
- `demo-free-hydrazur`

Le seed est idempotent : il cree ou met a jour les enregistrements existants.

Apres le seed, pensez a remettre :

```bash
export DEMO_SEED_ENABLED=false
```

## 5. Verification rapide

Healthcheck simple :

```bash
curl https://staging-api.hydrazur.app/health
```

Healthcheck detaille :

```bash
curl https://staging-api.hydrazur.app/v2/health
```

Login `demo-pro` :

```bash
curl -X POST https://staging-api.hydrazur.app/v2/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email":"demo-pro@hydrazur.test",
    "password":"demo1234"
  }'
```

Login `demo-free` :

```bash
curl -X POST https://staging-api.hydrazur.app/v2/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email":"demo-free@hydrazur.test",
    "password":"demo1234"
  }'
```

Verification de la session et des entitlements :

```bash
curl https://staging-api.hydrazur.app/v2/auth/me \
  -H "Authorization: Bearer VOTRE_TOKEN"
```

Attendu pour `demo-pro` :

- `subscription.planId = pro`
- `subscription.status = active`
- `pdfExport = true`
- `cloudSync = true`
- `teamMembers = true`
- `unlimitedClients = true`

Attendu pour `demo-free` :

- `subscription.planId = free`
- `pdfExport = false`
- `cloudSync = false`
- `teamMembers = false`
- `unlimitedClients = false`

## 6. URL a utiliser dans Flutter

Pour iOS/TestFlight :

```bash
flutter build ipa --release \
  --dart-define=APP_API_BASE_URL=https://staging-api.hydrazur.app/v2
```

L URL a injecter dans la build Flutter est :

- `https://staging-api.hydrazur.app/v2`

## 7. Conseils de plateforme

Pour Railway / Render / Fly :

- attachez un volume persistant pour la base SQLite et les medias
- exposez le service en HTTPS public
- configurez `PORT` depuis la plateforme
- ne dependez jamais de `localhost` pour l app mobile
