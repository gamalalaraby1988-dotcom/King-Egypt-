FROM debian:bookworm-slim

ARG GODOT_VERSION=4.7.2
ENV DEBIAN_FRONTEND=noninteractive
ENV GODOT_SILENCE_ROOT_WARNING=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip gettext-base nginx \
    libfontconfig1 libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 \
    libgl1 libasound2 libpulse0 libudev1 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://godot-releases.nbg1.your-objectstorage.com/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" -o /tmp/godot.zip \
    && unzip /tmp/godot.zip -d /opt/godot \
    && install -m 0755 /opt/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot \
    && rm -rf /tmp/godot.zip /opt/godot

WORKDIR /app
COPY . /app

# Import project assets once during image build; the generated .godot cache is
# included in the final image so the headless runtime does not need an editor.
RUN godot --headless --editor --path /app --quit

COPY deploy/render/nginx.conf.template /etc/nginx/templates/default.conf.template
COPY deploy/render/start.sh /usr/local/bin/start-game-server
RUN chmod 0755 /usr/local/bin/start-game-server

ENV PORT=10000
ENV KING_CITY_GAME_PORT=2456
ENV KING_CITY_TLS_TERMINATED_BY_PROXY=1

EXPOSE 10000
CMD ["/usr/local/bin/start-game-server"]
