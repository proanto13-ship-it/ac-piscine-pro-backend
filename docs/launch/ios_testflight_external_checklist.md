# TestFlight External Checklist

Objectif : passer d'une beta interne validee a un envoi pour 5 a 10 testeurs externes.

## Avant soumission externe

- [ ] la beta interne est validee
- [ ] au moins un iPhone reel a passe le flow metier complet
- [ ] le backend pilote cible est stable
- [ ] la commande `python3 backend_sync/v2_seed_demo.py --db ...` a ete lancee sur la base pilote
- [ ] les comptes pilotes existent
- [ ] les entitlements / abonnements pilotes sont prepares
- [ ] un compte demo Pro actif est pret pour App Review et les tests pilotes
- [ ] un compte demo Gratuit est pret pour verifier les limites et le bouton `Voir les offres`
- [ ] le compte `demo-pro` affiche bien `Plan actuel : Pro` et `Votre offre Pro est active.`
- [ ] le compte `demo-free` affiche bien `Plan actuel : Gratuit` et le paywall Pro
- [ ] la build TestFlight a ete generee avec `APP_API_BASE_URL` valide
- [ ] les limitations connues sont documentees

## Dans App Store Connect

- [ ] groupe de testeurs externes cree
- [ ] build choisie dans TestFlight
- [ ] notes de test ajoutees
- [ ] contact support renseigne
- [ ] notes App Review pretes
- [ ] credentials de demo prets si necessaires
- [ ] la procedure d activation manuelle Pro a ete testee sur au moins une organisation pilote
- [ ] le compte `demo-pro-hydrazur` a ete verifie avec `plan=pro`, `status=active` et les droits Pro effectifs

## Informations a partager aux testeurs

- [ ] email ou canal support
- [ ] perimetre du pilote
- [ ] limitations connues
- [ ] procedure de remontée de bug
- [ ] procedure de suppression de compte ou export donnees

## Avant ouverture du groupe

- [ ] support / diagnostic confirme sur l'iPhone de reference
- [ ] privacy et terms visibles
- [ ] chemin suppression de compte visible et explicable
- [ ] pricing / paywall visible et coherent
- [ ] connexion `demo-pro@hydrazur.test` validee avec mot de passe `demo1234`
- [ ] connexion `demo-free@hydrazur.test` validee avec mot de passe `demo1234`
- [ ] `demo-pro` se connecte sans saisie manuelle d endpoint API
- [ ] compte Gratuit : plan actuel `Gratuit`, limites visibles, bouton `Voir les offres`
- [ ] compte Pro : plan actuel `Pro`, message `Votre offre Pro est active.`
- [ ] compte Pro : export PDF, synchronisation cloud, clients illimites et equipe debloques si prevus par l offre
- [ ] aucun message `Passer a Pro` bloquant n apparait sur le compte Pro actif
- [ ] connexion `demo-pro` testee sans saisie manuelle d endpoint API
- [ ] bouton `Se connecter` actif des que email + mot de passe sont saisis

## Stop conditions

Ne pas ouvrir aux externes si :

- login non stable
- sync non fiable
- photos / PDF instables
- suppression de compte non explicable
- notes de review absentes ou credentials de demo manquants
