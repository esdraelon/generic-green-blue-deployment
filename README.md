# generic-green-blue-deployment

Reusable deployment primitives for ORK-family apps: **dev** (bind-mounted source) and **production blue-green** (code baked into the image, host nginx reverse proxy), driven by a per-repo `.greenblue` file.

Check this repository out once, add `bin/gb` to your `PATH`, and point it at any project that provides `.greenblue`, Docker compose overlays, and (optionally) [host-env-vault](https://github.com/your-org/host-env-vault) profiles.

## Quick start

```bash
export PATH="/path/to/generic-green-blue-deployment/bin:$PATH"

# One-time per app: copy an example config
cp /path/to/generic-green-blue-deployment/examples/amtgard-denarius.greenblue \
   /path/to/amtgard-denarius/.greenblue

# Local secrets (shared vault on your laptop)
export HOST_ENV_VAULT_CONFIG="/path/to/host-env-vault/dev-shared/host-config.toml"

gb /path/to/amtgard-denarius dev-up
gb /path/to/amtgard-denarius deploy    # production host; needs sudo for nginx
gb /path/to/amtgard-denarius status
```

Alternatively set `GB_PROJECT_ROOT` and omit the path:

```bash
export GB_PROJECT_ROOT=/path/to/amtgard-denarius
gb dev-up
```

## `.greenblue` contract

`.greenblue` is a **bash snippet** at the application repository root. It is sourced by `gb`; use `GB_*` variables (legacy names from existing `install.sh` / `dev-up.sh` still work — see `lib/load-config.sh`).

| Area | Key variables |
| --- | --- |
| Identity | `GB_PROJECT_NAME`, `GB_CONTAINER_APP_DIR`, `GB_COMPOSE_SERVICE` or `GB_COMPOSE_SERVICE_PATTERN` |
| Slots | `GB_BLUE_*` / `GB_GREEN_*` containers and ports, `GB_LEGACY_CONTAINER` for first bootstrap |
| Compose | `GB_WEB_COMPOSE_BASE`, `GB_WEB_COMPOSE_SLOT` (`%slot%`), `GB_WEB_COMPOSE_DEV`, stack lists `GB_DEV_STACKS`, `GB_DEPLOY_STACKS` |
| Shared infra | `GB_SHARED_NETWORK`, sessions/worker compose file lists |
| Nginx | `GB_NGINX_STRATEGY`: `site-file` (denarius/idp) or `ork3-color-symlink` |
| State | `GB_STATE_DIR` → `active` / `previous` slot files |
| App install | `GB_APP_INSTALL=composer-phinx` or `none`; override with `GB_HOOK_INSTALL_APP` |
| Hooks | `GB_HOOK_PRE_DEPLOY`, `GB_HOOK_AFTER_SLOT_UP`, `GB_HOOK_AFTER_SLOT_HEALTH`, `GB_HOOK_POST_DEPLOY` |
| Git | `GB_GIT_BRANCH`, `GB_INSTALL_SKIP_GIT_PULL`, pin with `GB_INSTALL_GIT_REF` |
| host-env-vault | `GB_HEV_PROFILES`, `GB_HEV_RENDER_ROOT`, `HOST_ENV_VAULT_CONFIG`, sync/render flags |

Examples for **amtgard-denarius**, **amtgard-idp**, and **ORK3** live under `examples/`.

## Commands

| Command | Purpose |
| --- | --- |
| `dev-up` | Start dev stacks (`GB_DEV_STACKS`: typically `sessions`, `web`, `worker`). Web uses prod + slot + **dev** overlay so the repo is bind-mounted. |
| `deploy` | Fetch/pull (unless skipped), optional HEV sync/render, ensure sessions, build **inactive** slot, install app, health-check, switch nginx, update state. |
| `status` | Print active/previous slot from `GB_STATE_DIR`. |
| `hev-sync` | `host-env-vault sync` using `HOST_ENV_VAULT_CONFIG` / CLI defaults. |
| `hev-render` | Render one profile or all in `GB_HEV_PROFILES` to `GB_HEV_RENDER_ROOT/<profile>/current`. |
| `config` | Dump resolved settings (debug). |

Pinned rollback (same as legacy `install.sh`):

```bash
GB_INSTALL_GIT_REF=9f3c1ab gb /path/to/app deploy
```

## host-env-vault

Designed to work with the **shared local dev** layout (`dev-shared/host-config.toml`, `scripts/local-shared-sync.sh`) and production `/etc/host-env-vault/config.toml`.

- Set `HOST_ENV_VAULT_CONFIG` to your TOML path.
- List profiles in `GB_HEV_PROFILES` (must match catalog profile names, e.g. `denarius-web`).
- Mount rendered trees in compose: `.../run/<profile>/current:/secrets:ro` (see host-env-vault README).
- `GB_HEV_SYNC_SOURCE=local` for laptop dev; omit on production hosts using SSM.
- `GB_HEV_REPO` or sibling `../host-env-vault` is used to build the binary if `host-env-vault` is not on `PATH`.

## How this maps to existing apps

| App | Today | With `gb` |
| --- | --- | --- |
| amtgard-denarius | `scripts/dev-up.sh`, `install.sh` | `.greenblue` + optional thin `install.sh` calling `gb deploy` |
| amtgard-idp | same pattern | same |
| ORK3 | `greenblue.sh` + color nginx symlinks | `examples/ork3.greenblue` + small hooks for ORK-specific compose service names |

Production behavior intentionally mirrors denarius `install.sh`: build inactive slot, composer + phinx inside the new container, health check on the slot port, copy `host/nginx.<slot>.conf` into sites-available/enabled, track active slot under `/var/lib/...`.

## Layout

```text
bin/gb              CLI entry
lib/                Config, compose, slots, nginx, git, health, hev
cmd/                dev-up, deploy, status, hev
examples/           Sample .greenblue files and hooks
```

## Requirements

- bash 3.2+ (macOS default), `docker` / `docker compose`, `curl`
- Production deploy: `sudo` or root for nginx and `/var/lib` state (unless `GB_STATE_DIR` is under the repo)
- Optional: `git`, `host-env-vault`, `cargo` (to build vault from source)
