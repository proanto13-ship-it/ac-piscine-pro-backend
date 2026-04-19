# Environnements de déploiement

Convention retenue : gestion simple par `--dart-define`, sans imposer de flavors natifs supplémentaires pour l'instant.

Objectif :

- garder le build existant compatible
- séparer clairement `dev`, `staging` et `prod`
- éviter qu'un seed démo ou des logs verbeux se retrouvent activés en production

## Variables supportées

- `APP_ENV` : `dev`, `staging`, `prod`
- `APP_API_BASE_URL` : endpoint V2 ou API principal selon l'environnement
- `APP_NAME_SUFFIX` : suffixe visible dans le nom affiché de l'app
- `APP_ENABLE_DEMO_MODE` : `true` ou `false`
- `APP_ENABLE_VERBOSE_LOGS` : `true` ou `false`

## Comportement adopté

- Si `APP_ENV` n'est pas fourni :
  - le comportement historique est conservé
  - aucun namespace de stockage supplémentaire n'est forcé
  - le nom visible reste `HydrAzur Pro`
- Si `APP_ENV=dev` ou `APP_ENV=staging` :
  - les fichiers locaux sont namespacés (`dev_...`, `staging_...`)
  - les backups, payloads de sync, logs et fichiers d'état utilisent aussi ce namespace
  - le nom affiché dans l'app reçoit un suffixe par défaut (`DEV`, `STAGING`) sauf surcharge
- Si `APP_ENV=prod` :
  - pas de suffixe ajouté par défaut
  - pas de mode démo activé par défaut
  - logs console verbeux désactivés par défaut
  - le script `backend_sync/v2_seed_demo.py` refuse explicitement de s'exécuter

## Commandes recommandées

### Dev

```bash
flutter run \
  --dart-define=APP_ENV=dev \
  --dart-define=APP_API_BASE_URL=http://127.0.0.1:8788/v2
```

### Staging

```bash
flutter run \
  --dart-define=APP_ENV=staging \
  --dart-define=APP_API_BASE_URL=https://staging.example.test/v2
```

### Production

```bash
flutter build ios --release \
  --dart-define=APP_ENV=prod \
  --dart-define=APP_API_BASE_URL=https://api.example.test/v2
```

Même principe pour Android :

```bash
flutter build apk --release \
  --dart-define=APP_ENV=prod \
  --dart-define=APP_API_BASE_URL=https://api.example.test/v2
```

## Option de suffixe explicite

Pour un build terrain plus visible :

```bash
flutter run \
  --dart-define=APP_ENV=staging \
  --dart-define=APP_NAME_SUFFIX=\" Pilot\" \
  --dart-define=APP_API_BASE_URL=https://staging.example.test/v2
```

## Données locales

Quand `APP_ENV` est explicitement défini :

- `dev` écrit dans des fichiers `dev_*.json`
- `staging` écrit dans des fichiers `staging_*.json`
- `prod` garde les noms historiques

Cela évite de mélanger :

- réglages cloud
- queue de sync
- progression onboarding
- rappels de visite
- logs
- backups et payloads exportés

## Démo et logs

- Le mode démo Flutter est désactivé par défaut en `prod`
- Les seeds démo backend sont bloqués si `APP_ENV=prod`
- Les logs restent écrits localement, mais la sortie console verbeuse est désactivée par défaut en `prod`

## Limites actuelles

- ce patch n'ajoute pas encore de vrais flavors natifs Android/iOS avec icônes séparées
- le suffixe d'environnement est visible dans l'app Flutter, mais pas encore garanti sur le libellé natif du launcher
- la séparation des données locales repose sur les namespaces de fichiers, pas sur des sandbox d'app distinctes
