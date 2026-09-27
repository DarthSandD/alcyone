// Proves the authentication fix in lib/src/navigation_policy.dart.
//
// The bug: the shell allowlisted only multica.ai and pushed every other URL to
// the system browser, so the OAuth / email-code callback wrote its session
// cookie to Chrome's cookie jar instead of the WebView's. Login appeared to
// succeed, then the app reloaded signed out.
//
// These tests pin the exact behaviour that prevents it. They are deliberately
// written around real-world identity-provider URLs rather than synthetic ones,
// so a regression in scheme handling fails here rather than on a user's phone.

import 'package:alcyone_mobile/src/navigation_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('auth round-trip stays inside the WebView', () {
    // THE REGRESSION THAT MATTERS MOST: these must all stay internal. If any
    // one is handed to the system browser, the session cookie is written to
    // the wrong store and login silently fails to stick.
    const authHosts = <String>[
      'https://accounts.google.com/o/oauth2/v2/auth?client_id=123',
      'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
      'https://auth0.com/authorize?audience=multica',
      'https://github.com/login/oauth/authorize?client_id=abc',
      'https://appleid.apple.com/auth/authorize',
      'https://login.descope.com/api/v1/auth/authorize',
    ];

    for (final url in authHosts) {
      test('keeps $url internal', () {
        expect(
          resolveNavAction(url),
          NavAction.internal,
          reason: 'handing an identity provider to the system browser breaks '
              'the login session (the original bug)',
        );
      });
    }

    test('keeps the OAuth callback back into Multica internal', () {
      // The callback is the moment the session cookie gets written. If this
      // is handed off, the user lands in Chrome and the app stays signed out.
      expect(
        resolveNavAction('https://multica.ai/auth/callback?code=abc123&state=xyz'),
        NavAction.internal,
      );
    });

    test('keeps the app itself and its API internal', () {
      expect(resolveNavAction('https://multica.ai'), NavAction.internal);
      expect(resolveNavAction('https://www.multica.ai/board'), NavAction.internal);
      expect(resolveNavAction('https://app.multica.ai/dash'), NavAction.internal);
      expect(resolveNavAction('https://api.multica.ai/v1/issues'), NavAction.internal);
    });

    test('keeps plain http internal (no silent https upgrade breakage)', () {
      expect(resolveNavAction('http://localhost:8080/health'), NavAction.internal);
    });

    test('is case-insensitive about the scheme', () {
      expect(resolveNavAction('HTTPS://MULTICA.AI/board'), NavAction.internal);
    });
  });

  group('non-web schemes hand off to the system', () {
    const handoffs = <String>[
      'mailto:support@multica.ai',
      'tel:+15551234567',
      'sms:+15551234567',
      'geo:37.7749,-122.4194',
      'intent://scan/#Intent;scheme=zxing;end',
      'market://details?id=com.multica.app',
      'whatsapp://send?text=hi',
      'tg://resolve?domain=multica',
    ];

    for (final url in handoffs) {
      test('hands $url off', () {
        expect(
          resolveNavAction(url),
          NavAction.external,
          reason: 'these cannot render in a WebView; blocking them without a '
              'hand-off would dead-end the user on a blank screen',
        );
      });
    }
  });

  group('unknown custom app schemes hand off, never swallow', () {
    // Allowlist semantics: an unrecognised scheme is handed to the system
    // rather than silently prevented, so a new deep link cannot brick a flow.
    test('hands a custom scheme off', () {
      expect(
        resolveNavAction('someapp://deep/link/123'),
        NavAction.external,
      );
    });

    test('hands an unknown scheme off rather than swallowing it', () {
      expect(resolveNavAction('weirdscheme://x'), NavAction.external);
    });
  });

  group('relative and malformed URLs never break the shell', () {
    test('keeps a relative URL internal', () {
      expect(resolveNavAction('/dashboard/board'), NavAction.internal);
      expect(resolveNavAction('#/issues/42'), NavAction.internal);
    });

    test('does not throw on an unparseable URL', () {
      // Preventing these would be strictly worse than letting the WebView try.
      expect(() => resolveNavAction('http://[malformed'), returnsNormally);
      expect(resolveNavAction('http://[malformed'), NavAction.internal);
    });

    test('does not throw on an empty URL', () {
      expect(resolveNavAction(''), NavAction.internal);
    });
  });
}
