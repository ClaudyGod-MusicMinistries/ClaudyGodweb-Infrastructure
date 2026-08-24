# ADR 0002: Immutable releases and expand/contract migrations

Status: accepted

Production accepts only `sha-*` image tags. The release process records the
previous application images, deploys, checks readiness, and restores those
images if readiness fails.

Database migrations are forward-only and use expand/contract sequencing:

1. Add backward-compatible schema.
2. Deploy code that can use both schemas.
3. Backfill and verify data.
4. Remove obsolete schema in a later release.

Automatic application rollback never reverses a database migration.
