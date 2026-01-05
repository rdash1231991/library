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

WORKDIR /app

# Copy pubspec first for better layer caching.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy the rest of the source.
COPY . .

# Build web release.
# Note: Newer Flutter versions removed the `--web-renderer` flag.
RUN flutter build web --release


FROM nginx:1.27-alpine AS runtime

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

