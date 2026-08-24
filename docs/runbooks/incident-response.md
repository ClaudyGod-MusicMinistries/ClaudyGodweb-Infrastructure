# Incident response runbook

1. Identify impact from external probes, Traefik metrics, service health, and
   recent deployments.
2. Preserve logs and the current release manifest.
3. If a release caused the incident, run the rollback procedure.
4. Use hostname-scoped maintenance mode only when user safety requires it.
5. Rotate affected credentials and revoke sessions for suspected compromise.
6. Restore data only after confirming corruption or loss and obtaining an
   explicit production change approval.
7. Document timeline, impact, recovery, and preventive actions.
