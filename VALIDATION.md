# Delivery validation

Environment: Linux, Flutter 3.32.8, Dart 3.8.1.

- `flutter analyze --no-pub`: passed, no issues.
- `flutter test --no-pub --reporter expanded`: passed, 8 tests.
- `flutter build web --release --no-pub --no-web-resources-cdn`: passed; final release compilation completed successfully.
- Visually inspected desktop (1440 × 1100) and mobile (390 × 844) renders with real bundled fonts, Material icons and artwork.

Tests cover:

1. Per-pet, per-day checklist isolation, toggle and save/reload through a mocked preferences store.
2. Deleting a pet cascades their associated records while preserving another pet's records.
3. Backup round-trip and rejection of unsupported versions or orphan records.
4. Mobile pet creation, dialog closure and task completion.
5. Desktop layout and navigation.
6. Creating health records and appointments, closing their forms and completing an appointment.
7–8. Desktop and mobile visual layout renders without framework exceptions.

The preference plugin's real Chrome storage and Android runtime were not exercised by these mocked tests. Android platform files are included, but an APK build, physical-device run and Play Store signing were not performed. Follow the README manual acceptance checklist on your computer. Screen previews contain test data only; the installed app starts empty.

The ZIP excludes build output, dependency caches, machine-specific SDK paths and IDE workspace files. Run setup_windows.bat first to resolve local dependencies and validate your installation.
