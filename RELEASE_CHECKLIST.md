# Release Checklist (Android APK)

Use this checklist before every production APK build.

## 1) Environment sanity

- Run `flutter doctor -v` and confirm no blocking Android toolchain issues.
- Use a stable Flutter channel and keep the same version across team devices.

## 2) Dependency sanity

- Run `flutter pub get`.
- Run `flutter pub outdated` and review critical plugin upgrades.
- Prefer maintained plugins. For classic Bluetooth in this project, use `flutter_bluetooth_serial_plus`.

## 3) Android compatibility

- Keep Gradle/AGP/Kotlin versions compatible with your Flutter version.
- If a plugin fails with `android:attr/lStar not found`, it is usually an old plugin compileSdk issue.
- This project contains a root Gradle safeguard to bump Android library modules to compile SDK 34.

## 4) Manifest and permissions

- Verify required Bluetooth permissions exist for Android 12+:
  - `BLUETOOTH_CONNECT`
  - `BLUETOOTH_SCAN`
- Keep legacy Bluetooth permissions for API <= 30 if needed:
  - `BLUETOOTH`
  - `BLUETOOTH_ADMIN`
- Keep location permissions only if your Bluetooth flow needs them.

## 5) App signing

- For production, create `android/keystore.properties` and provide:
  - `storeFile`
  - `storePassword`
  - `keyAlias`
  - `keyPassword`
- This project auto-uses release signing when `keystore.properties` exists.
- Without that file, build falls back to debug signing (good for local testing only).

## 6) Build and verify

- Build command:
  - `flutter build apk --release`
- Verify output exists:
  - `build/app/outputs/flutter-apk/app-release.apk`
- Install on a real device and test:
  - Bluetooth pairing
  - Device connection
  - Command send/receive behavior

## 7) If build fails

- Run clean cycle:
  - `flutter clean`
  - `flutter pub get`
  - `flutter build apk --release`
- If Android resource linking fails, inspect outdated plugins first.

## 8) Optional size optimization

- Analyze APK size:
  - `flutter build apk --release --analyze-size`
