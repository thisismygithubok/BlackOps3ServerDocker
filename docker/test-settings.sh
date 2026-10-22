#!/bin/bash
# Self-check for the docker_settings.cfg that entrypoint.sh generates from env vars. Run inside the image:
#   docker run --rm -v "$PWD/docker:/d:ro" --entrypoint bash thisismynameok/bo3-server-docker /d/test-settings.sh
set -euo pipefail
eval "$(sed -n '/^SETTINGS=(/,/^)/p; /^setting() {/,/^}/p' /d/entrypoint.sh)"
gen() { mkdir -p /tmp/t/zone && cd /tmp/t && eval "$(sed -n '/^prepare_wine/,/^}/p' /d/entrypoint.sh | sed -n '/^    {$/,/docker_settings.cfg$/p')" && cat zone/docker_settings.cfg; }
check() { if grep -qxF -- "$2" <<<"$3"; then echo "ok   $1"; else echo "FAIL $1: wanted [$2] in:"; echo "$3"; exit 1; fi; }
export SERVER_CONFIG=server_zm.cfg
out=$(gen); check "only exec when nothing set" 'exec "server_zm.cfg"' "$out"; [ "$(wc -l <<<"$out")" -eq 1 ] && echo "ok   no extra lines"
out=$(SERVER_NAME='My "Z" Server' SERVER_PASSWORD= MAX_PLAYERS=4 GAME_MODE=zclassic MAPS="zm_genesis zm_zod" SET_sv_skip_lobby=0 gen)
check "name, quotes stripped" 'set live_steam_server_name "My Z Server"' "$out"
check "empty password clears" 'set g_password ""' "$out"
check "max players" 'set com_maxclients "4"' "$out"
check "rotation built" 'set sv_maprotation "gametype zclassic map zm_genesis map zm_zod"' "$out"
check "SET_ passthrough" 'set sv_skip_lobby "0"' "$out"
out=$(RCON_PASSWORD=r00t BOT_DIFFICULTY=2 SKIP_LOBBY=0 gen)
check "rcon password" 'set rcon_password "r00t"' "$out"
check "bot difficulty" 'set bot_difficulty "2"' "$out"
check "skip lobby" 'set sv_skip_lobby "0"' "$out"
if (MAPS=zm_genesis gen) 2>/tmp/err; then echo "FAIL MAPS without GAME_MODE should error"; exit 1; else grep -q "Set GAME_MODE" /tmp/err && echo "ok   MAPS without GAME_MODE errors"; fi
