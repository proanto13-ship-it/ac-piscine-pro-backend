# Pilot Rollback And Recovery

## Objectif

Revenir rapidement a un etat stable si un probleme critique apparait chez un client pilote.

## 1. Rollback application

Conserver au minimum :

- l'APK pilote courant
- l'APK pilote precedent stable

En cas de regression critique :

1. stopper toute nouvelle diffusion du build courant
2. renvoyer l'APK precedent stable
3. demander un export `Support / Diagnostic`
4. demander un export local JSON si l'app est encore utilisable

## 2. Recuperation des donnees locales

Depuis l'appareil :

- utiliser `Compte et donnees`
- exporter les donnees locales en JSON si possible

## 3. Recuperation backend V2

Conserver des sauvegardes regulieres de :

- la base SQLite
- le dossier `media`

Exemples :

```bash
sqlite3 backend_sync/data/sync_v2_dev.sqlite3 ".backup '/tmp/sync_v2_backup.sqlite3'"
tar -czf /tmp/sync_v2_media_backup.tar.gz backend_sync/data/media
```

## 4. Si la sync est en cause

- demander au pilote d'arreter `push/pull`
- continuer en local si possible
- conserver une copie des diagnostics exportes
- corriger puis demander un nouveau test guide

## 5. Si l'abonnement est en cause

- verifier le statut backend de l'organisation
- relancer l'activation manuelle si besoin
- demander un rafraichissement depuis l'ecran `Etat de l abonnement`

## 6. Si les medias sont en cause

- verifier l'etat de sync
- verifier le stockage disque backend
- confirmer si le probleme touche seulement l'upload ou aussi le download

## 7. Decision de rollback

Rollback immediat si l'un de ces points est bloque :

- login
- creation intervention
- generation PDF
- sync critique
- perte de donnees constatee
