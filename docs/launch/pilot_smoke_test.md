# Pilot Smoke Test

Objectif : verifier le parcours critique reel avant envoi a chaque client pilote.

## Preconditions

- build release Android installee
- backend V2 accessible
- organisation pilote creee
- utilisateur pilote cree
- abonnement / entitlements pilotes definis

## Parcours critique

### 1. Login

- [ ] ouvrir l'app
- [ ] se connecter avec un compte V2 valide
- [ ] verifier que la session est restauree apres fermeture/reouverture si l'app n'est pas effacee

### 2. Onboarding

- [ ] verifier que l'onboarding apparait si le profil societe n'est pas configure
- [ ] saisir le profil societe minimum
- [ ] verifier l'arrivee sur l'ecran principal

### 3. Premier client

- [ ] creer un client
- [ ] verifier qu'il apparait dans la liste
- [ ] fermer puis rouvrir l'app et verifier qu'il est toujours present

### 4. Premiere intervention

- [ ] creer une intervention
- [ ] verifier qu'elle apparait dans l'historique du client

### 5. Photo

- [ ] ajouter au moins une photo
- [ ] verifier que l'aperçu local fonctionne

### 6. PDF

- [ ] generer un PDF
- [ ] verifier que le document se previsualise ou se partage correctement
- [ ] verifier que le feature gate est coherent avec l'abonnement du pilote

### 7. Sync

- [ ] lancer un `push`
- [ ] lancer un `pull`
- [ ] verifier que l'etat de sync devient `success` ou expliquer tout `partial_failure`

### 8. Redemarrage

- [ ] tuer l'app
- [ ] relancer l'app
- [ ] verifier la session, le client, l'intervention, la photo locale et les documents

## Ecran Support / Diagnostic

- [ ] ouvrir `Support / Diagnostic`
- [ ] exporter un diagnostic JSON
- [ ] verifier que le fichier est cree

## Ecran Etat de l abonnement

- [ ] ouvrir l'ecran dedie
- [ ] verifier plan, statut, message et source
- [ ] verifier le rafraichissement backend si une session V2 est active

## Decision pilote

- [ ] GO si tout le parcours critique passe sans blocage
- [ ] NO-GO si login, creation intervention, PDF ou sync sont bloquants
