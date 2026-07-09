# BRIO

**Tu energía, tu ritmo — nutrición y entrenamiento en una sola app.**

BRIO is an all-in-one fitness application for the Spanish market that unifies **nutrition tracking**, **strength training**, and **cardio/GPS activities** in a single product. It pairs a Flutter mobile client with a Django REST backend built on Clean Architecture.

> The user-facing app is Spanish-first (English localization is planned). Source code, comments, and this documentation are in English.

---

## Features

- **Dashboard** — daily overview with concentric macro rings (calories, protein, carbs, fat), streak tracking, and personalized highlights.
- **Nutrition** — food diary with macro targets, barcode scanning (Open Food Facts), on-device nutrition-label OCR (ML Kit), custom foods, and reusable saved meals. Macro goals are historized by date, so each day is measured against the target that was in effect that day.
- **Strength training** — routines, live workout sessions with set logging, workout history, and a manual weekly schedule.
- **Cardio & GPS activities** — Strava-style live tracking with an OpenStreetMap map and route polyline (distance, pace, time, calories), plus a shareable PNG that combines the route trace with a photo from the camera or gallery.
- **Social** — add friends and share records, workouts, and meals.
- **Profile** — body metrics and BMI, macro configuration, unit preferences, and a light / dark / system theme selector.

## Tech stack

**Mobile — Flutter (Dart, SDK 3.9+)**
- Riverpod (state management), go_router (navigation)
- Dio (HTTP), flutter_secure_storage (JWT), Hive (local cache)
- fl_chart (charts), google_fonts
- geolocator + flutter_map + latlong2 (GPS tracking & maps)
- mobile_scanner + google_mlkit_text_recognition (barcode & label OCR)
- flutter_local_notifications, image_picker, share_plus, gal, path_provider

**Backend — Django 6 + Django REST Framework**
- SimpleJWT (authentication), drf-spectacular (OpenAPI schema)
- Pillow (image generation), requests (Open Food Facts integration)
- waitress + whitenoise (production serving)

## Architecture

Both sides follow a layered Clean Architecture separating domain, application, infrastructure, and presentation concerns.

```
BRIO/
├── brio/            # Flutter mobile client
│   └── lib/
│       ├── core/        # theme, config, network, router, notifications, settings
│       ├── shared/      # reusable widgets
│       └── features/    # dashboard, nutrition, training, auth, profile, social
│                        #   each: data / domain / presentation
└── brio-backend/    # Django REST API
    └── apps/            # users, nutrition, training, social
        └── <app>/       # domain / application / infrastructure / presentation
```

## Getting started

### Backend

```bash
cd brio-backend
python -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

### Mobile app

```bash
cd brio
flutter pub get
flutter run
```

The backend base URL is centralized in `brio/lib/core/config/app_config.dart` (emulator vs. physical device vs. production).

## Deployment

Production runs on a Raspberry Pi using **waitress + Caddy** with HTTPS via DuckDNS. The mobile client selects the production API through `app_config.dart`.

## Theme

Light theme with the BRIO brand blue `#329FFC`. Dark and system modes are supported at runtime; the selected mode is persisted locally.
