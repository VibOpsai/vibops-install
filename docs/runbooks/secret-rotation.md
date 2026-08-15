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

---

_See also: `security-incident-response.md`, `../security-policy.md`_
