# ClaudyGod Infrastructure — Deployment Guide

## 🎯 Overview

This infrastructure is **designed to integrate with your existing shared proxy setup** at `~/apps/proxy`.

Your server has:
- ✅ Traefik v3.6 (reverse proxy, HTTPS, routing)
- ✅ docker-socket-proxy (Docker API security)
- ✅ error-service (custom 500-599 error pages)
- ✅ traefik-public network (external, pre-created)
- ✅ Prometheus metrics

**This repository adds ClaudyGod services** (frontend, API, database, cache) that automatically integrate with the shared proxy via Docker labels.

---

## 📦 What's Being Deployed

```
┌─────────────────────────────────────────────────┐
│     Shared Proxy (~/apps/proxy) - Existing      │
│  ┌───────────────────────────────────────────┐  │
│  │ Traefik v3.6 (Router, TLS, Rate Limit)   │  │
│  │ Socket Proxy (Docker API Security)       │  │
│  │ Error Service (500-599 Pages)            │  │
│  │ Prometheus Metrics                       │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
                      ▲
                      │ (routes traffic)
┌─────────────────────────────────────────────────┐
│    ClaudyGod Infrastructure (NEW - This Repo)   │
│  ┌───────────────────────────────────────────┐  │
│  │ Next.js Frontend (Server Components)      │  │
│  │ .NET 8 API (WebSocket + SSE ready)        │  │
│  │ PostgreSQL 16 (Database)                  │  │
│  │ Redis 7 (Cache + Realtime)                │  │
│  │ EF Core Migrate (Database Setup)          │  │
│  └───────────────────────────────────────────┘  │
│                                                 │
│ Traefik Labels → Picked up by shared proxy    │
│ claudygod-internal network → Isolated DB/Cache│
└─────────────────────────────────────────────────┘
```

---

## 🚀 Deployment Steps

### Step 1: Clone Repository

```bash
cd ~/apps
git clone https://github.com/ClaudyGod-MusicMinistries/ClaudyGodweb-Infrastructure.git claudygod
cd claudygod
```

### Step 2: Generate Secrets

```bash
# Generate strong random values
openssl rand -base64 48 > /tmp/jwt_key.txt
openssl rand -base64 32 > /tmp/encryption_key.txt
openssl rand -base64 32 > /tmp/postgres_pwd.txt
openssl rand -base64 32 > /tmp/redis_pwd.txt

# Display them
echo "=== Secrets ===" 
echo "JWT_KEY=$(cat /tmp/jwt_key.txt)"
echo "ENCRYPTION_KEY=$(cat /tmp/encryption_key.txt)"
echo "POSTGRES_PASSWORD=$(cat /tmp/postgres_pwd.txt)"
echo "REDIS_PASSWORD=$(cat /tmp/redis_pwd.txt)"
```

### Step 3: Create .env File

```bash
cp .env.example .env
nano .env
```

**Update these values:**

```env
# Secrets (from Step 2)
JWT_KEY=<paste from above>
ENCRYPTION_KEY=<paste from above>
POSTGRES_PASSWORD=<paste from above>
REDIS_PASSWORD=<paste from above>

# Email (Gmail)
EMAIL_SMTP_PASSWORD=<your gmail app password>
# Get from: https://myaccount.google.com/apppasswords

# Payment (Paystack - production only)
PAYSTACK_SECRET_KEY=sk_live_xxxxx
NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY=pk_live_xxxxx
# Get from: https://dashboard.paystack.com/#/settings/developers

# AI (Anthropic Claude)
ANTHROPIC_API_KEY=sk-ant-xxxxx
# Get from: https://console.anthropic.com/settings/keys
```

### Step 4: Deploy

```bash
# Verify shared network exists
docker network ls | grep traefik-public
# Should show: traefik-public  bridge   external

# Deploy all services
make deploy

# Or manually:
docker compose pull
docker compose up -d --remove-orphans
```

### Step 5: Verify

```bash
# Check all services are running
make ps

# Watch startup logs
make logs

# Check services individually
docker compose logs -f api      # Backend
docker compose logs -f web      # Frontend
docker compose logs -f db       # Database
docker compose logs -f redis    # Cache

# Verify health endpoints (wait ~60s for startup)
curl -I https://api.claudygod.org/healthz
curl -I https://claudygod.org/

# Verify Traefik picked up the services
cd ~/apps/proxy
docker compose logs traefik | grep claudygod | head -20
```

---

## 🌐 Access Points

After deployment, you'll have:

| Service | URL | Purpose |
|---------|-----|---------|
| **Frontend** | https://claudygod.org | Next.js app (SSR) |
| **Frontend** | https://www.claudygod.org | Redirects to claudygod.org |
| **API** | https://api.claudygod.org | .NET 8 REST API |
| **Swagger** | https://api.claudygod.org/swagger | API documentation |
| **Health Check** | https://api.claudygod.org/healthz | API health |

---

## 📊 Service Details

### Next.js Frontend (`web` container)

- **Port**: 3000 (internal, exposed via Traefik)
- **Features**: Server Components, real-time updates, live features
- **Health Check**: GET `/` every 30s
- **Router**: `claudygod-web-secure` (Traefik picks up via labels)
- **Error Handling**: Falls back to error-service on 500-599

### .NET 8 Backend API (`api` container)

- **Port**: 8080 (internal, exposed via Traefik)
- **Features**: WebSocket, SSE, CQRS, real-time subscriptions
- **Health Check**: GET `/healthz` every 30s
- **Router**: `claudygod-api-secure` (Traefik picks up via labels)
- **Database**: Connects to `db` service on `claudygod-internal` network
- **Cache**: Connects to `redis` service for sessions and pub/sub

### PostgreSQL Database (`db` container)

- **Port**: 5432 (internal only, not exposed to internet)
- **Network**: `claudygod-internal` (isolated)
- **Storage**: Named volume `db_data` (persistent across restarts)
- **Health Check**: `pg_isready` every 10s
- **Connection Pool**: 2-25 connections
- **Memory**: 256MB reservation, 512MB limit

### Redis Cache (`redis` container)

- **Port**: 6379 (internal only)
- **Network**: `claudygod-internal` (isolated)
- **Storage**: Named volume `redis_data` (RDB + AOF)
- **Features**: Session store, pub/sub for real-time, message queue
- **Eviction**: LRU when full (512MB max)
- **Health Check**: Redis ping every 10s

### Database Migrations (`migrate` container)

- **Purpose**: One-shot EF Core database migrations
- **Timing**: Runs before API starts (via `depends_on`)
- **Network**: `claudygod-internal` only
- **Retry**: Auto-restarts up to 3 times on failure
- **Cleanup**: Automatically stops after migrations complete

---

## 🔒 Security Architecture

### Network Isolation

```
Internet
   ↓
[Traefik - Port 80/443]  ← Handles TLS, routing
   ↓
[traefik-public network]
   ├→ Frontend (Next.js)
   └→ API (.NET 8)
         ↓
   [claudygod-internal network] ← ISOLATED (no internet)
         ├→ PostgreSQL
         └→ Redis
```

**Key Points:**
- Database and cache are on internal network only
- Cannot reach the internet from internal network
- Frontend and API can communicate with each other
- All traffic to internal services goes through the network, no direct exposure

### Container Security

- ✅ Non-root users (uid 1001 for Node.js, etc.)
- ✅ Read-only filesystems (except volumes)
- ✅ Capability dropping (DROP ALL + selective ADD)
- ✅ No privileged mode
- ✅ Tmpfs for temporary files

### Encryption & Secrets

- ✅ JWT keys (48 bytes, HS512)
- ✅ AES-256 encryption for sensitive data
- ✅ PostgreSQL password hashed
- ✅ Redis password protected
- ✅ All secrets in `.env` (gitignored, never committed)

### TLS/HTTPS

- ✅ Automatic via Let's Encrypt
- ✅ HTTP → HTTPS redirect
- ✅ 2-year HSTS header
- ✅ HTTP/2 support
- ✅ Modern cipher suites
- ✅ SNI strict mode

---

## 🛠️ Common Operations

### View Logs

```bash
# All services
make logs

# Specific service
docker compose logs -f api
docker compose logs -f web
docker compose logs -f db
docker compose logs -f redis

# Follow Traefik logs (from shared proxy)
cd ~/apps/proxy
docker compose logs -f traefik | grep claudygod
```

### Restart Services

```bash
# Restart all
make restart

# Restart specific service
docker compose restart api
docker compose restart web
```

### Check Status

```bash
# Quick status
make ps

# Detailed status
docker compose ps -a

# Resource usage
docker stats

# Health checks
docker compose ps | grep healthy
```

### Database Operations

```bash
# Backup database
make db-backup

# Restore from backup
make db-restore

# List backups
make db-list

# Connect to database shell
make db-shell
```

---

## 📈 Monitoring & Debugging

### Prometheus Metrics

Traefik exports Prometheus metrics on port 9090. The shared proxy has metrics collection configured.

To view ClaudyGod metrics:
```bash
curl http://localhost:9090/metrics | grep claudygod
```

### Health Endpoints

```bash
# API health
curl https://api.claudygod.org/healthz

# Frontend (just returns 200)
curl https://claudygod.org/

# Database health (from logs)
docker compose logs db | grep pg_isready

# Redis health
docker exec claudygod_redis redis-cli ping
```

### Performance Monitoring

```bash
# Docker resource usage
docker stats claudygod_api claudygod_web claudygod_db claudygod_redis

# Database connections
docker exec claudygod_db psql -U cgm -d claudygod -c \
  "SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;"

# Redis memory usage
docker exec claudygod_redis redis-cli INFO memory
```

---

## 🆘 Troubleshooting

### Services Won't Start

```bash
# Check full error
docker compose logs api
docker compose logs db

# Verify secrets are set
grep -E "JWT_KEY|POSTGRES_PASSWORD|REDIS_PASSWORD" .env

# Check network exists
docker network ls | grep traefik-public
docker network inspect traefik-public
```

### Database Connection Fails

```bash
# Check if container is healthy
docker compose ps db

# Test connection directly
docker compose exec db psql -U cgm -d claudygod -c "\dt"

# Check connection string
docker compose exec api env | grep ConnectionStrings
```

### Website Not Loading

```bash
# Check if frontend is running
docker compose ps web

# Check if Traefik picked up the service
cd ~/apps/proxy
docker compose logs traefik | grep claudygod-web

# Test directly (inside container)
docker compose exec web curl -I http://localhost:3000/
```

### Error Pages Not Loading

```bash
# Ensure error-service is running (in shared proxy)
cd ~/apps/proxy
docker compose ps error-service

# Trigger error page (returns 503)
curl -I https://api.claudygod.org/api/v1/test-500
```

### HTTPS Certificate Issues

```bash
# Check ACME storage (in shared proxy)
cd ~/apps/proxy
docker compose exec traefik ls -la /letsencrypt/

# Check Traefik logs for ACME errors
docker compose logs traefik | grep -i "acme\|certificate"

# Force renewal (if needed)
docker compose exec traefik traefik forcerenew
```

---

## 🚢 Production Checklist

- [ ] All secrets filled in `.env` (see .env.example)
- [ ] DNS records point to server:
  - `claudygod.org` → IP
  - `www.claudygod.org` → IP
  - `api.claudygod.org` → IP
- [ ] Shared proxy is running: `cd ~/apps/proxy && docker compose ps`
- [ ] `traefik-public` network exists: `docker network ls | grep traefik-public`
- [ ] Images are pushed to GHCR: Check `ghcr.io/claudygod-musicministries`
- [ ] Deploy services: `make deploy`
- [ ] Verify health endpoints work
- [ ] Test HTTPS certificate (green lock 🔒)
- [ ] Test API endpoints work
- [ ] Test frontend pages load
- [ ] Set up backups: `make db-backup`
- [ ] Monitor logs: `make logs`
- [ ] Configure monitoring/alerting

---

## 🔄 Updating & Redeployment

### Pull Latest Images

```bash
make pull
```

### Redeploy (Zero-Downtime)

```bash
make deploy
```

This will:
1. Pull latest images
2. Run database migrations
3. Start new containers
4. Stop old containers (Docker waits for graceful shutdown)

### Database Migrations

Migrations run automatically on each deploy (via `migrate` container).

If a migration fails:
```bash
# Check error
docker compose logs migrate

# Fix in backend repo, rebuild image, and redeploy
make deploy
```

---

## 📚 Architecture Documents

- **Plan**: `/root/.claude/plans/so-this-remote-v-linear-aurora.md`
- **Dockerfile**: Frontend at `ghcr.io/claudygod-musicministries/website2.0`
- **Dockerfile**: Backend at `ghcr.io/claudygod-musicministries/cgm-backend`
- **Shared Proxy**: `~/apps/proxy/docker-compose.yml` (socket-proxy, traefik, error-service)

---

## 🤝 Multi-Tenant Integration

This infrastructure lives alongside other apps on your shared proxy:

```
~/apps/
├── proxy/                    ← Shared (Traefik, socket-proxy, error-service)
│   ├── docker-compose.yml
│   ├── traefik/
│   └── error-service/
│
├── claudygod/               ← ClaudyGod (This repo)
│   ├── docker-compose.yml
│   ├── .env
│   └── scripts/
│
└── other-apps/              ← WisdomChurch, etc.
    ├── docker-compose.yml
    └── .env
```

All apps share:
- Traefik (routing + HTTPS)
- socket-proxy (Docker security)
- error-service (error pages)
- Prometheus (metrics)

Each app has its own:
- Databases
- Cache/Redis
- Internal networks
- Containers

---

## 💬 Support

For issues:
1. Check logs: `docker compose logs`
2. Review troubleshooting section above
3. Check shared proxy is healthy: `cd ~/apps/proxy && docker compose ps`
4. Verify .env values are correct
5. Contact: admin@claudygod.org

---

**Last Updated**: 2026-05-25  
**Infrastructure Version**: 2.0 (Shared Proxy Aligned)  
**Traefik**: v3.6  
**Docker Compose**: v3.9
