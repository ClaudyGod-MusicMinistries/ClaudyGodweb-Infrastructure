# Security model

## Trust boundaries

- Internet traffic enters only through the separately managed Traefik proxy.
- Redis is attached only to the internal network and uses authentication.
- Application egress and ingress networks are separate.
- Managed PostgreSQL, SMTP, payment, AI, and object-storage services are
  external trust boundaries.
- Production environment files and backup identities are server secrets and
  must be readable only by the deployment account.

## Required controls

- Restrict membership of `traefik-public` to approved workloads.
- Use a non-root deployment account with narrowly scoped Docker access.
- Restrict SSH by firewall, key-only authentication, and GitHub Environment
  approval.
- Rotate service credentials at least quarterly and after any suspected leak.
- Treat `INTERNAL_API_KEY` only as service authentication; every request still
  requires route-level authorization and end-user authorization where relevant.
- The web proxy must allowlist backend routes and must never convert a service
  credential into administrator authorization.
- Store the age backup identity outside the repository and outside the backup
  bucket.

The application repositories must implement route allowlisting, authorization,
metrics endpoints, and safe `/healthz` behavior; those controls cannot be
enforced solely from this infrastructure repository.
