# Backend Sync V2

La V1 legacy reste dans `backend_sync/server.py` et continue de fonctionner telle quelle.

## Lancer la V2 en local ou en staging

```bash
cd backend_sync
python3 v2_server.py
```

Par defaut, la V2 ecoute sur `http://0.0.0.0:8000` et utilise SQLite dans `backend_sync/data/sync_v2_dev.sqlite3`.

Le serveur initialise automatiquement les tables manquantes au demarrage et positionne `PRAGMA user_version` pour la version de schema SQLite courante.

## Seed demo local

Un tenant de demonstration peut etre cree localement sans toucher a la V1:

```bash
cd backend_sync
python3 v2_seed_demo.py
```

Le script initialise une organization demo, un utilisateur de connexion, quelques clients, interventions, documents et medias placeholders dans la base SQLite V2.

Options utiles :

```bash
python3 v2_seed_demo.py --db /tmp/hydrazur_demo.sqlite3 --org-id demo-hydrazur --email demo@hydrazur.test --password demo1234
```

Ce seed reste manuel uniquement. Aucune donnee demo n est injectee automatiquement.

## Environnements et variables utiles

La V2 lit d abord `SYNC_V2_ENV`, puis `APP_ENV` si besoin. Valeurs supportees :

- `dev`
- `staging`
- `prod`

Comportements utiles :

- `dev` : bootstrap public autorise par defaut, token admin dev possible
- `staging` : comportement proche prod avec validation renforcee
- `prod` : bootstrap public desactive par defaut, secrets explicites obligatoires

Variables principales :

- `SYNC_V2_ENV` : environnement logique
- `SYNC_V2_HOST` : host d'ecoute
- `SYNC_V2_PORT` : port d'ecoute
- `PORT` : alias standard plateforme du port d'ecoute
- `SYNC_V2_DB` : chemin SQLite
- `DATABASE_URL` : alias staging/public pour SQLite (`sqlite:///...`)
- `SYNC_V2_MEDIA_DIR` : dossier de stockage local des medias
- `SYNC_V2_AUTH_SECRET` : secret HMAC des tokens
- `AUTH_SECRET` / `JWT_SECRET` : alias standards du secret d'auth
- `SYNC_V2_ADMIN_TOKEN` : token admin simple pour les actions manuelles d'abonnement
- `ADMIN_SEED_TOKEN` : alias staging/public du token admin
- `SYNC_V2_ALLOWED_ORIGINS` : origins CORS autorises, separes par des virgules
- `CORS_ALLOWED_ORIGINS` : alias staging/public des origins CORS
- `SYNC_V2_DEMO_SEED_ENABLED` / `DEMO_SEED_ENABLED` : autorise le seed demo en staging
- `SYNC_V2_ALLOW_PUBLIC_BOOTSTRAP` : autorise ou non `POST /v2/organizations` et `POST /v2/users` sans auth
- `SYNC_V2_MAX_JSON_BYTES` : taille max d'un body JSON
- `SYNC_V2_MAX_UPLOAD_BYTES` : taille max d'un upload media
- `SYNC_V2_SQLITE_BUSY_TIMEOUT_MS` : timeout SQLite
- `SYNC_V2_RATE_LIMIT_LOGIN` : debit max pour `/v2/auth/login`
- `SYNC_V2_RATE_LIMIT_ADMIN` : debit max pour les endpoints admin
- `SYNC_V2_RATE_LIMIT_DESTRUCTIVE` : debit max pour les suppressions sensibles
- `SYNC_V2_RATE_LIMIT_UPLOAD` : debit max pour `POST /v2/media/upload`
- `SYNC_V2_RATE_LIMIT_WINDOW_SECONDS` : fenetre de limitation
- `SYNC_V2_LOG_LEVEL` : niveau de logs Python
- `SYNC_V2_BILLING_IOS_PRO_PRODUCT_ID` : product id iOS du plan `Pro`
- `SYNC_V2_BILLING_ANDROID_PRO_PRODUCT_ID` : product id Android du plan `Pro`
- `SYNC_V2_PRO_TRIAL_DAYS` : duree de l essai gratuit Pro en jours, `0` pour desactiver l essai

Exemple staging :

```bash
APP_ENV=staging PORT=8000 DATABASE_URL=sqlite:////srv/hydrazur/staging.sqlite3 python3 v2_server.py
```

Render / services cloud :

```bash
APP_ENV=staging PORT=8000 DATABASE_URL=sqlite:////srv/hydrazur/staging.sqlite3 python3 v2_server.py
```

Si votre plateforme lance encore `python3 server.py`, l entrypoint legacy reroute maintenant automatiquement vers la V2 en `staging` et `prod`.

Guide Render detaille :

- [backend_sync/DEPLOY_RENDER_STAGING.md](/Users/ac/ac_piscine_pro copie/backend_sync/DEPLOY_RENDER_STAGING.md)

Pour les pilotes en local, vous pouvez garder le token admin par defaut `dev-admin-token` ou le surcharger :

```bash
SYNC_V2_ADMIN_TOKEN=mon-token-admin python3 v2_server.py
```

## Demarrage production minimal

Exemple raisonnable sans infra cloud specifique :

```bash
cd backend_sync
SYNC_V2_ENV=prod \
SYNC_V2_HOST=0.0.0.0 \
SYNC_V2_PORT=8788 \
SYNC_V2_DB=/srv/hydrazur/data/sync_v2.sqlite3 \
SYNC_V2_MEDIA_DIR=/srv/hydrazur/data/media \
SYNC_V2_AUTH_SECRET='change-me-prod-secret' \
SYNC_V2_ADMIN_TOKEN='change-me-admin-token' \
SYNC_V2_ALLOWED_ORIGINS='https://app.example.com' \
python3 v2_server.py
```

En `prod`, le serveur refuse de demarrer si `SYNC_V2_AUTH_SECRET` ou `SYNC_V2_ADMIN_TOKEN` restent sur leur valeur dev par defaut.

## Healthcheck, logs et erreurs

- `GET /health` expose un statut simple pour les plateformes cloud
- `GET /v2/health` expose maintenant l environnement, la config utile non sensible et l etat SQLite
- les logs backend sont emis en JSON ligne par ligne, avec `requestId`, statut HTTP, duree et contexte org/user si connu
- une erreur non capturee renvoie une `500` JSON avec `requestId`
- les endpoints sensibles ont une limitation de debit memoire-processus simple

## Initialisation, sauvegarde et restauration SQLite

Initialisation :

- au premier demarrage, la base et les dossiers manquants sont crees automatiquement
- SQLite passe en `WAL`, `foreign_keys=ON`, `busy_timeout` et `synchronous=NORMAL`

Sauvegarde SQLite dev :

```bash
sqlite3 backend_sync/data/sync_v2_dev.sqlite3 ".backup '/tmp/sync_v2_backup.sqlite3'"
tar -czf /tmp/sync_v2_media_backup.tar.gz backend_sync/data/media
```

Restauration SQLite dev :

```bash
cp /tmp/sync_v2_backup.sqlite3 backend_sync/data/sync_v2_dev.sqlite3
rm -rf backend_sync/data/media
tar -xzf /tmp/sync_v2_media_backup.tar.gz -C backend_sync/data
```

Pour une restauration propre, arretez le serveur avant de remplacer la base ou le dossier `media`.

## Endpoints V2

- `GET /health`
- `GET /v2/health`
- `POST /v2/auth/login`
- `GET /v2/auth/me`
- `GET /v2/account/export`
- `DELETE /v2/account/me`
- `GET /v2/team/members`
- `GET /v2/team/invitations`
- `POST /v2/team/invitations`
- `POST /v2/public-links`
- `GET /v2/public/share/{token}`
- `GET /v2/public/share/{token}/media/{attachment_id}`
- `POST /v2/admin/subscriptions/assign`
- `POST /v2/billing/events/subscription-updated`
- `POST /v2/billing/mobile/reconcile`
- `POST /v2/billing/trial/start`
- `GET|POST /v2/organizations`
- `GET|PUT|DELETE /v2/organizations/{id}`
- `GET|POST /v2/users`
- `GET|PUT|DELETE /v2/users/{id}`
- `GET|POST /v2/clients`
- `GET|PUT|DELETE /v2/clients/{id}`
- `GET|POST /v2/interventions`
- `GET|PUT|DELETE /v2/interventions/{id}`
- `GET|POST /v2/financial-documents`
- `GET|PUT|DELETE /v2/financial-documents/{id}`

Chaque ressource porte un `organization_id`. Les listes acceptent aussi `?organization_id=...` pour filtrer, mais la V2 applique maintenant un scope strict sur l'organisation de l'utilisateur connecte.

Pour le dev :

- `POST /v2/organizations` et `POST /v2/users` restent ouverts pour amorcer un tenant local
- toutes les autres routes CRUD sous `/v2/...` exigent un token Bearer
- tout acces cross-org renvoie une erreur
- `admin` et `manager` peuvent inviter et lister les invitations d equipe
- `technician` peut voir les membres de son organisation mais ne peut pas gerer les invitations

En `prod`, le bootstrap public est desactive par defaut. Il peut etre reactive explicitement avec `SYNC_V2_ALLOW_PUBLIC_BOOTSTRAP=true` si vous assumez ce risque dans un environnement controle.

## Exemple rapide

Creer une organisation :

```bash
curl -X POST http://127.0.0.1:8788/v2/organizations \
  -H "Content-Type: application/json" \
  -d '{"id":"org_demo","organization_id":"org_demo","name":"HydrAzur Demo"}'
```

Creer un client :

```bash
curl -X POST http://127.0.0.1:8788/v2/clients \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer VOTRE_TOKEN" \
  -d '{"id":"client_1","organization_id":"org_demo","display_name":"Piscine Martin"}'
```

Login de dev :

```bash
curl -X POST http://127.0.0.1:8788/v2/auth/login \
  -H "Content-Type: application/json" \
  -d '{"organization_id":"org_demo","email":"admin@example.test","password":"secret"}'
```

Login demo sans `organization_id` quand l email est unique :

```bash
curl -X POST http://127.0.0.1:8000/v2/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"demo-pro@hydrazur.test","password":"demo1234"}'
```

## Deploiement staging

Procedure complete :

- [backend_sync/DEPLOY_STAGING.md](/Users/ac/ac_piscine_pro copie/backend_sync/DEPLOY_STAGING.md)

## Equipe et invitations simples

Inviter un manager ou un technicien depuis un compte `admin` ou `manager` :

```bash
curl -X POST http://127.0.0.1:8788/v2/team/invitations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer VOTRE_TOKEN" \
  -d '{
    "email":"tech@example.test",
    "fullName":"Technicien Demo",
    "role":"technician"
  }'
```

Lister les membres de l organisation :

```bash
curl http://127.0.0.1:8788/v2/team/members \
  -H "Authorization: Bearer VOTRE_TOKEN"
```

## Billing et cycle de vie d abonnement

Statuts supportes :

- `trial`
- `active`
- `past_due`
- `canceled`
- `expired`

Semantique simple :

- `trial` : acces Pro temporaire jusqu a `endedAtIso`
- `active` : acces Pro normal
- `past_due` : acces Pro bloque tant que le paiement n est pas regularise
- `canceled` : abonnement resilie mais acces conserve jusqu a `endedAtIso`
- `expired` : plus d acces Pro

Demarrer un essai gratuit quand `SYNC_V2_PRO_TRIAL_DAYS` est superieur a `0` :

```bash
curl -X POST http://127.0.0.1:8788/v2/billing/trial/start \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer VOTRE_TOKEN" \
  -d '{"plan_id":"pro"}'
```

## Liens publics client en lecture seule

Creer un lien public pour une intervention :

```bash
curl -X POST http://127.0.0.1:8788/v2/public-links \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer VOTRE_TOKEN" \
  -d '{
    "resource_type":"intervention",
    "resource_id":"inter_1",
    "expires_at_iso":"2026-05-17T18:00:00Z"
  }'
```

Le backend renvoie un `publicUrl` directement consultable par le client.

Limites de securite actuelles :

- le lien est strictement borne a une seule ressource `intervention` ou `financial_document`
- aucun acces aux autres donnees de l organisation n est expose
- les medias publics ne sont servis que pour les pieces jointes de l intervention partagee
- le lien reste secret par possession du token; si le lien fuit, il reste accessible jusqu a expiration
- il n y a pas encore de revocation manuelle UI des liens dans ce patch

## Activation manuelle d'un abonnement pilote

Assigner le plan `Pro` a une organization :

```bash
curl -X POST http://127.0.0.1:8788/v2/admin/subscriptions/assign \
  -H "Content-Type: application/json" \
  -H "X-Admin-Token: dev-admin-token" \
  -d '{
    "organization_id":"org_demo",
    "plan_id":"pro",
    "status":"active",
    "started_at_iso":"2026-04-17T09:00:00Z",
    "ended_at_iso":"2026-06-17T18:00:00Z"
  }'
```

Desactiver l'abonnement :

```bash
curl -X POST http://127.0.0.1:8788/v2/admin/subscriptions/assign \
  -H "Content-Type: application/json" \
  -H "X-Admin-Token: dev-admin-token" \
  -d '{
    "organization_id":"org_demo",
    "plan_id":"free",
    "status":"expired",
    "started_at_iso":"2026-04-17T09:00:00Z",
    "ended_at_iso":"2026-04-30T18:00:00Z"
  }'
```

Dans l'app Flutter, utilisez ensuite le bouton `Rafraichir depuis le backend` dans les reglages de pricing pour recharger les entitlements et l'etat d'abonnement.

## Reception d'un evenement billing

Ce endpoint prepare l'integration d'un vrai provider de paiement sans coupler la V2 a un provider unique.

```bash
curl -X POST http://127.0.0.1:8788/v2/billing/events/subscription-updated \
  -H "Content-Type: application/json" \
  -H "X-Admin-Token: dev-admin-token" \
  -d '{
    "provider":"mock-web",
    "event_type":"subscription.updated",
    "organization_id":"org_demo",
    "plan_id":"pro",
    "status":"active",
    "started_at_iso":"2026-04-17T09:00:00Z",
    "ended_at_iso":"2026-06-17T18:00:00Z",
    "external_customer_id":"cus_demo",
    "external_subscription_id":"sub_demo"
  }'
```

Voir aussi `docs/billing_integration.md` pour les points d'integration Flutter/backend a brancher ensuite.

## Reconciliation billing mobile natif

Le client Flutter natif peut maintenant envoyer une preuve d achat/restauration apres passage par l abstraction `BillingProvider`.

```bash
curl -X POST http://127.0.0.1:8788/v2/billing/mobile/reconcile \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer VOTRE_TOKEN" \
  -d '{
    "provider":"app_store",
    "purchases":[
      {
        "provider":"app_store",
        "platform":"ios",
        "productId":"com.hydrazur.pro.monthly",
        "purchaseId":"ios_tx_001",
        "status":"purchased",
        "transactionDateIso":"2026-04-17T10:00:00Z",
        "serverVerificationData":"signed-receipt"
      }
    ]
  }'
```

Ce endpoint :

- mappe le `productId` mobile vers le plan backend
- journalise la transaction
- met a jour la `subscription`
- renvoie le snapshot billing final

Limite actuelle :

- la validation store-server complete n est pas encore branchee
- la reconciliation reste pragmatique et prepare la future verification App Store / Google Play sans dupliquer les entitlements cote client

## Compte et donnees

La V2 expose aussi des actions minimales pour l'utilisateur connecte :

- `GET /v2/account/export`
- `DELETE /v2/account/me`

Limites actuelles :

- l'export utilisateur est renvoye en JSON
- l'export backend est scope a l'organisation courante quand les donnees sont partagees
- l'app Flutter exporte actuellement en JSON local, pas encore en ZIP
- si l'utilisateur supprime son compte dans une organisation partagee, seul son compte est supprime
- si c'est le dernier utilisateur de l'organisation, les donnees org associees sont supprimees cote backend V2
