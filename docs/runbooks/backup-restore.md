# Backup and restore runbook

Install `age`, create an offline identity, store its public recipient in `.env`
as `BACKUP_AGE_RECIPIENT`, and keep its private identity outside the repository.
Schedule `make db-backup` daily using the host service manager. Configure a
versioned, private S3 bucket and alert on job failure or stale backup age.

Quarterly, restore the newest backup into an isolated non-production Supabase
project. Set `BACKUP_AGE_IDENTITY_FILE` and run `make db-restore`. Never test a
restore against production. Record restore duration and verify critical row
counts and application smoke tests.
