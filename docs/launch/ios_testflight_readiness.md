# iOS TestFlight Readiness

Date de l'audit : 2026-04-17

Objectif : evaluer l'etat reel du produit pour une strategie iOS-first via TestFlight, sans masquer les points faibles.

## Resume executif

Etat actuel :

- `flutter analyze` : OK
- `flutter test` : OK
- `flutter build ios --release --no-codesign` : OK
- `flutter build ipa --release` : OK

Artefacts generes :

- `build/ios/iphoneos/Runner.app`
- `build/ios/archive/Runner.xcarchive`
- `build/ios/ipa/*.ipa`

Verdict honnete :

- **pret pour une beta TestFlight encadree**, sous reserve d'un smoke test iPhone reel complet
- **pas encore pret pour un lancement public large**, surtout a cause du billing public non completement industrialise

## 1. Compatibilite App Store Connect observee

### Chaine locale

- Flutter : 3.41.5
- Dart : 3.11.3
- Xcode : 26.3
- Build Xcode : 17C529
- CocoaPods : 1.16.2

### Configuration iOS observee

- cible iOS minimale : `13.0`
- display name : `HydrAzur Pro`
- bundle identifier : `com.antonio.acpiscine`
- signing : `Automatic`
- development team : `82C965QUQR`
- version app : `1.0.0`
- build number : `1`

### Validation archive IPA

Validation relevee lors de `flutter build ipa --release` :

- Version Number : `1.0.0`
- Build Number : `1`
- Display Name : `HydrAzur Pro`
- Deployment Target : `13.0`
- Bundle Identifier : `com.antonio.acpiscine`

Conclusion :

- la base de soumission App Store Connect est techniquement saine
- aucun blocage structurel n'a ete observe sur bundle id, target iOS, signing auto ou archive

## 2. Procedure exacte build / archive / upload TestFlight

### Build et archive

Depuis la racine du repo :

```bash
flutter pub get
flutter analyze
flutter test
flutter build ipa --release \
  --dart-define=APP_API_BASE_URL=https://staging-api.hydrazur.app
```

Resultat attendu :

- archive : `build/ios/archive/Runner.xcarchive`
- IPA : `build/ios/ipa/*.ipa`

### Variante build release sans codesign

Utile pour verifier uniquement la compilation :

```bash
flutter build ios --release --no-codesign
```

### Test local sur iPhone physique

Pour tester le login iPhone contre un backend lance sur votre Mac :

```bash
flutter run --release \
  --dart-define=APP_API_BASE_URL=http://IP_DU_MAC:8788/v2 \
  -d VOTRE_IPHONE_ID
```

Important :

- `localhost` ou `127.0.0.1` ne fonctionnent pas depuis un iPhone physique
- utilisez l IP reseau du Mac sur le meme Wi-Fi ou USB tunnel approprie
- la build TestFlight doit embarquer une `APP_API_BASE_URL` valide pour eviter toute saisie manuelle d endpoint par les testeurs

### Upload TestFlight

Deux voies simples :

1. Transporter macOS

- ouvrir l'app Transporter
- glisser-deposer `build/ios/ipa/*.ipa`
- envoyer vers App Store Connect

2. `altool`

```bash
xcrun altool --upload-app \
  --type ios \
  -f build/ios/ipa/*.ipa \
  --apiKey VOTRE_API_KEY \
  --apiIssuer VOTRE_ISSUER_ID
```

## 3. Flow metier complet sur iPhone

Etat reel de verification a ce stade :

- build et installation iOS release possibles
- archive et export IPA valides
- parcours metier **non automatise de bout en bout** sur iPhone dans ce patch

Conclusion honnete :

- le produit est techniquement livrable a TestFlight
- le GO testeurs externes doit etre conditionne a une passe manuelle sur iPhone reel du flow :
  - login
  - onboarding
  - creation client
  - creation intervention
  - ajout photo
  - generation PDF
  - sync
  - redemarrage app

Checklist associee :

- voir [ios_testflight_smoke_test.md](/Users/ac/ac_piscine_pro copie/docs/launch/ios_testflight_smoke_test.md)

## 4. Suppression de compte

Chemin disponible dans l'app :

- `Support / Diagnostic`
- `Compte, donnees et suppression`
- `Demander la suppression de mon compte`

Point positif :

- le chemin est maintenant plus visible et donc plus defendable pour la conformite iOS

Limite :

- la suppression backend depend d'une session V2 active et du backend configure

## 5. Risques restants avant invitation TestFlight

### Risques acceptables pour une beta encadree

- support local par export diagnostic, pas encore outille distant
- SQLite cote backend
- invitations equipe encore simples
- UI encore partiellement en francais dur

### Risques a communiquer clairement

- le billing mobile public n'est pas encore un socle totalement industrialise
- l'activation manuelle backend peut rester necessaire pour certains pilotes
- la sync V2 est robuste mais pas un moteur de sync parfait

### Risques encore bloquants pour une ouverture publique large

- validation serveur Apple/Store pas encore assez complete pour monetisation publique a grande echelle
- legal a relire avant generalisation
- pas de verification automatique end-to-end iPhone du parcours complet

## 6. Checklist go / no-go TestFlight

### GO TestFlight interne

- [x] analyze OK
- [x] tests Flutter OK
- [x] build iOS release OK
- [x] archive IPA OK
- [x] chemin de suppression de compte visible
- [ ] smoke test iPhone reel complet execute

### GO testeurs externes

- [ ] smoke test iPhone reel complet execute
- [ ] compte pilote et backend V2 verifies
- [ ] politique d'activation abonnement pilote decidee
- [ ] limitations connues partagees aux testeurs

## 7. Recommandation

Recommandation actuelle :

- **oui pour une phase TestFlight pilote reelle**, si tu executes d'abord la smoke checklist iPhone et si tu gardes un support proche des premiers testeurs
- **non pour une ouverture publique plus large** tant que la partie billing public et la verification metier iPhone complete ne sont pas verrouillees
