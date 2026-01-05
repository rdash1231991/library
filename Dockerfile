##
## Multi-stage build:
## - Stage 1: build Flutter web release
## - Stage 2: serve via nginx
##
## Usage:
##   docker build -t habit-challenge-tracker .
##   docker run --rm -p 8080:80 habit-challenge-tracker
##

FROM ghcr.io/cirruslabs/flutter:stable AS build

# Create a non-root user for the build.
RUN useradd -m -u 10001 flutteruser

# Cirrus' Flutter SDK lives in /sdks/flutter (owned by root). Flutter writes to
# /sdks/flutter/bin/cache during `flutter pub get` / builds, so we must make that
# cache writable for the non-root user.
RUN mkdir -p /sdks/flutter/bin/cache && chown -R flutteruser:flutteruser /sdks/flutter/bin/cache

USER flutteruser
WORKDIR /home/flutteruser/app

# Git safety: mark Flutter SDK as safe for this user.
RUN git config --global --add safe.directory /sdks/flutter

# Copy pubspec first for better layer caching.
COPY --chown=flutteruser:flutteruser pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy the rest of the source.
COPY --chown=flutteruser:flutteruser . .

# Drift (web wasm) runtime dependency (used by in-memory sqlite on web).
RUN mkdir -p web && \
    curl -L "https://github.com/simolus3/sqlite3.dart/releases/latest/download/sqlite3.wasm" -o web/sqlite3.wasm

# Build web release.
# Note: Newer Flutter versions removed the `--web-renderer` flag.
RUN flutter build web --release --no-wasm-dry-run


FROM nginx:1.27-alpine AS runtime

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

