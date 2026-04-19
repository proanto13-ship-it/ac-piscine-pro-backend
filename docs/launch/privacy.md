# Politique de confidentialite

## 1. Objet

Cette politique de confidentialite explique quelles donnees sont traitees par l'application, pour quelles finalites et quels choix sont disponibles pour l'utilisateur.

## 2. Donnees traitees

Selon l'usage, l'application peut traiter :

- donnees de compte et d'organisation
- profil societe
- clients
- interventions
- documents financiers
- photos et pieces jointes
- reglages metier et de synchronisation
- informations techniques necessaires au support

## 3. Donnees stockees localement

Par defaut, l'application conserve des donnees localement sur l'appareil afin de fonctionner hors ligne, notamment :

- clients
- interventions
- documents
- reglages de l'espace de travail
- progression d'onboarding
- file d'attente de synchronisation

Les secrets sensibles ne doivent pas etre inclus dans les sauvegardes ni dans les payloads de synchronisation. Les tokens et cles sensibles sont stockes separement de facon securisee quand cette capacite est disponible sur la plateforme.

## 4. Synchronisation cloud

Si la synchronisation cloud est activee, certaines donnees peuvent etre transmises au backend configure par l'organisation. Le perimetre depend du mode de synchronisation et de la configuration du backend.

Dans la V2, les donnees sont scopees par `organization_id`.

## 5. Medias

Les photos et pieces jointes peuvent etre conservees localement sur l'appareil. Si la synchronisation V2 des medias est activee et fonctionnelle, elles peuvent aussi etre envoyees au backend configure.

## 6. Support

L'utilisateur peut exporter un package de diagnostic depuis l'application. Ce package est concu pour exclure les secrets et inclure uniquement des informations techniques non sensibles utiles au support.

## 7. Achats integres

Si les abonnements mobiles natifs sont actives sur l'environnement utilise, certaines informations de transaction peuvent etre utilisees pour reconcilier l'etat de l'abonnement avec le backend. L'application ne pretend pas remplacer les politiques de confidentialite Apple ou Google.

## 8. Suppression et export des donnees

L'application permet, selon le contexte :

- l'export des donnees locales
- l'export des donnees backend si une session V2 est active
- la reinitialisation des donnees locales
- la suppression du compte backend si le backend le permet

## 9. Liens publics

L'application peut creer des liens publics en lecture seule pour certains rapports et interventions. Ces liens sont limites a la ressource autorisee, mais toute personne possedant le lien peut y acceder jusqu'a expiration ou revocation si ce mecanisme est disponible.

## 10. Securite

Des mesures raisonnables sont prises pour limiter l'exposition des donnees, mais aucun systeme n'est totalement exempt de risque. L'organisation reste responsable de sa configuration, de ses acces et du choix de son environnement d'hebergement.

## 11. Contact

Pour une demande relative aux donnees, utiliser en priorite l'ecran `Compte et donnees` et l'ecran `Aide / Support` dans l'application.
