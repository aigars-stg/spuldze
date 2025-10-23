# Spuldze

A Flutter application for monitoring Latvia electricity prices in real-time.

## Description

Spuldze (Latvian for "light bulb") is a mobile application designed to help users track electricity prices in Latvia. The app provides real-time pricing information to help users make informed decisions about their energy consumption.

## Features

- Real-time electricity price monitoring
- Support for both Latvian and English languages
- Material 3 design with dark mode support
- iOS and Android support

## Getting Started

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK (3.0.0 or higher)
- iOS development: Xcode 14.0 or higher, iOS 13.0+
- Android development: Android Studio, Android SDK 21+

### Installation

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Run `flutter run` to start the app

### Localization

The app supports:
- English (en)
- Latvian (lv)

Localization files are located in `lib/l10n/`.

## Project Structure

```
lib/
├── main.dart           # App entry point
├── models/            # Data models
├── services/          # Business logic and API services
├── screens/           # App screens
├── widgets/           # Reusable widgets
├── utils/             # Utility functions
└── l10n/              # Localization files
```

## Platform Configuration

### iOS
- Minimum version: iOS 13.0
- Supported orientations: Portrait, Landscape

### Android
- Minimum SDK: 21 (Android 5.0)
- Target SDK: Latest
- Permissions: Internet access

## License

This project is private and not licensed for public use.
