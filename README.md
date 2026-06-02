# Navavishkar Navigation Enabled System (NNES)

Cross-platform indoor and campus navigation system built with Flutter and Dart.

NNES combines graph-based routing, sensor-aided positioning, QR marker anchoring, and image-based recognition to provide reliable navigation in GPS-challenging environments such as office and lab buildings.

## Overview

NNES is designed for indoor-first guidance where traditional map navigation is not enough.  
The app supports users navigating across office/lab spaces using multiple complementary signals:

- GPS + graph routing for outdoor/large-area movement
- Indoor graph navigation with room-level nodes
- QR marker-based position correction
- Visual lab/location recognition (OCR + feature matching + embeddings)
- Sensor-assisted continuity using heading and steps

## Key Features

- Real-time route computation using shortest-path logic (Dijkstra-based)
- Indoor and hybrid navigation modes
- QR marker scan and room-anchor navigation flow
- Image-assisted lab detection pipeline with fallback strategies
- BLE and Wi-Fi scan support for indoor positioning diagnostics
- Voice navigation prompts via text-to-speech
- Multi-platform Flutter targets: Android, iOS, Web, Windows, Linux, macOS

## Tech Stack

| Component | Technology |
|---|---|
| Framework | Flutter |
| Language | Dart (SDK `>=3.0.0 <4.0.0`) |
| Navigation/Positioning | geolocator, flutter_compass, pedometer, sensors_plus |
| Wireless | flutter_blue_plus (BLE), wifi_scan |
| Vision & ML | mobile_scanner, google_mlkit_text_recognition, tflite_flutter, image, dartcv4/opencv_dart |
| Voice Guidance | flutter_tts |
| UI | Material Design, google_fonts |
| Tooling | flutter_lints, flutter_launcher_icons |

## Architecture and Project Structure

The app follows a feature-first organization with shared core modules:

```text
lib/
├── core/
│   ├── models/          # Graph models and shared entities
│   ├── services/        # Image recognition and shared services
│   ├── theme/           # App theme
│   └── utils/           # Path engines (indoor/hybrid routing)
├── features/
│   ├── home/            # Landing and home screens
│   ├── navigation/      # GPS/indoor/hybrid navigation screens + painters
│   ├── positioning/     # BLE, Wi-Fi, sensor fusion, marker scanning
│   ├── localization/    # Localization services
│   ├── est_location/    # Estimated location logic and UI
│   └── ui/              # Shared UI flows/pages
└── main.dart

assets/
├── data/                # office_map.json and map data
├── images/              # Branding and UI assets
├── office_dataset/      # Reference location/lab images
└── models/              # TFLite model assets
```

## Installation

### Prerequisites

- Flutter SDK installed and configured
- Dart SDK (compatible with project constraints)
- Android Studio / Xcode / Chrome (based on your target platform)

### Steps

```bash
git clone <your-repository-url>
cd nnes_app
flutter pub get
flutter run
```

To run on a specific target:

```bash
flutter run -d android
flutter run -d chrome
flutter run -d windows
```

## How to Use

1. Launch the app.
2. Open the home/landing flow.
3. Choose one of the navigation modes:
   - GPS Navigation
   - Indoor Navigation
   - Hybrid Navigation
   - Marker/Visual assisted flows
4. Select source and destination (or scan marker where applicable).
5. Follow visual and voice guidance prompts.

## Assets and Data Requirements

Ensure these paths are present and correctly populated:

- `assets/data/office_map.json`
- `assets/office_dataset/TIH Photos/`
- `assets/models/` (TFLite model files)
- `assets/images/`

If asset paths are changed, update `pubspec.yaml` accordingly.

## Utility Scripts

- `tools/generate_qr_codes.py`  
  Generates QR marker images for marker-based navigation anchors.

## Development Notes

- Main app entry: `lib/main.dart`
- Theme setup: `lib/core/theme/app_theme.dart`
- Path engines: `lib/core/utils/path_engine.dart`, `lib/core/utils/hybrid_path_engine.dart`
- Image recognition: `lib/core/services/image_recognition_service.dart`

## Current Status

NNES is a functional prototype with broad feature coverage for indoor navigation workflows.  
Further improvements can focus on:

- stronger test coverage,
- tighter data/model path consistency,
- deeper BLE/Wi-Fi calibration,
- and CI automation for analyze/test/build.

## Contact

For project collaboration or support, add your contact details here:

- Name:
- Email:
- LinkedIn:
- GitHub:
