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
pip install fastapi uvicorn psycopg2-binary bcrypt PyJWT python-dotenv
uvicorn backend.main:app --reload
```

Run validation with:

```bash
flutter analyze
flutter test
```

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
