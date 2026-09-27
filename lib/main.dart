import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'src/navigation_policy.dart';

const String kAppName = 'Alcyone';
const String kDefaultUrl = 'https://multica.ai';
const String kPrefsKeyUrl = 'alcyone.base_url';
const String kPrefsKeyTheme = 'alcyone.theme_mode';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0B0D10),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const AlcyoneApp());
}

class AlcyoneApp extends StatefulWidget {
  const AlcyoneApp({super.key});

  @override
  State<AlcyoneApp> createState() => _AlcyoneAppState();
}

class _AlcyoneAppState extends State<AlcyoneApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(kPrefsKeyTheme) ?? 'dark';
    if (!mounted) return;
    setState(() {
      _themeMode = switch (stored) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
    });
  }

  Future<void> _setTheme(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kPrefsKeyTheme, mode.name);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: Shell(
        themeMode: _themeMode,
        onThemeChanged: _setTheme,
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5865F2),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0B0D10) : const Color(0xFFF7F8FA),
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      }),
    );
  }
}

/// The app shell: a splash screen that hands off to the live Multica web app.
class Shell extends StatefulWidget {
  const Shell({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  WebViewController? _controller;
  String _baseUrl = kDefaultUrl;
  bool _booting = true;
  int _progress = 0;
  String? _fatalError;
  bool _pulling = false;
  DateTime _lastBackPress = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(kPrefsKeyUrl);
    if (mounted) {
      setState(() {
        _baseUrl = (stored != null && stored.isNotEmpty) ? stored : kDefaultUrl;
      });
    }
    _initWebView();
  }

  void _initWebView() {
    // AUTH FIX: the base WebViewController has no cookie API, but the Android
    // platform controller does. Build the controller from Android creation
    // params, then enable third-party cookies - Android disables them by
    // default (API 21+), which breaks the OAuth/email-code round-trip because
    // the auth provider's cookie gets dropped and the callback lands signed out.
    final controller = WebViewController.fromPlatformCreationParams(
      AndroidWebViewControllerCreationParams(),
    );
    _enableAuthCookies(controller);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0B0D10))
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/131.0.0.0 Mobile Safari/537.36 AlcyoneShell/1.0',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _fatalError = null);
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() {
                _booting = false;
                _progress = 0;
              });
            }
          },
          onWebResourceError: (err) {
            if (!err.isForMainFrame.orTrue) return;
            if (mounted) {
              setState(() {
                _booting = false;
                _progress = 0;
                _fatalError = err.description;
              });
            }
          },
          onNavigationRequest: (req) async {
            // AUTH FIX: policy lives in lib/src/navigation_policy.dart so it
            // can be unit-tested. Every http(s) URL - including third-party
            // identity hosts - stays in this WebView, so the OAuth callback
            // writes its session cookie to the store this app actually reads.
            if (resolveNavAction(req.url) == NavAction.external) {
              _openExternally(req.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    _controller = controller;
    controller.loadRequest(Uri.parse(_baseUrl));
  }

  /// AUTH FIX: enable third-party cookies on the Android WebView.
  ///
  /// Android disables third-party cookies by default (API 21+). Multica's
  /// login round-trips through an external auth host, so without this the
  /// provider's cookie is discarded and the callback back to multica.ai lands
  /// unauthenticated - the symptom being "login succeeds, then the app is
  /// still signed out". This is a no-op on non-Android platforms.
  void _enableAuthCookies(WebViewController controller) {
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      // ignore: unawaited_futures
      AndroidWebViewCookieManager(
        AndroidWebViewCookieManagerCreationParams
            .fromPlatformWebViewCookieManagerCreationParams(
          const PlatformWebViewCookieManagerCreationParams(),
        ),
      ).setAcceptThirdPartyCookies(platform, true).catchError((_) {});
    }
  }

  Future<void> _openExternally(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) _toast('No app can open that link');
      }
    } catch (_) {
      if (mounted) _toast('Could not open link');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  Future<void> _reload() async {
    setState(() {
      _fatalError = null;
      _booting = true;
    });
    await _controller?.loadRequest(Uri.parse(_baseUrl));
  }

  Future<void> _refresh() async {
    if (_pulling) return;
    setState(() => _pulling = true);
    HapticFeedback.selectionClick();
    try {
      await _controller?.reload();
    } finally {
      if (mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        setState(() => _pulling = false);
      }
    }
  }

  Future<void> _handleBack() async {
    final canGoBack = _controller != null && await _controller!.canGoBack();
    if (canGoBack) {
      await _controller!.goBack();
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastBackPress) < const Duration(seconds: 2)) {
      await SystemNavigator.pop();
    } else {
      _lastBackPress = now;
      _toast('Press back again to exit $kAppName');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: Stack(
          children: [
            if (_controller != null && _fatalError == null)
              Positioned.fill(child: _buildWebView()),
            if (_booting && _fatalError == null)
              const Positioned.fill(child: _SplashScreen()),
            if (_fatalError != null)
              Positioned.fill(
                child: _ErrorView(error: _fatalError!, onRetry: _reload),
              ),
            if (_progress > 0 && _progress < 100)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _ProgressBar(value: _progress / 100),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebView() {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF5865F2),
      backgroundColor: Theme.of(context).colorScheme.surface,
      displacement: 28,
      edgeOffset: MediaQuery.of(context).padding.top,
      child: WebViewWidget(controller: _controller!),
    );
  }
}

extension on bool? {
  bool get orTrue => this ?? true;
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: value, end: value),
        duration: const Duration(milliseconds: 180),
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: 2.5,
          backgroundColor: Colors.transparent,
          valueColor: const AlwaysStoppedAnimation(Color(0xFF5865F2)),
        ),
      ),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    return Container(
      color: const Color(0xFF0B0D10),
      child: Center(
        child: FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.86, end: 1.0).animate(
              CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF5865F2), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5865F2).withValues(alpha: 0.42),
                        blurRadius: 32,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.hub_rounded,
                    size: 46,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  kAppName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'connected to Multica',
                  style: TextStyle(
                    color: Color(0xFF7A8391),
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0D10),
      padding: const EdgeInsets.symmetric(horizontal: 34),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: const Color(0xFF5865F2).withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.wifi_tethering_off_rounded,
                size: 36,
                color: Color(0xFF5865F2),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              "Can't reach Multica",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF7A8391), fontSize: 13),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 19),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF5865F2),
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
