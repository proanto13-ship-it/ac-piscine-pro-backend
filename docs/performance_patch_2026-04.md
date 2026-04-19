## Patch performance cible

Perimetre: patch ciblé sans refonte globale, concentré sur les goulets les plus probables observes dans le code.

### Changements appliques

- Photos d'intervention capturees plus legeres:
  - `intervention_sheet_page.dart`: `maxWidth` passe de `1800` a `1400`, `imageQuality` de `82` a `76`
  - `photo_diagnosis_page.dart`: `maxWidth` passe de `2000` a `1600`, `imageQuality` de `84` a `78`
- Previsualisations photo decodees a taille cible:
  - vignettes 96x96 decodees avec `cacheWidth/cacheHeight = 192`
  - cartes galerie decodees avec `cacheWidth = 640`
  - carte photo diagnostic decodee avec `cacheWidth = 960`
- PDF d'intervention:
  - lecture locale des photos limitee a `4` images max par PDF, alignée avec la limite deja appliquee dans `PdfService`
- Liste clients:
  - chargement progressif par paquets de `40` clients

### Metriques simples avant / apres

- Photos lues pour un PDF d'intervention:
  - avant: `N` photos locales lues meme si le PDF n'en affichait que 4
  - apres: `4` lectures max
- Rendu initial de la liste client:
  - avant: toutes les cartes candidates visibles dans la liste de recherche
  - apres: `40` cartes puis `Charger plus`
- Taille de decode des apercus photo:
  - avant: decode potentiellement pleine resolution fichier
  - apres: decode ciblee sur la taille d'affichage

### Limites

- Pas de refonte de la generation PDF ni du protocole sync
- Pas de benchmark instrumente sur device dans ce patch
- La visionneuse plein ecran garde volontairement l'image complete pour ne pas degrader le zoom
