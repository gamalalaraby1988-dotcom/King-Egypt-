# KING OF EGYPT CITY dedicated server image.
# Build from the repository root:
# docker build -f deploy/godot-server/Dockerfile -t king-city-server:staging .
ARG GODOT_VERSION=4.7.2
FROM debian:bookworm-slim

ARG GODOT_VERSION
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip \
    libfontconfig1 libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 \
    libgl1 libasound2 libpulse0 libudev1 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL \
    "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
    -o /tmp/godot.zip \
    && unzip /tmp/godot.zip -d /tmp/godot \
    && install -m 0755 /tmp/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot \
    && rm -rf /tmp/godot /tmp/godot.zip

WORKDIR /app
COPY . /app

# Import project resources at image-build time; do not import on every container boot.
RUN godot --headless --editor --path /app --quit

RUN useradd --system --uid 10001 --home-dir /data --create-home cityserver \
    && mkdir -p /data \
    && chown -R 10001:10001 /app /data

ENV HOME=/data
ENV XDG_DATA_HOME=/data/.local/share
ENV KING_CITY_GAME_PORT=2456
VOLUME ["/data"]

COPY deploy/godot-server/entrypoint.sh /usr/local/bin/king-city-entrypoint
RUN chmod 0755 /usr/local/bin/king-city-entrypoint

USER 10001:10001
EXPOSE 2456/tcp
ENTRYPOINT ["/usr/local/bin/king-city-entrypoint"]
