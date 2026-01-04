FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy only what we need for build caching
COPY pubspec.yaml /app/pubspec.yaml
COPY analysis_options.yaml /app/analysis_options.yaml
COPY lib /app/lib

RUN flutter config --enable-web
# Create missing platform folder(s) inside container (doesn't change your repo)
RUN flutter create --platforms=web .
RUN flutter pub get
RUN flutter build web --release

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80

