#!/bin/bash
set -euo pipefail

SERVER_DIR=/server/UnrankedServer
STEAMCMD_DIR=/home/bo3/steamcmd

install() {
    if [ ! -x "$STEAMCMD_DIR/steamcmd.sh" ]; then
        # bind mounts / pre-existing volumes don't get the image's copy of this dir
        mkdir -p "$STEAMCMD_DIR"
        curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar -xz -C "$STEAMCMD_DIR"
    fi
    # Anonymous login is refused for 545990 ("Missing configuration"): the account must own BO3.
    # steamcmd prompts for password / Steam Guard, then caches the login in $STEAMCMD_DIR
    "$STEAMCMD_DIR/steamcmd.sh" +@sSteamCmdForcePlatformType windows +force_install_dir /server \
        +login "${STEAM_USER:?Set STEAM_USER to a Steam account that owns Black Ops 3}" +app_update 545990 validate +quit || true
    [ -d "$SERVER_DIR" ] || { echo "steamcmd did not install app 545990. Check the login above and that /server is writable by uid 1000." >&2; exit 1; }

    # Repo configs never overwrite files the user has already edited
    cp -r --update=none /opt/bo3/UnrankedServer/. "$SERVER_DIR/"
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
            echo "set sv_maprotation \"gametype ${GAME_MODE:?Set GAME_MODE (e.g. zclassic) together with MAPS}$(printf ' map %s' $MAPS)\""
        fi
        # SET_<setting>=<value>: any other setting
        for var in $(compgen -e | grep '^SET_'); do
            echo "set ${var#SET_} \"${!var//\"/}\""   # cfg strings can't contain quotes
        done
    } > zone/docker_settings.cfg
}

case "${1:-t7x}" in
    install|update)
        install
        ;;
    t7x|boiii)
        prepare_wine
        exec wine "$1.exe" -headless +set fs_game "$MOD_ID" +set net_port "$GAME_PORT" +set logfile 2 +exec docker_settings.cfg
        ;;
    vanilla)
        prepare_wine
        # Valve's server opens a window, so give it a virtual display (xvfb-run hangs as PID 1)
        Xvfb :99 -nolisten tcp &
        export DISPLAY=:99
        until [ -e /tmp/.X11-unix/X99 ]; do sleep 0.2; done
        exec wine BlackOps3_UnrankedDedicatedServer.exe +set fs_game usermaps +set net_port "$GAME_PORT" +set logfile 2 +exec docker_settings.cfg
        ;;
    *)
        exec "$@"
        ;;
esac
