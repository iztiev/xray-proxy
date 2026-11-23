# Templates

Source files for the stack. `install.sh` (repo root) renders them on the server by
replacing every `{{NAME}}` literally. Templates are committed; rendered files are secret.

| Template | Rendered to (next to `install.sh`) | Notes |
|---|---|---|
| `.env.template` | `.env` | Secrets and settings read by compose. Values single-quoted (literal, no `$` interpolation). |
| `compose.yml` | `compose.yml` | No `{{}}` vars; reads `${…}` from `.env` at runtime |
| `Caddyfile` | `Caddyfile` | No `{{}}` vars; reads `{$…}` env from compose |
| `xray/server.json` | `xray/server.json` | Server inbound |
| `xray/client.json` | `clients/<email>.config.json` | xray-core client, one per client; copy to Windows |

`install.sh` also writes `clients/<email>.link.txt`, a `vless://` share link for
v2rayN / v2rayNG import.

Three syntaxes, do not mix them up:
- `{{NAME}}` — install-time, filled by `install.sh`.
- `${NAME}` — compose runtime, from `.env`.
- `{$NAME}` — Caddy runtime, from the container environment.

## Variables

| Variable | Used in | Source in `install.sh` |
|---|---|---|
| `DOMAIN` | `.env`, `xray/server.json`, `xray/client.json` | prompt. Website hostname = REALITY serverName = client SNI. |
| `ACME_EMAIL` | `.env` | prompt (the email) |
| `ADMIN_EMAIL` | `.env` | prompt (same email): website admin login |
| `ADMIN_PASSWORD` | `.env` | prompt (hidden, min 8 chars, no `'`) |
| `JWT_PRIVATE_KEY` | `.env` | `openssl rand -hex 32` (64 hex chars) |
| `DB_PASSWORD` | `.env` | `openssl rand -hex 32` |
| `MYSQL_ROOT_PASSWORD` | `.env` | `openssl rand -hex 32` |
| `REALITY_PRIVATE_KEY` | `xray/server.json` | `xray x25519` → `PrivateKey` (x25519, always 43 chars) |
| `REALITY_PUBLIC_KEY` | `xray/client.json` | same run → `Password` (public key) |
| `XRAY_CLIENTS` | `xray/server.json` | raw JSON array: `[{"id": "<uuid>", "flow": "xtls-rprx-vision", "email": "<email>"}]` |
| `XRAY_SHORT_IDS` | `xray/server.json` | raw JSON array: `["<hex>"]` |
| `CLIENT_EMAIL` | `xray/client.json` | the email (first client) |
| `CLIENT_UUID` | `xray/client.json` | `/proc/sys/kernel/random/uuid` |
| `CLIENT_SHORT_ID` | `xray/client.json` | `openssl rand -hex 8` |
| `CLIENT_SOCKS_PORT` | `xray/client.json` | `10808` |
| `CLIENT_HTTP_PORT` | `xray/client.json` | `10809` |

The website runs in UTC (`TIME_ZONE: UTC` hardcoded in compose; it only affects how
the web UI shows timestamps).

## Rendering rules

- Literal replacement; output is LF, UTF-8 without BOM.
- Any `{{…}}` left after rendering is a hard error.
- Validated with `docker compose config -q` and `xray run -test` (server and client).
