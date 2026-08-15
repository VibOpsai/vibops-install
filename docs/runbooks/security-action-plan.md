# VibOps — Plan d'Action Sécurité (PAS)

*Document préparé en vue d'un audit de sécurité externe — juin 2026*

---

## Contexte

Un sprint sécurité complet (2026-06-20) a fermé 19 vulnérabilités applicatives (commits `cd79263` → `a2bd3d2`) et produit les documents de référence suivants :

- `docs/security-policy.md` — politique de sécurité
- `docs/runbooks/security-incident-response.md` — réponse aux incidents
- `docs/runbooks/secret-rotation.md` — procédures de rotation des secrets

Les actions ci-dessous nécessitent une intervention manuelle avant remise du dossier à l'auditeur.

---

## 1. Rotation des secrets (staging en premier)

| # | Action | Responsable | Statut |
|---|--------|-------------|--------|
| 1.1 | Générer un nouveau `JWT_SECRET_KEY` et le déployer en staging — vérifier l'invalidation des sessions et la reconnexion | David | ☐ |
| 1.2 | Générer un nouveau `SECRET_KEY` (Fernet) et exécuter le script de re-chiffrement sur les champs LDAP/SSO — vérifier le login LDAP | David | ☐ |
| 1.3 | Générer un nouvel `INTERNAL_API_KEY` — vérifier les appels console→core et gateway→core | David | ☐ |
| 1.4 | Rotation de `LLM_API_KEY` sur la console Anthropic — mettre à jour `.env` dans tous les environnements | David | ☐ |
| 1.5 | Documenter les résultats de la rotation dans `docs/runbooks/secret-rotation.md` | David | ☐ |

---

## 2. MFA sur les accès infrastructure

| # | Action | Responsable | Statut |
|---|--------|-------------|--------|
| 2.1 | Activer MFA sur le compte GitHub (`davidmacamara-boop`) | David | ☐ |
| 2.2 | Activer MFA sur la console Anthropic (gestion des clés API) | David | ☐ |
| 2.3 | Activer MFA sur le provider cloud hébergeant `app.vibops.ai` | David | ☐ |

---

## 3. Contacts du runbook

| # | Action | Responsable | Statut |
|---|--------|-------------|--------|
| 3.1 | Renseigner les noms et numéros réels dans `docs/runbooks/security-incident-response.md` (templates P0 actuellement avec placeholders) | David | ☐ |
| 3.2 | Définir l'adresse email de divulgation responsable (security contact public) | David | ☐ |

---

## 4. Validation en staging

| # | Test | Critère de succès | Statut |
|---|------|-------------------|--------|
| 4.1 | Déployer `main` en staging | Services healthy | ☐ |
| 4.2 | Test account lockout : 5 échecs de login consécutifs | Compte verrouillé 15 min, HTTP 429 | ☐ |
| 4.3 | Test CSRF : POST sans header `X-XSRF-TOKEN` | HTTP 403 | ☐ |
| 4.4 | Test stream ticket : ouvrir log stream sans ticket | HTTP 401 | ☐ |
| 4.5 | Vérifier `/docs` et `/redoc` en mode production (`APP_ENV=production`) | HTTP 404 | ☐ |
| 4.6 | Vérifier Swagger inaccessible sur le gateway en production | HTTP 404 | ☐ |

---

## 5. Vérifications avant remise à l'auditeur

| # | Vérification | Statut |
|---|-------------|--------|
| 5.1 | `VAULT_KEY` non vide dans tous les environnements (le startup log affiche un warning sinon) | ☐ |
| 5.2 | `POSTGRES_PASSWORD` fort dans tous les environnements (était `password` jusqu'au 2026-06-20) | ☐ |
| 5.3 | Remettre `docs/security-policy.md` à l'auditeur | ☐ |
| 5.4 | Remettre `docs/openapi.json` à l'auditeur (surface API — 168 routes) | ☐ |
| 5.5 | Remettre le présent PAS à l'auditeur comme preuve de démarche | ☐ |

---

## Références

| Document | Lien |
|----------|------|
| Politique de sécurité | `docs/security-policy.md` |
| Réponse aux incidents | `docs/runbooks/security-incident-response.md` |
| Rotation des secrets | `docs/runbooks/secret-rotation.md` |
| ADR-0006 (dette sécurité console — fermé) | `core/docs/adr/0006-console-security-debt.md` |
| Surface API | `docs/openapi.json` |
| Issue GitHub | davidmacamara-boop/vibops#18 |

---

*VibOps — Confidentiel*
