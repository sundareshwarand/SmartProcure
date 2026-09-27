# SmartProcure — Phase 1 frontend scaffold

This repository contains the Phase 1 Flutter frontend scaffold for SmartProcure (SIH 26032).

What is included:
- Riverpod-based state management skeleton
- GoRouter navigation
- Dio API service layer
- Mock repository for demo data
- Localization-ready structure (EN/HI/TA)
- Theme/design system with government-style colors
- Reusable widgets (GovernmentCard, PrimaryButton, LoadingState)
- Role-based routing foundation

Run (requires Flutter SDK):

```bash
flutter pub get
flutter analyze
flutter run -d emulator-5554   # or your Android device
```

Notes:
- This is Phase 1: scaffold and foundations. Replace `Env.apiBaseUrl` and mock repository with real API implementations when backend is available.
