# Habit Challenge Tracker

Production-ready **local-first Habit Tracker** built with Flutter.

## What it does (v1)

- Create a **Challenge** with a duration (30/60/custom), start date, habits, and optional baseline metrics.
- Daily **one-page checklist**:
  - Single tap = **Done (green)**
  - Double tap = **Not Done (red)**
  - Long press = **Reset (neutral)**
- **Calendar progress** with color-coded days (green/red/gray) via `table_calendar`.
- **Share progress card** as an image (Story 1080×1920, Square 1080×1080) via `RepaintBoundary` + `share_plus`.
- **Local notifications** per habit (enable/disable, time change reschedules) via `flutter_local_notifications`.
- No backend. “Continue as Guest” (local-only).

## Tech stack

- **Flutter + Dart**
- **State**: Riverpod (`flutter_riverpod`)
- **DB**: Drift + SQLite (`drift`, `sqlite3_flutter_libs`)
- **Routing**: `go_router`
- **Calendar**: `table_calendar`
- **Notifications**: `flutter_local_notifications` (+ timezone setup)
- **Share**: `share_plus`
- **Date formatting**: `intl`

## Project structure

```
lib/
  main.dart
  app.dart
  core/
    theme/
    utils/
    constants/
  data/
    db/
    repositories/
  domain/
    models/
    services/
  features/
    onboarding/
    home/
    create_challenge/
    checklist/
    calendar/
    share/
  widgets/
```

## Setup

```bash
flutter pub get
```

## Run

```bash
flutter run
```

## Demo data (quick testing)

Run with a seed toggle:

```bash
flutter run --dart-define=DEMO_DATA=true
```

Then on the empty Home state, tap **Seed demo data**.

## Notifications testing

### Android

- Ensure the app is installed and launched once.
- Enable reminders from **Checklist → Reminders**.
- On Android 13+, grant the **POST_NOTIFICATIONS** permission when prompted.
- For exact scheduling, Android may require allowing exact alarms depending on OS settings.

### iOS

- Run on a simulator/device.
- The first time you enable a reminder, iOS prompts for notification permission.
- Verify delivery in Notification Center.

## Tests

```bash
flutter test
```

## Docker (easy deployment)

Docker is best suited for deploying the **Flutter web build** (mobile builds aren’t “run” in Docker).

### Run with docker-compose

```bash
docker compose up --build
```

Open `http://localhost:8080`.

### Run with plain docker

```bash
docker build -t habit-challenge-tracker .
docker run --rm -p 8080:80 habit-challenge-tracker
```

## Notes

- All data is stored locally in SQLite via Drift.
- Challenge window = `startDate .. startDate + durationDays - 1`.
