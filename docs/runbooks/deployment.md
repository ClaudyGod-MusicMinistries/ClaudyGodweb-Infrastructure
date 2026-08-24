# Deployment and rollback runbook

Deploy an immutable release with `TAG=sha-<commit> make deploy`. Targeted
releases use `make deploy-api` or `make deploy-web`. Use the GitHub
production environment for normal releases and require an approving reviewer.

The release script saves previous application images under `.releases/`, runs
forward-compatible migrations, reconciles services, and waits up to two minutes
for public readiness. Failed readiness triggers application rollback.

For a manual rollback, run `make rollback` and type `ROLLBACK`. This restores
the prior API and web images only. Investigate migration compatibility before
rolling back across a schema change.
