#!/bin/bash
# Self-check for entrypoint.sh: the generated docker_settings.cfg and the Zombies filelist. Run inside the image:
#   docker run --rm -v "$PWD/docker:/d:ro" --entrypoint bash thisismynameok/bo3-server-docker /d/test-entrypoint.sh
set -euo pipefail
eval "$(sed -n '/^SETTINGS=(/,/^)/p; /^setting() {/,/^}/p; /^zombies_filelist() {/,/^}/p; /^server_filelist() {/,/^}/p' /d/entrypoint.sh)"
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

# Zombies filelist from MAPS
[ -z "$(MAPS="mp_spire" zombies_filelist)" ] && echo "ok   no filelist without zm_ maps"
fl=$(MAPS="zm_genesis mp_spire zm_prison" zombies_filelist)
check "shared zombies files" 'regex:^zone/(en_)?zm_(patch|common|levelcommon)\.f[fd]$' "$fl"
check "map line" 'regex:^zone/(en_)?zm_genesis(_patch)?\.f[fd]$' "$fl"
[ "$(wc -l <<<"$fl")" -eq 3 ] && echo "ok   one line per zm_ map, mp_ skipped"
# the regexes must match the real file names and nothing else
matches() { local l; while read -r l; do [[ $1 =~ ${l#regex:} ]] && return 0; done <<<"$fl"; return 1; }
for f in zone/zm_genesis.ff zone/en_zm_genesis.ff zone/zm_genesis_patch.ff zone/zm_genesis.fd zone/zm_common.fd zone/en_zm_levelcommon.ff; do
  matches "$f" || { echo "FAIL $f not matched"; exit 1; }
done
for f in zone/zm_genesis_other.ff zone/mp_spire.ff zone/zm_zod.ff zone/core_common.ff; do
  ! matches "$f" || { echo "FAIL $f wrongly matched"; exit 1; }
done
echo "ok   filelist matches exactly the right files"

# Server download skips multiplayer maps unless the server is multiplayer
[ -n "$(SERVER_CONFIG=server_zm.cfg MAPS="zm_genesis" server_filelist)" ] && echo "ok   zombies server skips mp_ maps"
[ -n "$(SERVER_CONFIG=server_zm.cfg server_filelist)" ] && echo "ok   zombies server without MAPS skips mp_ maps"
[ -z "$(SERVER_CONFIG=server.cfg server_filelist)" ] && echo "ok   multiplayer config downloads everything"
[ -z "$(SERVER_CONFIG=server_zm.cfg MAPS="zm_genesis mp_spire" server_filelist)" ] && echo "ok   an mp_ map in MAPS downloads everything"
