package com.alcyone.alcyone_mobile

import android.os.Bundle
import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterActivity

/**
 * Alcyone host activity.
 *
 * The critical job here is cookie configuration for authentication. Multica's
 * login is an OAuth / email-code round-trip: the session cookie is set by a
 * callback arriving from an external auth host, then read back on multica.ai.
 * Two Android WebView defaults break that flow:
 *
 *  1. Third-party cookies are OFF by default on Lollipop+ (API 21+). Without
 *     this the auth provider's cookie is dropped and the callback to multica.ai
 *     lands unauthenticated - the app appears to "log in successfully" yet
 *     reloads signed out.
 *  2. Without persistent cookies, closing the app discards the session and the
 *     user must re-authenticate on every launch.
 *
 * setAcceptThirdPartyCookies is a WebView *instance* method, and the WebView
 * belongs to the webview_flutter plugin rather than to this activity, so it is
 * not reachable from configureFlutterEngine. The durable fix is in Dart
 * (lib/main.dart) where the controller is owned; here we do the global,
 * activity-scoped half that only CookieManager exposes.
 */
class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Global, app-wide cookie policy. Persisted across launches, so a
        // completed login survives an app restart.
        CookieManager.getInstance().apply {
            setAcceptCookie(true)
            flush()
        }
    }
}
