# VibOps — Encrypting the Cloudflare → origin leg

_Last updated: 2026-09-26 · v0.47.3_

> **When to use this runbook:**
> - Closing the last clear-text leg in front of the production console
> - Adding a new host behind Cloudflare
> - After any origin rebuild — the certificate lives on the origin and does not
>   survive a fresh machine

---

## What is exposed today

`demo.vibops.ai` resolves to Cloudflare (188.114.96.2 at the time of writing),
which forwards to an origin in Helsinki. **The origin address is not recorded
here on purpose: it cannot be established from outside** — that is what putting
a host behind Cloudflare is for — and an earlier version of this runbook named
167.233.117.135, which is `app.vibops.ai`, a different host. Take the address
from the DNS zone or the provider console, not from a neighbour's A record.

What was verified from outside on 26/09/2026: `demo.vibops.ai` answers only
through Cloudflare. The firewall of 13/09 does its half of the job.

What it did not close is the leg itself. Between Cloudflare's edge and Helsinki
the traffic crosses transit providers in clear: session cookies, JWTs, every
response body. Anyone able to observe a hop on that path reads them. Cloudflare
labels this SSL mode ("Flexible") as insecure in its own dashboard.

The fix is free and permanent: a Cloudflare **Origin CA** certificate, valid 15
years, trusted by Cloudflare alone — which is the only client that should ever
reach the origin directly.

## The trap: order matters, and the wrong order takes the site down

Switching SSL mode to *Full (strict)* **before** the origin serves a valid
certificate makes Cloudflare refuse the origin and every visitor gets a 502. The
origin must be able to serve TLS first. The steps below are in the order that
never breaks the site; do not reorder them for convenience.

There is a second, quieter trap. *Full* (without "strict") accepts **any**
certificate the origin presents, including a self-signed one and including one
presented by whoever manages to sit in the middle. It encrypts the leg without
authenticating it. Only *Full (strict)* does both. Stopping at *Full* looks
finished on the dashboard and leaves the interception path open.

## Procedure

### 1. Generate the Origin CA certificate (Cloudflare dashboard)

SSL/TLS → Origin Server → **Create Certificate**.

- Private key type: RSA (2048) unless the proxy needs ECDSA
- Hostnames: `demo.vibops.ai` — add any other proxied host in the same cert
- Validity: 15 years

Cloudflare shows the certificate and the private key **once**. Copy both now.
The private key is a production secret: it goes to the origin over SSH, never
into this repository, never into a chat, never into a ticket.

### 2. Install it on the origin

```bash
ssh <origin>
sudo install -d -m 0755 /etc/ssl/cloudflare
sudo install -m 0644 /dev/stdin /etc/ssl/cloudflare/origin.pem   # paste the certificate
sudo install -m 0600 /dev/stdin /etc/ssl/cloudflare/origin.key   # paste the private key
```

Point the reverse proxy at them and have it listen on 443. The exact directive
depends on what fronts the stack on that host — nginx `ssl_certificate` /
`ssl_certificate_key`, Caddy `tls <cert> <key>`, Traefik a file provider entry.
Reload, do not restart, so a bad config fails without dropping traffic.

### 3. Verify the origin serves TLS *before* touching Cloudflare

From the origin itself, since the firewall blocks everyone else:

```bash
openssl s_client -connect 127.0.0.1:443 -servername demo.vibops.ai </dev/null 2>/dev/null \
  | grep -E 'subject=|issuer='
# issuer must read: CloudFlare Origin SSL Certificate Authority
```

If this does not answer, stop here. The next step would take the site down.

### 4. Switch the SSL mode

SSL/TLS → Overview → **Full (strict)**.

Not *Flexible* (clear leg), not *Full* (encrypted but unauthenticated — see the
second trap above).

### 5. Confirm from outside

```bash
curl -sI https://demo.vibops.ai | head -3          # 200/405, not 502
curl -sI http://demo.vibops.ai | grep -i location  # must redirect to https
```

Then enable **Always Use HTTPS** and, once the leg is confirmed stable, HSTS.
Enable HSTS last: it is remembered by browsers and hard to walk back.

## What this does not cover

The Origin CA certificate is trusted **only by Cloudflare**. Reaching the origin
directly — bypassing the edge — will warn, which is intended: nothing should. It
also means this certificate cannot serve a host that must be reachable without
Cloudflare in front.

The private key sits on the origin. A rebuilt machine has no certificate, will
fail *Full (strict)*, and takes the host down until step 2 is repeated. Add it to
whatever provisions that host.

Fifteen years is long enough to forget. The expiry belongs in the same calendar
as the rotations in `secret-rotation.md`.
