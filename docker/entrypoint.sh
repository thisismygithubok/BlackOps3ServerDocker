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

prepare_wine() {
    [ -d "$SERVER_DIR" ] || { echo "No server files in /server. Run first: docker compose run --rm bo3 install" >&2; exit 1; }
    [ -d "$WINEPREFIX" ] || { wineboot --init && wineserver -w; }
    # EZZBOIII needs its runtime files in %LOCALAPPDATA%/boiii
    local appdata="$WINEPREFIX/drive_c/users/bo3/AppData/Local"
    [ -d "$appdata/boiii" ] || unzip -q /opt/bo3/boiii-server-files.zip -d "$appdata"
    cd "$SERVER_DIR"
    # The game writes its console to files, not stdout: mirror them into `docker logs`
    tail -n0 -F identities/dedicatedpc/console_mp.log boiii/games_{mp,zm,cp}.log 2>/dev/null &
}

case "${1:-t7x}" in
    install|update)
        install
        ;;
    t7x|boiii)
        prepare_wine
        exec wine "$1.exe" -headless +set fs_game "$MOD_ID" +set net_port "$GAME_PORT" +set logfile 2 +exec "$SERVER_CONFIG"
        ;;
    vanilla)
        prepare_wine
        # Valve's server opens a window, so give it a virtual display (xvfb-run hangs as PID 1)
        Xvfb :99 -nolisten tcp &
        export DISPLAY=:99
        until [ -e /tmp/.X11-unix/X99 ]; do sleep 0.2; done
        exec wine BlackOps3_UnrankedDedicatedServer.exe +set fs_game usermaps +set net_port "$GAME_PORT" +set logfile 2 +exec "$SERVER_CONFIG"
        ;;
    *)
        exec "$@"
        ;;
esac
