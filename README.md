# reminder_hub

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# Google Drive backup setup (Android)

Google Sign-In on Android requires a Google Cloud **Web application OAuth client ID**. The current client ID is configured as the app's default. The Android app's OAuth client must also use package name `com.reminderhub.reminder_hub` and include the SHA-1 certificate fingerprint for the signing key used by that build (debug, release, and Play App Signing fingerprints may differ).

Example for a local debug run:

You can override the configured ID at build/run time with the `GOOGLE_SERVER_CLIENT_ID` Dart define if the Google OAuth client is changed.

The client ID is an identifier, not a client secret. If using Firebase `google-services.json` instead, configure its Gradle plugin and ensure the file contains the Web OAuth client entry (`client_type: 3`) rather than also supplying the Dart define.

## Android APK builds

For personal use, `flutter build apk --release` signs the release APK with the local Android debug key, so no production keystore setup is needed. This is not suitable for publishing, and reinstalling an APK signed with a different key over this one will fail; uninstall the old app first if needed.
