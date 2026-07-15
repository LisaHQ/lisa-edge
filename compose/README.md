# Compose

LISA Edge uses a small base Compose file plus one fragment per optional service.
The base `docker-compose.yml` is intentionally empty; `scripts/lib/compose.sh`
builds the final `docker compose -f ...` argument list from
`LISA_COMPOSE_SERVICES`.

Service fragments live in `services/` and are named after their selection key,
for example `mqtt.yml` and `uptime-kuma.yml`.

When adding a service:

1. Add `services/<service>.yml`.
2. Register the service and any dependency in `scripts/lib/compose.sh`.
3. Add its environment defaults to `.env.template`.
4. Add a matching provisioning module under `provisioning/services/` when user
   input is required.
5. Add service-selection and image-policy coverage under `test/unit/`.
6. Document the service under `docs/services/`.

Validate all selected fragments with:

```bash
bash tools/validate-compose.sh
```
