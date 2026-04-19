# Deploy Render Staging

Objectif : deployer la V2 sur Render avec les routes SaaS/auth attendues par l app iOS.

## 1. Root Directory

Deux options :

- si le service Render pointe deja sur `backend_sync/`, gardez ce dossier comme Root Directory
- sinon, depuis la racine du repo, adaptez les commandes avec le prefixe `backend_sync/`

## 2. Build Command

Le backend V2 utilise uniquement la bibliotheque standard Python pour servir l API.

Build Command conseillee :

```bash
pip install -r requirements.txt
```

## 3. Start Command

Commande recommandee pour le service Render actuel :

```bash
python3 server.py
```

Ce mode ajoute dans `server.py` une compatibilite staging/TestFlight pour :

- `POST /v2/auth/login`
- `GET /v2/auth/me`
- `GET /v2/billing/entitlements`
- `GET /v2/sync`
- `GET /v2/clients`
- `PUT /v2/clients/{id}`
- `POST /v2/clients`
- `GET /v2/interventions`
- `PUT /v2/interventions/{id}`
- `POST /v2/interventions`
- `GET /v2/financial-documents`
- `PUT /v2/financial-documents/{id}`
- `POST /v2/financial-documents`
- `GET /v2/media`
- `POST /v2/media/upload`
- `GET /v2/media/{id}/download`

tout en conservant :

- `GET /health`
- `GET /sync`
- `POST /sync`

Alternative full V2 :

```bash
python3 render_app.py
```

Important :

- si vous utilisez `python3 server.py`, cette auth demo est une compatibilite staging/TestFlight, pas une auth production finale
- si vous voulez l API V2 complete, preferez ensuite `python3 render_app.py`

## 4. Variables d environnement

Variables minimales :

- `APP_ENV=staging`
- `PORT` fourni par Render
- `DATABASE_URL=sqlite:////var/data/sync_v2_staging.sqlite3`
- `SYNC_V2_MEDIA_DIR=/var/data/media`
- `AUTH_SECRET=...`
- `ADMIN_SEED_TOKEN=...`
- `CORS_ALLOWED_ORIGINS=https://ac-piscine-pro-backend.onrender.com`
- `DEMO_SEED_ENABLED=false`

Notes :

- utilisez un disque persistant Render pour SQLite et les medias
- ne hardcodez jamais les secrets
- l app iOS/TestFlight doit utiliser :
  - `https://ac-piscine-pro-backend.onrender.com/v2`

## 5. Seed des comptes demo

Temporairement :

```bash
export DEMO_SEED_ENABLED=true
python3 v2_seed_demo.py
export DEMO_SEED_ENABLED=false
```

Comptes attendus :

- `demo-pro@hydrazur.test` / `demo1234`
- `demo-free@hydrazur.test` / `demo1234`

## 6. Validation curl

Healthcheck :

```bash
curl -i https://ac-piscine-pro-backend.onrender.com/health
```

Attendu :

- `200`
- `service = hydr-azur-sync`
- `v2Auth = true`
- `syncV2 = true`

Login demo Pro :

```bash
curl -i -X POST https://ac-piscine-pro-backend.onrender.com/v2/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"demo-pro@hydrazur.test","password":"demo1234"}'
```

Validation session :

```bash
curl -i https://ac-piscine-pro-backend.onrender.com/v2/auth/me \
  -H "Authorization: Bearer VOTRE_TOKEN"
```

Push client minimal :

```bash
curl -i -X PUT https://ac-piscine-pro-backend.onrender.com/v2/clients/client-demo-1 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer VOTRE_TOKEN" \
  -d '{"id":"client-demo-1","name":"Client Démo","createdAtIso":"2026-04-19T08:00:00Z","updatedAtIso":"2026-04-19T08:00:00Z","version":1}'
```

Pull clients :

```bash
curl -i https://ac-piscine-pro-backend.onrender.com/v2/clients \
  -H "Authorization: Bearer VOTRE_TOKEN"
```

Pull sync global :

```bash
curl -i https://ac-piscine-pro-backend.onrender.com/v2/sync \
  -H "Authorization: Bearer VOTRE_TOKEN"
```

Attendu pour `demo-pro` :

- `subscription.planId = pro`
- `subscription.status = active`
- `pdfExport = true`
- `cloudSync = true`
- `teamMembers = true`
- `unlimitedClients = true`

## 7. Diagnostic du probleme actuel

Si Render repond :

- `/health` : `service = hydr-azur-sync`
- `/v2/auth/login` : `404 {"message":"Route inconnue."}`

alors le service public lance encore le backend legacy.

La correction est :

1. redeployer avec la version de `server.py` qui expose les routes V2 de compatibilite
2. garder la Start Command `python3 server.py`
3. verifier `APP_ENV=staging`
4. relancer le seed demo
5. valider au minimum `GET /health`, `POST /v2/auth/login`, `GET /v2/auth/me`, `GET /v2/clients`
