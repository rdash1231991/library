# Flutter Preset App

This Flutter app talks to the backend in `preset_service/`:

- Create preset from 1 photo (`POST /preset`) → save JSON preset locally
- Apply preset to another photo (`POST /apply`) → preview + share/save output

## Backend

Run the backend first (from repo root):

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r preset_service/requirements.txt
uvicorn preset_service.app:app --reload --host 0.0.0.0 --port 8000
```

## App

From `flutter_preset_app/`:

```bash
flutter pub get
flutter run
```

## Run everything with Docker (local web URL)

From the repo root:

```bash
docker compose up --build
```

- Backend: `http://localhost:8000`
- Web app: `http://localhost:8080`

## Base URL (important)

- Android emulator: `http://10.0.2.2:8000`
- iOS simulator: `http://localhost:8000`
- Chrome/web (same computer): `http://localhost:8000`
- Real device: `http://<your-laptop-LAN-IP>:8000`

You can change this in the app under **Settings**.

