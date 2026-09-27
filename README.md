# Alcyone

**A native Android shell for [Multica](https://multica.ai).**

Alcyone gives your existing Multica workspace a real Android app — icon on the
home screen, splash screen, fullscreen, hardware back navigation, pull-to-refresh,
native file upload and camera for attachments, external links in your real
browser, and a proper offline/retry screen.

## What this is (and is not)

**This is NOT a clone of Multica's code.** It is a native shell that loads the
real, live `multica.ai` web app in a hardened, chrome-free WebView.

| | |
|---|---|
| **Your workspace** | Real Multica Cloud — same account, same agents, same issues, comments and history |
| **Your data** | Stays in Multica Cloud. Nothing is forked, re-hosted, or re-branded |
| **The UI inside** | Multica's own responsive web app, not a ported native codebase |
| **The shell** | Genuinely native — Flutter, custom splash, Material 3, edge-to-edge |

Because it loads the live app rather than a copy, you get Multica's latest
features the moment they ship. The trade-off is that the layout inside is
Multica's responsive web design rather than a purpose-built native UI.

## Features

- Custom animated splash with handoff to the live board
- Edge-to-edge fullscreen, dark theme by default
- Hardware back walks Multica's own history; double-tap at root to exit
- Pull-to-refresh with haptic feedback
- Top loading-progress bar
- Native attachment picker + camera via WebView intents
- External links (docs, GitHub, OAuth) open in the real browser
- Network-failure screen with retry, never a blank white page
- HTTPS-only: cleartext traffic is disabled in the network security config

## Requirements

- Android 6.0 (API 23) or newer
- A Multica account and network access

## Install

Grab the APK from the releases page and install it on your device (allow
"install unknown apps" when prompted), then log in with your normal Multica
credentials.

## Build from source

Requires the Flutter SDK and the Android toolchain (JDK 17, Android SDK
platform 35, build-tools 35).

```bash
flutter pub get
flutter build apk --release --target-platform android-arm64
```

The APK lands at `build/app/outputs/flutter-apk/app-release.apk`.

> The build deliberately does **not** pin an `ndkVersion` — this app compiles no
> native C/C++ code, and leaving it unset stops the toolchain from downloading an
> unnecessary multi-gigabyte NDK.

## Regenerate the launcher icon

```bash
flutter test test/make_icon_test.dart
```

Writes `assets/icon/alcyone_icon.png` (1024×1024).

## Project layout

```
lib/main.dart              app shell: splash, WebView host, back nav, error view
android/app/               Gradle project (ndkVersion intentionally unset)
test/make_icon_test.dart   launcher-icon generator
```

## License

MIT. Multica is a separate project by its respective authors and is neither
included nor affiliated with this shell — this app simply loads the public
`multica.ai` web app on your device.
