# generic-green-blue-deployment

Reusable deployment primitives for containerized web apps: **dev** (bind-mounted source) and **production blue-green** (code baked into the image, host nginx reverse proxy), driven by a per-repo `.greenblue` file.

Check this repository out once, add `bin/gb` to your `PATH`, and point it at any project that provides `.greenblue`, Docker compose overlays, and (optionally) host-env-vault profiles.

## Quick start

```bash
export PATH="/path/to/generic-green-blue-deployment/bin:$PATH"

cp /path/to/generic-green-blue-deployment/examples/minimal.greenblue \
   /path/to/my-app/.greenblue
# edit .greenblue for your compose paths, ports, and names

gb /path/to/my-app dev-up
gb --hev-config /path/to/vault/host-config.toml /path/to/my-app deploy
gb /path/to/my-app status
```

With a default project directory:

```bash
export GB_PROJECT_ROOT=/path/to/my-app
gb dev-up
gb --hev-config /path/to/vault/host-config.toml deploy
```

## `.greenblue` contract

`.greenblue` is a **bash snippet** at the application repository root. It is sourced by `gb`; use `GB_*` variables (shorter legacy names from older per-app install scripts still work — see `lib/load-config.sh`).

| Area | Key variables |
| --- | --- |
| Identity | `GB_PROJECT_NAME`, `GB_CONTAINER_APP_DIR`, `GB_COMPOSE_SERVICE` or `GB_COMPOSE_SERVICE_PATTERN` |
| Slots | `GB_BLUE_*` / `GB_GREEN_*` containers and ports, `GB_LEGACY_CONTAINER` for first bootstrap |
| Compose | `GB_WEB_COMPOSE_BASE`, `GB_WEB_COMPOSE_SLOT` (`%slot%`), `GB_WEB_COMPOSE_DEV`, stack lists `GB_DEV_STACKS`, `GB_DEPLOY_STACKS` |
| Shared infra | `GB_SHARED_NETWORK`, sessions/worker compose file lists |
| Nginx | `GB_NGINX_STRATEGY`: `site-file` or `color-symlink` |
| State | `GB_STATE_DIR` → `active` / `previous` slot files |
| App install | `GB_APP_INSTALL=composer-phinx` or `none`; override with `GB_HOOK_INSTALL_APP` |
| Hooks | `GB_HOOK_PRE_DEPLOY`, `GB_HOOK_AFTER_SLOT_UP`, `GB_HOOK_AFTER_SLOT_HEALTH`, `GB_HOOK_POST_DEPLOY` |
| Git | `GB_GIT_BRANCH`, `GB_INSTALL_SKIP_GIT_PULL`, pin with `GB_INSTALL_GIT_REF` |
| host-env-vault | `GB_HEV_PROFILES`, `GB_HEV_RENDER_ROOT`, optional default `GB_HEV_CONFIG`, sync/render flags |

Templates live under `examples/` (`minimal`, `multi-stack`, `nginx-color-symlink`).

## Commands

| Command | Purpose |
| --- | --- |
| `dev-up` | Start dev stacks (`GB_DEV_STACKS`: e.g. `sessions`, `web`, `worker`). Web uses prod + slot + **dev** overlay so the repo is bind-mounted. |
| `deploy` | Fetch/pull (unless skipped), optional HEV sync/render, ensure sessions, build **inactive** slot, install app, health-check, switch nginx, update state. |
| `status` | Print active/previous slot from `GB_STATE_DIR`. |
| `hev-sync` | `host-env-vault sync` using `--hev-config` or `GB_HEV_CONFIG`. |
| `hev-render` | Render one profile or all in `GB_HEV_PROFILES` to `GB_HEV_RENDER_ROOT/<profile>/current`. |
| `config` | Dump resolved settings (debug). |

Pinned rollback:

```bash
GB_INSTALL_GIT_REF=9f3c1ab gb --hev-config /path/to/vault/host-config.toml /path/to/my-app deploy
```

## host-env-vault

Pass the vault TOML on the command line (recommended):

```bash
gb --hev-config /etc/host-env-vault/config.toml /path/to/my-app hev-sync
gb --hev-config /path/to/dev-shared/host-config.toml /path/to/my-app hev-render app-web
```

You may also set `GB_HEV_CONFIG` in `.greenblue` as a project default; `--hev-config` overrides it.

- List profiles in `GB_HEV_PROFILES` (must match catalog profile names).
- After `render`, inject secrets appear as `secrets.env` under `<profile>/current/`; mount that directory in compose (see host-env-vault docs).
- `GB_HEV_SYNC_SOURCE=local` for offline/dev sync; omit on hosts using SSM.
- Optional `GB_HEV_BIN` or `GB_HEV_REPO` in `.greenblue` if the binary is not on `PATH`.

## Production deploy flow

Build the **inactive** slot, run the configured install step (default: composer + phinx in the new container), health-check the slot port, activate nginx (`site-file` copies `host/nginx.<slot>.conf`, or `color-symlink` flips `sites-enabled/default`), and record the active slot under `GB_STATE_DIR`. The previously active slot is left running for rollback unless your hooks remove it.

## Layout

```text
bin/gb              CLI entry
lib/                Config, compose, slots, nginx, git, health, hev
cmd/                dev-up, deploy, status, hev
examples/           Sample .greenblue files and hooks
```

## Requirements

- bash 3.2+ (macOS default), `docker` / `docker compose`, `curl`
- Production deploy: `sudo` or root for nginx and system state dirs (unless `GB_STATE_DIR` is under the repo)
- Optional: `git`, `host-env-vault`, `cargo` (only if building vault from `GB_HEV_REPO`)
