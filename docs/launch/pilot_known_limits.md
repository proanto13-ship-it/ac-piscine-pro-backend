# Pilot Known Limits

Ce document liste les limites connues a communiquer honnetement aux clients pilotes.

## Distribution

- la procedure Android release est prete
- la distribution Android publique type Play Store n'est pas encore l'objectif de ce pilote
- le pilote doit rester encadre

## Billing

- le produit gere les statuts `trial`, `active`, `past_due`, `canceled`, `expired`
- l'activation manuelle backend reste le mode le plus fiable pour un pilote
- le billing mobile natif n'est pas encore une base publique industrialisee
- la validation serveur Apple / Google n'est pas encore complete

## Synchronisation

- la sync V2 est operationnelle mais reste pragmatique
- des conflits limites peuvent encore exister dans des cas rares
- la reprise apres reseau instable est bonne, sans etre un moteur de sync parfait

## Medias

- les medias fonctionnent en local et en V2
- le backend utilise un stockage disque local pour l'instant
- il n'y a pas encore de stockage cloud externe ni de gestion avancee de quota

## Equipe

- les roles simples existent
- les invitations sont basiques
- il n'y a pas encore de parcours complet d'acceptation par email

## Support

- le support integre exporte un package local
- il n'y a pas d'envoi automatique vers un outil externe

## Legal et contenu

- les contenus `privacy` et `terms` existent dans le repo
- ils doivent encore etre relus juridiquement avant une ouverture publique large

## Backend

- SQLite est acceptable pour un petit pilote
- ce n'est pas encore une architecture de production a forte charge
