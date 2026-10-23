# CLAUDE.md

Docker image for hosting Black Ops 3 servers (focus: Zombies) under Wine. Published as `thisismynameok/bo3-server-docker` (multi-arch: amd64, arm64 work in progress). The README is the user-facing documentation; keep it in sync with any behavior change.

## Layout
- `Dockerfile`: per-arch base selected by `TARGETARCH`. `base-amd64` = Debian trixie `wine64` + `xvfb`. `base-arm64` = Hangover (Wine + FEX) with its DLLs stripped of debug info. Both get DepotDownloader (native build per arch).
- `docker/entrypoint.sh`: the only logic. Modes: `install`/`update` (downloads), `boiii`/`t7x` (custom clients, `-headless`), `vanilla` (Treyarch's official server under Xvfb, MP only, amd64 only), anything else is exec'd.
- `docker/test-entrypoint.sh`: self-check for the entrypoint's pure functions (settings cfg, filelists). Run it after changing them.
- `UnrankedServer/{boiii,t7x,zone}`: server configs copied into the server folder on install (never overwriting user edits). `boiii/` and `t7x/` are identical copies.
- `boiii-server-files.zip`: EZZBOIII runtime files, unzipped into the Wine prefix's `AppData/Local` on first start.
- `docker-compose.yml`: reference compose file; the README's step-1 compose block mirrors it.

## Commands
```bash
# self-check (in the image, bash 5; macOS bash 3.2 can't run it)
docker run --rm -v "$PWD/docker:/d:ro" --entrypoint bash thisismynameok/bo3-server-docker /d/test-entrypoint.sh
# local build for one arch (this Mac is arm64; amd64 builds run emulated)
docker buildx build --builder desktop-linux --platform linux/arm64 -t bo3-arm64-test --load .
# publish multi-arch latest (needs the docker-container builder)
docker buildx build --builder multi-builder --platform linux/amd64,linux/arm64 -t thisismynameok/bo3-server-docker:latest --push .
```

## How it works / gotchas
- **Settings**: env vars (`SERVER_NAME`, `MAPS` + `GAME_MODE`, ..., `SET_<dvar>`) are written to `zone/docker_settings.cfg`, which `exec`s `SERVER_CONFIG` first and then sets them. Command-line `+set` does NOT work for overrides: the engine applies `+set` before any cfg runs, so the cfg wins. `g_log` and `sv_lobby_mode` are deliberately not env vars (log mirroring reads g_log; lobby mode must match SERVER_CONFIG).
- **Downloads**: DepotDownloader with `-remember-password`; the token lives in `/home/bo3/.local/share/IsolatedStorage` (volume), keyed by the executable's path, so keep DepotDownloader at `/usr/local/bin/DepotDownloader`. Anonymous login is refused for app 545990 (server) and 311210 (game). Zombies/campaign servers skip `zone/(en_)?mp_*` (2.8 of 4.4 GB) via a lookahead filelist. Zombies maps also need sound banks (`zone/snd/all` and `zone/snd/en` for the core, shared Zombies and map zones). The first map load works without them, but reloading the map (`map_rotate` when the last player leaves) crashes with `Com_ERROR: sound bank ... failed to load`. Workshop items download flat (no `zone/` subfolder) into `usermaps/<FolderName from workshop.json>`; the game loads that layout.
- **Logs**: the game writes its console to `identities/dedicatedpc/console_mp.log` (all three modes), not stdout; the entrypoint `tail -F`s it plus `boiii/games_*.log` into `docker logs`.
- **Expected noise**: many `Could not find fx/weapon "..."` lines on Zombies maps are normal (shared scripts reference other maps' assets); the `syswow64\rundll32.exe` error at prefix creation is harmless (no 32-bit Wine).
- **xvfb-run hangs as PID 1**: start `Xvfb` directly and wait for its socket.
- **ARM dead ends (don't retry)**: Box64 + x86-64 Wine crash-loops `explorer.exe` (all Wine 8-10 builds); the amd64 image under Docker Desktop's Rosetta fails (`invalid gdt selector`); Box32 can't run Valve's current 32-bit steamcmd.
- The official server is **Treyarch's**, not Valve's (only SteamCMD is Valve's). It can't host Zombies.

## Conventions
- Keep it minimal: bash in the entrypoint, no extra tooling. Comment only non-obvious "why".
- Behavior changes need the README (and `docker-compose.yml` if relevant) updated in the same commit.
- Commit locally and ask before `git push`. Never touch the live `bo3-server` container on the user's host unless asked.
