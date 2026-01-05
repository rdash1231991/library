# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS flutter_build
WORKDIR /build

# Copy project definition
COPY flutter_preset_app/pubspec.yaml flutter_preset_app/analysis_options.yaml ./
# Copy source code
COPY flutter_preset_app/lib ./lib

# Enable web and generate web scaffolding (since 'web' folder might not verify exist in repo)
RUN flutter config --enable-web
RUN flutter create --platforms=web .

# Get dependencies and build
RUN flutter pub get
RUN flutter build web --release

# Stage 2: Python Runtime
FROM python:3.12-slim
WORKDIR /app

# Install system dependencies for OpenCV
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 libsm6 libxrender1 libxext6 \
    && rm -rf /var/lib/apt/lists/*

# Install python dependencies
COPY preset_service/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy python code
COPY preset_service /app/preset_service

# Copy built flutter web files to the static folder
COPY --from=flutter_build /build/build/web /app/preset_service/static

# Expose port
EXPOSE 8000

# Run
CMD ["uvicorn", "preset_service.app:app", "--host", "0.0.0.0", "--port", "8000"]
