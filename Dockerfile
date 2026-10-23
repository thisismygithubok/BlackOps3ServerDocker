ARG TARGETARCH

FROM debian:trixie-slim AS base-amd64
# wine64 only: BO3 and the custom clients are 64-bit
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl wine wine64 xvfb unzip \
 && rm -rf /var/lib/apt/lists/*
ENV DEPOTDOWNLOADER_ARCH=x64

# ARM64 (work in progress): Hangover runs the x86-64 game (Wine + FEX)
FROM debian:trixie-slim AS hangover
ARG HANGOVER_VERSION=11.16
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl llvm \
 && mkdir /ho && cd /ho \
 && curl -fsSL https://github.com/AndreRH/hangover/releases/download/hangover-${HANGOVER_VERSION}/hangover_${HANGOVER_VERSION}_debian13_trixie_arm64.tar | tar -x \
 && for d in *.deb; do dpkg-deb -x "$d" /x; done \
 && find /x/usr/lib/wine/aarch64-windows -type f \( -name "*.dll" -o -name "*.exe" -o -name "*.sys" -o -name "*.drv" \) \
      -exec llvm-strip --strip-debug {} +

FROM debian:trixie-slim AS base-arm64
# Hangover's DLLs ship with debug info (1.7GB): swap in the stripped copies and drop the
# 32-bit x86 DLLs (BO3 is 64-bit only) in the same layer so the originals never land in the image
RUN --mount=type=bind,from=hangover,source=/ho,target=/ho \
    apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip /ho/*.deb \
 && rm -rf /var/lib/apt/lists/* /usr/lib/wine/aarch64-windows /usr/lib/wine/i386-windows
COPY --from=hangover /x/usr/lib/wine/aarch64-windows /usr/lib/wine/aarch64-windows
ENV DEPOTDOWNLOADER_ARCH=arm64

FROM base-${TARGETARCH}
# DepotDownloader fetches the server, map and Workshop files (native build for each arch)
ARG DEPOTDOWNLOADER_VERSION=3.4.0
RUN curl -fsSL -o /tmp/dd.zip https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_${DEPOTDOWNLOADER_VERSION}/DepotDownloader-linux-${DEPOTDOWNLOADER_ARCH}.zip \
 && unzip -q /tmp/dd.zip DepotDownloader -d /usr/local/bin && chmod 755 /usr/local/bin/DepotDownloader && rm /tmp/dd.zip \
 && useradd -m -u 1000 bo3 \
 && mkdir /server \
 && mkdir -m 1777 /tmp/.X11-unix \
 && chown bo3:bo3 /server

USER bo3
# Invariant globalization: DepotDownloader (.NET) then doesn't need libicu
ENV WINEPREFIX=/home/bo3/.wine WINEDEBUG=-all XDG_RUNTIME_DIR=/tmp DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 \
    GAME_PORT=27017 MOD_ID= SERVER_CONFIG=server_zm.cfg STEAM_USER=

COPY boiii-server-files.zip /opt/bo3/
COPY --chown=bo3:bo3 UnrankedServer /opt/bo3/UnrankedServer
COPY --chmod=755 docker/entrypoint.sh /usr/local/bin/entrypoint.sh

WORKDIR /server
# /home/bo3 holds the wine prefix (~800MB, created on first start) and the cached Steam login
VOLUME ["/server", "/home/bo3"]
EXPOSE 27017/udp 27017/tcp
ENTRYPOINT ["entrypoint.sh"]
CMD ["boiii"]
