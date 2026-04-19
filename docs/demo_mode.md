# Mode demo

Le mode demo est manuel uniquement. Aucune donnee de demonstration n est injectee automatiquement au demarrage, en release ou en production.

## App Flutter

1. Ouvrir `Reglages` puis `Compte et donnees`.
2. Utiliser `Charger les donnees demo`.
3. L app efface d abord les donnees locales existantes, la session V2 locale et les secrets stockes.
4. Elle recharge ensuite un jeu de donnees exemples realistes avec:
   - profil societe
   - reglages workspace
   - 4 clients
   - 7 interventions
   - 3 documents financiers
   - medias placeholders locaux

Le seed demo desactive la synchronisation cloud par defaut pour eviter de melanger des donnees demo avec un vrai tenant.

## Retour a un environnement propre

Dans `Compte et donnees`, utiliser `Reinitialiser mes donnees locales`.

Cette action supprime:
- JSON locaux
- backups
- medias
- secrets stockes en securise
- session V2 locale

## Backend V2 dev

Pour creer un tenant demo local cote backend:

```bash
cd backend_sync
python3 v2_seed_demo.py
```

Le script affiche ensuite:
- `organization_id`
- email
- mot de passe

Par defaut, il cree une organization demo avec plan `Pro`, quelques clients, interventions, documents et medias de demonstration dans la base SQLite V2 locale.
