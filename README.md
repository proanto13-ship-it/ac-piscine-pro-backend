# HydrAzur Pro

Application Flutter de diagnostic terrain pour piscinistes.

## Ce que fait l'app

- gestion d'un portefeuille clients
- saisie d'analyses d'eau
- calcul d'indicateurs techniques comme le LSI
- recommandations d'ajustement chimique
- chiffrage interne produits + main d'oeuvre
- génération de PDF d'intervention

## Stack

- Flutter
- stockage local sur l'appareil
- génération PDF avec `pdf` et `printing`
- backend de synchro léger en Python standard dans `backend_sync/`

## Lancer le projet

```bash
flutter pub get
flutter run
```

Pour lancer proprement `dev`, `staging` ou `prod` avec des `dart-define` dédiés, voir [docs/deployment_environments.md](/Users/ac/ac_piscine_pro%20copie/docs/deployment_environments.md).

## Structure utile

- `lib/main.dart` : shell principal, navigation, formulaires clients
- `lib/diagnostic_page_pro.dart` : rendu du diagnostic pro
- `lib/logic/diagnostic_logic.dart` : règles métier et recommandations
- `lib/services/pdf_service.dart` : génération du rapport PDF
- `lib/services/local_storage_service.dart` : persistance locale des données
- `lib/models/pricing_settings.dart` : catalogue et réglages tarifaires
- `backend_sync/server.py` : backend de synchro HTTP pour multi-appareil

## Synchro cloud simple

Un backend minimal est fourni dans [`backend_sync/server.py`](/Users/ac/ac_piscine_pro%20copie/backend_sync/server.py).

Pour le lancer :

```bash
cd backend_sync
python3 server.py
```

Puis, dans l'app :

- `Endpoint API` : `http://IP_DU_SERVEUR:8787/sync`
- `Clé API / token` : optionnel, à remplir seulement si `SYNC_API_KEY` est défini côté serveur

Le détail est documenté dans [`backend_sync/README.md`](/Users/ac/ac_piscine_pro%20copie/backend_sync/README.md).

## Priorités produit

1. fiabiliser la persistance locale et préparer une synchro cloud
2. renforcer la cohérence métier des recommandations
3. améliorer le suivi client et l'historique des interventions
4. rendre le PDF exploitable comme vrai document commercial
