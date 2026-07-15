# Reverse Proxy (Planned)

Status: design only; there is no deployable reverse-proxy service in LISA Edge.

A future implementation may provide internal HTTPS and stable names for local
dashboards. Candidate technologies include Caddy, Traefik and Nginx Proxy
Manager, but no choice has been made.

Do not publish administrative dashboards directly to the internet. Use VPN
access and firewall allowlists. Do not add a reverse-proxy key to
`LISA_COMPOSE_SERVICES` until it appears in `./lisa-edge service list`.
