# Runbook — Issuing a VibOps licence

How a customer gets a licence after the 14-day trial, who can issue one, and
where the key that signs them lives.

This runbook exists because none of it did. `scripts/onboard-client.sh` pointed
at `scripts/gen_licence.py` from the beginning; that file was never in the
history, and nobody held the private key matching the public key embedded in the
product. VibOps could read a licence that nobody could issue, so every
deployment was capped at fourteen days with no way forward. Found on 01/10/2026
while scoping a POC that had to continue past the trial.

---

## 1. What a licence is

A self-contained RS256 JWT. The product verifies it **offline**, against a
public key compiled into `core/app/licence.py`. No activation call, no licence
server, no telemetry — that is a sovereignty argument we make in writing, and
this is its consequence:

> **A licence cannot be revoked.** Only expire. Date them short and renew,
> rather than issuing long ones you cannot take back.

Claims carried: `customer`, `plan`, `iat`, `exp`, `gpu_max`, `users_max`,
`clusters_max`. The ceilings travel in the key rather than being looked up from
the plan name — a customer buys numbers, and a plan's definition can change
between two versions of the product.

---

## 2. The signing key

| | |
|---|---|
| Algorithm | RSA 4096, PKCS#8 PEM, unencrypted |
| Public half | embedded in `core/app/licence.py`, shipped in every image |
| Private half | **outside this repository, outside every development machine** |
| Created | 01/10/2026 |

**Where it must live:** a password manager or secret vault entry that at least
two people can reach. One holder is one lost key, and the product has no
recovery path — replacing the pair means shipping a new release and reissuing
every customer's licence.

**Where it must never live:** this repository, a laptop's home directory, a
chat message, a CI secret. `tests/test_licence_issuance.py` fails if any private
key material appears anywhere in the tree.

**Permissions:** `chmod 600`. The generator refuses to sign with a key readable
beyond its owner, because such a key is to be treated as disclosed — and this
one cannot be revoked.

### If the key is lost or disclosed

There is no revocation list. The procedure is a product release:

1. Generate a new pair.
2. Replace `_PUBLIC_KEY` in `core/app/licence.py`.
3. Ship a release — **every key signed by the old pair stops being accepted on
   upgrade**, so reissue every live customer's licence first and hand it over
   with the upgrade.
4. Customers who do not upgrade keep working on the old key. That is the only
   reason a disclosure is not immediately fatal, and it is also why it cannot be
   contained.

---

## 3. Issuing a key

```bash
export VIBOPS_LICENCE_PRIVATE_KEY=~/.vibops/licence-signing-key.pem

# A 30-day POC
python3 scripts/gen_licence.py --customer "Oreus" --plan pro --days 30

# A year, no ceilings
python3 scripts/gen_licence.py --customer "Oreus" --plan enterprise --days 365

# Explicit ceilings, overriding the plan's
python3 scripts/gen_licence.py --customer "Oreus" --plan pro --days 30 \
    --gpu-max 128 --users-max 25 --clusters-max 8
```

Plans and their default ceilings come from `PLAN_LIMITS` in the product itself,
read at generation time rather than copied here — two lists always drift, and
this one would reach a customer.

| Plan | GPU | Users | Gateways |
|---|---|---|---|
| trial | 10 | 5 | 5 |
| starter | 10 | 5 | 2 |
| pro | 50 | 20 | 10 |
| enterprise | unlimited | unlimited | unlimited |

**`clusters_max` counts gateways, not clusters** — `check_clusters` is called on
gateway creation with the number of `Gateway` rows in the organisation. One site
is one unit however many clusters its gateway reports.

Beyond 400 days the generator refuses unless `VIBOPS_LICENCE_ALLOW_LONG=1`. A
key that cannot be revoked should be a decision, not a typo.

---

## 4. Installing it at the customer

Two routes, both valid, and the first is the one to prefer.

**Console** — Admin (⚙) → Licence, paste, save. Validated, applied **hot** with
no restart, and written to the `platform_licence` table so it survives the next
one. The page then shows where the active licence came from and when the trial
started.

**Deployment** — `VIBOPS_LICENCE_KEY` in `.env` (Compose) or
`core.secret.licenceKey` (Helm). Read at boot.

Precedence is **database > environment > trial**. The database wins
deliberately: an operator activating a licence in the console acts after
deployment, and an environment variable winning would silently undo that at the
first restart.

Before v0.48.7 a key pasted in the console lived only in the process and
vanished at the next `docker compose up`, and the trial clock was anchored at
process start — so restarting reopened fourteen days.

---

## 5. What expiry actually does

Checked in exactly three places, all of which return **402**:

- creating a gateway
- creating a user
- sending an organisation invite

Everything else keeps running: gateways ping, metrics are stored, energy is
measured, the console works. **You can no longer add; you can still see.**

That is the right degradation, and it is quiet — nobody notices until someone
tries to add something. Tell the customer before day fourteen, not during.

The GPU ceiling is separate from expiry and is checked on every heartbeat. Since
01/10/2026 it reports rather than blocks: metrics are kept, the ping answers
`gpu_limit_exceeded`, Connect logs it in the customer's own logs, and
`gpu_current` on the Licence page tells the truth. Before that it returned
before writing the metrics — and `gpu_current` is computed from those metrics,
so a 64-GPU fleet on a 10-GPU trial displayed "0 / 10", in green.

---

## 6. The registry

Every issuance appends a line to `~/.vibops/licences.csv` — override with
`VIBOPS_LICENCE_REGISTRY`. It is created `0600` on first write.

```
issued_at,customer,plan,days,expires_at,gpu_max,users_max,clusters_max,fingerprint
2026-10-02 16:08:15Z,Oreus,pro,365,2027-10-02,50,20,10,623d33e87aa6a5d4
```

It holds a **fingerprint of the key, not the key**. A registry containing the
JWTs would be a file whose leak hands a third party working licences, for a
traceability a hash provides just as well.

It protects nothing technically — it answers a question that had no answer:
who holds what, until when. Nothing else knows: there is no licence server to
query, by design.

What to do with it:

```bash
# Ce qui expire dans les trente jours
awk -F, -v d="$(date -u -v+30d +%Y-%m-%d 2>/dev/null || date -u -d '+30 days' +%Y-%m-%d)" \
  'NR>1 && $5 <= d {print $5, $2, $3}' ~/.vibops/licences.csv | sort
```

A failed write does not stop the issuance — the key is already signed, and
losing it because a file was not writable would be worse — but it says so on
stderr. A registry that fails silently is worth no more than no registry.

**Back it up with the signing key.** They are the two things that cannot be
reconstructed: the key issues, the registry remembers.

---

## 7. Renewal

Nothing renews itself. There is no reminder, no job, no mail. The only signal is
the countdown banner in the customer's own console — which is to say, the
customer finds out before we do.

Until that is automated, the practice is: a calendar entry per issued key, set
two weeks before `exp`. The claims of every key issued should be recorded
somewhere durable — customer, plan, ceilings, `iat`, `exp` — because the key
itself is the only other record and the customer holds it.
