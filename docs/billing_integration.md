# Billing Integration

## Objectif

L'app ne doit pas etre couplee a un provider unique. Le frontend passe donc par une abstraction `BillingProvider`.

## Cote Flutter

- `BillingProvider` definit 3 points d'entree :
  - `createCheckoutSession(...)`
  - `startCheckout(...)`
  - `restorePurchases(...)`
- `BillingCheckoutSession` porte les infos de session de checkout :
  - provider
  - plan cible
  - mode `web`, `native` ou `manual`
  - URLs eventuelles
  - metadata
- `BillingResult` porte le resultat du flow :
  - statut
  - message
  - session associee
  - besoin de refresh des entitlements ou non
  - metadata provider optionnelle

## Provider actuel

- `DevBillingProvider` est l'implementation mock/dev actuelle.
- Il ne lance pas de paiement reel.
- Il retourne une action manuelle, compatible avec l'activation pilote backend deja en place.

## Provider mobile natif

Un provider natif Flutter peut maintenant etre active sans casser le mode dev.

Activation Flutter par `dart-define` :

- `APP_ENABLE_NATIVE_BILLING=true`
- `APP_BILLING_IOS_PRO_PRODUCT_ID=com.hydrazur.pro.monthly`
- `APP_BILLING_ANDROID_PRO_PRODUCT_ID=com.hydrazur.pro.monthly`

Si ces variables ne sont pas fournies, l'app garde le fallback `DevBillingProvider`.

## Points d'integration reels a brancher ensuite

### Checkout web / B2B

Un provider web pourra :

- creer une session de checkout backend
- retourner un `BillingCheckoutSession` en mode `web`
- ouvrir `checkoutUrl`
- attendre ensuite le webhook/backend event pour mettre a jour la subscription

### Billing mobile natif

Un provider mobile pourra :

- mapper le plan interne vers un produit App Store / Play Billing
- lancer l'achat natif
- restaurer un achat deja actif
- retourner un `BillingResult` avec le statut d'achat
- appeler ensuite le backend pour confirmer le recu et mettre a jour la subscription

Convention minimale actuelle :

- plan `Pro`
  - iOS : `APP_BILLING_IOS_PRO_PRODUCT_ID`
  - Android : `APP_BILLING_ANDROID_PRO_PRODUCT_ID`

## Cote backend

La V2 expose maintenant 2 points d'entree simples :

- `POST /v2/billing/events/subscription-updated`
- `POST /v2/billing/mobile/reconcile`

Ce endpoint est pense comme recepteur normalise pour un futur webhook ou worker d'integration. Il applique :

- `organization_id`
- `plan_id`
- `status`
- `started_at_iso`
- `ended_at_iso`
- metadata provider optionnelle

`/v2/billing/mobile/reconcile` est pense pour le client mobile authentifie :

- il recoit la preuve d'achat/restauration native
- il mappe `productId -> planId` cote serveur
- il journalise la transaction mobile
- il met a jour la `subscription`
- il renvoie le snapshot billing final

Variables backend a configurer :

- `SYNC_V2_BILLING_IOS_PRO_PRODUCT_ID`
- `SYNC_V2_BILLING_ANDROID_PRO_PRODUCT_ID`

## Strategie recommandee ensuite

1. Le provider externe cree ou confirme l'achat.
2. Le backend traduit l'evenement du provider vers `/v2/billing/events/subscription-updated`, ou bien le client mobile appelle `/v2/billing/mobile/reconcile`.
3. Le frontend recharge `/v2/billing/entitlements`.
4. `FeatureGate` reste pilote par les entitlements backend.
