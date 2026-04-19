# Readiness Report

Date de l'audit : 2026-04-17

Ce rapport vise a donner un etat honnete et exploitable du produit avant :

- un lancement pilote terrain
- un lancement public plus large

Le rapport decrit l'etat du repo au moment de l'audit, avec les validations executees reellement.

## Correctifs mineurs faits pendant l'audit

Deux petits problemes evidents ont ete corriges pendant cet audit, sans refonte :

1. test backend V2 de readiness mis a jour apres l'ajout de nouveaux champs billing dans `SyncV2Config`
2. suppression d'un doublon parasite `MainActivity.kt` dans un dossier Android de sauvegarde, qui bloquait `flutter build apk --debug`

## 1. Etat de compilation Flutter

Etat actuel :

- `flutter analyze` : OK
- `flutter build apk --debug` : OK

Resultat concret :

- APK debug genere avec succes : `build/app/outputs/flutter-apk/app-debug.apk`

Limites de ce constat :

- aucun build iOS n'a ete relance dans cet audit
- aucun build Android release signe n'a ete relance dans cet audit
- le build Android remonte encore des warnings Java/Kotlin sur `source/target 8 obsolete`, mais ils ne bloquent pas la compilation actuelle

Conclusion :

- etat Flutter satisfaisant pour un pilote Android
- pas encore suffisant, a lui seul, pour conclure a un go public iOS

## 2. Etat des tests Flutter

Commande executee :

```bash
flutter test
```

Resultat :

- OK
- 71 tests passent

Couverture utile observee dans le repo :

- logique diagnostic et photo
- compatibilite JSON de plusieurs modeles
- documents financiers
- pricing / feature gating
- auth V2
- billing service
- sync queue
- sync V2
- public share
- onboarding
- support diagnostic
- team service

Conclusion :

- bonne base de non-regression pour un pilote
- couverture encore surtout unitaire / service, peu de tests widget end-to-end

## 3. Etat des tests backend

Commande executee :

```bash
python3 -m unittest \
  backend_sync.tests.test_v2_auth \
  backend_sync.tests.test_v2_media \
  backend_sync.tests.test_v2_conflicts \
  backend_sync.tests.test_v2_billing \
  backend_sync.tests.test_v2_account \
  backend_sync.tests.test_v2_team \
  backend_sync.tests.test_v2_public_share \
  backend_sync.tests.test_v2_production_ready
```

Resultat :

- OK
- 25 tests passent

Couverture utile observee :

- auth V2
- media upload/download
- conflits et soft delete
- billing / entitlements / trial
- export et suppression de compte
- equipe et permissions minimales
- public share read-only
- readiness backend minimale

Conclusion :

- backend V2 raisonnablement testable pour un usage pilote
- la couverture reste modeste pour une ambition publique a plus grande echelle

## 4. Fonctionnalites pretes

Fonctionnalites pretes ou suffisamment avancees pour un pilote :

- login V2 et restauration de session
- onboarding societe minimal
- gestion locale de clients
- creation d'interventions
- pieces jointes photo
- generation de PDF
- partage simple des PDF
- synchronisation V2 avec auth
- file d'attente locale de sync avec retry
- upload et download media V2
- resolution simple de conflits avec soft delete
- mode demo
- support integre avec export diagnostic
- export local des donnees
- suppression locale des donnees
- suppression de compte backend si disponible
- equipe basique avec roles `admin`, `manager`, `technician`
- partage public read-only d'un rapport ou d'une intervention
- pricing `Free` / `Pro`
- paywall simple
- cycle de vie d'abonnement `trial`, `active`, `past_due`, `canceled`, `expired`
- contenus de lancement dans `docs/launch/`

## 5. Fonctionnalites encore fragiles

Fonctionnalites presentes mais encore fragiles ou incomplètes :

- billing mobile natif :
  - le flow client est branche
  - la validation serveur Apple/Google n'est pas encore reelle
- sync V2 :
  - architecture claire
  - robustesse correcte
  - pas encore moteur de sync avance ni merge champ par champ
- backend media :
  - stockage disque local
  - pas de stockage objet ni de strategie de retention
- partage public :
  - proprement scope
  - encore base sur possession du lien/token
  - pas de vraie UI de revocation avancee
- equipe :
  - invitations simples
  - pas encore de vrai parcours d'acceptation par email
- legal :
  - documents presentes dans le repo
  - pas encore valides juridiquement
- observabilite :
  - logs applicatifs et backend presents
  - pas de monitoring distant ni d'alerting
- multi-environnements :
  - logique Flutter en place
  - pas encore de vrais flavors natifs complets

## 6. Risques de lancement

Risques principaux pour un lancement pilote :

- conflits de sync encore possibles dans des cas limites non couverts par les tests
- media sync depend d'un backend V2 correctement configure et d'un stockage local serveur
- experience de support encore locale : export de diagnostic, pas d'envoi automatise
- iOS non reverifie dans cet audit

Risques principaux pour un lancement public :

- validation in-app purchase cote serveur encore insuffisante pour une monetisation publique robuste
- backend SQLite acceptable pour petit trafic, pas pour une forte charge ni une haute disponibilite
- documents privacy/terms a relire juridiquement
- pas de pipeline d'exploitation complet type monitoring, alerting, rotation/retention centralisee, incident response
- pas de release build iOS verifiee dans cet audit

## 7. Dette technique acceptable vs bloquante

### Dette acceptable pour un pilote

- warnings Java/Kotlin de compatibilite source 8
- absence de monitoring SaaS
- UI encore partiellement en francais dur
- tests plutot unitaires que scenario utilisateur complet automatise
- stockage media local disque cote backend
- SQLite en backend

### Dette bloquante pour un lancement public

- absence de vraie validation serveur des achats mobiles
- absence de build iOS relance et valide
- absence de verification de signature / reconciliations store completes
- absence de relecture legale finale des contenus `privacy` et `terms`
- backend mono-instance SQLite si l'ambition est un trafic significatif ou une criticite forte

## 8. Checklist de lancement pilote

### Go technique minimum

- [x] `flutter analyze`
- [x] `flutter test`
- [x] tests backend V2
- [x] build Android debug
- [ ] build iOS cible pilote si iPhone/iPad dans le scope

### Configuration pilote

- [ ] choisir un environnement `staging` propre
- [ ] configurer `APP_ENV` et `APP_API_BASE_URL`
- [ ] configurer `SYNC_V2_AUTH_SECRET`
- [ ] configurer `SYNC_V2_ADMIN_TOKEN`
- [ ] configurer `SYNC_V2_PRO_TRIAL_DAYS` selon la strategie pilote
- [ ] verifier les product IDs billing si un test natif est voulu
- [ ] decider si le billing natif reste desactive pour le pilote

### Donnees et exploitation

- [ ] creer au moins une organisation pilote
- [ ] creer les comptes d'equipe necessaires
- [ ] verifier les plans / subscriptions / entitlements backend
- [ ] verifier les sauvegardes SQLite et media
- [ ] seed demo disponible si besoin pour les demonstrations

### Smoke tests pilote

- [ ] login
- [ ] onboarding
- [ ] creation client
- [ ] creation intervention
- [ ] ajout photo
- [ ] generation PDF
- [ ] push / pull V2
- [ ] redemarrage app et recuperation des donnees
- [ ] partage public read-only d'un rapport
- [ ] export support diagnostic

### Cadrage pilote

- [ ] prevenir que le produit est en phase pilote
- [ ] definir le canal de remontée des bugs
- [ ] definir la fenetre de support et la procedure de rollback

## 9. Checklist de lancement public

### Preconditions bloquantes

- [ ] valider juridiquement `privacy.md`
- [ ] valider juridiquement `terms.md`
- [ ] verifier les metadonnees stores et la copy finale
- [ ] relancer et valider les builds iOS et Android release
- [ ] valider la signature et la distribution reelle
- [ ] finaliser la validation serveur des achats natifs
- [ ] valider la politique de gestion des abonnements et des remboursements

### Backend public minimum

- [ ] environnement `prod` configure proprement
- [ ] secrets prod changes
- [ ] bootstrap public desactive
- [ ] sauvegarde SQLite automatisee si SQLite est conservee temporairement
- [ ] politique de retention media documentee
- [ ] supervision minimale des erreurs et des logs
- [ ] procedure d'intervention incident documentee

### Produit et support

- [ ] relire les messages in-app lies au billing et aux statuts d'abonnement
- [ ] verifier la coherence des feature gates selon les entitlements backend
- [ ] verifier la page pricing avec les vrais plans
- [ ] verifier le flux de suppression/export de donnees
- [ ] verifier les liens publics et leur expiration
- [ ] documenter le support utilisateur final

### Go/no-go public

- [ ] pas d'erreur critique ouverte sur login, sync, PDF, billing, account deletion
- [ ] au moins un test terrain complet reussi sur Android
- [ ] au moins un test terrain complet reussi sur iOS si iOS est public

## 10. Plan de rollback minimal

Objectif : revenir rapidement a un etat sain sans perdre inutilement les donnees locales deja saisies.

### Si un probleme critique Flutter survient

- retirer temporairement le build des stores ou du canal de distribution pilote
- revenir au build precedent connu comme stable
- desactiver si besoin les fonctions les plus risquées cote config et support :
  - billing natif
  - partage public
  - sync V2

### Si un probleme critique backend V2 survient

- couper l'acces V2 public temporairement
- basculer les utilisateurs pilotes sur usage local uniquement si necessaire
- restaurer SQLite + dossier media depuis la derniere sauvegarde si corruption
- geler les changements manuels d'abonnement tant que l'etat n'est pas clarifie

### Si le billing pose probleme

- desactiver `APP_ENABLE_NATIVE_BILLING`
- repasser temporairement sur l'activation manuelle backend/admin
- suspendre l'ouverture publique de l'achat in-app jusqu'a validation correcte

### Si le partage public pose probleme

- suspendre la creation de nouveaux liens
- expirer ou revoquer les liens existants si necessaire

### Si la sync pose probleme

- recommander aux pilotes de continuer localement
- geler `push/pull` le temps de corriger
- demander un export diagnostic et un backup local avant toute manipulation

## Verdict honnete

### Pour un lancement pilote

Verdict : **oui, avec discipline**

Le produit est assez avance pour un pilote terrain encadre, surtout sur Android, a condition de :

- garder un backend V2 proprement configure
- assumer que le billing natif n'est pas encore completement industrialise
- garder une procedure de support et de rollback simple

### Pour un lancement public

Verdict : **pas encore sans reserve**

Les principaux bloqueurs a traiter avant une ouverture publique sereine sont :

- validation serveur reelle du billing mobile
- verification iOS release
- relecture legale finale des contenus de confidentialite et conditions
- choix clair sur l'architecture backend si l'usage attendu depasse un petit volume pilote
