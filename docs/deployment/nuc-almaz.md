# NUC / Almaz deployment

This stack is meant for the existing homelab split: the Go API and PostgreSQL run on the NUC, while Cloudflare and Caddy stay on Almaz and reverse-proxy to the NUC.

## Services

- `postgres` stays on the private Docker network only.
- `api` listens on `:8080` inside Docker and publishes `8080` on the NUC for Almaz to reach.
- Caddy stays on Almaz and proxies the public hostname to the NUC API.

## Environment

Create a private `.env` on the NUC with values like:

```bash
POSTGRES_USER=museum
POSTGRES_PASSWORD=change-me
DATABASE_URL=postgres://museum:change-me@postgres:5432/invisible_museum?sslmode=disable
API_PUBLISHED_ADDR=8080
```

Do not publish the Postgres port. The deployment compose file does not expose it.

## Caddy / Cloudflare

Sample Caddyfile: `backend/deploy/Caddyfile.almaz`

```caddy
museum-api.example.com {
	encode zstd gzip
	reverse_proxy http://nuc.lan:8080
}
```

Replace `nuc.lan` with the NUC hostname or LAN IP reachable from Almaz. Point the Cloudflare DNS/tunnel route for `museum-api.example.com` at Almaz, not directly at the NUC.

## Make commands

From repo root:

```bash
make nuc-up
make nuc-logs
make nuc-smoke
make nuc-rollback
make nuc-down
```

`make nuc-smoke` checks:

- `GET /healthz`
- `GET /api/v1/admin/contributions?status=pending`

## Rollback

Rollback one migration:

```bash
make nuc-rollback
```

If the schema needs a full reset, stop the stack, back up data, then run Goose down/up manually.

## Smoke checks

```bash
curl http://localhost:8080/healthz
curl http://localhost:8080/api/v1/admin/contributions?status=pending
```

From Almaz, verify the upstream before editing the public route:

```bash
curl http://nuc.lan:8080/healthz
```

When going through Caddy/Cloudflare, use the public hostname instead of localhost.
