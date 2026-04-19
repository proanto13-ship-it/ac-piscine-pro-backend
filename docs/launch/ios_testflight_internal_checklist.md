# TestFlight Internal Checklist

Objectif : valider le passage de la build archivee a une beta interne iOS avant tout groupe externe.

## Build et upload

- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `flutter build ipa --release`
- [ ] upload de l'IPA dans App Store Connect
- [ ] build visible dans TestFlight
- [ ] metadata de build minimales completees

## Verification App Review / ecrans visibles

- [ ] page de connexion accessible
- [ ] pricing / paywall accessible depuis la connexion
- [ ] support / diagnostic accessible depuis la connexion
- [ ] privacy accessible depuis la connexion
- [ ] terms accessibles depuis la connexion
- [ ] chemin suppression de compte verifie apres connexion

## Verification metier sur iPhone reel

- [ ] login
- [ ] onboarding
- [ ] creation client
- [ ] creation intervention
- [ ] ajout photo
- [ ] generation PDF
- [ ] sync
- [ ] redemarrage app

## Verification support

- [ ] export diagnostic JSON
- [ ] navigation vers `Compte, donnees et suppression`
- [ ] export local JSON
- [ ] suppression de compte testee si environnement pilote le permet

## Verification abonnement

- [ ] ecran `Etat de l abonnement` lisible
- [ ] rafraichissement backend OK
- [ ] paywall coherent avec le statut pilote

## Decision

- [ ] GO interne si aucun blocage critique
- [ ] NO-GO externe si login, photo, PDF, sync ou suppression de compte sont incertains
