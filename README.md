# generic-green-blue-deployment

Reusable bash toolkit for containerized web apps: **dev** (bind-mounted source) and **production blue-green** (image-based deploy, host nginx), configured per application via a `.greenblue` file at the app root — the same role as `.env`: **local operator config, never committed**.

## Install the toolkit (once)

Clone this repository to a fixed path on each deploy host (or your laptop for dev). Operators invoke `gb` by absolute path; you do not need to add it to `PATH`.

```bash
sudo mkdir -p /var/gb
sudo git clone https://github.com/your-org/generic-green-blue-deployment.git \
  /var/gb/generic-green-blue-deployment
```

Alternative layout (single user / dev machine):

```bash
git clone https://github.com/your-org/generic-green-blue-deployment.git ~/greenblue
```

Set `GB_TOOLKIT_ROOT` only if you use `--toolkit` or symlink multiple checkouts; the default is the directory containing the `bin/gb` you execute.

## Configure each application

On the **application** repository root (e.g. `/var/www/my-app`), create `.greenblue` from a template — do **not** commit it:

```bash
cp /var/gb/generic-green-blue-deployment/examples/.greenblue.dev.example \
   /var/www/my-app/.greenblue
# edit compose paths, ports, container names, hooks
```

Production:

```bash
cp /var/gb/generic-green-blue-deployment/examples/.greenblue.prod.example \
   /var/www/my-app/.greenblue
```

Other shaped templates live under `examples/` (multi-stack, nginx `color-symlink`, sample hooks).

Recommended **application** `.gitignore` entries (secrets, slot state, HEV runtime wiring):

```gitignore
.greenblue
.gb/
```

The toolkit writes `{app-root}/.gb/runtime.env` during deploy when HEV mount maps or hooks set deployment wiring variables. That file is for `docker compose --env-file` — not application `.env`. Treat `.gb/` like local runtime state.

Optional convenience on a host that always deploys one app:

```bash
export GB_PROJECT_ROOT=/var/www/my-app
/var/gb/generic-green-blue-deployment/bin/gb deploy
/var/gb/generic-green-blue-deployment/bin/gb revert
```

## Day-to-day commands

Primary interface:

```bash
/var/gb/generic-green-blue-deployment/bin/gb /var/www/my-app deploy
/var/gb/generic-green-blue-deployment/bin/gb /var/www/my-app revert
/var/gb/generic-green-blue-deployment/bin/gb /var/www/my-app status
```

Production with host-env-vault:

```bash
/var/gb/generic-green-blue-deployment/bin/gb \
  --hev-config /etc/host-env-vault/config.toml \
  /var/www/my-app deploy
```

Pinned prod deploy (also enables worker image rebuild for that deploy):

```bash
GB_INSTALL_GIT_REF=9f3c1ab \
  /var/gb/generic-green-blue-deployment/bin/gb /var/www/my-app deploy
```

Fast traffic rollback vs redeploying a pinned commit:

```bash
# Switch nginx back to the last active slot (no git pull, no slot rebuild)
/var/gb/generic-green-blue-deployment/bin/gb /var/www/my-app revert

# Deploy a specific SHA onto the inactive slot, then cut over
GB_INSTALL_GIT_REF=9f3c1ab /var/gb/generic-green-blue-deployment/bin/gb /var/www/my-app deploy
```

| Command | Purpose |
| --- | --- |
| `deploy` | **Dev** (`GB_MODE=dev`): start dev stacks (`GB_DEV_STACKS`). **Prod** (`GB_MODE=prod`): fetch/pull, optional HEV sync/render, blue-green slot deploy, nginx switch. |
| `revert` | Prod only: point host nginx at the **previous** slot from `GB_STATE_DIR/previous` (containers stay up; active/previous state files are swapped). |
| `status` | Print active/previous slot from `GB_STATE_DIR`. |
| `config` | Dump resolved settings (debug). |

## `.greenblue` contract

`.greenblue` is a **bash snippet** at `{project-root}/.greenblue` only. It is sourced by `gb`; use `GB_*` variables (shorter legacy names from older per-app install scripts still work — see `lib/load-config.sh`).

| Area | Key variables |
| --- | --- |
| Mode | `GB_MODE=dev` or `GB_MODE=prod` (if unset: prod when `GB_WEB_COMPOSE_BASE` exists, else dev) |
| Identity | `GB_PROJECT_NAME`, `GB_CONTAINER_APP_DIR`, `GB_COMPOSE_SERVICE` or `GB_COMPOSE_SERVICE_PATTERN` |
| Slots | `GB_BLUE_*` / `GB_GREEN_*` containers and ports, `GB_LEGACY_CONTAINER` for first bootstrap |
| Compose | `GB_WEB_COMPOSE_BASE`, `GB_WEB_COMPOSE_SLOT` (`%slot%`), `GB_WEB_COMPOSE_DEV`, stack lists `GB_DEV_STACKS`, `GB_DEPLOY_STACKS` |
| Shared infra | `GB_SHARED_NETWORK`, sessions/worker compose file lists |
| Nginx | `GB_NGINX_STRATEGY`: `site-file` or `color-symlink` |
| State | `GB_STATE_DIR` → `active` / `previous` slot files (often under `{GB_ROOT}/.gb/state`) |
| App install | `GB_APP_INSTALL=composer-phinx` or `none`; override with `GB_HOOK_INSTALL_APP` |
| Install flags | `GB_INSTALL_REBUILD_SESSIONS`, `GB_INSTALL_RESET_SESSIONS` (Redis `FLUSHDB`), `GB_SESSION_REDIS_DB`, `GB_INSTALL_REBUILD_WORKER` (auto `1` when `GB_INSTALL_GIT_REF` is set on deploy) |
| Hooks | `GB_HOOK_PRE_DEPLOY`, `GB_HOOK_AFTER_SLOT_UP`, `GB_HOOK_AFTER_SLOT_HEALTH`, `GB_HOOK_HEV_AFTER_RENDER`, `GB_HOOK_ENSURE_SESSIONS`, `GB_HOOK_ENSURE_WORKER`, `GB_HOOK_POST_DEPLOY` (prod deploy), `GB_HOOK_POST_COMMAND` (dev deploy) |
| Git | `GB_GIT_BRANCH`, `GB_INSTALL_SKIP_GIT_PULL`, pin with `GB_INSTALL_GIT_REF` |
| host-env-vault | `GB_HEV_PROFILES`, `GB_HEV_RENDER_ROOT`, `GB_HEV_VAULT_ROOT`, `GB_HEV_CONFIG`, `GB_HEV_SYNC_STRICT`, `GB_HEV_MOUNT_MAP`, sync/render flags |
| Deploy wiring | `GB_RUNTIME_ENV_FILE` (default `{GB_ROOT}/.gb/runtime.env`) |

Templates (copy to your app as `.greenblue`, do not commit):

- `examples/.greenblue.dev.example`
- `examples/.greenblue.prod.example`
- `examples/.greenblue.prod.multi-stack.example`
- `examples/.greenblue.prod.nginx-color-symlink.example`

Hooks receive `GB_ROOT`, `GB_CMD`, `GB_TOOLKIT_ROOT`, and slot variables in the environment.

## host-env-vault

Pass the vault TOML on the command line (recommended):

```bash
/var/gb/generic-green-blue-deployment/bin/gb \
  --hev-config /etc/host-env-vault/config.toml \
  /var/www/my-app deploy
```

You may also set `GB_HEV_CONFIG` in `.greenblue` as a project default; `--hev-config` overrides it.

- **`GB_HEV_VAULT_ROOT`**: directory used as the working directory when invoking `host-env-vault` (`cd` into the vault tree). Defaults to the directory containing `GB_HEV_CONFIG` when unset. When the config file lives under that root, `--config` is passed as a path relative to the vault root.
- List profiles in `GB_HEV_PROFILES` (must match catalog profile names).
- After `render`, inject secrets appear as `secrets.env` under `<profile>/current/`; mount that directory in compose (see host-env-vault docs).
- **`GB_HEV_SYNC_STRICT`**: defaults to `1`. Sync/render failures abort the deploy; set `GB_HEV_SYNC_STRICT=0` in `.greenblue` to log and continue.
- **`GB_HEV_MOUNT_MAP`**: space-separated entries mapping rendered profiles to host env vars (and optional compose mount hints). Each entry is `profile:ENV_VAR` or `profile:ENV_VAR:container_path`. After render, the toolkit sets `ENV_VAR` to the absolute host path of `{render_root}/{profile}/current` and writes the same `KEY=value` lines to `{GB_ROOT}/.gb/runtime.env`. Mount map runs before the optional `GB_HOOK_HEV_AFTER_RENDER` hook.
- **`GB_RUNTIME_ENV_FILE`**: deployment wiring only (not application `.env`). Hooks may append lines, e.g. `echo 'EXTRA=value' >> "$GB_RUNTIME_ENV_FILE"`.
- `docker compose` is invoked with `--env-file` pointing at `GB_RUNTIME_ENV_FILE` when that file exists, so compose can reference mount-map variables.
- `GB_HEV_SYNC_SOURCE=local` for offline/dev sync; omit on hosts using SSM.
- Optional `GB_HEV_BIN` or `GB_HEV_REPO` in `.greenblue` if the binary is not on `PATH`.
- HEV sync/render runs inside `deploy` when enabled in `.greenblue` (`GB_HEV_SYNC_ON_DEPLOY`, `GB_HEV_RENDER_ON_DEPLOY`, and dev-mode `GB_HEV_*_ON_DEV_UP` flags).

## Production deploy flow

Build the **inactive** slot, run the configured install step (default: composer + phinx in the new container), health-check the slot port, activate nginx (`site-file` copies `host/nginx.<slot>.conf`, or `color-symlink` flips `sites-enabled/default`), and record the active slot under `GB_STATE_DIR`. The previously active slot is left running for rollback unless your hooks remove it.

## Layout

```text
bin/gb              CLI entry (invoke by absolute path)
lib/                Config, compose, slots, nginx, git, health, hev
cmd/                deploy, revert, status, internal deploy helpers
examples/           Sample .greenblue templates and hooks
tests/smoke.sh      Minimal CLI smoke test
```

## Requirements

- bash 3.2+ (macOS default), `docker` / `docker compose`, `curl`
- Production deploy: `sudo` or root for nginx and system state dirs (unless `GB_STATE_DIR` is under the repo)
- Optional: `git`, `host-env-vault`, `cargo` (only if building vault from `GB_HEV_REPO`)
