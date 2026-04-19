# App Review Notes

Ce document prepare le contenu a copier dans App Store Connect pour accelerer la review de la beta TestFlight externe.

## 1. Resume produit

HydrAzur Pro est une application de terrain pour professionnels piscine. Elle permet de gerer des clients, des interventions, des photos, des PDF et une synchronisation cloud.

## 2. Ecrans visibles par App Review

Depuis l'ecran de connexion, App Review peut acceder sans authentification a :

- login
- mode local via `Continuer en local`
- pricing / paywall
- support / diagnostic
- politique de confidentialite
- conditions d'utilisation

Apres connexion, App Review peut acceder a :

- onboarding
- creation client
- creation intervention
- ajout photo
- generation PDF
- synchronisation
- etat de l'abonnement
- compte, donnees et suppression

## 3. Comptes de demonstration recommandes

Prevoir deux comptes distincts pour la review et les tests TestFlight :

### Compte demo Pro actif

A fournir a App Review pour verifier toutes les fonctions principales sans blocage :

```text
Usage: demo Pro actif
Endpoint API: https://VOTRE-ENDPOINT
Organization ID: demo-pro-hydrazur
Email: demo-pro@hydrazur.test
Password: demo1234
```

Note :

- le login visible dans l'app demande seulement email + mot de passe
- la build TestFlight doit embarquer une `APP_API_BASE_URL` par defaut pour eviter toute saisie manuelle d endpoint par les testeurs
- `Organization ID` peut rester vide pour ce compte si l email est unique sur le backend seed

Fonctions attendues sur ce compte :

- export PDF actif
- synchronisation cloud active
- clients illimites si l'offre Pro le prevoit
- equipe active si l'offre Pro le prevoit
- `Plan actuel : Pro`
- `Votre offre Pro est active.`
- aucune saisie manuelle d endpoint n est necessaire dans le flux normal

### Compte demo Gratuit

A fournir pour verifier le comportement normal en offre gratuite :

```text
Usage: demo Gratuit
Endpoint API: https://VOTRE-ENDPOINT
Organization ID: demo-free-hydrazur
Email: demo-free@hydrazur.test
Password: demo1234
```

Fonctions attendues sur ce compte :

- consultation et creation de base actives
- limites gratuites visibles proprement
- bouton `Voir les offres` visible
- fonctions Pro presentees sans jargon technique
- `Plan actuel : Gratuit`

## 3 bis. Commande de seed recommandee pour la beta

Avant App Review ou ouverture TestFlight externe, preparer les deux comptes de demonstration avec la commande suivante :

```bash
cd backend_sync
python3 v2_seed_demo.py --db data/sync_v2.sqlite3
```

Cette commande cree :

- une organisation `demo-pro-hydrazur`
- un utilisateur `demo-pro@hydrazur.test`
- une subscription `Pro` active
- les droits Pro effectifs :
  - `pdfExport = true`
  - `cloudSync = true`
  - `teamMembers = true`
  - `unlimitedClients = true`
- une organisation `demo-free-hydrazur`
- un utilisateur `demo-free@hydrazur.test`
- un compte en offre `Gratuit`

Commande de build recommandee pour la beta iOS :

```bash
flutter build ipa --release \
  --dart-define=APP_API_BASE_URL=https://staging-api.hydrazur.app
```

## 4. Etapes principales pour reproduire le flow

1. Ouvrir l'application
2. Depuis la connexion, verifier `Pricing / Paywall`, `Support / Diagnostic`, `Confidentialite`, `Conditions`
3. Se connecter avec le compte de demonstration
   Pour `demo-pro`, aucun endpoint manuel ne doit etre necessaire dans le flux normal.
4. Completer l'onboarding si demande
5. Creer un client
6. Creer une intervention
7. Ajouter une photo
8. Generer un PDF
9. Lancer une synchronisation
10. Ouvrir `Etat de l'abonnement`
11. Ouvrir `Support / Diagnostic`
12. Ouvrir `Compte, donnees et suppression`

## 5. Suppression de compte

Chemin dans l'app :

`Support / Diagnostic` -> `Compte, donnees et suppression` -> `Demander la suppression de mon compte`

Note honnete :

- la suppression backend depend d'une session connectee valide et de la configuration backend
- l'export et la suppression locale des donnees sont egalement disponibles

## 6. Billing / abonnement

Information honnete pour la review :

- le produit affiche un paywall et un etat d'abonnement
- pour cette beta, l'activation Pro peut etre geree manuellement cote backend pour les organisations pilotes
- si le billing natif n'est pas completement active sur cette beta, le mentionner explicitement dans les notes de review

## 7. Notes de review recommandées

Texte type a adapter :

```text
Cette application est une beta TestFlight pour des professionnels piscine.

Deux comptes de demonstration sont fournis pour la review :
- Compte Pro : Endpoint API ..., Organization ID demo-pro-hydrazur, Email demo-pro@hydrazur.test, Password demo1234
- Compte Gratuit : Endpoint API ..., Organization ID demo-free-hydrazur, Email demo-free@hydrazur.test, Password demo1234

Avant connexion, vous pouvez consulter :
- le pricing / paywall
- le support / diagnostic
- la politique de confidentialite
- les conditions d'utilisation

Apres connexion, vous pouvez tester :
- l'onboarding
- la creation client
- la creation intervention
- l'ajout photo
- la generation PDF
- la synchronisation cloud
- l'etat de l'abonnement
- le chemin de suppression de compte

Chemin suppression de compte :
Support / Diagnostic -> Compte, donnees et suppression -> Demander la suppression de mon compte

Si le billing natif n'est pas actif sur cette beta, l'activation de l'abonnement pilote est geree cote backend pour les comptes de demonstration. Le compte `demo-pro` doit etre active en `plan=pro` et `status=active` avant soumission.
```

## 8. Points fragiles a ne pas cacher

- le billing public n'est pas encore le point le plus mature du produit
- la sync V2 est robuste mais reste pragmatique
- certaines fonctions d'equipe sont encore simples
- cette beta vise un pilote reel encadre, pas encore une ouverture publique large
