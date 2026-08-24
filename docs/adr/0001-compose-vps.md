# ADR 0001: Retain Docker Compose on one VPS

Status: accepted

The current availability, scale, and team requirements do not justify a
cluster orchestrator. Production will use Docker Compose on a hardened VPS,
managed services for PostgreSQL and object storage, and a separately owned
shared ingress platform.

This decision must be revisited when horizontal host scaling, multi-zone
availability, independent autoscaling, or a larger operations team is required.
