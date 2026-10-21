FROM debian:trixie-slim

# wine64 only: BO3 and the custom clients are 64-bit. lib32gcc-s1 is for steamcmd (32-bit).
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl wine wine64 xvfb lib32gcc-s1 unzip \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -m -u 1000 bo3 \
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
