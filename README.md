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

## Authentication

Multica's login is an OAuth / email-code round-trip: it leaves for an external
auth host and returns via a callback to `multica.ai`. Two things had to be right
for the session to survive that trip:

1. **The whole round-trip stays in the WebView.** The shell only hands a link to
   the system browser for non-web schemes (`mailto:`, `tel:`, `intent:`, custom
   app links). Every `http(s)` navigation stays internal, so the callback sets
   the session cookie in the WebView's own store rather than the browser's.
   Pushing the auth host to Chrome made login look successful but left the app
   signed out on reload.

2. **Third-party cookies are on, and the session persists.** Android disables
   third-party cookies by default (API 21+), which silently breaks SSO
   callbacks. `_enableAuthCookies` in `lib/main.dart` turns them on via
   `AndroidWebViewCookieManager`, and `MainActivity.kt` enables and flushes
   cookies via `android.webkit.CookieManager` so the session also survives an
   app restart.

The navigation rule itself is a pure function in
`lib/src/navigation_policy.dart`, covered by `test/navigation_policy_test.dart`
(23 tests) using real identity-provider URLs — Google, Microsoft, Auth0, GitHub,
Apple, Descope — plus the callback URL. If a future change ever hands an
identity provider to the system browser again, the tests fail on CI rather than
on a user's phone.

## Tests

```bash
flutter test                                   # 25 tests
flutter test test/navigation_policy_test.dart  # the auth policy on its own
```

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
flutter test test/make_icon_test.dart               # assets/icon/alcyone_icon.png
flutter test test/make_icon_foreground_test.dart   # adaptive foreground (safe zone)
dart run flutter_launcher_icons                    # writes the mipmap resources
```

The mark reworks the existing Omni Eyes View language — an eye around a globe in
cyan `#00F6FF` — into a six-blade aperture that reads as an eye, a camera
shutter, and a fan-out of agents around a central orchestrator. Everything is
sized for a 48px home-screen render: bold strokes, solid pupil and orbiting
nodes, no hairlines.

## Project layout

```
lib/main.dart                       app shell: splash, WebView host, back nav, error view
lib/src/navigation_policy.dart      pure, tested URL-routing policy
android/app/src/main/kotlin/.../MainActivity.kt   persistent cookie configuration
test/navigation_policy_test.dart    23 tests pinning the auth behaviour
test/make_icon_test.dart            launcher icon generator
test/make_icon_foreground_test.dart adaptive-icon foreground generator
```

## License

MIT. Multica is a separate project by its respective authors and is neither
included nor affiliated with this shell — this app simply loads the public
`multica.ai` web app on your device.
