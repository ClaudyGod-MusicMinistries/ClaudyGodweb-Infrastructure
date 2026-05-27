# 🚀 ClaudyGod Infrastructure — Deployment Status

**Last Updated:** 2026-05-27
**Status:** ✅ READY FOR PRODUCTION DEPLOYMENT

---

## ✅ Fixed Issues

### 1. Optional Payment & AI Features
- **Issue:** Deployment was blocking on missing Paystack and Anthropic API keys
- **Fix:** Made these features optional in the deployment script
- **Files Changed:**
  - `scripts/deploy.sh` — Separated required vs optional variables
  - `docker/docker-compose.yml` — Already had optional syntax (`${VAR:-}`)
  - `Makefile` — Already displays optional vars correctly
- **Result:** Deployment now proceeds without payment/AI features, warns if not configured

### 2. Validation Flow
```
Deployment Chain (Correct Flow):
1. website2.0 repo push to main
   ↓
2. GitHub Actions: Build frontend image → GHCR
   ↓
3. GitHub Actions: Deploy via SSH to infrastructure repo
   ↓
4. Infrastructure deploy.sh runs:
   - ✓ Check required vars (domain, database, cache, secrets)
   - ⊘ Warn about optional vars (payment, AI)
   - ✓ Pull images from GHCR
   - ✓ Run migrations
   - ✓ Start services
```

---

## 📋 Required Variables (Must Be Set)

These variables **must** be configured in `.env` on the VPS:

| Variable | Purpose | How to Get |
|---|---|---|
| `DOMAIN` | Main website domain | Set to `claudygod.org` |
| `API_DOMAIN` | Backend API domain | Set to `api.claudygod.org` |
| `BACKEND_IMAGE` | Docker image for API | From GHCR: `ghcr.io/claudygod-musicministries/cgm-api:latest` |
| `FRONTEND_IMAGE` | Docker image for web | From GHCR: `ghcr.io/claudygod-musicministries/cgm-web:latest` |
| `SUPABASE_CONNECTION_STRING` | Database connection | From Supabase Dashboard |
| `REDIS_PASSWORD` | Cache password | Generate: `openssl rand -base64 32` |
| `JWT_KEY` | JWT signing key | Generate: `openssl rand -base64 48` |
| `ENCRYPTION_KEY` | AES-256 key | Generate: `openssl rand -base64 32` |
| `EMAIL_SMTP_HOST` | Email relay server | Use: `smtp-relay.brevo.com` |
| `EMAIL_SMTP_USERNAME` | Email username | From Brevo dashboard |
| `EMAIL_SMTP_PASSWORD` | Email password | From Brevo dashboard |
| `GRAFANA_ADMIN_PASSWORD` | Monitoring dashboard password | Generate: `openssl rand -base64 32` |

---

## 🔧 Optional Variables (Can Be Set Later)

These features are **not required** for core deployment:

| Variable | Feature | Status |
|---|---|---|
| `PAYSTACK_SECRET_KEY` | Payment processing (NGN) | ⏳ Can be added later |
| `NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY` | Paystack public key | ⏳ Can be added later |
| `ANTHROPIC_API_KEY` | AI validation for Zelle transfers | ⏳ Can be added later |

**How to Enable Later:**
```bash
# Edit .env on VPS
nano .env
# Add your keys
docker compose restart api
```

---

## 🎯 Deployment Checklist

### On Your VPS (207.180.253.39)

- [ ] Repository cloned to `~/apps/claudygod/ClaudyGodweb-Infrastructure`
- [ ] `.env` file created with all **required** variables
- [ ] `docker network create traefik-public` has been run
- [ ] Traefik proxy is running at `~/apps/proxy`
- [ ] DNS records point to VPS:
  - [ ] `claudygod.org` → 207.180.253.39
  - [ ] `api.claudygod.org` → 207.180.253.39
  - [ ] `metrics.claudygod.org` → 207.180.253.39

### GitHub Actions Setup

- [ ] Repository secrets configured:
  - `VPS_HOST` = `207.180.253.39`
  - `VPS_USER` = `server`
  - `VPS_SSH_KEY` = your private SSH key
  - `VPS_DEPLOY_PATH` = `/home/server/apps/claudygod/ClaudyGodweb-Infrastructure`
- [ ] GHCR credentials configured if using private registry
- [ ] GitHub PAT (if needed) has `read:packages` and `write:packages` scope

### Docker Images

- [ ] Backend image built and pushed: `ghcr.io/claudygod-musicministries/cgm-api:latest`
- [ ] Frontend image built and pushed: `ghcr.io/claudygod-musicministries/cgm-web:latest`

---

## 🚀 How to Deploy

### First-Time Deployment

```bash
# On VPS
cd ~/apps/claudygod/ClaudyGodweb-Infrastructure

# Test configuration
make env-check     # Verify all required vars are set

# Deploy
make deploy        # Pulls images and starts services

# Verify
make ps            # Show service status
make health-check  # Test health endpoints
```

### After Code Changes

```bash
# On your local machine
cd website2.0/ClaudyGodWebApp
git push origin main

# Automatically:
# 1. GitHub Actions builds frontend image
# 2. GitHub Actions deploys to VPS via SSH
# 3. infrastructure repo deploy.sh runs
# 4. Services updated
```

---

## ✅ Verification

After deployment, verify everything is working:

```bash
# Service status
curl -I https://claudygod.org/
# Expected: 200 or 301 (redirect to https)

# API health
curl -I https://api.claudygod.org/healthz
# Expected: 200 OK

# Monitoring
curl -I https://metrics.claudygod.org/
# Expected: 200 (Grafana dashboard)
```

---

## 📊 Service Architecture

```
Traefik (Reverse Proxy on port 80/443)
├── claudygod.org (www.claudygod.org) → Next.js web (port 3000)
├── api.claudygod.org/healthz → .NET API (port 8080)
└── metrics.claudygod.org → Grafana (port 3000)

Services (Docker Compose)
├── redis:7            (in-memory cache)
├── migrate            (one-shot DB migrations)
├── api:8080           (.NET 8 ASP.NET Core)
└── web:3000           (Next.js 14)

External Services (Managed)
├── Supabase PostgreSQL (database)
├── Brevo SMTP (email)
└── Paystack (payments) — optional
```

---

## 🔄 Environment Variable Management

### Load on Server
```bash
# The deploy.sh script automatically:
set -a
source .env
set +a
# Then validates all required vars
```

### Update at Runtime
```bash
# Edit .env
nano .env

# Restart specific service
docker compose restart api    # For API changes
docker compose restart web    # For web changes
```

---

## 📝 Important Notes

1. **SUPABASE_CONNECTION_STRING** — Must use the Shared Pooler (IPv4, port 5432)
2. **Environment Variables with Spaces** — Are properly handled by the deploy script
3. **Optional Features** — Payment and AI validation can be added anytime without redeployment
4. **Backup Strategy** — Use `make db-backup` regularly
5. **Monitoring** — Grafana dashboard available at `https://metrics.claudygod.org`

---

## 🆘 Troubleshooting

### Services not starting
```bash
make logs              # View all logs
make logs-api          # View API logs
make logs-web          # View frontend logs
docker compose ps      # Check container status
```

### Health check failing
```bash
make health-check      # Re-run health checks
make restart           # Restart all services
docker compose up -d   # Full redeploy
```

### Need to roll back
```bash
# Use previous image tag
nano .env
# Change TAG=latest to TAG=previous-commit-sha
docker compose up -d
```

---

## 🎓 Next Steps

1. **Verify** all required environment variables are set on VPS
2. **Test** deployment with: `make deploy`
3. **Monitor** with: `make logs`
4. **Configure** optional features (Paystack, Anthropic) when ready
5. **Backup** database regularly with: `make db-backup`

**Deployment is ready to go!** 🎉
