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

# Don't run flutter as root (recommended by Flutter tooling).
RUN useradd -m -u 10001 flutteruser
USER flutteruser
WORKDIR /home/flutteruser/app

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

