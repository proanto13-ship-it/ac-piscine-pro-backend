# AGENTS.md

## Structure
- `lib/models` : modèles de données et sérialisation JSON.
- `lib/services` : services applicatifs, stockage, sync, PDF, numérotation.
- `backend_sync` : backend Python de synchronisation.
- `test` : tests unitaires et de logique métier.

## Commandes
- `flutter pub get`
- `flutter analyze`
- `flutter test`

## Règles
- Conserver la compatibilité ascendante des JSON déjà stockés localement.
- Si un modèle ou champ évolue, prévoir le fallback dans `fromJson` et `toJson`.
- Ne jamais mettre de secrets dans les backups ni dans les payloads de sync.
- Préférer les nouveaux modèles dans `lib/models`.
- Préférer les nouveaux services dans `lib/services`.
- Éviter les changements hors périmètre demandé.

## Definition Of Done
- Code formaté.
- `flutter analyze` OK.
- `flutter test` OK.
- Diff relu avant livraison.
