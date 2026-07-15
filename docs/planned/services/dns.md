# DNS Helpers (Planned)

Status: design only; there is no deployable LISA Edge DNS service yet.

The intended role is lightweight local resolution for names such as
`mqtt.home.arpa` and `lisa-edge.home.arpa`. Prefer the existing gateway or DNS
server as the source of truth unless operating DNS on the edge host is an
explicit site decision.

Do not add `dns` to `LISA_COMPOSE_SERVICES`; it is not a registered selection
key. A future implementation must add a service owner under `services/`,
register the key, add provisioning and health checks, and then move this page
to `docs/services/`.
