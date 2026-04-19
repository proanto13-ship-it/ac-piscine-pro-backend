# iPhone Smoke Test

Objectif : valider le parcours metier critique sur un iPhone reel avant d'ajouter des testeurs TestFlight externes.

## Preconditions

- build TestFlight ou build release iOS installee
- backend V2 accessible
- compte pilote cree
- organisation pilote creee
- abonnement / entitlements pilotes definis

## 1. Installation et lancement

- [ ] l'app s'installe sans crash au premier lancement
- [ ] l'icone, le nom et l'ecran de lancement sont corrects
- [ ] aucune alerte systeme inattendue ne bloque l'entree dans l'app

## 2. Login

- [ ] se connecter avec un compte V2 valide
- [ ] verifier que l'echec de login est bien gere sur mauvais mot de passe
- [ ] verifier que la session se restaure apres fermeture / relance

## 3. Onboarding

- [ ] verifier que l'onboarding s'affiche si le profil societe est incomplet
- [ ] renseigner nom, telephone, email, adresse, pays, locale, devise
- [ ] terminer l'onboarding sans blocage

## 4. Creation client

- [ ] creer un client
- [ ] verifier qu'il apparait dans la liste
- [ ] verifier que la fiche client est consultable

## 5. Creation intervention

- [ ] creer une intervention
- [ ] verifier qu'elle apparait dans l'historique du client

## 6. Photo

- [ ] autoriser l'acces appareil photo si necessaire
- [ ] ajouter au moins une photo
- [ ] verifier l'aperçu local

## 7. PDF

- [ ] generer un PDF
- [ ] verifier l'ouverture / preview iOS
- [ ] verifier le partage iOS

## 8. Sync

- [ ] lancer un `push`
- [ ] lancer un `pull`
- [ ] verifier le statut de sync
- [ ] verifier qu'aucune erreur silencieuse ne bloque l'utilisateur

## 9. Redemarrage

- [ ] tuer l'app
- [ ] relancer l'app
- [ ] verifier login/session
- [ ] verifier client, intervention, photo locale et documents

## 10. Support / Diagnostic

- [ ] ouvrir `Support / Diagnostic`
- [ ] exporter un diagnostic JSON
- [ ] verifier l'acces a `Compte, donnees et suppression`

## 11. Abonnement

- [ ] ouvrir `Etat de l abonnement`
- [ ] verifier plan, statut, message et source
- [ ] verifier le rafraichissement backend

## Decision

- [ ] GO TestFlight interne si tout le parcours critique passe
- [ ] GO testeurs externes seulement apres au moins un iPhone reel sans blocage sur login, photo, PDF et sync
