# Support

## Canaux de support disponibles

Le canal principal de support est integre directement dans l'application via l'ecran `Aide / Support`.

Depuis cet ecran, un utilisateur peut :

- signaler un bug
- envoyer un retour produit
- exporter un diagnostic JSON ou ZIP
- consulter le guide utilisateur
- consulter la FAQ, la politique de confidentialite et les conditions d'utilisation

## Contenu du diagnostic de support

Le package de diagnostic contient au minimum :

- version de l'application
- numero de build
- plateforme
- environnement actif (`dev`, `staging`, `prod`)
- etat de synchronisation
- logs recents rediges
- resume local des donnees
- identifiants non sensibles de session, utilisateur et organisation si disponibles

Le diagnostic ne doit pas contenir :

- mot de passe
- token de session
- cle API
- secret technique

## Reponse attendue du support

Pour un traitement efficace, demander a l'utilisateur :

1. ce qu'il essayait de faire
2. ce qu'il attendait
3. ce qu'il a observe
4. si le probleme est bloquant ou non
5. d'exporter un diagnostic si necessaire

## Limitations honnetes a communiquer

- le support integre n'envoie pas automatiquement les donnees a un SaaS externe
- l'export est local : le fichier doit ensuite etre transmis par le canal choisi par l'equipe
- certaines fonctions avancees dependent d'un backend V2 correctement configure

## Reponse courte type

> Merci, nous avons bien recu votre retour. Merci d'ajouter si possible un export de diagnostic depuis l'ecran Aide / Support afin de verifier la version, l'etat de sync et les logs non sensibles.
