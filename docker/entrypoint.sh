#!/bin/bash
set -euo pipefail

SERVER_DIR=/server/UnrankedServer

# DepotDownloader with the cached login: the first run asks for the password and Steam Guard code
# (anonymous is refused: the account must own BO3), later runs reuse the token saved in /home/bo3
steam_download() {
    DepotDownloader -username "${STEAM_USER:?Set STEAM_USER to a Steam account that owns Black Ops 3}" -remember-password -os windows "$@"
}

# DepotDownloader filelist for the Zombies maps in MAPS: fast files plus the sound banks (zone/snd/all and
# zone/snd/en) of the core zones, the shared Zombies zones and each zm_ map. The first map load works without
# sound banks, but reloading the map (map_rotate after the last player leaves) crashes without them.
# Custom map codenames just match nothing here; they come from WORKSHOP_MAPS.
zombies_filelist() {
    local map lines=""
    for map in ${MAPS:-}; do
        if [[ $map == zm_* ]]; then
            lines+="regex:^zone/(en_)?${map}(_patch)?\.f[fd]\$"$'\n'
            lines+="regex:^zone/snd/(all|en)/${map}(_patch)?\.(all|en)(\.p)?\.sab[ls]\$"$'\n'
        fi
    done
    if [ -n "$lines" ]; then
        printf '%s\n' 'regex:^zone/(en_)?zm_(patch|common|levelcommon)\.f[fd]$' \
            'regex:^zone/snd/(all|en)/zm_(patch|common|levelcommon)\.(all|en)(\.p)?\.sab[ls]$' \
            'regex:^zone/snd/(all|en)/core_[a-z_]+\.(all|en)(\.p)?\.sab[ls]$'
        printf '%s' "$lines"
    fi
}

# DepotDownloader filelist for the server download: Zombies and campaign servers skip the
# multiplayer maps (2.8GB of the 4.4GB). Empty (= everything) for multiplayer.
server_filelist() {
    if [ "$SERVER_CONFIG" != server.cfg ] && [[ " ${MAPS:-} " != *" mp_"* ]]; then
        echo 'regex:^(?!UnrankedServer/zone/(en_)?mp_)'
    fi
}

# workshop <id> <usermaps|mods>: download a Workshop item into usermaps/<FolderName> or mods/<id>
workshop() {
    local tmp="$SERVER_DIR/.workshop/$1" name="$1"
    rm -rf "$tmp"
    steam_download -app 311210 -pubfile "$1" -dir "$tmp"
    rm -rf "$tmp/.DepotDownloader"
    if [ "$2" = usermaps ]; then
        name=$(sed -n 's/.*"FolderName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$tmp/workshop.json" 2>/dev/null || true)
        [ -n "$name" ] || { echo "Workshop item $1 has no FolderName in workshop.json: is it a map?" >&2; exit 1; }
    fi
    mkdir -p "$SERVER_DIR/$2"
    rm -rf "${SERVER_DIR:?}/$2/$name"
    mv "$tmp" "$SERVER_DIR/$2/$name"
    echo "Workshop item $1 installed as $2/$name"
}

install() {
    local filelist server_files=()
    filelist=$(server_filelist)
    if [ -n "$filelist" ]; then
        echo "$filelist" > /tmp/server-filelist.txt
        server_files=(-filelist /tmp/server-filelist.txt)
    fi
    steam_download -app 545990 -dir /server "${server_files[@]}"
    [ -d "$SERVER_DIR" ] || { echo "The server files were not downloaded. Check the login above and that /server is writable by uid 1000." >&2; exit 1; }

    # Repo configs never overwrite files the user has already edited
    cp -r --update=none /opt/bo3/UnrankedServer/. "$SERVER_DIR/"

    filelist=$(zombies_filelist)
    if [ -n "$filelist" ]; then
        echo "$filelist" > /tmp/filelist.txt
        steam_download -app 311210 -filelist /tmp/filelist.txt -dir "$SERVER_DIR"
    fi
    for id in ${WORKSHOP_MAPS:-}; do
        workshop "$id" usermaps
    done
    if [ -n "${MOD_ID:-}" ]; then
        workshop "$MOD_ID" mods
    fi

    curl -fL https://master.bo3.eu/t7x/t7x.exe -o "$SERVER_DIR/t7x.exe"
    curl -fL https://github.com/Ezz-lol/boiii-free/releases/latest/download/boiii.exe -o "$SERVER_DIR/boiii.exe"
}

# ENV_VAR=setting: each env var that is set overrides that setting in SERVER_CONFIG.
# g_log and sv_lobby_mode are left out on purpose: log mirroring reads g_log, and the lobby mode must match SERVER_CONFIG.
SETTINGS=(
    SERVER_NAME=live_steam_server_name
    SERVER_DESCRIPTION=live_steam_server_description
    SERVER_PASSWORD=g_password
    RCON_PASSWORD=rcon_password
    MAX_PLAYERS=com_maxclients
    MIN_PLAYERS=lobby_min_players
    PRIVATE_SLOTS=sv_privateClients
    CONNECTION_TIMEOUT=sv_timeout
    RECONNECT_LIMIT=sv_reconnectlimit
    VERIFY_CLIENT_FILES=sv_pure
    CHAT_FLOOD_PROTECTION=sv_floodProtect
    SKIP_LOBBY=sv_skip_lobby
    LAN_ONLY=sv_lanonly
    THIRD_PERSON=cg_thirdPerson
    DEAD_CHAT=g_deadChat
    FIRST_GOBBLEGUM_FREE=scr_firstGumFree
    TEAM_BALANCE=scr_teambalance
    BOTS_ALLIES=bot_maxallies
    BOTS_AXIS=bot_maxAxis
    BOTS_FFA=bot_maxFree
    BOT_DIFFICULTY=bot_difficulty
)

# setting <dvar> <ENV_VAR>: emit `set <dvar> "<value>"` if ENV_VAR is set (empty counts, e.g. to clear a password)
setting() {
    if [ -n "${!2+x}" ]; then
        echo "set $1 \"${!2//\"/}\""   # cfg strings can't contain quotes
    fi
}

prepare_wine() {
    [ -d "$SERVER_DIR" ] || { echo "No server files in /server. Run first: docker compose run --rm bo3 install" >&2; exit 1; }
    [ -d "$WINEPREFIX" ] || { wineboot --init && wineserver -w; }
    # EZZBOIII needs its runtime files in %LOCALAPPDATA%/boiii
    local appdata="$WINEPREFIX/drive_c/users/bo3/AppData/Local"
    [ -d "$appdata/boiii" ] || unzip -q /opt/bo3/boiii-server-files.zip -d "$appdata"
    cd "$SERVER_DIR"
    for map in ${MAPS:-}; do
        [ -e "zone/$map.ff" ] || [ -d "usermaps/$map" ] || {
            echo "Map $map has no files. Run: docker compose run --rm bo3 update (custom maps: add their Workshop ID to WORKSHOP_MAPS)" >&2
            exit 1
        }
    done
    if [ -n "${MOD_ID:-}" ] && [ ! -d "mods/$MOD_ID" ]; then
        echo "Mod $MOD_ID has no files. Run: docker compose run --rm bo3 update" >&2
        exit 1
    fi
    # The game writes its console to files, not stdout: mirror them into `docker logs`
    tail -n0 -F identities/dedicatedpc/console_mp.log boiii/games_{mp,zm,cp}.log 2>/dev/null &
    # Settings from env vars override SERVER_CONFIG. They go in a generated cfg that runs it first:
    # `+set` on the command line is applied before any cfg runs, so the cfg would win.
    {
        echo "exec \"$SERVER_CONFIG\""
        for pair in "${SETTINGS[@]}"; do
            setting "${pair#*=}" "${pair%%=*}"
        done
        if [ -n "${MAPS:-}" ]; then
            local maps=($MAPS)
            echo "set sv_maprotation \"gametype ${GAME_MODE:?Set GAME_MODE (e.g. zclassic) together with MAPS}$(printf ' map %s' "${maps[@]}")\""
            # The lobby script starts the first map itself, so continue the rotation after it (else it plays twice)
            if [ ${#maps[@]} -gt 1 ]; then
                echo "set sv_mapRotationCurrent \"gametype $GAME_MODE$(printf ' map %s' "${maps[@]:1}")\""
            fi
        fi
        # SET_<setting>=<value>: any other setting
        for var in $(compgen -e | grep '^SET_'); do
            echo "set ${var#SET_} \"${!var//\"/}\""   # cfg strings can't contain quotes
        done
    } > zone/docker_settings.cfg
}

case "$1" in
    install|update)
        install
        ;;
    t7x|boiii)
        prepare_wine
        exec wine "$1.exe" -headless +set fs_game "$MOD_ID" +set net_port "$GAME_PORT" +set logfile 2 +exec docker_settings.cfg
        ;;
    vanilla)
        prepare_wine
        # Treyarch's server opens a window, so give it a virtual display (xvfb-run hangs as PID 1)
        Xvfb :99 -nolisten tcp &
        export DISPLAY=:99
        until [ -e /tmp/.X11-unix/X99 ]; do sleep 0.2; done
        exec wine BlackOps3_UnrankedDedicatedServer.exe +set fs_game usermaps +set net_port "$GAME_PORT" +set logfile 2 +exec docker_settings.cfg
        ;;
    *)
        exec "$@"
        ;;
esac
