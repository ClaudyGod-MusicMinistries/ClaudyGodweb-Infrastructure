# ClaudyGod production infrastructure

Docker Compose infrastructure for ClaudyGod Music Ministries, designed to run
behind a server-wide Traefik proxy.

## Runtime architecture

- Next.js web application from GHCR
- ASP.NET Core API from GHCR
- Redis cache/session store on an isolated network
- Supabase managed PostgreSQL
- Brevo SMTP, Paystack, and AIProvider integrations
- Grafana connected to the shared Prometheus service
- Shared Traefik ingress and automatic TLS

See [ARCHITECTURE.md](ARCHITECTURE.md) for trust boundaries, delivery flow,
reliability targets, and the improvement roadmap.

## Requirements

- Linux host with Docker Engine and Docker Compose v2
- Existing external Docker network named `traefik-public`
- Shared Traefik proxy configured with `web`, `websecure`, and `letsencrypt`
- DNS for the web, API, and Grafana domains
- GHCR access and managed-service credentials

## First deployment

```bash
cp .env.example .env
# Fill every required value; never commit .env.
make validate
make deploy
make health-check
```

Generate independent credentials with `openssl rand -base64 48`. At minimum,
replace every `CHANGE_ME` value, including `JWT_KEY`, `ENCRYPTION_KEY`,
`INTERNAL_API_KEY`, `REDIS_PASSWORD`, and `GRAFANA_ADMIN_PASSWORD`.

`make deploy` runs preflight checks, pulls images, applies database migrations,
reconciles the stack, and fails if public health checks do not recover. For
targeted deployments:

```bash
./scripts/deploy.sh --api-only
./scripts/deploy.sh --web-only
TAG=sha-abcdef1 ./scripts/deploy.sh
```

Use immutable commit-SHA tags for controlled production releases and rollbacks.

## Common operations

```bash
make help
make ps
make logs
make logs-api
make logs-web
make restart-api
make maintenance
make maintenance-off
```

## Validation and CI/CD

`make lint` validates the rendered Compose model, parses all shell scripts, runs
ShellCheck when installed, and checks for obvious committed credentials. Pull
requests run the same validation in GitHub Actions.

Production deploys use the GitHub `production` Environment and are serialized
to prevent overlapping migrations. Configure required reviewers and these
secrets:

- `VPS_HOST`, `VPS_PORT`, `VPS_USER`, `VPS_SSH_KEY`, `VPS_DEPLOY_PATH`
- `GH_PAT` with read-only package access when GHCR packages are private

The VPS keeps its production `.env`; CI does not copy secrets into the repo.

## Database recovery

Supabase backups/PITR are the primary recovery mechanism. The scripts here add
portable logical exports:

```bash
make db-backup
make db-list
make db-restore                 # restores the newest local export
./scripts/restore.sh backups/claudygod_db_YYYYMMDDTHHMMSSZ.sql.gz
```

Restores are destructive and require typing `RESTORE`. Test restoration against
a separate staging project quarterly. Set `AWS_BACKUP_BUCKET` to copy verified
exports to a private S3 bucket with server-side encryption.

## Repository layout

```text
.github/workflows/   validation and production deployment
docker/              Compose stack, Grafana provisioning, maintenance page
scripts/             deploy, validate, backup, and restore automation
ARCHITECTURE.md      production design and improvement roadmap
```

Do not use the older status/guide files as executable specifications; the
Compose model, `.env.example`, this README, and `ARCHITECTURE.md` are canonical.
