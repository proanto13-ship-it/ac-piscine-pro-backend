# Backend de synchro HydrAzur Pro

Petit backend Python sans dependance externe pour synchroniser les donnees de l'app.

## Ce qu'il fait

- recoit un export de l'app via `POST /sync`
- stocke le payload sur disque dans `backend_sync/data/sync_store.json`
- renvoie le dernier payload via `GET /sync`
- expose un check simple via `GET /health`

## Lancer le serveur

```bash
cd backend_sync
python3 server.py
```

Par defaut, le serveur ecoute sur `http://0.0.0.0:8787`.

## Variables utiles

- `SYNC_HOST` : host d'ecoute
- `SYNC_PORT` : port d'ecoute
- `SYNC_API_KEY` : token optionnel pour proteger `GET /sync` et `POST /sync`

Exemple :

```bash
SYNC_PORT=8787 SYNC_API_KEY=mon_token python3 server.py
```

## Brancher l'app Flutter

Dans l'ecran `Preparation cloud`, utilise :

- `Endpoint API` : `http://IP_DU_SERVEUR:8787/sync`
- `Cle API / token` : la valeur de `SYNC_API_KEY` si tu en as defini une

L'app fera :

- `POST` sur cet endpoint pour envoyer les donnees
- `GET` sur ce meme endpoint pour les recuperer

## Tester rapidement

```bash
curl http://127.0.0.1:8787/health
curl -H "x-api-key: mon_token" http://127.0.0.1:8787/sync
```

Envoi d'un payload :

```bash
curl -X POST http://127.0.0.1:8787/sync \
  -H "Content-Type: application/json" \
  -H "x-api-key: mon_token" \
  -d '{"clients":[],"pricingSettings":{},"companyProfile":{},"teamMembers":[],"cloudSyncSettings":{}}'
```
