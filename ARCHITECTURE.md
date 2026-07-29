# Production architecture

## System context

Internet traffic terminates at the server-wide Traefik proxy. Traefik discovers
the web and API containers on the external `traefik-public` network. The web,
API, and Redis services also communicate over the isolated
`claudygod-internal` network. PostgreSQL and SMTP are managed services.

```text
Users -> Traefik/TLS -> Next.js web -> ASP.NET API -> Supabase PostgreSQL
                  \-> ASP.NET API  -> Redis
                                    -> Brevo / Paystack / AIProvider

Operators -> Grafana -> shared Prometheus
GitHub Actions -> SSH deployment -> Docker Compose on production VPS
```

## Trust boundaries

- Only Traefik joins the public ingress path; application ports are not
  published on the host.
- Redis is reachable only from the internal Docker network and requires
  authentication.
- The web-to-API credential is server-side (`INTERNAL_API_KEY`) and must never
  be exposed through a `NEXT_PUBLIC_*` variable.
- Production secrets live in the VPS `.env` and GitHub Environment secrets.
  They are not stored in this repository.
- Containers drop Linux capabilities and disallow privilege escalation. The
  application containers use read-only root filesystems with explicit writable
  mounts.

## Delivery workflow

1. Pull requests run Compose validation, shell parsing, ShellCheck, and a basic
   credential scan.
2. A production deployment is serialized through the GitHub `production`
   environment. Configure required reviewers in repository settings.
3. API deployment pulls the image, runs the one-shot migration, replaces the
   API service, and verifies `/health`.
4. Web deployment replaces only the web service and verifies the public root.
5. Full deployments reconcile all runtime services and remove true orphans.

Prefer immutable image digests or commit-SHA tags in production. `latest` is
convenient but weakens auditability and deterministic rollback.

## Reliability model

- Docker restarts long-running services after process or host failure.
- Redis data, uploads, API logs, and Grafana state use named volumes.
- Database availability and point-in-time recovery are owned by Supabase; local
  logical exports are an additional recovery layer, not a replacement.
- Deployment fails when public health checks do not recover within the timeout.
- Maintenance mode is a high-priority Traefik router returning HTTP 503.

## Operational targets

Initial service-level objectives should be agreed with the product owner:

- Public web availability: 99.9% monthly.
- API availability: 99.9% monthly, measured at `/health`.
- p95 server latency: below 500 ms for non-AI endpoints.
- Recovery point objective: 24 hours until PITR/backup automation is verified.
- Recovery time objective: 2 hours, tested quarterly.

Alert on sustained 5xx rates, endpoint unavailability, certificate expiry,
container restart loops, disk usage above 80%, memory pressure, failed backups,
and failed deployments. Every alert must link to a runbook.

## Improvement roadmap

1. Pin GitHub Actions and container images by digest and enable Dependabot.
2. Add an external uptime monitor and alert routing (email/Slack/PagerDuty).
3. Export application metrics and provision version-controlled Grafana
   dashboards and alerts.
4. Move runtime secrets to Docker secrets or a dedicated secret manager.
5. Add automated restore testing into an isolated Supabase staging project.
6. Move to a managed container platform only when scaling, availability, or
   team-size requirements justify its operational cost.
