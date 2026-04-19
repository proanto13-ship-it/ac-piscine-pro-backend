# Android Pilot Release

## Objectif

Produire un APK Android release exploitable pour un pilote encadre de 3 a 8 organisations clientes.

## Etat actuel du repo

Le projet peut produire un APK release avec :

- une vraie signature release si `android/key.properties` est fourni
- un fallback debug-signed si aucun keystore release n'est configure

Ce fallback debug-signed est acceptable pour un pilote tres controle en diffusion directe, mais il ne doit pas etre considere comme un setup public final.

## Fichiers attendus pour une vraie signature release

Creer `android/key.properties` avec :

```properties
storePassword=VOTRE_MOT_DE_PASSE_STORE
keyPassword=VOTRE_MOT_DE_PASSE_CLE
keyAlias=VOTRE_ALIAS
storeFile=/chemin/vers/votre-release-key.jks
```

## Build release

Depuis la racine du repo :

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

APK attendu :

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Verification minimale avant envoi

- l'APK se lance sur un appareil Android reel
- le mode d'environnement pilote est correct
- l'endpoint backend cible est le bon
- le support / diagnostic est accessible
- l'etat de l'abonnement est lisible

## Recommandation pour le pilote

Pour un pilote payant encadre :

- privilegier un build release avec vrai keystore
- garder la diffusion limitee
- documenter la version envoyee et les organisations autorisees
- conserver un APK precedent stable pour rollback rapide
