# VibOps — Makefile
# Usage:
#   make quickstart                   # first-time setup: copy .env, generate secrets, start stack
#   make up                           # start the full stack
#   make down                         # stop the stack
#   make check                        # verify the stack is healthy
#   make logs SERVICE=core            # tail logs for a service
#   make pilot-create-client ORG=acme EMAIL=admin@acme.com PASSWORD=s3cr3t
#   make pilot-create-client ORG=acme EMAIL=admin@acme.com PASSWORD=s3cr3t BUDGET=5000

.PHONY: up down logs quickstart check pilot-create-client backup-now backup-list help

# ── Stack ──────────────────────────────────────────────────────────────────────

quickstart:
	@if [ -f .env ]; then \
		echo "→ .env already exists — skipping copy. Edit it manually if needed."; \
	else \
		cp .env.example .env; \
		echo "→ .env created from .env.example"; \
		SECRET=$$(openssl rand -hex 32); \
		JWT=$$(openssl rand -hex 32); \
		PGPASS=$$(openssl rand -hex 16); \
		GRAFPASS=$$(openssl rand -hex 12); \
		sed -i.bak "s/change-me-in-production/$$SECRET/" .env; \
		sed -i.bak "s/change-me-jwt-secret-in-production/$$JWT/" .env; \
		sed -i.bak "s/^POSTGRES_PASSWORD=$$/POSTGRES_PASSWORD=$$PGPASS/" .env; \
		sed -i.bak "s|\$${POSTGRES_PASSWORD}|$$PGPASS|g" .env; \
		sed -i.bak "s/^GRAFANA_PASSWORD=$$/GRAFANA_PASSWORD=$$GRAFPASS/" .env; \
		rm -f .env.bak; \
		echo "→ SECRET_KEY, JWT_SECRET_KEY, POSTGRES_PASSWORD and GRAFANA_PASSWORD generated"; \
		echo ""; \
		echo "  Edit .env and set:"; \
		echo "    LLM_PROVIDER + LLM_API_KEY  (or set LLM_PROVIDER=ollama for local LLM)"; \
		echo "    AUTH_PASSWORD_HASH          (run: make hash PASSWORD=yourpassword)"; \
		echo ""; \
	fi
	docker compose up -d
	@echo ""
	@echo "→ Stack starting — waiting for core to be healthy..."
	@sleep 8
	@$(MAKE) check --no-print-directory
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Next steps — required before first use:"
	@echo ""
	@echo "  1. Set your LLM provider in .env:"
	@echo "       LLM_PROVIDER=claude   → add LLM_API_KEY=sk-ant-..."
	@echo "       LLM_PROVIDER=openai   → add LLM_API_KEY + LLM_BASE_URL"
	@echo "       LLM_PROVIDER=ollama   → no key needed"
	@echo ""
	@echo "  2. Create your admin account:"
	@echo "       make hash PASSWORD=yourpassword"
	@echo "       → paste the result into AUTH_PASSWORD_HASH in .env"
	@echo ""
	@echo "  3. Create your organisation:"
	@echo "       make pilot-create-client ORG=\"My Company\" EMAIL=you@company.com PASSWORD=yourpassword"
	@echo ""
	@echo "  4. Restart the agent after editing .env:"
	@echo "       docker compose restart agent"
	@echo ""
	@HOST=$$(hostname -I 2>/dev/null | awk '{print $$1}' || echo "localhost"); \
	echo "  Console: http://$$HOST:8003"; \
	if [ "$$HOST" != "localhost" ] && [ "$$HOST" != "127.0.0.1" ]; then \
		echo "           (or http://localhost:8003 from this machine)"; \
	fi; \
	echo ""; \
	echo "  Licence: trial mode — 14 days, 10 GPUs, 5 users, 2 clusters."; \
	echo "           Add VIBOPS_LICENCE_KEY to .env to activate your licence."; \
	echo "           Contact david@vibops.ai to obtain a key."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f $(SERVICE)

check:
	@bash scripts/poc-healthcheck.sh http://localhost:8000

hash:
	@test -n "$(PASSWORD)" || (echo "Usage: make hash PASSWORD=yourpassword"; exit 1)
	@docker compose run --rm core python -c \
		"from app.auth import hash_password; print(hash_password('$(PASSWORD)'))"

# ── Pilot Onboarding ───────────────────────────────────────────────────────────
# Crée une organisation + admin + budget optionnel dans l'instance VibOps locale.
# Idempotent : peut être relancé sans danger (le password est mis à jour).
#
# Paramètres requis :
#   ORG      — nom de l'organisation  (ex: "Acme Corp")
#   EMAIL    — email de l'admin       (ex: admin@acme.com)
#   PASSWORD — mot de passe admin     (ex: changeme123)
#
# Paramètres optionnels :
#   SLUG     — identifiant URL        (défaut: valeur de ORG en minuscules)
#   BUDGET   — plafond mensuel USD    (ex: 5000 — aucun budget si absent)
#   SOFT_CAP — seuil d'alerte %       (défaut: 80)
#   HARD_CAP — seuil de blocage %     (défaut: 100)
#
# Exemples :
#   make pilot-create-client ORG=acme EMAIL=admin@acme.com PASSWORD=s3cr3t
#   make pilot-create-client ORG="BioTech AI" EMAIL=cto@biotech.io PASSWORD=p@ss BUDGET=12000

ORG      ?=
EMAIL    ?=
PASSWORD ?=
SLUG     ?= $(shell echo "$(ORG)" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
BUDGET   ?=
SOFT_CAP ?= 80
HARD_CAP ?= 100

pilot-create-client:
	@test -n "$(ORG)"      || (echo "Erreur : ORG est requis.   Usage: make pilot-create-client ORG=acme EMAIL=... PASSWORD=..."; exit 1)
	@test -n "$(EMAIL)"    || (echo "Erreur : EMAIL est requis. Usage: make pilot-create-client ORG=acme EMAIL=... PASSWORD=..."; exit 1)
	@test -n "$(PASSWORD)" || (echo "Erreur : PASSWORD est requis."; exit 1)
	$(eval _BUDGET_ARG := $(if $(filter-out ,$(BUDGET)),--budget $(BUDGET),))
	docker compose exec core python -m scripts.pilot_provision \
		--org      "$(ORG)" \
		--slug     "$(SLUG)" \
		--email    "$(EMAIL)" \
		--password "$(PASSWORD)" \
		--soft-cap "$(SOFT_CAP)" \
		--hard-cap "$(HARD_CAP)" \
		$(_BUDGET_ARG)

# ── Backup ─────────────────────────────────────────────────────────────────────

backup-now:
	@echo "→ Lancement d'un backup manuel..."
	docker compose exec backup sh -c \
		'DEST=/backups/vibops_$$(date -u +%Y-%m-%dT%H%M%S)_manual.sql.gz; \
		 pg_dump -h postgres -U vibops -d vibops_db | gzip > $$DEST && echo "✓ $$DEST"'

backup-list:
	@echo "Backups disponibles :"
	docker compose exec backup sh -c 'ls -lh /backups/vibops_*.sql.gz 2>/dev/null || echo "(aucun backup)"'

# ── Release ────────────────────────────────────────────────────────────────────

publish:
	@bash scripts/publish-install-repo.sh $(VERSION)

# ── Help ───────────────────────────────────────────────────────────────────────

help:
	@echo ""
	@echo "VibOps — available commands"
	@echo ""
	@echo "  make quickstart                            First-time setup + start"
	@echo "  make up                                    Start the stack"
	@echo "  make down                                  Stop the stack"
	@echo "  make check                                 Health check (all services)"
	@echo "  make logs SERVICE=core                     Tail logs for a service"
	@echo "  make hash PASSWORD=yourpassword            Generate bcrypt password hash"
	@echo ""
	@echo "  make pilot-create-client \\"
	@echo "    ORG=acme EMAIL=admin@acme.com \\"
	@echo "    PASSWORD=s3cr3t [BUDGET=5000]            Provision a client org"
	@echo ""
	@echo "  make backup-now                            Manual PostgreSQL backup"
	@echo "  make backup-list                           List available backups"
	@echo ""
	@echo "  make publish VERSION=v0.15.1               Publish to public install repo"
	@echo ""
