# Filament Colorizer

A Flutter application for extracting and analyzing colors from 3D printing filament images using Google Gemini AI.

## Project Overview

This multi-platform app allows users to:
1. Import filament spool images (drag & drop or file picker)
2. Group images for batch processing
3. Process images through Gemini AI to extract color information
4. Export color data in various formats

## Tech Stack

- **Framework:** Flutter (SDK ^3.7.2)
- **State Management:** Riverpod (`flutter_riverpod`)
- **AI Integration:** Google Gemini (`google_generative_ai`)
- **Environment:** `flutter_dotenv` for API key management

## Project Structure

```
lib/
├── main.dart              # App entry point
├── models/                # Data models
│   ├── color_result.dart
│   ├── colorized_image.dart
│   ├── image_group.dart
│   ├── imported_image.dart
│   └── processing_status.dart
├── providers/             # Riverpod state providers
│   ├── export_provider.dart
│   ├── groups_provider.dart
│   ├── images_provider.dart
│   └── processing_provider.dart
├── screens/               # UI screens
│   ├── import_screen.dart
│   ├── grouping_screen.dart
│   ├── processing_screen.dart
│   └── export_screen.dart
└── services/              # Business logic
    ├── gemini_service.dart
    ├── file_service.dart
    ├── export_service.dart
    └── nano_banana_service.dart
```

## Setup

1. Copy `.env.example` to `.env`
2. Add your Gemini API key to `.env`:
   ```
   GEMINI_API_KEY=your_api_key_here
   ```
3. Run `flutter pub get`
4. Run `flutter run`

## Supported Platforms

- Windows
- macOS
- Android
- iOS
- Web

## Commands

```bash
# Install dependencies
flutter pub get

# Run app
flutter run

# Build for Windows
flutter build windows

# Build for Web
flutter build web

# Run tests
flutter test
```
