/// Navigation policy for the Alcyone WebView shell.
///
/// Kept as a pure, testable function so the authentication behaviour can be
/// proven by tests rather than only by manual QA on a device.
///
/// THE AUTH BUG THIS PREVENTS
/// --------------------------
/// Multica's login is an OAuth / email-code round-trip: the browser leaves
/// multica.ai for an external identity host, then returns via a callback to
/// `https://multica.ai/...`. The original shell allowlisted only multica.ai
/// hosts and pushed every other URL to the *system browser*. The callback
/// therefore set its session cookie in Chrome's cookie jar instead of the
/// WebView's own store, so the app reloaded still signed out - login appeared
/// to succeed and then silently did not stick.
///
/// The rule is therefore: EVERY http(s) URL stays inside the WebView. Only
/// schemes that genuinely cannot render in a WebView are handed off.
library;

/// Schemes that must always be handed to an external handler.
///
/// `intent:` is Android's inter-app escape hatch; the rest are device schemes.
/// None of them can be rendered by a WebView, so blocking them without a
/// hand-off would dead-end the user on a blank screen.
///
/// This set documents intent — [resolveNavAction] is written as an allowlist
/// on `http`/`https`, which is strictly safer than a denylist: an unrecognised
/// scheme is handed off rather than silently swallowed.
const Set<String> kNonWebSchemes = <String>{
  'mailto',
  'tel',
  'sms',
  'geo',
  'intent',
  'market',
  'whatsapp',
  'tg',
};

/// What the shell should do with a URL.
enum NavAction {
  /// Render it in the WebView.
  internal,

  /// Hand it to the system (external browser or installed app).
  external,
}

/// Decides whether [url] renders inside the shell or is handed to the system.
///
/// Returns [NavAction.internal] for all `http`/`https` traffic — including
/// third-party identity hosts — so that an OAuth callback lands back in this
/// WebView and writes the session cookie to the store the app actually reads.
NavAction resolveNavAction(String url) {
  final uri = Uri.tryParse(url);

  // Unparseable URLs are passed through rather than dropped: preventing them
  // would be strictly worse than letting the WebView try.
  if (uri == null) return NavAction.internal;

  final scheme = uri.scheme.toLowerCase();

  // Web traffic always stays internal. This branch must come first: it is the
  // entire fix for the lost-login-session bug.
  if (scheme == 'http' || scheme == 'https') return NavAction.internal;

  // A custom app scheme (googleusercontent://, slack://, ...) needs the
  // installed app that registered it.
  if (scheme.isNotEmpty) return NavAction.external;

  // Relative or schemeless URL: same-document navigation, keep it internal.
  return NavAction.internal;
}
