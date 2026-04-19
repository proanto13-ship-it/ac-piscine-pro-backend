# iOS TestFlight Known Limits

Ce document liste les limites connues a communiquer honnetement avant une beta iOS via TestFlight.

## Billing

- le flux de billing mobile natif existe cote app
- la validation serveur Apple n'est pas encore industrialisee pour un lancement public large
- pour un pilote reel, l'activation manuelle backend reste la voie la plus fiable si besoin

## Sync

- la sync V2 est exploitable, mais reste pragmatique
- des cas limites de conflits peuvent encore exister
- le stockage media backend reste local disque

## Support

- le support integre exporte un diagnostic local
- il n'y a pas encore d'envoi automatise vers un outil externe

## Equipe

- les roles simples existent
- les invitations sont minimales
- il n'y a pas encore de vrai parcours d'acceptation par email

## Legal

- le chemin de suppression de compte existe dans l'app
- les contenus `privacy` et `terms` existent dans le repo
- une relecture juridique finale reste recommandee avant ouverture publique large

## Architecture backend

- SQLite est acceptable pour une beta ou un petit pilote
- ce n'est pas encore une architecture de production a forte charge

## Verification metier

- le build, l'archive et l'IPA sont generables
- le parcours metier complet doit encore etre valide manuellement sur iPhone reel avant invitation externe massive
