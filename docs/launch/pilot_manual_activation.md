# Manual Pilot Activation

## Objectif

Activer ou desactiver simplement l'offre Pro pour une organisation pilote, sans paiement automatise.

## Endpoint backend

Le backend V2 expose :

```text
POST /v2/admin/subscriptions/assign
```

Header requis :

```text
X-Admin-Token: VOTRE_TOKEN_ADMIN
```

## Exemple activation Pro

```bash
curl -X POST http://127.0.0.1:8788/v2/admin/subscriptions/assign \
  -H "Content-Type: application/json" \
  -H "X-Admin-Token: dev-admin-token" \
  -d '{
    "organization_id":"org_demo",
    "plan_id":"pro",
    "status":"active",
    "started_at_iso":"2026-04-17T10:00:00Z",
    "ended_at_iso":"2026-05-17T10:00:00Z"
  }'
```

Effet attendu :

- `plan = pro`
- `status = active`
- `pdfExport = true`
- `cloudSync = true`
- `teamMembers = true`
- `unlimitedClients = true`

Ces droits sont derives du plan `Pro` retourne par le snapshot billing V2.

## Comptes de demonstration recommandes

- `demo-pro-hydrazur` / `demo-pro@hydrazur.test` / `demo1234`
- `demo-free-hydrazur` / `demo-free@hydrazur.test` / `demo1234`

Le script `backend_sync/v2_seed_demo.py` cree maintenant :

- une organisation de demonstration Pro active
- une organisation de demonstration Gratuit

## Exemple essai gratuit

Si l'essai est active via `SYNC_V2_PRO_TRIAL_DAYS`, l'organisation peut aussi commencer un essai via l'app ou l'API dediee.

## Desactivation simple

Pour simuler une fin d'acces :

- `status = expired`
- ou `status = canceled` avec une `ended_at_iso` proche

## Cote application

Apres activation manuelle :

1. ouvrir `Etat de l abonnement`
2. appuyer sur `Actualiser mon abonnement`
3. verifier :
   - `Plan actuel : Pro`
   - `Votre offre Pro est active.`
   - le statut attendu
4. verifier ensuite dans l'app que les entitlements Pro sont bien debloques :
   - export PDF
   - synchronisation cloud
   - clients illimites si prevu
   - equipe si prevu

## Recommandation pilote

- tenir une liste des organisations pilotes actives
- noter date de debut, date de fin et statut
- eviter les changements improvises sans trace
