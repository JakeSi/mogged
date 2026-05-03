# mogged

iOS face scanning app using MediaPipe face landmarks to score facial features.

## Requirements

- Xcode 16+
- iOS 17.6+ device (camera required — simulator shows preview mode only)
- CocoaPods

## Setup

**1. Install dependencies**

```bash
pod install
```

**2. Add Firebase config**

Download `GoogleService-Info.plist` from the [Firebase Console](https://console.firebase.google.com) and place it at `mogged/GoogleService-Info.plist`. This file is gitignored — do not commit it.

**3. Open the workspace**

```bash
open mogged.xcworkspace
```

Always open `.xcworkspace`, not `.xcodeproj`.

**4. Build and run**

Select a physical device and run. The simulator shows a static preview — the live camera scan requires a real device.

## Architecture

```
mogged/
├── App/            # Entry point, analytics
├── Camera/         # AVFoundation capture session
├── Vision/         # MediaPipe face landmark detection
├── Scoring/        # Metric calculation and aggregation
├── Features/       # SwiftUI screens (Home, Scan, Results)
├── Models/         # SwiftData models
└── DesignSystem/   # Typography, theme, shared components
```

## Dependencies

| Package | Purpose |
|---|---|
| MediaPipeTasksVision | Face landmark detection |
| FirebaseAnalytics | Usage analytics |
