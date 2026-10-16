# generic-green-blue-deployment — milestone checklist

Stack from `main`. One branch + one commit per milestone. Gates: `bash -n` on all `bin/gb`, `lib/*.sh`, `cmd/*.sh`; run `tests/smoke.sh` when present.

Resume from: M1

## M1 — CLI contract: deploy, revert, contextual `.greenblue`

- [x] Public commands: `deploy`, `revert` (and `config`, `status` for ops). Remove or hide `dev-up`, `install`, `hev-sync`, `hev-render` from primary usage/help (hev may remain as internal phases of deploy).
- [x] Load only `{GB_ROOT}/.greenblue` (not in git). Document `.greenblue.dev.example` / `.greenblue.prod.example` templates; rename `examples/*.greenblue` accordingly.
- [x] Export stable hook env: `GB_ROOT`, `GB_CMD`, `GB_TOOLKIT_ROOT`, slot vars.
- [x] Fix dev pipeline: `GB_HOOK_POST_DEPLOY` must not run for dev-style deploy; use `GB_HOOK_POST_COMMAND` or phase-specific hooks.
- [x] `tests/smoke.sh` + checklist update.

## M2 — HEV: vault context, strict sync, mount map, runtime.env

- [ ] `GB_HEV_VAULT_ROOT` + run vault CLI with correct working directory and relative config when set.
- [ ] `GB_HEV_SYNC_STRICT` default `1`; non-strict only via `.greenblue`.
- [ ] `GB_HEV_MOUNT_MAP` applied before hooks; then `GB_HOOK_HEV_AFTER_RENDER` (optional).
- [ ] Write gitignored `{GB_ROOT}/.gb/runtime.env` from map (+ hook appends); compose documented to use it.
- [ ] Gates + checklist update.

## M3 — Deploy/revert pipeline and install flags

- [ ] `revert`: slot-based using `previous` state file; optional `GB_INSTALL_GIT_REF` via env for SHA revert documented.
- [ ] `GB_INSTALL_REBUILD_SESSIONS`, `GB_INSTALL_RESET_SESSIONS`, `GB_SESSION_REDIS_DB`, `GB_INSTALL_REBUILD_WORKER`; pin deploy sets rebuild worker.
- [ ] Replace hardcoded `gb_ensure_worker` behavior with `GB_HOOK_ENSURE_WORKER` defaulting to current behavior.
- [ ] `GB_HOOK_ENSURE_SESSIONS` optional override.
- [ ] Gates + checklist update.

## M4 — Docs and operator UX

- [ ] README: `/var/gb/.../bin/gb /var/www/app deploy|revert`; `.greenblue` like `.env`, not committed.
- [ ] `.gitignore` in toolkit for nothing sensitive; document target `.gb/` gitignore in README for app admins.
- [ ] Gates + checklist update.
