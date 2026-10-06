# MediGuide

MediGuide is a Flutter healthcare app with a FastAPI backend for user authentication, doctor discovery, and appointment workflows.

## Project Layout

- `lib/` - Flutter application, screens, models, widgets, and API services
- `backend/` - FastAPI application and PostgreSQL connection helpers
- `test/` - Flutter widget tests

## Requirements

- Flutter SDK with Dart 3.13 or newer
- Python 3.10 or newer
- PostgreSQL

## Configuration

Copy `.env.example` to `.env` and provide the PostgreSQL connection values and a strong `SECRET_KEY`. The `.env` file is intentionally ignored by Git.

## Run Locally

Install the Flutter dependencies and start the app:

```bash
flutter pub get
flutter run
```

Install the backend dependencies and start the API from the repository root:

```bash
pip install -r backend/requirements.txt
uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

## Use the App Outside Your Local Network

The app defaults to `http://127.0.0.1:8000` for local development. To connect
from another network, the backend needs a public HTTPS URL. For a temporary
free test URL, keep your computer and backend running, install
[Cloudflare Tunnel](https://developers.cloudflare.com/tunnel/downloads/), then
run in a second terminal:

```bash
cloudflared tunnel --url http://localhost:8000
```

Cloudflare prints a temporary `https://....trycloudflare.com` URL. Pass that
URL into Flutter without a trailing slash:

```bash
flutter run --dart-define=API_BASE_URL=https://your-temporary-url.trycloudflare.com
```

For an Android APK, use the same define while building:

```bash
flutter build apk --dart-define=API_BASE_URL=https://your-temporary-url.trycloudflare.com
```

The tunnel URL changes when the tunnel is restarted, and the URL stops working
when the tunnel or backend stops. Anyone who obtains the URL can reach the
public API; use this temporary tunnel only for testing, not with real patient
data. A hosted backend requires a public database and its credentials to be
configured as hosting-provider environment variables.

## Deploy a Stable Test Backend to Render

The `render.yaml` Blueprint provisions the API and a separate PostgreSQL database.
It uses the Render Postgres internal connection URL and generates a private JWT
secret. The API initializes the required schema and a demo doctor catalogue at
startup. It does not copy local users, appointments, or health records.
The diagnostic comparison catalogue also contains explicitly labelled sample
Rajshahi facilities and example prices; these are for UI demonstration only,
not verified offers. Doctor search returns matching specialties ordered by
consultation fee, while diagnostic offers are ordered from lowest to highest.

Push the repository to GitHub, sign in to [Render](https://dashboard.render.com),
choose **New > Blueprint**, connect this repository, review the resources, and
deploy the Blueprint. Render provides a stable `https://...onrender.com` API
URL. Build a new APK with that URL:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://your-api.onrender.com
```

This Blueprint uses Render's free web-service and Postgres plans for testing.
Free web services can sleep when idle, and free Postgres databases expire after
30 days. Do not use this setup with real patient data; select paid plans and
configure appropriate privacy, backup, and operational controls before any
production or sensitive-data use.

Run validation with:

```bash
flutter analyze
flutter test
```

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
