# ClaudyGod production infrastructure

Production infrastructure for ClaudyGod Music Ministries on a hardened Docker
Compose VPS. PostgreSQL and object storage are managed by Supabase; ingress and
monitoring are platform dependencies owned outside this repository.

## Prerequisites

- Linux, Docker Engine, Docker Compose v2, `curl`, and `age`
- external Docker network `traefik-public`
- shared Traefik entrypoints `web` and `websecure` and resolver `letsencrypt`
- private GHCR access and production DNS
- a reachable Prometheus service when the monitoring profile is used

## Configure and validate

```bash
cp .env.example .env
# Replace every placeholder and set an immutable sha-* TAG.
make validate
```

Keep `.env` mode `0600`. Never commit it. The backup encryption identity must
live outside the repository and backup bucket.

## Release

```bash
TAG=sha-a1b2c3d make deploy
make deploy-api
make deploy-web
make health
make rollback
```

`latest` is rejected. A release records the previous application images, runs
forward-compatible migrations, deploys, waits for readiness, and attempts an
application rollback on failure. Database migrations are never automatically
reversed.

Normal production releases run through the GitHub `production` Environment.
Configure required reviewers and `VPS_HOST`, `VPS_PORT`, `VPS_USER`,
`VPS_SSH_KEY`, `VPS_DEPLOY_PATH`, and a read-only `GH_PAT` when required.

## Operations

```bash
make ps
make logs
make maintenance
make maintenance-off
make backup
make backups
make restore
```

Maintenance routing is hostname-scoped and cannot intercept unrelated services
on the shared proxy. Backups are age-encrypted before reaching local disk and
may be copied to a versioned private S3 bucket.

## Documentation

- [Architecture](ARCHITECTURE.md)
- [Security model](docs/security-model.md)
- [Deployment runbook](docs/runbooks/deployment.md)
- [Backup and restore](docs/runbooks/backup-restore.md)
- [Incident response](docs/runbooks/incident-response.md)
- [Architecture decisions](docs/adr/)

The shared proxy contract is documented under `docker/traefik/`; its actual
configuration belongs in the platform repository.
