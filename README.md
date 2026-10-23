# BlackOps3ServerDocker

A Docker image for hosting **Call of Duty: Black Ops 3** servers, aimed at **Zombies**. One container runs [EZZBOIII](https://forum.ezz.lol/topic/5/bo3-guide), [T7X](https://forum.alterware.dev/t/how-to-install-the-t7x-client/1418/2) or Treyarch's official dedicated server under Wine.

Image: [`thisismynameok/bo3-server-docker`](https://hub.docker.com/r/thisismynameok/bo3-server-docker) (amd64; arm64 is a [work in progress](#arm64-hosts-work-in-progress)).

**No copyrighted files are distributed.** The container downloads the game files with your own Steam account.

- **Maps and mods downloaded for you**: list the maps in `MAPS` and Workshop items in `WORKSHOP_MAPS` / `MOD_ID`. Then `install` / `update` fetch exactly those files with [DepotDownloader](https://github.com/SteamRE/DepotDownloader) from your Steam license, without downloading the full game. A Zombies server needs about 5 GB plus its maps (Revelations: about 7 GB in total).
- **Settings as env vars**: server name, password, max players, game mode, maps and every other setting from the configs can be set in `docker-compose.yml`.
- **Server console in `docker logs`**: the game's console and game logs are mirrored into the container logs.
- **Player guide**: how to install EZZBOIII or T7X and connect, including on a Mac. See [Joining a server](#joining-a-server-players).

This is a fork of [framilano/BlackOps3ServerInstaller](https://github.com/framilano/BlackOps3ServerInstaller), which also has script installs for Windows and Linux.

## Table of Contents
- [Hosting a server](#hosting-a-server)
- [Joining a server (players)](#joining-a-server-players)
- [Credits](#credits)

## Hosting a server
This section sets up a **Zombies** server. For multiplayer, use `server.cfg` instead of `server_zm.cfg`.

### What you need
- An x86-64 Linux host with Docker and Docker Compose (or an ARM64 host, see [ARM64 hosts](#arm64-hosts-work-in-progress))
- A Steam account that owns Black Ops 3, plus the DLC for any DLC maps you want to host. Anonymous Steam login is refused for the server files.
- UDP port `27017` forwarded to the host on your router, if people join over the internet

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
    ports:
      - "27017:27017/udp"     # the game uses UDP only
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
      # Maps: downloaded by `install` / `update`, see step 2
      GAME_MODE: zclassic
      MAPS: "zm_genesis"
      # WORKSHOP_MAPS: ""     # Workshop IDs of custom maps
      # Server settings, see step 3
      SERVER_NAME: "My Zombies Server"
      # SERVER_PASSWORD: "secret"
      # MAX_PLAYERS: "4"
    volumes:
      - ./server:/server      # game files + configs (server/UnrankedServer/zone/server_zm.cfg)
      - ./home:/home/bo3      # Wine prefix + cached Steam login
```
Publish the port as `/udp`: a plain `"27017:27017"` maps TCP only, and players can't connect. Docker's port mapping bypasses ufw, so no firewall rule is needed.

To have the server show up in the server browser's **LAN** tab too, use `network_mode: host` instead of `ports:` (LAN discovery broadcasts don't reach a container behind port mapping). The host firewall then applies, so with ufw allow the port:
```bash
sudo ufw allow 27017/udp comment 'BO3 Server'
```

**Not in the server browser?** The server registers with EZZBOIII's master servers by sending a heartbeat from port 27017. Some routers change the source port of that outgoing traffic, even with a port forward in place. The master servers then list your server on a random port that nobody can reach, and the browser leaves it out, while `connect <ip>:27017` still works. To fix it, add a **source NAT** rule on your router that keeps the port for the server's outgoing UDP:
- Protocol: UDP
- Source: the server's LAN IP, port `27017`
- Destination: any
- Translate to: your public IP, port unchanged

On UniFi (Network 9/10) that's a Policy Table → NAT policy of type **Source NAT**. To check what the master servers see, send `\xff\xff\xff\xffgetservers T7 8 full empty` over UDP to `master.ezz.lol:20810` and look for your public IP:port in the reply.

### 2. Download the server and map files
```bash
docker compose run --rm bo3 install
```
This asks for your Steam password and Steam Guard code once, then downloads:
- the dedicated server files. A Zombies or campaign server skips the multiplayer maps (2.8 GB of the 4.4 GB). Those are downloaded only for `server.cfg` or when `MAPS` contains an `mp_` map.
- the Zombies files and sound banks for each stock map in `MAPS`, from your Black Ops 3 license (only those files, not the whole game). The server needs the sound banks to reload a map, for example to start a new match after the last player leaves.
- the custom maps in `WORKSHOP_MAPS` and the mod in `MOD_ID` (see [Hosting custom maps](#hosting-custom-maps))
- both clients (`boiii.exe`, `t7x.exe`)

The login is cached in `home/`, so later runs don't prompt. After changing `MAPS` or `WORKSHOP_MAPS`, run `docker compose run --rm bo3 update` to download the new files. Files you already have are skipped. If you don't own a map's DLC, its files aren't downloaded, and the server won't start until you remove that map from `MAPS`.

| Map | Codename | Comes with |
|---|---|---|
| Shadows of Evil | `zm_zod` | Base game |
| The Giant | `zm_factory` | Season Pass / The Giant DLC |
| Der Eisendrache | `zm_castle` | DLC 1 Awakening |
| Zetsubou No Shima | `zm_island` | DLC 2 Eclipse |
| Gorod Krovi | `zm_stalingrad` | DLC 3 Descent |
| Revelations | `zm_genesis` | DLC 4 Salvation |
| Nacht der Untoten, Verrückt, Shi No Numa, Kino der Toten, Ascension, Shangri-La, Moon, Origins | `zm_prototype`, `zm_asylum`, `zm_sumpf`, `zm_theater`, `zm_cosmodrome`, `zm_temple`, `zm_moon`, `zm_tomb` | Zombies Chronicles |

### 3. Server settings
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

Apply changes with `docker compose up -d` (after `update`, if you changed `MAPS`). Values can't contain double quotes.

Settings you don't set this way come from `server/UnrankedServer/zone/server_zm.cfg`, which you can still edit (apply with `docker compose restart`). At startup the container writes `zone/docker_settings.cfg`, which runs `server_zm.cfg` and then applies these values. Don't edit it, because it's regenerated every start.

### 4. Start the server
```bash
docker compose up -d
docker logs -f bo3
```
The first start takes a little longer while the Wine prefix is created. The server console is mirrored into the container logs. A line like `InitGame: map zm_genesis; gametype zclassic;` means the map loaded. Lots of `Could not find fx/weapon "..."` lines are normal. The shared Zombies scripts look up assets from every map, and only the loaded map's assets exist.

### Hosting custom maps
1. Find the map on the [Steam Workshop](https://steamcommunity.com/app/311210/workshop/) and copy the number at the end of its URL (`?id=<number>`).
2. Add it to `WORKSHOP_MAPS` in `docker-compose.yml` (separate several IDs with spaces), then run `docker compose run --rm bo3 update`. The map is installed as `usermaps/<codename>/`, and `update` prints the codename (`Workshop item <id> installed as usermaps/<codename>`). To look it up later, list the folders: `ls server/UnrankedServer/usermaps/`.
3. Put the codename in `MAPS` and run `docker compose up -d`.

Every player needs the same map, in the same version. See [Joining a server](#joining-a-server-players). If the server stays in the lobby instead of loading a custom map, set `SKIP_LOBBY: "0"`.

### Day-to-day
| Task | Command |
|---|---|
| Logs | `docker logs -f bo3` |
| Server console | `docker attach bo3` (detach: Ctrl-P Ctrl-Q) |
| Apply `docker-compose.yml` changes (settings, `command`, ...) | `docker compose up -d` |
| Apply `server_zm.cfg` changes | `docker compose restart` |
| Change maps | Edit `MAPS` / `WORKSHOP_MAPS`, then `docker compose run --rm bo3 update && docker compose up -d` |
| Update server files, maps and clients | `docker compose run --rm bo3 update && docker compose restart` |
| Update the image | `docker compose pull && docker compose up -d` |
| Switch client | Change `command:` to `boiii` or `t7x`, then `docker compose up -d` |
| Load a Workshop mod | Set `MOD_ID: "<Workshop ID>"`, then `docker compose run --rm bo3 update && docker compose up -d`. The mod is installed in `mods/<id>/`. It must support the custom clients; some mods say they only work with the regular game |

`command: vanilla` runs Treyarch's official server under a virtual display. It is multiplayer-only and can't host Zombies.

### ARM64 hosts (work in progress)
The image is multi-arch: on an ARM64 host, Docker pulls the arm64 variant automatically, and the setup above stays the same. Inside, [Hangover](https://github.com/AndreRH/hangover) runs the x86-64 game (Wine with FEX emulation), and DepotDownloader has a native arm64 build.

- **Tested:** on an Apple Silicon Mac with Docker Desktop, both `boiii` and `t7x` load Revelations (`zm_genesis`) and listen on the game port. At idle the server uses about a third of a CPU core and 2 GB of RAM.
- **On Docker Desktop (Mac)**, `network_mode: host` only works if host networking is enabled in Docker Desktop's settings. The default `ports:` mapping works without it.
- **Not supported:** `command: vanilla`. The arm64 variant has no virtual display.
- **Not tested yet:** players joining and playing, a full `install` with a Steam login inside the arm64 image, and ARM Linux servers such as Ampere or Graviton.
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

## Credits
The server configs come from these projects:
- [T7X](https://forum.alterware.dev/t/how-to-install-the-t7x-client/1418/2)
- [EZZBOIII](https://forum.ezz.lol/topic/5/bo3-guide)
- [T7 Configuration files](https://github.com/Dss0/t7-server-config)
- [BOIIIEasyServer](https://github.com/rcv11x/BOIIIEasyServer)
- [framilano/BlackOps3ServerInstaller](https://github.com/framilano/BlackOps3ServerInstaller)
