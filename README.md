# BlackOps3ServerInstaller

## What this fork adds
This is a fork of [framilano/BlackOps3ServerInstaller](https://github.com/framilano/BlackOps3ServerInstaller). It keeps the original Windows and Linux scripts and adds a Docker setup, aimed at hosting **Zombies** servers:

- **Docker image** [`thisismynameok/bo3-server-docker`](https://hub.docker.com/r/thisismynameok/bo3-server-docker): Wine, steamcmd, this repo's configs and the EZZBOIII files in one image. One container runs EZZBOIII, T7X or Treyarch's official server. See [How to run with Docker](#how-to-run-with-docker-linux-amd64).
- **Server settings as env vars**: server name, password, max players, game mode, maps and every other setting from the configs can be set in `docker-compose.yml`, without editing `.cfg` files.
- **Zombies map files without the full game**: [DepotDownloader](https://github.com/SteamRE/DepotDownloader) fetches only the Zombies files you need from your own Steam license. Includes a table of every map's codename and the DLC it needs.
- **Server console in `docker logs`**: the game's console and game logs are mirrored into the container logs for all three clients.
- **Player guide**: how to install EZZBOIII or T7X and connect, including on a Mac. See [Joining a server](#joining-a-server-players).
- **ARM64 support (work in progress)**: the image is multi-arch. On ARM64 hosts it uses [Hangover](https://github.com/AndreRH/hangover) and Box64, and it is tested on Apple Silicon. See [ARM64 hosts](#arm64-hosts-work-in-progress).

Simplifying Black Ops 3 server installation for both Steam Black Ops 3 and Custom Clients (like T7X or BOIII). \
**No copyrighted files are distributed using these scripts.** \
\
This repository merges configurations and scripts from these projects:\
[T7X](https://forum.alterware.dev/t/how-to-install-the-t7x-client/1418/2)\
[EZZBOIII](https://forum.ezz.lol/topic/5/bo3-guide)\
[T7 Configuration files](https://github.com/Dss0/t7-server-config)\
[BOIIIEasyServer](https://github.com/rcv11x/BOIIIEasyServer)

**You can create servers on both Linux-based platforms and Windows.**

**There doesn't seem to be a way to run zombies server using the official BO3 Server Launcher. Currently zombies servers are only available using custom clients**

## Table of Contents  
- [How to install on Windows](#how-to-install-on-windows)
- [How to install on Linux (Ubuntu, Debian, Arch)](#how-to-install-on-linux-ubuntu-debian-arch)
- [How to run with Docker (Linux amd64)](#how-to-run-with-docker-linux-amd64)
- [Joining a server (players)](#joining-a-server-players)
- [EZZBOIII Server Additional Steps](#ezzboiii-server-additional-steps)
- [Cool, but Zombies?](#cool-but-zombies)
- [Mods?](#mods)
- [Custom Maps?](#custom-maps)
- [Notes](#notes)

## How to install on Windows
1. Clone this repository wherever you want to install the server
2. Double click on `server_files_downloader.bat`
3. Wait for server files to download through [steamcmd](https://developer.valvesoftware.com/wiki/SteamCMD)
4. Wait for the custom clients executable to download  (currently [T7X](https://forum.alterware.dev/t/how-to-install-the-t7x-client/1418/2) or [EZZBOIII](https://forum.ezz.lol/topic/5/bo3-guide))
5. **(For Custom Clients)** You can now edit `CustomClient_Server.bat` and `zone/server.cfg` (or `zone/server_cp.cfg` or `zone/server_zm.cfg`) with your desired settings
6. **(For Custom Clients)** Launch your server using `CustomClient_Server.bat boiii` if you want to use EZBOIII or `CustomClient_Server.bat t7x` if you want to use T7X
7. **(For official servers on vanilla BO3)** Launch your server using `Launch_Server.bat`
5. Done!

## How to install on Linux (Ubuntu, Debian, Arch)
Official BO3 servers only aimed for Windows support, but [Wine](https://www.winehq.org/) can help us run it on Linux too.
1. Clone this repository wherever you want to install the server
2. Make `server_files_downloader.sh` executable using `chmod +x` and execute it with `./server_files_downloader.sh ubuntu` (note, I currently support `ubuntu`, `debian` and `arch`). Example, if you're on arch just type `./server_files_downloader.sh arch`
3. Follow the setup "wizard" and confirm a bunch of wine required steps. Wait for server files to download through [steamcmd](https://developer.valvesoftware.com/wiki/SteamCMD)
4. Wait for the custom clients executable to download  (currently [T7X](https://forum.alterware.dev/t/how-to-install-the-t7x-client/1418/2) or [EZZBOIII](https://forum.ezz.lol/topic/5/bo3-guide))
5. **(For Custom Clients)** Make `CustomClient_Server.sh` executable using `chmod +x`. Edit your `CustomClient_Server.sh` and `zone/server.cfg` (or `zone/server_cp.cfg` or `zone/server_zm.cfg`) with your desired settings
6. **(For Custom Clients)** Launch your server using `CustomClient_Server.sh boiii` if you want to use EZBOIII or `CustomClient_Server.sh t7x` if you want to use T7X
7. **(For official servers on vanilla BO3)** Launch your server using `Launch_Server.sh`
5. Done!

## How to run with Docker (Linux amd64)
A ready-made image, [`thisismynameok/bo3-server-docker`](https://hub.docker.com/r/thisismynameok/bo3-server-docker), runs the server under Wine on any x86-64 Linux host (ARM64 support is [a work in progress](#arm64-hosts-work-in-progress)). It includes Wine, steamcmd, this repo's configs and the EZZBOIII files. Game files are **not** in the image: you download them with your own Steam account. This section sets up a **Zombies** server. For multiplayer, use `server.cfg` instead of `server_zm.cfg`.

### What you need
- An x86-64 Linux host with Docker and Docker Compose (or an ARM64 host, see [ARM64 hosts](#arm64-hosts-work-in-progress))
- A Steam account that owns Black Ops 3, plus the DLC for any DLC maps you want to host. Anonymous Steam login is refused for the server files.
- UDP and TCP port `27017` forwarded to the host on your router, if people join over the internet

### 1. Set up the service
```bash
mkdir -p bo3/server bo3/home && cd bo3
sudo chown 1000:1000 server home        # the container runs as uid 1000
```
Create `docker-compose.yml` in that folder:
```yaml
services:
  bo3:
    image: thisismynameok/bo3-server-docker:latest
    container_name: bo3
    network_mode: host        # recommended: no port mapping needed
    init: true
    stdin_open: true          # `docker attach bo3` for the server console (detach: Ctrl-P Ctrl-Q)
    tty: true
    restart: unless-stopped
    command: boiii            # boiii (EZZBOIII) or t7x. Players must use the same client.
    environment:
      GAME_PORT: 27017
      SERVER_CONFIG: server_zm.cfg
      MOD_ID: ""
      STEAM_USER: "your_steam_username"
      # Server settings (see step 4)
      SERVER_NAME: "My Zombies Server"
      GAME_MODE: zclassic
      MAPS: "zm_genesis"
      # SERVER_PASSWORD: "secret"
      # MAX_PLAYERS: "4"
    volumes:
      - ./server:/server      # game files + configs (server/UnrankedServer/zone/server_zm.cfg)
      - ./home:/home/bo3      # Wine prefix + cached Steam login
```
If you can't use host networking, remove `network_mode` and add `ports: ["27017:27017/udp", "27017:27017/tcp"]`.

### 2. Download the server files
```bash
docker compose run --rm bo3 install
```
This asks for your Steam password and Steam Guard code once, then downloads the dedicated server files and both clients (`boiii.exe`, `t7x.exe`). The login is cached, so later updates don't prompt.

### 3. Add the Zombies map files
The dedicated server download only contains multiplayer files. Zombies needs the shared Zombies fast files plus the files of each map you host. [DepotDownloader](https://github.com/SteamRE/DepotDownloader) fetches only those files from your Black Ops 3 license, so you don't have to download the whole game:
```bash
mkdir ~/bo3zm && cd ~/bo3zm
curl -fLO https://github.com/SteamRE/DepotDownloader/releases/latest/download/DepotDownloader-linux-x64.zip
unzip DepotDownloader-linux-x64.zip && chmod +x DepotDownloader

cat > filelist.txt <<'EOF'
regex:^zone/(en_)?zm_(patch|common|levelcommon)\.f[fd]$
regex:^zone/(en_)?zm_genesis(_patch)?\.f[fd]$
EOF

./DepotDownloader -app 311210 -os windows -username your_steam_username -remember-password -filelist filelist.txt -dir out
cp out/zone/* /path/to/bo3/server/UnrankedServer/zone/
```
`-filelist filelist.txt` tells DepotDownloader which files to download. Without it, it downloads the whole game. Each line of `filelist.txt` matches files by their path inside the game folder. A line is either an exact path (`zone/zm_genesis.ff`) or, with the `regex:` prefix, a regular expression.

- The **first line** is always needed. It matches the shared Zombies files: `zm_patch`, `zm_common` and `zm_levelcommon` (`.ff` and `.fd`), plus their English `en_` versions.
- **Each further line** selects one map. It matches that map's files, its `_patch` file and their `en_` versions. For another map, copy the line and replace `zm_genesis` with the map's codename from the table below:
  ```
  regex:^zone/(en_)?<codename>(_patch)?\.f[fd]$
  ```

To add maps later, add their lines and run the same command again. Files you already have are skipped. Then copy `out/zone/*` to the server again. On an ARM64 host, download `DepotDownloader-linux-arm64.zip` instead.

| Map | Codename | Comes with |
|---|---|---|
| Shadows of Evil | `zm_zod` | Base game |
| The Giant | `zm_factory` | Season Pass / The Giant DLC |
| Der Eisendrache | `zm_castle` | DLC 1 Awakening |
| Zetsubou No Shima | `zm_island` | DLC 2 Eclipse |
| Gorod Krovi | `zm_stalingrad` | DLC 3 Descent |
| Revelations | `zm_genesis` | DLC 4 Salvation |
| Nacht der Untoten, Verrückt, Shi No Numa, Kino der Toten, Ascension, Shangri-La, Moon, Origins | `zm_prototype`, `zm_asylum`, `zm_sumpf`, `zm_theater`, `zm_cosmodrome`, `zm_temple`, `zm_moon`, `zm_tomb` | Zombies Chronicles |

### 4. Pick the map and settings
Set them in `docker-compose.yml`. Each one you set overrides the same setting in `server_zm.cfg`. Any you leave out keep the default from that file, listed below (Zombies / multiplayer where they differ). On/off settings use `"1"` and `"0"`.

| Env var | What it does | Default |
|---|---|---|
| `SERVER_NAME` | Name in the server browser | `Default BOIII Zombies Server` |
| `SERVER_DESCRIPTION` | Description in the server browser | `My longest YEA BOIII ZOMBIES ever` |
| `SERVER_PASSWORD` | Password to join (empty = none) | empty |
| `RCON_PASSWORD` | Remote console password (empty = disabled) | empty |
| `MAX_PLAYERS` | Maximum players | `4` / `18` |
| `MIN_PLAYERS` | Players needed to start the match (Zombies, campaign) | `1` |
| `PRIVATE_SLOTS` | Slots reserved for private clients | `0` |
| `GAME_MODE` | Game mode, set together with `MAPS` | `zclassic` / `tdm` |
| `MAPS` | Map codenames, played in order, e.g. `"zm_genesis zm_zod"` | `zm_tomb` / all MP maps |
| `SKIP_LOBBY` | `1` = load the map immediately, `0` = wait in the lobby | `1` |
| `LAN_ONLY` | `1` = hide the server from the public server list | `0` |
| `CONNECTION_TIMEOUT` | Seconds before a stalled connection is dropped | `30` |
| `RECONNECT_LIMIT` | Reconnect attempts allowed | `3` |
| `VERIFY_CLIENT_FILES` | `1` = require clients' game files to match the server's | `0` |
| `CHAT_FLOOD_PROTECTION` | `1` = limit chat spam | `1` |
| `THIRD_PERSON` | `1` = third-person view | `0` |
| `DEAD_CHAT` | `1` = everyone sees dead players' chat | `0` |
| `FIRST_GOBBLEGUM_FREE` | Zombies: `1` = first GobbleGum is free, `0` = 500 points | `1` |
| `TEAM_BALANCE` | Multiplayer: `1` = auto-balance teams | `1` |
| `BOTS_ALLIES`, `BOTS_AXIS`, `BOTS_FFA` | Multiplayer: number of bots per team / in free-for-all | `0` |
| `BOT_DIFFICULTY` | Multiplayer: `0` easy, `1` normal, `2` hard, `3` veteran | `1` |
| `SET_<setting>` | Any other server setting, by its in-game name: `SET_<setting>: "value"` | |

The maps must be ones whose files you added in step 3. Apply changes with `docker compose up -d`. Values can't contain double quotes.

Settings you don't set this way come from `server/UnrankedServer/zone/server_zm.cfg`, which you can still edit (apply with `docker compose restart`). At startup the container writes `zone/docker_settings.cfg`, which runs `server_zm.cfg` and then applies these values. Don't edit it, because it's regenerated every start.

### 5. Start the server
```bash
docker compose up -d
docker logs -f bo3
```
The first start takes a little longer while the Wine prefix is created. The server console is mirrored into the container logs. A line like `InitGame: map zm_genesis; gametype zclassic;` means the map loaded. Lots of `Could not find fx/weapon "..."` lines are normal. The shared Zombies scripts look up assets from every map, and only the loaded map's assets exist.

### Hosting custom maps
1. Find the map on the [Steam Workshop](https://steamcommunity.com/app/311210/workshop/) and copy the number at the end of its URL (`?id=<number>`).
2. Download it with DepotDownloader:
   ```bash
   cd ~/bo3zm
   ./DepotDownloader -app 311210 -pubfile <number> -username your_steam_username -remember-password -dir workshop_<number>
   ```
3. The map's codename is the `FolderName` in `workshop_<number>/workshop.json`. Copy the downloaded files to `server/UnrankedServer/usermaps/<codename>/`, so you end up with `usermaps/<codename>/zone/...`.
4. Set `MAPS: "<codename>"` in `docker-compose.yml` and run `docker compose up -d`.

Every player needs the same map, in the same version. See [Joining a server](#joining-a-server-players). If the server stays in the lobby instead of loading a custom map, set `SKIP_LOBBY: "0"`.

### Day-to-day
| Task | Command |
|---|---|
| Logs | `docker logs -f bo3` |
| Server console | `docker attach bo3` (detach: Ctrl-P Ctrl-Q) |
| Apply `docker-compose.yml` changes (settings, `command`, ...) | `docker compose up -d` |
| Apply `server_zm.cfg` changes | `docker compose restart` |
| Update server files and clients | `docker compose run --rm bo3 update && docker compose restart` |
| Update the image | `docker compose pull && docker compose up -d` |
| Switch client | Change `command:` to `boiii` or `t7x`, then `docker compose up -d` |
| Load a mod | Copy the mod to `server/UnrankedServer/mods/<id>/`, set `MOD_ID: "<id>"`, then `docker compose up -d` (see [Mods?](#mods)) |

`command: vanilla` runs Treyarch's official server under a virtual display. It is multiplayer-only and can't host Zombies.

### ARM64 hosts (work in progress)
The image is multi-arch: on an ARM64 host, Docker pulls the arm64 variant automatically, and the setup above stays the same. Inside, [Hangover](https://github.com/AndreRH/hangover) runs the x86-64 game (Wine with FEX emulation), and [Box64](https://github.com/ptitSeb/box64) runs Valve's 64-bit steamcmd.

- **Tested:** on an Apple Silicon Mac with Docker Desktop, both `boiii` and `t7x` load Revelations (`zm_genesis`) and listen on the game port. At idle the server uses about a third of a CPU core and 2 GB of RAM.
- **On Docker Desktop (Mac)**, `network_mode: host` only works if host networking is enabled in Docker Desktop's settings. Otherwise use the `ports:` mapping.
- **Not supported:** `command: vanilla`. The arm64 variant has no virtual display.
- **Not tested yet:** players joining and playing, a full `install` with a Steam login (only an anonymous Steam connection was tested), and ARM Linux servers such as Ampere or Graviton.
- **Don't force the amd64 image** (`platform: linux/amd64`) on a Mac. Docker Desktop's Rosetta emulation can't run it.

## Joining a server (players)
Everyone plays through the same custom client as the server: **EZZBOIII** if the server uses `command: boiii`, **T7X** if it uses `command: t7x`. Ask the host which one.

### What you need
- Black Ops 3 on Steam (Windows version), installed
- The DLC for the map being hosted, if it's a DLC map
- The custom map from the Workshop, if it's a custom map

### Install EZZBOIII
1. Download `boiii.exe` from the [latest release](https://github.com/Ezz-lol/boiii-free/releases/latest).
2. In Steam, right-click Black Ops III → **Manage** → **Browse local files**, and put `boiii.exe` in that folder, next to `BlackOps3.exe`.
3. With Steam running, start `boiii.exe` from that folder, not from Steam's Play button.

### Install T7X
1. Download [`t7x.exe`](https://master.bo3.eu/t7x/t7x.exe). The [T7X install guide](https://forum.alterware.dev/t/how-to-install-the-t7x-client/1418/2) has more detail.
2. Put it in the Black Ops 3 folder (Steam → right-click Black Ops III → **Manage** → **Browse local files**).
3. With Steam running, start `t7x.exe` from that folder.

Antivirus software sometimes flags custom clients. Only download them from the links above.

### Connect
In the client, open the console with the `~` key and type:
```
connect <server-address>:27017
```
You can also find the server by name in the client's server browser.

### Getting custom maps
Subscribe to the same map on the [Steam Workshop](https://steamcommunity.com/app/311210/workshop/) and let Steam download it before you join. If the client can't find the map, copy it from `Steam/steamapps/workshop/content/311210/<number>` into `<Black Ops 3 folder>/usermaps/<codename>/`.

### Playing on a Mac
The native macOS version of Black Ops 3 can't run these clients. Use [CrossOver](https://www.codeweavers.com/crossover) instead:
1. Create a Windows 10 64-bit bottle and install the Windows version of Steam in it.
2. Install Black Ops 3 in that Steam. It's the same purchase, so you don't need to buy it again.
3. Follow the steps for your client above.
4. Start `boiii.exe` or `t7x.exe` with CrossOver's **Run Command**.

Performance depends on your Mac. If the game doesn't start, change the bottle's graphics backend from D3DMetal to DXVK.

## EZZBOIII Server Additional Steps
*Only for the Windows/Linux script installs. The Docker image does this automatically.*

EZZBOIII requires some additional files in your `%APPDATA%/Local` folder to create a new server. Extract [`boiii-server-files.zip`](https://github.com/framilano/BlackOps3ServerInstaller/blob/main/boiii-server-files.zip) and move the extracted `boiii` folder:
- Windows: in your `%APPDATA%/Local` folder
- Linux: open your wine prefix and copy the `boiii` folder in `AppData/Local` folder present in it

## Cool, but Zombies?
*Docker: you need the same files, but DepotDownloader fetches them for you. See [3. Add the Zombies map files](#3-add-the-zombies-map-files).*

The default server files only downloads MP-ready stuff. To serve a Zombies server you need to copy these fast files
from your BO3 game files and put them into `zone`:

```
zone/en_zm_patch.ff
zone/en_zm_common.ff
zone/en_zm_levelcommon.ff
zone/zm_patch.ff
zone/zm_common.fd
zone/zm_common.ff
zone/zm_levelcommon.ff
```
Let's say you want to create a Shadows of Evil server, you need to copy these fast files too.
```
zone/en_zm_zod.ff
zone/en_zm_zod_patch.ff
zone/zm_zod.ff
zone/zm_zod.fd
zone/zm_zod_patch.ff
```

## Mods?
*Docker: put the mod in `server/UnrankedServer/mods/<id>/` the same way, but set `MOD_ID: "<id>"` in `docker-compose.yml` instead of editing `CustomClient_Server.bat`.*

There's a difference between Custom Maps and Mods, this section will explain how to load a mod downloaded from the Steam Workshop.
Let's say you subscribed to the [The Kermit Mod](https://steamcommunity.com/sharedfiles/filedetails/?id=1638465081), this will create a folder in your Steam folder in `steamapps/workshop/content/311210/1638465081`, create a new `mods` folder inside the root of your server folder (in UnrankedServer) and copy the folder named `1638465081` (this number changes depending on the mod) inside it. The resulting folders structure should look like this:

![immagine](https://github.com/user-attachments/assets/23843aca-0bd8-4dbc-8cfe-8dba4eba12c0)

Now modify the `set ModFolderName=` in `CustomClient_Server.bat` into `set ModFolderName=1638465081`, that's it, you're done!

## Custom Maps?
*Docker: see [Hosting custom maps](#hosting-custom-maps). The folder layout is the same, inside `server/UnrankedServer/`.*

This section will explain how to load custom maps downloaded from the Steam Workshop.
Let's say you downloaded the [Mob of the Dead](https://steamcommunity.com/sharedfiles/filedetails/?id=3373649394) custom map and want to host a server with it, create the `usermaps` folder inside the root of your server folder (in UnrankedServer) and create a folder within it called `zm_prison` (the map codename, easily guess the name from the map gamefiles), put all map files inside this folder.

![Screenshot_2025-05-10_22-47-36](https://github.com/user-attachments/assets/002f790f-9843-4288-8fb4-67c929bb4f61)

Edit `server_zm.cfg` and add in map rotation `zm_prison`

`set sv_maprotation "gametype zclassic map zm_prison"`

That's it


## Notes
1. Unless you're playing LAN with friends, you need to port forward you router and open the ports used by your server in Windows Firewall.
2. If you don't need any custom client, just delete `t7x.exe` or `boiii.exe`. *(Script installs only: in Docker, `update` downloads them again.)*
3. Remember to change the port in `CustomClient_Server.bat` if you're launching the server in the same machine where you're playing Black Ops 3. *(Docker: set `GAME_PORT` in `docker-compose.yml`.)*
4. To save space, you can delete any unused fast files in `UnrankedServer/zone`
5. **(For Custom Clients)** To customise your server maps rotation and gamemodes just edit the files in `UnrankedServer/zone`, `server_zm.cfg` changes zombies configuration, `server.cfg` changes multiplayer configurations, `server_cp.cfg` changes coop campaign configuration.
These files can be executed even with the vanilla `Launch_Server.bat` or `Launch_Server.sh` but you need to edit these first to execute the desired .cfg file. *(Docker: choose the file with `SERVER_CONFIG` in `docker-compose.yml`.)*
6. If you're trying to host on a Linux ARM64 machine, you should check out [Hangover](https://github.com/AndreRH/hangover), pair it with wine and you're done! *(Docker: the image's arm64 variant already does this, see [ARM64 hosts](#arm64-hosts-work-in-progress).)*
