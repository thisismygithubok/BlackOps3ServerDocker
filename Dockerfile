ARG TARGETARCH

FROM debian:trixie-slim AS base-amd64
# wine64 only: BO3 and the custom clients are 64-bit. lib32gcc-s1 is for steamcmd (32-bit).
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl wine wine64 xvfb lib32gcc-s1 unzip \
 && rm -rf /var/lib/apt/lists/*

# ARM64 (work in progress): Hangover runs the x86-64 game (FEX), Box64 runs steamcmd
FROM sonroyaalmerol/steamcmd-arm64:root-trixie AS box64

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
# Box64 launcher + generic build only (the device-tuned builds made no difference for steamcmd)
COPY --from=box64 /usr/local/bin/box64 /usr/local/bin/box64-generic /usr/local/bin/
COPY --from=box64 /usr/lib/box64-x86_64-linux-gnu /usr/lib/box64-x86_64-linux-gnu
# steamcmd.sh runs $DEBUGGER $STEAMEXE: the 64-bit steamcmd under Box64 (Box32 can't run the 32-bit one)
ENV DEBUGGER=box64 STEAM_PLATFORM=linux64 BOX64_LOG=0

FROM base-${TARGETARCH}
RUN useradd -m -u 1000 bo3 \
 && mkdir /server /home/bo3/steamcmd \
 && mkdir -m 1777 /tmp/.X11-unix \
 && chown bo3:bo3 /server /home/bo3/steamcmd

USER bo3
ENV WINEPREFIX=/home/bo3/.wine WINEDEBUG=-all XDG_RUNTIME_DIR=/tmp \
    GAME_PORT=27017 MOD_ID= SERVER_CONFIG=server.cfg STEAM_USER=

COPY boiii-server-files.zip /opt/bo3/
COPY --chown=bo3:bo3 UnrankedServer /opt/bo3/UnrankedServer
COPY --chmod=755 docker/entrypoint.sh /usr/local/bin/entrypoint.sh

WORKDIR /server
# /home/bo3 holds the wine prefix (~800MB, created on first start) and the steamcmd login
VOLUME ["/server", "/home/bo3"]
EXPOSE 27017/udp 27017/tcp
ENTRYPOINT ["entrypoint.sh"]
CMD ["t7x"]
