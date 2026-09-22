# VibOps — Secret Rotation Runbook

_Last updated: 2026-06-19 · v0.18.0_

> **When to use this runbook:**
> - Scheduled rotation (see schedule at the bottom)
> - Suspected or confirmed credential exposure
> - Employee offboarding (anyone who had access to `.env`)
> - Post-incident remediation

---

## Secrets Inventory

| Secret | Env var | Where used | Rotation impact |
|--------|---------|-----------|----------------|
| Fernet encryption key | `SECRET_KEY` | Encrypts LDAP/SSO credentials at rest in DB | Re-encrypt stored secrets; no downtime if done correctly |
| JWT signing key | `JWT_SECRET_KEY` | Signs all user access + refresh tokens | **All active sessions invalidated immediately** |
| Internal service key | `INTERNAL_API_KEY` | Agent → Core, Console → Core auth (`X-Internal-Key` header) | Service-to-service calls fail until all services restarted |
| Vault Fernet key | `VAULT_KEY` | Encrypts secrets stored in the secrets vault (`/api/v1/secrets`) | Secrets unreadable until re-encryption complete |
| Database password | `POSTGRES_PASSWORD` | Core, Celery workers, Console → PostgreSQL | DB connections drop until all services restarted |
| LLM API key | `LLM_API_KEY` | Agent → Anthropic/OpenAI | Agent LLM calls fail until restarted |
| Gateway connect token | Per-gateway Bearer token | Gateway → Core ping/claim/result endpoints | Gateway goes offline until re-registered |
| Account password | `users.password_hash` (in the database) | Every console and API login — this is the only thing `/auth/login` checks | The account holder changes it through the API; no deploy, no downtime |
| Auth-enabled flag | `AUTH_PASSWORD_HASH` | Read by the briefing worker and the agent only to decide whether auth is on; its value is compared to nothing | None on logins. Emptying it disables authentication |
| Hetzner root password | — (provider console) | The demo VM, and therefore everything running on it | None on the product; full compromise if leaked |
| Agent identity key | `INTERNAL_API_KEY`, agent identity `key_hash` | Agent → Core, and `POST /agent-identities/{id}/rotate` | The agent stops being able to call Core until restarted |

**Where these actually live.** `.github/workflows/deploy.yml` passes
`JWT_SECRET_KEY`, `AUTH_PASSWORD_HASH`, `VAULT_KEY` and `LLM_API_KEY` from
GitHub repository secrets into the Helm release with `--set`. Changing a GitHub
secret therefore changes production **at the next deploy**, not immediately, and
not visibly. Two consequences worth stating before anyone edits one:

- The old value keeps working until the next tag is pushed. A rotation that
  feels done is not done until a deploy has run.
- `gh secret set VAULT_KEY` without the re-encryption in §4 below makes every
  stored secret unreadable at that deploy. There is no undo: the ciphertext is
  still there and the key that opens it is gone. Re-encrypt first, always.

---

## Prerequisites

```bash
# You need:
# 1. SSH/shell access to the production host
# 2. Current .env file backup:
cp /opt/vibops/.env /opt/vibops/.env.bak.$(date +%Y%m%d)

# 3. Ability to restart services:
docker compose -f /opt/vibops/docker-compose.yml restart <service>

# 4. Admin JWT for API verification:
TOKEN=$(curl -s -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"<password>"}' | jq -r .access_token)
```

---

## 1. SECRET_KEY (Fernet — encrypts LDAP/SSO credentials)

**Impact:** LDAP and SSO credentials stored in the DB are encrypted with this key. Rotating without re-encryption makes them unreadable. Plan for a maintenance window if LDAP/SSO is in use.

**Step-by-step:**

```bash
# Step 1: Generate new key
NEW_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
echo "New SECRET_KEY: $NEW_KEY"

# Step 2: Re-encrypt existing secrets in DB (run BEFORE updating .env)
# This script reads with OLD key, writes with NEW key
docker compose exec core python3 - <<'EOF'
import asyncio
from cryptography.fernet import Fernet
from sqlalchemy import select, update
from app.database import AsyncSessionFactory
from app.models.tenant import Organization
import os

OLD_KEY = os.environ["SECRET_KEY"]          # current key still in env
NEW_KEY = input("Enter new SECRET_KEY: ")   # paste new key

old_f = Fernet(OLD_KEY.encode())
new_f = Fernet(NEW_KEY.encode())

async def reencrypt():
    async with AsyncSessionFactory() as db:
        result = await db.execute(select(Organization))
        orgs = result.scalars().all()
        for org in orgs:
            if org.ldap_bind_password_enc:
                plain = old_f.decrypt(org.ldap_bind_password_enc.encode())
                org.ldap_bind_password_enc = new_f.encrypt(plain).decode()
            if org.oidc_client_secret_enc:
                plain = old_f.decrypt(org.oidc_client_secret_enc.encode())
                org.oidc_client_secret_enc = new_f.encrypt(plain).decode()
        await db.commit()
        print(f"Re-encrypted {len(orgs)} orgs")

asyncio.run(reencrypt())
EOF

# Step 3: Update .env
sed -i "s/^SECRET_KEY=.*/SECRET_KEY=$NEW_KEY/" /opt/vibops/.env

# Step 4: Restart core (console reads SECRET_KEY too)
docker compose restart core console worker beat

# Step 5: Verify
curl -s http://localhost:8000/api/v1/health | jq .
# Try logging in and fetching an LDAP-backed org
```

**Rollback:** Restore `.env.bak.*`, re-encrypt again with old key from backup, restart services.

---

## 2. JWT_SECRET_KEY (signs all JWTs)

**Impact:** All active user sessions (access tokens + refresh tokens) are invalidated the moment core restarts. Users must log in again. Agent machine keys are unaffected (they use separate HMAC). Plan to notify users before rotating during business hours.

**Step-by-step:**

```bash
# Step 1: Generate new key
NEW_JWT=$(python3 -c "import secrets; print(secrets.token_hex(32))")
echo "New JWT_SECRET_KEY: $NEW_JWT"

# Step 2: (Optional) Announce maintenance window to users

# Step 3: Update .env
sed -i "s/^JWT_SECRET_KEY=.*/JWT_SECRET_KEY=$NEW_JWT/" /opt/vibops/.env

# Step 4: Restart core ONLY (JWT verification is in core)
docker compose restart core

# Step 5: Verify — old token should now be rejected
curl -H "Authorization: Bearer $OLD_TOKEN" http://localhost:8000/api/v1/health
# Expect: 401 Unauthorized

# Step 6: Log in fresh and confirm new token works
NEW_TOKEN=$(curl -s -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"<password>"}' | jq -r .access_token)
curl -H "Authorization: Bearer $NEW_TOKEN" http://localhost:8000/api/v1/health
# Expect: 200 OK
```

**Rollback:** Restore old `JWT_SECRET_KEY` in `.env`, restart core. Old tokens become valid again.

**Emergency use (breach):** Same procedure — skip the maintenance window announcement.

---

## 3. INTERNAL_API_KEY (service-to-service auth)

**Impact:** Agent and Console cannot reach Core internal endpoints (`/audit/ingest`, internal webhooks) until they are all restarted with the new key. Window of failure is the restart gap — keep it short.

**Step-by-step:**

```bash
# Step 1: Generate new key
NEW_INTERNAL=$(python3 -c "import secrets; print(secrets.token_hex(32))")

# Step 2: Update .env on ALL hosts (core, agent, console share this key)
sed -i "s/^INTERNAL_API_KEY=.*/INTERNAL_API_KEY=$NEW_INTERNAL/" /opt/vibops/.env

# Step 3: Restart all services simultaneously to minimize the gap
docker compose restart core agent console worker beat

# Step 4: Verify internal connectivity
# Check agent logs — should not show 401 errors on internal calls
docker compose logs agent --tail=20 | grep -i "internal\|401\|403"
```

**Rollback:** Restore old key in `.env`, restart all services.

---

## 4. VAULT_KEY (Fernet — encrypts secrets vault)

**Impact:** All secrets stored via `POST /api/v1/secrets` are unreadable until re-encryption is complete. Jobs that depend on vault secrets will fail during the window. Plan a maintenance window.

**Step-by-step:**

```bash
# Step 1: Generate new Fernet key
NEW_VAULT=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")

# Step 2: Re-encrypt vault secrets (run BEFORE updating .env)
docker compose exec core python3 - <<'EOF'
import asyncio
from cryptography.fernet import Fernet
from sqlalchemy import select
from app.database import AsyncSessionFactory
from app.models.secret import Secret
import os

OLD_KEY = os.environ["VAULT_KEY"]
NEW_KEY = input("Enter new VAULT_KEY: ")

old_f = Fernet(OLD_KEY.encode())
new_f = Fernet(NEW_KEY.encode())

async def reencrypt():
    async with AsyncSessionFactory() as db:
        result = await db.execute(select(Secret))
        secrets = result.scalars().all()
        for s in secrets:
            plain = old_f.decrypt(s.encrypted_value.encode())
            s.encrypted_value = new_f.encrypt(plain).decode()
        await db.commit()
        print(f"Re-encrypted {len(secrets)} secrets")

asyncio.run(reencrypt())
EOF

# Step 3: Update .env
sed -i "s/^VAULT_KEY=.*/VAULT_KEY=$NEW_VAULT/" /opt/vibops/.env

# Step 4: Restart core and workers
docker compose restart core worker beat

# Step 5: Verify — read a known secret
curl -H "Authorization: Bearer $TOKEN" \
  -H "X-Require-Write: true" \
  "http://localhost:8000/api/v1/secrets/test-secret"
```

**Rollback:** Restore old `VAULT_KEY` in `.env`, restart. Secrets are still encrypted with old key.

---

## 5. POSTGRES_PASSWORD (database password)

**Impact:** All services that connect to PostgreSQL will fail until restarted with the new password. This is a maintenance window — plan accordingly.

**Step-by-step:**

```bash
# Step 1: Generate new password
NEW_PG_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")

# Step 2: Change password in PostgreSQL FIRST
docker compose exec postgres psql -U vibops -c \
  "ALTER USER vibops PASSWORD '$NEW_PG_PASS';"

# Step 3: Update DATABASE_URL in .env
# Old: postgresql+asyncpg://vibops:oldpass@localhost:5432/vibops_db
sed -i "s|postgresql+asyncpg://vibops:[^@]*@|postgresql+asyncpg://vibops:$NEW_PG_PASS@|" /opt/vibops/.env

# Step 4: Also update POSTGRES_PASSWORD if set separately
sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$NEW_PG_PASS/" /opt/vibops/.env

# Step 5: Restart all services that connect to DB
docker compose restart core worker beat console

# Step 6: Verify
curl http://localhost:8000/api/v1/health | jq .database
# Expect: "ok"
```

**Rollback:** Reset PostgreSQL password back to old value (`ALTER USER`), restore `.env`, restart.

---

## 6. LLM_API_KEY (Anthropic / OpenAI API key)

**Impact:** LLM calls from the agent fail until the agent is restarted. No data loss.

**Step-by-step:**

```bash
# Step 1: Generate new API key in the provider dashboard
# Anthropic: https://console.anthropic.com → API Keys → Create Key
# OpenAI: https://platform.openai.com → API keys → Create new secret key

# Step 2: Update .env (in agent service config)
sed -i "s/^LLM_API_KEY=.*/LLM_API_KEY=<new-key>/" /opt/vibops/.env

# Step 3: Revoke old key in the provider dashboard AFTER updating .env

# Step 4: Restart agent
docker compose restart agent

# Step 5: Verify
docker compose logs agent --tail=20 | grep -i "anthropic\|openai\|error"
# Send a test chat message through the console
```

**Rollback:** Restore old key in `.env`, restart agent, un-revoke old key in provider dashboard (if still possible).

---

## 7. Gateway Connect Token (per-gateway)

**Impact:** The specific gateway goes offline until re-registered with the new token. Its pending/running jobs are cancelled when the old gateway record is deleted.

**Step-by-step:**

```bash
# Step 1: Identify gateway
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/v1/gateways
# Note the gateway_id of the gateway to rotate

# Step 2: Delete the old gateway (cancels its pending jobs)
curl -X DELETE -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/api/v1/gateways/<gateway_id>"

# Step 3: Register a new gateway — get a fresh token
curl -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "<cluster-name>", "description": "rotated token"}' \
  "http://localhost:8000/api/v1/gateways"
# Save the token — it is shown ONCE

# Step 4: On the gateway host, update the CONNECT_TOKEN env var and restart
# docker-compose.gateway.yml or equivalent
sed -i "s/^CONNECT_TOKEN=.*/CONNECT_TOKEN=<new-token>/" /opt/vibops-gateway/.env
docker compose -f /opt/vibops-gateway/docker-compose.gateway.yml restart gateway

# Step 5: Verify gateway is online
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/v1/gateways
# Check last_ping_at is recent (< 1 min ago)
```

---

## 8. Admin password

**Read this first, because the docstrings lie.** Several comments in the code
(`app/auth.py`, `app/models/tenant.py`) describe `AUTH_PASSWORD_HASH` as a
fallback administrator credential used when no `User` row matches. The login
endpoint does not implement that. `POST /api/v1/auth/login` looks up
`users.username` or `users.email` and compares against `users.password_hash`,
and nothing else. Verified 22/09/2026.

`AUTH_PASSWORD_HASH` survives as a **flag**: `briefing_task.py` and the agent
read it only to decide whether authentication is enabled at all — empty means
dev mode. Its value is never compared to a password anywhere in the codebase.

So there are two different operations, and only the second one changes how
anyone logs in.

### 8a. Rotating a real account's password

This is the one that matters. It needs no SSH and no deploy — the account holder
does it through the API:

```bash
# Log in with the current password to get a token
TOKEN=$(curl -s -X POST https://<host>/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"<CURRENT>"}' | jq -r .access_token)

# Change it (minimum 8 characters; the endpoint re-checks the current one)
curl -s -o /dev/null -w "%{http_code}\n" -X PATCH https://<host>/api/v1/auth/me/password \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"current_password":"<CURRENT>","new_password":"<NEW>"}'    # expect 204

# Verify the old one is dead — expect 401
curl -s -o /dev/null -w "%{http_code}\n" -X POST https://<host>/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"<CURRENT>"}'
```

An account whose password is lost has no self-service path: an org admin
recreates it, or the row's `password_hash` is set directly in the database using
the scrypt recipe below.

### 8b. Rotating `AUTH_PASSWORD_HASH`

Worth doing as hygiene — it is passed into the cluster by `deploy.yml` and has
been unchanged since 11/04/2026 — but understand that it changes no login. Keep
it non-empty, or authentication turns itself off.

**Impact:** none on who can log in. Takes effect at the next deploy.

It holds a hash, not the password — and not a bcrypt one.
`app/auth.py` uses scrypt and stores `salt:hash` in hex
(`hashlib.scrypt(n=16384, r=8, p=1)`, 16-byte hex salt). A bcrypt string in that
secret produces an account nobody can log into, and the failure reads as a wrong
password rather than a malformed hash. Generate it with the product's own
function so the two can never disagree:

```bash
# Step 1: generate a password and its hash together
NEW_PASSWORD=$(python3 -c "import secrets; print(secrets.token_urlsafe(24))")
NEW_HASH=$(docker compose exec -T core python3 -c "
import sys
from app.auth import hash_password
print(hash_password(sys.argv[1]))
" "$NEW_PASSWORD")

# Off the host, without a running stack, the same thing in plain Python:
#   python3 -c "
#   import hashlib, secrets, sys
#   salt = secrets.token_hex(16)
#   h = hashlib.scrypt(sys.argv[1].encode(), salt=salt.encode(), n=16384, r=8, p=1)
#   print(f'{salt}:{h.hex()}')
#   " "$NEW_PASSWORD"

# Step 2: store the password where a human will find it. Do this before step 3 —
# the hash is one-way, and a password lost here is an account lost.
echo "$NEW_PASSWORD"

# Step 3: the GitHub secret, which deploy.yml passes to the chart
gh secret set AUTH_PASSWORD_HASH --body "$NEW_HASH"

# Step 4: the VM's own .env, for anything not going through the chart
ssh <host> "sed -i 's|^ADMIN_PASSWORD=.*|ADMIN_PASSWORD='\"$NEW_PASSWORD\"'|' /opt/vibops/.env"

# Step 5: it is not in effect until a deploy runs
git push origin vX.Y.Z    # or run the Deploy workflow manually

# Step 6: verify the old one is dead — this must return 401
curl -s -o /dev/null -w "%{http_code}\n" -X POST https://<host>/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"<OLD PASSWORD>"}'
```

---

## 9. Hetzner root password

Not a product secret — it is the machine everything else runs on, so it belongs
in this list rather than in someone's head.

1. Hetzner Cloud console → the server → **Rescue** → *Reset root password*.
2. The new password is shown **once**. Store it before closing the dialog.
3. SSH in with it and confirm, then prefer a key: `ssh-copy-id`, and set
   `PasswordAuthentication no` in `/etc/ssh/sshd_config`. A password that cannot
   be used remotely is a password that cannot be brute-forced remotely.
4. Note for this project: VM keys have to be declared by hand in the Hetzner web
   console — the API creates servers without one.

---

## 10. Agent identity key

An agent authenticates to Core with a key whose hash is stored in
`agent_identities.key_hash`. Rotation is a product feature, not a file edit:

```bash
# Issues a new key and invalidates the old one in the same call.
curl -s -X POST https://<host>/api/v1/agent-identities/<id>/rotate \
  -H "Authorization: Bearer $ADMIN_JWT" | jq -r .key

# Put the value in the agent's environment, then restart it.
# Verify: the agent's next call succeeds, and the old key returns 401.
```

`POST /agent-identities/{id}/revoke` is the other half — use it when the key is
to be withdrawn rather than replaced. A revoked identity refuses rotation, by
design: reviving a revoked agent should be a deliberate act, not a side effect.

---

## 11. Switching the application to `vibops_app`

**On the Helm chart this is done for you.** `postgresql.appRole.enabled`
defaults to true: the chart generates the role's password into its own Secret
on first install, a `grant-app-role` init container gives the role that
password after the migrations create it, and core, the worker and beat connect
as `vibops_app`. The init container refuses to continue if the role turns out
to be a superuser or to carry BYPASSRLS, so a silently exempt role fails the
deployment instead of quietly disabling every policy.

Setting `postgresql.appRole.enabled: false` puts the application back on the
owner. That does not remove the policies; it removes their effect. It is the
rollback if an isolation bug ever locks a legitimate read out.

**Everywhere else — the Compose deployment, an external database — it is still
manual**, because there the same process runs the migrations and serves the
API, so it needs two connections and only has one. What follows is that
procedure. Migration `f5a6b7c8d9e0` creates the role without a password;
credentials do not belong in migrations.

```bash
# 1. Give it a password
NEW_DB_PASSWORD=$(python3 -c "import secrets; print(secrets.token_urlsafe(24))")
psql "$ADMIN_DATABASE_URL" -c \
  "ALTER ROLE vibops_app WITH LOGIN PASSWORD '$NEW_DB_PASSWORD'"

# 2. Confirm it is not exempt — all three must be false
psql "$ADMIN_DATABASE_URL" -c \
  "SELECT rolsuper, rolbypassrls, rolcreaterole FROM pg_roles WHERE rolname='vibops_app'"

# 3. Point the application at it (NOT alembic — migrations stay on vibops)
#    core, worker, beat, console: DATABASE_URL=postgresql+asyncpg://vibops_app:<pw>@…

# 4. Restart, then verify isolation is real: as vibops_app with no scope set,
#    this must return 0 rows, not every row.
psql "postgresql://vibops_app:$NEW_DB_PASSWORD@<host>/vibops_db" -c \
  "SELECT count(*) FROM training_exchanges"
```

Step 4 is the only proof that matters. If it returns rows, one of the three
pieces is missing and the policies are decorative — check `FORCE` on the table,
`rolsuper` on the role, and that the app sets `app.current_org_id`.

Keep `vibops` for Alembic. A data migration has to reach every tenant.

---

## Emergency Rotation — Full Rotation in < 30 Minutes

Use this procedure when a breach is suspected and there is no time to be methodical. Accept that:
- All user sessions are killed
- Some secrets may not be re-encrypted (accept temporary data unavailability)
- Services will have a brief outage during restart

```bash
#!/bin/bash
# emergency-rotate-all.sh — run as root on the production host
set -e

echo "[$(date -u)] Starting emergency rotation"
ENV_FILE="/opt/vibops/.env"
cp "$ENV_FILE" "$ENV_FILE.emergency-bak.$(date +%Y%m%d%H%M%S)"

# Generate all new secrets
NEW_SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
NEW_JWT_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
NEW_INTERNAL_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
NEW_VAULT_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
NEW_PG_PASS=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")

echo "[$(date -u)] Generated new secrets"

# Update .env
sed -i "s/^SECRET_KEY=.*/SECRET_KEY=$NEW_SECRET_KEY/" "$ENV_FILE"
sed -i "s/^JWT_SECRET_KEY=.*/JWT_SECRET_KEY=$NEW_JWT_KEY/" "$ENV_FILE"
sed -i "s/^INTERNAL_API_KEY=.*/INTERNAL_API_KEY=$NEW_INTERNAL_KEY/" "$ENV_FILE"
sed -i "s/^VAULT_KEY=.*/VAULT_KEY=$NEW_VAULT_KEY/" "$ENV_FILE"

# Change PostgreSQL password
docker compose exec -T postgres psql -U vibops -c \
  "ALTER USER vibops PASSWORD '$NEW_PG_PASS';"
sed -i "s|postgresql+asyncpg://vibops:[^@]*@|postgresql+asyncpg://vibops:$NEW_PG_PASS@|" "$ENV_FILE"

echo "[$(date -u)] .env updated, restarting all services"

# Restart everything
docker compose down
docker compose up -d

echo "[$(date -u)] Services restarting. Vault secrets will need re-encryption — see secret-rotation.md #4"
echo "[$(date -u)] LLM_API_KEY must be rotated manually in provider dashboard"
echo "[$(date -u)] Gateway tokens must be rotated per gateway — see secret-rotation.md #7"
echo "[$(date -u)] Emergency rotation complete. New .env committed to secrets manager."

# Print new secrets for secrets manager entry (shown once)
echo ""
echo "=== NEW SECRETS — STORE IN SECRETS MANAGER NOW ==="
echo "SECRET_KEY=$NEW_SECRET_KEY"
echo "JWT_SECRET_KEY=$NEW_JWT_KEY"
echo "INTERNAL_API_KEY=$NEW_INTERNAL_KEY"
echo "VAULT_KEY=$NEW_VAULT_KEY"
echo "POSTGRES_PASSWORD=$NEW_PG_PASS"
```

> After emergency rotation: re-encrypt vault secrets (runbook section 4) and SECRET_KEY-protected data (section 1) as soon as possible. Users will need to re-authenticate and re-enter LDAP/SSO credentials in the console.

---

## Rotation Schedule Recommendations

| Secret | Recommended frequency | Trigger for immediate rotation |
|--------|----------------------|-------------------------------|
| `JWT_SECRET_KEY` | Every 90 days | Any suspected token theft |
| `INTERNAL_API_KEY` | Every 90 days | Any employee offboarding |
| `SECRET_KEY` | Every 180 days | Any suspected DB access |
| `VAULT_KEY` | Every 180 days | Any suspected DB access |
| `POSTGRES_PASSWORD` | Every 180 days | Any suspected DB access |
| `LLM_API_KEY` | Per provider recommendation (90 days) | Provider notifies of exposure |
| Gateway tokens | Every 90 days, or per offboarding | Gateway host compromise |
| Admin password | Every 90 days | Any value that has ever been committed |
| Hetzner root password | Every 180 days | Any shared access, any offboarding |

### Credentials known to need rotation

Recorded 22/09/2026 so the list does not live in anyone's memory.

| Credential | Why | Who can do it |
|---|---|---|
| `Montreal69@` | Was committed in five seed scripts and removed from the working tree on 14/09/2026. It remains in the git history of every clone: `git log --all -S'Montreal69'` finds eight commits. Removing it from history is not the fix — the fix is that the password stops working. **Rotate it with §8a**; `AUTH_PASSWORD_HASH` has no effect on it. | Whoever holds the demo admin account |
| `VibOps2026!` | The demo console password, shared in demonstrations. Same: §8a. | Same |
| `LLM_API_KEY` | Last set 05/05/2026. A new key has to be minted in the Anthropic console; nobody else can produce one. | The Anthropic account holder |
| Hetzner root password | Set at VM creation and unchanged since. | The Hetzner account holder |
| Test agent key | Issued for the local inference chain; never rotated. `POST /api/v1/agent-identities/{id}/rotate` issues a new one and revokes the old. | Any org admin |

`JWT_SECRET_KEY` and `VAULT_KEY` in GitHub secrets date from 11/04/2026 and
have never been rotated. `AUTH_PASSWORD_HASH` was rotated on 22/09/2026 — which
changed no login, for the reason §8 explains. `VAULT_KEY` is the one that
needs §4 followed exactly rather than a `gh secret set`.

---

_See also: `security-incident-response.md`, `../security-policy.md`_
