# Production architecture

## System context

```text
Internet -> shared Traefik/TLS -> Next.js web -> ASP.NET API
                              \-> ASP.NET API -> Supabase PostgreSQL
                                                Redis
                                                Supabase object storage
                                                SMTP / payment / AI providers

Operators -> external monitoring platform -> Grafana / Prometheus / alerts
GitHub Actions -> SSH -> canonical release script -> Docker Compose VPS
```

The platform repository owns the host baseline, firewall, shared ingress,
Prometheus, alert routing, and external probes. This repository owns only the
ClaudyGod services, application routing labels, release automation, encrypted
logical backups, and runbooks.

## Network boundaries

- `traefik-public` is an externally managed ingress network.
- `claudygod-internal` is internal-only and carries web/API/Redis traffic.
- `claudygod-egress` gives API and migration workloads external connectivity
  without attaching migrations to ingress or host networking.
- No application port is published on the host.

Only trusted workloads may join the shared ingress network. The web-to-API
credential authenticates the service, not the end user, and cannot replace
normal authorization.

## Reliability and delivery

- Production uses immutable `sha-*` application tags.
- Deployments are serialized and approved through a GitHub Environment.
- API migrations use the expand/contract pattern.
- Container and public readiness checks gate releases.
- Previous application versions are recorded and restored after failed
  readiness checks.
- Redis uses `noeviction` because it stores sessions as well as cache data.
- Managed database recovery is primary; encrypted logical exports provide an
  independently portable recovery layer.

## Service objectives

- Web and API monthly availability: 99.9%.
- Non-AI API p95 latency: below 500 ms.
- Database RPO: 24 hours until managed PITR is contractually verified.
- Service RTO: 2 hours, tested quarterly.

Alert on external endpoint failure, sustained 5xx responses, latency SLO burn,
certificate expiry, container restart loops, disk or memory pressure, backup
failure or staleness, and failed releases. Every alert must link to a runbook.

## Remaining platform obligations

The following cannot be completed inside this application repository and must
be enforced by the platform and application repositories:

- VPS provisioning, firewall, SSH hardening, Docker updates, and scheduled jobs
- shared Traefik and Prometheus deployment, dashboards, alerts, and log storage
- SSO or private-network protection for Grafana
- backend route allowlisting, end-user authorization, metrics, and distinct
  liveness/readiness endpoints
- repository/environment branch protection and required reviewers
- managed-service PITR policy and bucket immutability

These are deployment prerequisites, not optional future architecture.
