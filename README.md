# ClaudyGod Music Ministries — Production Infrastructure

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A production-grade infrastructure repository for deploying ClaudyGod Music Ministries, featuring a modern, scalable architecture with Docker Compose (Docker Swarm ready) and Kubernetes manifests.

## 🎯 Overview

This repository orchestrates the complete ClaudyGod stack:

- **Frontend**: Next.js 14+ (TypeScript, Tailwind CSS)
- **Backend**: .NET 8 ASP.NET Core (Clean Architecture, CQRS)
- **Database**: PostgreSQL 16 (primary datastore)
- **Cache**: Redis 7 (session storage, rate limit counters)
- **Reverse Proxy**: Traefik v3.3 (automatic TLS via Let's Encrypt)
- **AI Integration**: Anthropic Claude (payment slip validation)
- **Payment**: Paystack (NGN) + Zelle (USD, AI-validated)
- **Email**: Gmail SMTP (transactional emails)

### Architecture Highlights

- 🔒 **Security-First**: Non-root containers, network isolation, HSTS, CSP headers
- 🚀 **High Performance**: Gzip compression, HTTP/2, Redis caching, connection pooling
- 📈 **Scalable**: Horizontal pod autoscaling (HPA) ready, rate limiting, health checks
- 🔄 **CI/CD Ready**: GitHub Actions SSH deploy + Watchtower support
- 🛡️ **Resilient**: Automatic HTTPS, health checks, graceful shutdown, backup automation

---

## 📋 Prerequisites

### Development/Testing

- Docker 25+ and docker-compose plugin
- Ports 80 and 443 available (for Traefik)
- 2GB+ free disk space
- Internet connection (to pull images from GHCR)

### Production Deployment

- Linux VPS (Ubuntu 22.04+, Debian 12+, etc.)
- Docker & docker-compose plugin installed
- DNS A records pointing to server IP:
  - `claudygod.com` → VPS IP
  - `api.claudygod.com` → VPS IP
- Email SMTP credentials (Gmail or custom)
- Paystack API keys
- Anthropic Claude API key
- GitHub Container Registry (GHCR) credentials

### Optional (for Kubernetes)

- Managed Kubernetes cluster (GKE, EKS, AKS) OR self-hosted (k3s, kubeadm)
- `kubectl` CLI configured
- Helm 3+ (optional, for easier management)

---

## 🚀 Quick Start (Docker Compose)

### 1. Clone and Configure

```bash
# Clone this repository
git clone https://github.com/ClaudyGod-MusicMinistries/ClaudyGodweb-Infrastructure.git
cd ClaudyGodweb-Infrastructure

# Copy configuration template
cp .env.example .env
nano .env  # Fill in all CHANGE_ME values
```

### 2. Generate Secure Secrets

```bash
# Generate random values for secrets
echo "JWT_KEY=$(openssl rand -base64 48)"
echo "ENCRYPTION_KEY=$(openssl rand -base64 32)"
echo "POSTGRES_PASSWORD=$(openssl rand -base64 32)"
echo "REDIS_PASSWORD=$(openssl rand -base64 32)"
```

Update your `.env` file with these values.

### 3. One-Time Server Setup

```bash
# Create external Docker network (only once per server)
docker network create traefik-public

# Verify the network exists
docker network ls | grep traefik-public
```

### 4. Deploy

```bash
# Full deployment (pulls images, runs migrations, starts services)
make deploy

# Or manually:
docker compose pull
docker compose up -d --remove-orphans
```

### 5. Verify Deployment

```bash
# Check service status
make ps

# Watch logs
make logs

# Test health endpoints (after ~60s for services to start)
curl https://api.claudygod.com/healthz
curl https://claudygod.com/
```

---

## 📁 Repository Structure

```
.
├── .env.example                      # Configuration template (copy to .env)
├── .gitignore                        # Exclude secrets from git
├── Makefile                          # Convenience commands
├── README.md                         # This file
│
├── docker/                           # Docker Compose production stack
│   ├── docker-compose.yml            # Main orchestration (6 services)
│   ├── docker-compose.maintenance.yml # Maintenance mode overlay
│   ├── traefik/
│   │   ├── traefik.yml              # Traefik static config
│   │   └── dynamic.yml              # Middleware definitions
│   └── maintenance/
│       └── index.html               # Maintenance page
│
├── k8s/                              # Kubernetes manifests (optional)
│   ├── namespace.yaml               # claudygod namespace
│   ├── configs/
│   │   ├── configmap.yaml
│   │   └── secret.yaml.example
│   ├── database/
│   │   ├── postgres-statefulset.yaml
│   │   ├── postgres-service.yaml
│   │   └── postgres-pvc.yaml
│   ├── cache/
│   │   ├── redis-deployment.yaml
│   │   └── redis-service.yaml
│   ├── backend/
│   │   ├── api-deployment.yaml
│   │   ├── api-service.yaml
│   │   └── api-hpa.yaml
│   ├── frontend/
│   │   ├── web-deployment.yaml
│   │   ├── web-service.yaml
│   │   └── web-hpa.yaml
│   ├── ingress/
│   │   ├── ingress.yaml
│   │   └── cert-issuer.yaml
│   └── jobs/
│       └── migrate-job.yaml
│
├── .github/
│   └── workflows/
│       └── deploy.yml               # GitHub Actions CI/CD
│
└── scripts/
    ├── deploy.sh                    # Production deployment automation
    ├── backup.sh                    # PostgreSQL backup with retention
    └── restore.sh                   # Database restore from backup
```

---

## 🛠️ Common Operations

### Deployment & Updates

```bash
# Full deployment (pull + migrate + start)
make deploy

# Pull latest images without restarting
make pull

# Restart services after config changes
make restart

# View deployment status
make ps

# Follow all logs
make logs

# View API logs only
make logs-api
```

### Database Operations

```bash
# Backup database
make db-backup

# List available backups
make db-list

# Restore from backup (interactive)
make db-restore

# Open PostgreSQL shell
make db-shell
```

### Maintenance

```bash
# Enable maintenance mode (503 Service Unavailable)
make maintenance

# Disable maintenance and redeploy
make maintenance-off

# Clean up Docker artifacts
make clean

# Full system validation
make validate
```

### Kubernetes (Optional)

```bash
# Deploy to Kubernetes cluster
make k8s-apply

# Check Kubernetes status
make k8s-status

# Follow API pod logs
make k8s-logs-api

# Scale API deployment
make k8s-scale-api REPLICAS=5

# Rolling restart
make k8s-rollout
```

---

## 📊 Services Overview

### Traefik Reverse Proxy

- **Port**: 80 (HTTP → HTTPS redirect), 443 (HTTPS)
- **Role**: Automatic HTTPS via Let's Encrypt, routing, rate limiting, security headers
- **Dashboard**: http://127.0.0.1:8080 (localhost only)
- **Entrypoints**:
  - `web` (80): HTTP, auto-redirects to HTTPS
  - `websecure` (443): HTTPS with TLS 1.2+

### PostgreSQL Database

- **Version**: 16-alpine
- **Port**: 5432 (internal network only, not exposed to internet)
- **Storage**: Named volume `db_data` (persistent)
- **Credentials**: Via `.env` (POSTGRES_USER, POSTGRES_PASSWORD)
- **Health**: `pg_isready` probe every 10 seconds

### Redis Cache

- **Version**: 7-alpine
- **Port**: 6379 (internal network only)
- **Storage**: Named volume `redis_data` (persistent RDB + AOF)
- **Policy**: Maxmemory 512MB, LRU eviction
- **Auth**: Password protected (REDIS_PASSWORD)

### .NET 8 API Backend

- **Port**: 8080 (internal, exposed via Traefik)
- **Routes**: `/api/v1/*`
- **Health**: GET `/healthz` (every 30 seconds)
- **Dependencies**: PostgreSQL, Redis
- **Startup**: Runs EF Core migrations automatically
- **Logging**: JSON logs to `/app/logs/`

### Next.js Frontend

- **Port**: 3000 (internal, exposed via Traefik)
- **Routes**: `claudygod.com` + `www.claudygod.com`
- **Health**: GET `/` (every 30 seconds)
- **Build Mode**: Standalone (optimized for Docker)
- **Static**: Aggressive caching for `/_next/static/`

### EF Core Migration Job

- **Purpose**: One-time database schema setup
- **Trigger**: Runs before API startup (migrations complete first)
- **Retry**: Automatic retry (up to 3 times) on failure
- **Network**: Internal only (no internet access)

---

## 🔐 Security Configuration

### Network Isolation

- **traefik-public** (external): Only Traefik, frontend, API
- **internal** (bridge): PostgreSQL, Redis, migration job (no internet)
  - `internal: true` prevents outbound internet access

### SSL/TLS

- **Automatic HTTPS** via Let's Encrypt + Traefik ACME
- **Certificate Renewal**: Automatic (90 days)
- **TLS Version**: 1.2+ minimum
- **Cipher Suites**: Modern, secure (TLS 1.3 preferred)
- **HSTS**: 2 years with preload

### Security Headers

- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: SAMEORIGIN`
- `Strict-Transport-Security: max-age=63072000; includeSubdomains; preload`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy: geolocation=(), microphone=(), camera=(), ...`

### Rate Limiting

- **Global**: 100 req/min, burst 50
- **Auth**: 10 req/5min, burst 5 (login/register)
- **AI**: 10 req/min, burst 3 (expensive operations)

### Non-Root Containers

- Traefik: `nobody:nogroup` (65534:65534)
- All containers run as non-root for security

---

## 🔄 CI/CD Integration

### GitHub Actions SSH Deploy

The repository includes a GitHub Actions workflow (`.github/workflows/deploy.yml`) that automatically deploys when new images are pushed to GHCR.

#### Setup Instructions

1. **Generate SSH Key Pair** on your server:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/deploy -N ""
   cat ~/.ssh/deploy.pub >> ~/.ssh/authorized_keys
   ```

2. **Add GitHub Secrets** to your repository:
   - `VPS_HOST`: Your server IP or hostname
   - `VPS_USER`: Deployment user (e.g., `deploy`)
   - `VPS_SSH_KEY`: Private key from `~/.ssh/deploy`
   - `VPS_DEPLOY_PATH`: Path to ClaudyGodweb-Infrastructure (e.g., `/opt/claudygod`)
   - `SLACK_WEBHOOK`: (Optional) Slack notifications

3. **Automatic Deployment** triggers when:
   - New image pushed to `ghcr.io/claudygod-musicministries/cgm-backend`
   - New image pushed to `ghcr.io/claudygod-musicministries/website2.0`
   - Manually triggered via GitHub Actions

#### Alternative: Watchtower

For automatic updates without GitHub Actions:

```bash
docker run -d \
  --name watchtower \
  --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --interval 3600 \
  --cleanup \
  ghcr.io/claudygod-musicministries/cgm-backend \
  ghcr.io/claudygod-musicministries/website2.0
```

---

## 💾 Backup & Restore

### Automatic Backups

```bash
# Daily backup (kept for 30 days)
make db-backup

# Restore from backup (interactive selection)
make db-restore

# List recent backups
make db-list
```

### Backup Retention

- **Daily**: Last 30 days
- **Weekly**: Last 12 weeks
- **Monthly**: Last 3 months

### S3 Upload (Optional)

To upload backups to S3:

```bash
# Install AWS CLI
pip install awscli

# Configure credentials
aws configure

# Run backup with S3 upload
AWS_BACKUP_BUCKET=s3://my-backup-bucket make db-backup
```

---

## 📈 Monitoring & Debugging

### View Logs

```bash
# All services
docker compose logs -f --tail=100

# Specific service
docker compose logs -f --tail=50 api
docker compose logs -f --tail=50 web
docker compose logs -f --tail=50 db

# Traefik access logs
docker compose logs -f traefik
```

### Performance Monitoring

```bash
# Docker resource usage
docker stats

# Database connections
docker exec claudygod_db psql -U cgm -d claudygod -c "SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;"

# Redis memory
docker exec claudygod_redis redis-cli INFO memory
```

### Traefik Dashboard

Access Traefik dashboard (localhost only):

```bash
# SSH tunnel to server
ssh -L 8080:127.0.0.1:8080 user@server

# Open browser
open http://127.0.0.1:8080
```

---

## 🆘 Troubleshooting

### Services Won't Start

```bash
# Check what's wrong
docker compose logs

# Verify .env variables
make env-check

# Check Docker network
docker network ls
docker network inspect traefik-public

# Validate configuration
make lint
```

### Database Connection Issues

```bash
# Check if DB container is healthy
docker compose ps db

# Try connecting directly
docker compose exec db psql -U cgm -d claudygod

# Check logs
docker compose logs db
```

### HTTPS Certificate Issues

```bash
# Check Traefik logs
docker compose logs traefik | grep -i "acme\|certificate\|tls"

# Verify Let's Encrypt status
docker exec claudygod_traefik ls -la /acme/

# Force certificate renewal (advanced)
docker compose exec traefik traefik forcerenew
```

### High Memory Usage

```bash
# Check Redis memory
docker exec claudygod_redis redis-cli --stat

# Check PostgreSQL connections
docker exec claudygod_db psql -U cgm -d claudygod -c "SELECT count(*) FROM pg_stat_activity;"

# Scale down or increase limits
```

---

## 🚢 Production Deployment Checklist

- [ ] Clone infrastructure repo
- [ ] Configure `.env` with all production secrets
- [ ] Generate strong secrets (JWT_KEY, ENCRYPTION_KEY, etc.)
- [ ] Create DNS A records (`claudygod.com`, `api.claudygod.com`)
- [ ] Open firewall ports (80, 443)
- [ ] Create `traefik-public` network
- [ ] Run `make deploy` or `./scripts/deploy.sh`
- [ ] Verify HTTPS certificate (Green lock 🔒)
- [ ] Test API health endpoint
- [ ] Test frontend functionality
- [ ] Set up database backups (`make db-backup`)
- [ ] Configure GitHub Actions secrets for CD
- [ ] Set up uptime monitoring
- [ ] Configure error tracking (optional: Sentry)
- [ ] Enable log aggregation (optional: ELK, Datadog)

---

## 🆙 Updating Services

### Update Frontend or Backend

```bash
# Build and push new image to GHCR from the respective repo
# Then pull latest in infrastructure:

make pull          # Pull latest images
make deploy        # Deploy with zero downtime (rolling update)

# Or automatically via GitHub Actions (if configured)
```

### Update Infrastructure Configuration

```bash
# Edit docker-compose.yml or Traefik config
nano docker/docker-compose.yml

# Validate changes
make lint

# Apply changes
make deploy
```

### Database Schema Changes

```bash
# New migrations run automatically on next deploy
make deploy

# If something goes wrong, restore from backup
make db-restore
```

---

## 📚 Architecture & Design Patterns

### Clean Architecture (Backend)

- **Domain** Layer: Entities, value objects, domain events
- **Application** Layer: CQRS (MediatR), validation (FluentValidation)
- **Infrastructure** Layer: EF Core, Redis, email, file storage, JWT
- **API** Layer: Controllers, middleware, Swagger/OpenAPI

### Next.js (Frontend)

- **App Router**: Modern, file-based routing
- **Standalone**: Optimized output for Docker
- **SSG**: Static generation where possible
- **React Hook Form**: Efficient form handling

### Traefik

- **Docker Provider**: Auto-discover containers by labels
- **File Provider**: Static middleware definitions
- **ACME**: Automatic certificate provisioning
- **Middleware**: Rate limiting, security headers, compression

---

## 📖 Further Reading

- [Traefik Documentation](https://doc.traefik.io/)
- [Docker Compose Specification](https://docs.docker.com/compose/compose-specification/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Next.js Production Guide](https://nextjs.org/docs/going-to-production)
- [.NET 8 Best Practices](https://learn.microsoft.com/en-us/dotnet/)

---

## 📄 License

MIT License — See [LICENSE](LICENSE) for details.

---

## 💬 Support & Questions

For issues or questions:

1. **Check the Troubleshooting section** above
2. **Review logs**: `docker compose logs`
3. **Check GitHub Issues**: https://github.com/ClaudyGod-MusicMinistries/ClaudyGodweb-Infrastructure/issues
4. **Contact**: peter4tech@gmail.com

---

**Built with ❤️ for ClaudyGod Music Ministries**

Last updated: 2026-05-25  
Infrastructure as Code Version: 1.0.0