# Shared proxy contract

This application does not own the server-wide Traefik deployment. The platform
repository that operates Traefik is authoritative for static configuration,
TLS, access logs, global middleware, and Prometheus scraping.

ClaudyGod requires:

- an external Docker network named `traefik-public`;
- entrypoints named `web` and `websecure`;
- a certificate resolver named `letsencrypt`;
- `exposedByDefault=false` on the Docker provider;
- network isolation preventing untrusted workloads from joining
  `traefik-public`;
- alerting for certificate expiry and proxy routing failures.

Application-specific routing is defined only through labels in the Compose
files. Do not copy shared proxy configuration into this repository.
