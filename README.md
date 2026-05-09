# Traan (Raksha) - Women Safety App

Traan is a Flutter mobile application focused on personal safety features such as SOS messaging, emergency calling, safety resources, and crime-related awareness tools.

## What is implemented in this codebase

- Firebase-based authentication (email/password + Google sign-in)
- Firestore-backed user profile data (including emergency contacts)
- SOS flow that sends location-aware SMS via device messaging app
- One-tap emergency calling from the home screen
- Map view (embedded web map)
- Tools section with crime news feed and quick-access safety resources
- Fake call experience with multilingual scripted audio/text prompts

## Tech stack

- **Framework:** Flutter (Dart)
- **Backend services:** Firebase Auth, Cloud Firestore
- **Mobile integrations:** Telephony/SMS, geolocation, direct phone calling, permissions
- **Other integrations:** News API, webview, Google Maps Flutter package (dependency present)

## Project structure (high level)

- `/home/runner/work/traan/traan/lib/main.dart` - App bootstrap + Firebase init
- `/home/runner/work/traan/traan/lib/pages/` - Auth, profile, and main navigation screens
- `/home/runner/work/traan/traan/lib/Home/` - Home screen (SOS + helplines)
- `/home/runner/work/traan/traan/lib/tools/` - Tools tab + news fetch logic
- `/home/runner/work/traan/traan/lib/Map/` - Map screen
- `/home/runner/work/traan/traan/lib/models/` - Models + SOS service
- `/home/runner/work/traan/traan/assets/` - App images/audio/data assets

## Prerequisites

- Flutter SDK (Dart 3 compatible; project uses `sdk: >=3.0.0 <4.0.0`)
- Android Studio / Xcode toolchains for target platform
- Firebase project configured for Android/iOS (files already present in this repo)

## Setup

```bash
git clone https://github.com/Samaksh912/traan.git
cd traan
flutter pub get
flutter run
```

## Validation commands

```bash
flutter analyze
flutter test
```

## Configuration notes

- The code uses Firebase initialization via `lib/firebase_options.dart`.
- News fetching uses an API key in `lib/tools/fetchnews.dart`; replace with your own key for production.
- `pubspec.yaml` currently points `telephony` to a local Windows path. Update this dependency source to a valid package source/path for your environment before building.

## Contributors

- Samaksh Goel
- S Shreya
- Vaishnavi Amancharla
- Yuvika Gandhi
- Aditi S
