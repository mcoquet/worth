# Worth Desktop Distribution — Implementation Plan

**Status:** IN PROGRESS
**Source:** Revised from `tauri-desktop-app.md` proposal
**Estimate:** 10-15 days

## Key Decisions

- **Git deps with tags** for `agent_ex` and `mneme` — keeps them in sync across all projects that use them
- **libSQL only** for the desktop build — no database server to bundle, single file at `~/.worth/worth.db`
- **PostgreSQL support** stays available for server deployments (postgrex stays in the release binary but is not used at runtime)
- **Feature-flagged** via `WORTH_DESKTOP=1` env var — web/CLI path is untouched
- **Direct TCP coordination** between Rust and Elixir (simpler than ElixirKit — Rust finds a port, spawns OTP, polls until HTTP responds)

---

## Phase 0: Prerequisites

### 0.1 Convert `agent_ex` and `mneme` to git dependencies
- [x] Verify git repos have tags (`agent_ex` → `v0.1.1`, `mneme` → `v0.2.0`)
- [x] Push tags to remote (`git push origin v0.x.x` in each repo)
- [x] Update `mix.exs` to use `git:` + `tag:` instead of `path:`
- [x] Add `override: true` on mneme dep (agent_ex also depends on mneme via path)
- [x] Verify `mix deps.get` and `mix compile` still work

### 0.2 Add release configuration
- [x] Add `:releases` key to `mix.exs` (worth + desktop release configs)
- [x] Create `rel/env.sh.eex` with desktop-specific env vars
- [x] Create `rel/vm.args.eex` (minimal, no distribution)
- [x] Move mneme anonymous function config to module capture (`&Worth.Memory.Embeddings.Adapter.credentials/0`)
- [x] Verify `MIX_ENV=prod mix release worth` produces artifact (92MB)

### 0.3 Desktop-specific runtime config
- [x] Rewrite `config/runtime.exs` with `WORTH_DESKTOP=1` branch
- [x] Desktop: bind to `127.0.0.1`, auto-generate `SECRET_KEY_BASE`, `server: true`
- [x] Server: existing `0.0.0.0` bind + required `SECRET_KEY_BASE` env var

### 0.4 Refactor CLI to separate server start from browser open
- [x] Create `lib/worth/boot.ex` — `Worth.Boot.run/1` starts app and returns URL
- [x] Add `--no-open` / `-n` flag to CLI
- [x] `Worth.CLI` calls `Worth.Boot` then conditionally opens browser

### 0.5 Auto-migrate on boot for libSQL
- [x] `Worth.Boot.run_migrations!/0` runs `Ecto.Migrator.run` when `WORTH_DESKTOP=1` or `WORTH_AUTO_MIGRATE=1`
- [x] Creates `~/.worth/` directory and DB file path on boot

### 0.6 PostgreSQL deps in desktop release
- [x] Kept postgrex in release (transitive dep from ash_postgres/ecto_libsql, can't cleanly remove)
- [x] Desktop release forces `WORTH_DATABASE_BACKEND=libsql` via env.sh — postgrex code is dead weight but harmless

---

## Phase 1: OTP Release Validation
- [x] Build: `MIX_ENV=prod mix release worth --overwrite` succeeds
- [x] Release size: 92MB uncompressed
- [x] env.sh correctly generated with desktop mode branching
- [ ] Start release on clean machine / Docker (no Elixir, no PostgreSQL) — manual test needed

---

## Phase 2: Tauri Scaffold + Integration

### 2.1 Project structure
- [x] Create `rel/desktop/` directory
- [x] Create `rel/desktop/src-tauri/Cargo.toml` with deps
- [x] Create `rel/desktop/src-tauri/tauri.conf.json`
- [x] Create `rel/desktop/src-tauri/splash.html`
- [x] Create `rel/desktop/src-tauri/build.rs`
- [x] Create `rel/desktop/src-tauri/icons/` (placeholder)

### 2.2 Rust side (`src-tauri/src/`)
- [x] `main.rs` — entry point
- [x] `lib.rs` — OTP lifecycle: find port, spawn release, splash → main window, tray menu
- [x] System tray (Open / Quit)
- [x] Single instance enforcement (`tauri-plugin-single-instance`)
- [x] Graceful shutdown (kill OTP child on exit)
- [x] TCP PubSub server (starts listener, passes `WORTH_PUBSUB` to OTP, receives `ready`/`shutdown` frames)
- [x] Crash reporter (show dialog on OTP crash or startup timeout)
- [x] Window close hides to tray (OTP keeps running)
- [x] App compiles and launches successfully — web UI loads in Tauri window
- [x] Auto-migrations run on first boot (libSQL)
- [x] Added missing `workspace_index_entries` migration
- [x] Fixed `EmbeddingModelIdAnd1536Dim` migration for libSQL adapter check

### 2.3 Elixir side (`lib/worth/desktop/`)
- [x] `bridge.ex` — TCP PubSub client (connects to `WORTH_PUBSUB` env var)
- [x] Broadcasts `ready:<url>` after endpoint starts
- [x] Listens for `quit` → `System.stop()`
- [x] Broadcasts `shutdown` on application stop
- [x] Hooked into supervision tree (only starts when `WORTH_DESKTOP=1`)
- [x] Connection retry loop (30 retries, 1s interval)
- [x] Frame buffering for partial TCP reads

### 2.4 Build orchestration
- [x] Create `rel/desktop/tauri.sh` build script
- [x] Subcommands: `release`, `tauri`, `build`, `dev`
- [x] `tauri_build` copies OTP release into `src-tauri/rel/` for Tauri resource bundling
- [x] `tauri.conf.json` resources config bundles `rel/**/*`
- [x] End-to-end build tested successfully (Linux x86_64)

---

## Phase 3: Build Pipeline + CI
- [ ] GitHub Actions workflow for 4 platforms
- [ ] macOS ARM64 (`.dmg`, `.app`)
- [ ] macOS x86_64 (`.dmg`, `.app`)
- [ ] Linux x86_64 (`.AppImage`, `.deb`)
- [ ] Windows x86_64 (`.exe` NSIS installer)
- [ ] Upload artifacts to GitHub Releases
- [ ] No PostgreSQL needed in CI (libSQL is embedded)

---

## Phase 4: Polish
- [x] App icons: hand-crafted SVG with stylized W + blue-purple gradient, converted to `.icns` (290KB), `.ico` (335KB), `.png` (32/128/256/512)
- [x] Slogan: "Your ideas are WORTH more" — added to splash screen, empty chat state, CLI help
- [x] System tray menu (Open Worth, Quit) — Rust side done
- [x] Single instance enforcement (`tauri-plugin-single-instance`) — Rust side done
- [x] Window close → hide to tray, tray Quit → full shutdown
- [ ] Auto-update setup (`tauri-plugin-updater`, defer code signing)
- [ ] Deep linking (`worth://` URL scheme) — optional

---

## Phase 5: Distribution
- [ ] GitHub Releases with platform artifacts
- [ ] Linux install script (`curl | chmod`)
- [ ] Homebrew Cask (macOS) — later
- [ ] Windows installer signing — later

---

## Files Changed

| File | Action |
|------|--------|
| `mix.exs` | Updated: git deps, releases config |
| `config/config.exs` | Updated: module capture for mneme credentials |
| `config/runtime.exs` | Rewritten: desktop mode branch |
| `rel/env.sh.eex` | Created: release env with desktop flags |
| `rel/vm.args.eex` | Created: minimal VM args |
| `lib/worth/boot.ex` | Created: server start logic extracted from CLI |
| `lib/worth/cli.ex` | Updated: uses Worth.Boot, added --no-open |
| `lib/worth/desktop/bridge.ex` | Created: TCP PubSub bridge for Tauri |
| `lib/worth/application.ex` | Updated: added Desktop.Bridge to children, ready broadcast |
| `lib/worth/memory/embeddings/adapter.ex` | Updated: added credentials/0 function |
| `rel/desktop/src-tauri/Cargo.toml` | Created |
| `rel/desktop/src-tauri/tauri.conf.json` | Created |
| `rel/desktop/src-tauri/src/main.rs` | Created |
| `rel/desktop/src-tauri/src/lib.rs` | Created |
| `rel/desktop/src-tauri/build.rs` | Created |
| `rel/desktop/src-tauri/splash.html` | Created |
| `rel/desktop/src-tauri/icons/*` | Created: icon.svg, icon.png, icon.icns, icon.ico, 32/128/256 PNGs |
| `rel/desktop/tauri.sh` | Created |

---

## Progress Log

| Date | Phase | What was done |
|------|-------|---------------|
| 2026-04-10 | 0.1 | Converted agent_ex (v0.1.1) and mneme (v0.2.0) to git deps, pushed tags, added override:true |
| 2026-04-10 | 0.2 | Added releases config to mix.exs, created rel/env.sh.eex and rel/vm.args.eex, fixed anonymous function in config |
| 2026-04-10 | 0.3 | Rewrote runtime.exs with WORTH_DESKTOP=1 branch (127.0.0.1 bind, auto secret, server:true) |
| 2026-04-10 | 0.4 | Created Worth.Boot module, refactored CLI to use it, added --no-open flag |
| 2026-04-10 | 0.5 | Added auto-migrate to Worth.Boot (WORTH_DESKTOP=1 or WORTH_AUTO_MIGRATE=1) |
| 2026-04-10 | 0.6 | Kept postgrex in release (transitive dep), desktop forces libSQL via env |
| 2026-04-10 | 1 | Verified release builds (92MB), env.sh generated correctly |
| 2026-04-10 | 2.1 | Created Tauri project structure under rel/desktop/src-tauri/ |
| 2026-04-10 | 2.2 | Implemented Rust side: splash screen, OTP spawn, tray menu, single instance, graceful shutdown |
| 2026-04-10 | 2.3 | Implemented Elixir bridge: TCP PubSub client, ready broadcast, quit listener |
| 2026-04-10 | 2.4 | Created tauri.sh build orchestration script |
| 2026-04-10 | 4 | Generated app icon (SVG → PNG/ICO/ICNS), slogan "Your ideas are WORTH more" added to UI + splash + CLI |
| 2026-04-11 | 2.2 | Rewrote Rust lib.rs: replaced HTTP polling with TCP PubSub server, sends WORTH_PUBSUB to OTP, handles ready/shutdown frames, removed reqwest dep |
| 2026-04-11 | 2.3 | Rewrote Elixir bridge: connection retry loop, frame buffering for partial TCP reads, shutdown broadcast on app stop, removed duplicate ready broadcast from application.ex |
| 2026-04-11 | 2.4 | Fixed build pipeline: tauri_build copies release into src-tauri/rel/, tauri.conf.json resources config, removed dead WORTH_PORT from env.sh.eex, expanded .gitignore for full target/ |
| 2026-04-11 | — | App compiles and launches successfully on Linux x86_64 — web UI loads in Tauri window, splash → main window transition works, tray icon functional |
| 2026-04-11 | — | Fixed vm.args.eex duplicate -mode conflict, fixed release_dir path resolution for dev builds |
| 2026-04-11 | — | Fixed Elixir bridge send_frame: 4-byte big-endian header, iolist-safe send |
| 2026-04-11 | — | Moved auto-migrate to application.ex (after supervisor start) |
| 2026-04-11 | — | Added missing workspace_index_entries migration |
| 2026-04-11 | — | Fixed EmbeddingModelIdAnd1536Dim migration: LibSql vs LibSQL typo |
| 2026-04-11 | — | Added window close → hide to tray behavior |
