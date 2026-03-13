import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'animated_splash.dart';
import 'config/app_config.dart';
import 'screens/kiosk_mode_selection_screen.dart';
import 'screens/kiosk_webview_screen.dart';
import 'services/kiosk_mode_service.dart';
import 'services/debug_log_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize debug log service FIRST to capture all native events
  DebugLogService().initialize();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  await _applyKioskSystemUi();
  runApp(const KioskApp());
}

Future<void> _applyKioskSystemUi() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
}

class KioskApp extends StatefulWidget {
  const KioskApp({super.key});

  @override
  State<KioskApp> createState() => _KioskAppState();
}

class _KioskAppState extends State<KioskApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyKioskSystemUi();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyKioskSystemUi();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MEGAPOS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC2410C)),
        useMaterial3: true,
      ),
      home: const KioskAppHome(),
    );
  }
}

/// Main app home that handles routing based on kiosk mode selection state
class KioskAppHome extends StatelessWidget {
  const KioskAppHome({super.key});

  @override
  Widget build(BuildContext context) {
    // Fixed-mode launch (no selection page), controlled by .env or --dart-define.
    if (!AppConfig.useModeSelection) {
      return AnimatedSplashScreen(
        duration: const Duration(milliseconds: 2000),
        child: KioskWebViewScreen(
          kioskUrl: AppConfig.fixedModeUrl,
          title: AppConfig.fixedModeTitle,
        ),
      );
    }

    return FutureBuilder<bool>(
      future: KioskModeService.isKioskModeSelected(),
      builder: (context, snapshot) {
        // While loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading MEGAPOS...'),
                ],
              ),
            ),
          );
        }

        // If kiosk mode was previously selected, navigate to webview
        if (snapshot.data == true) {
          return FutureBuilder<String?>(
            future: KioskModeService.getKioskModeType(),
            builder: (context, typeSnapshot) {
              return FutureBuilder<String?>(
                future: KioskModeService.getKioskModeUrl(),
                builder: (context, urlSnapshot) {
                  if (typeSnapshot.connectionState == ConnectionState.done &&
                      urlSnapshot.connectionState == ConnectionState.done &&
                      typeSnapshot.data != null &&
                      urlSnapshot.data != null) {
                    return KioskWebViewScreen(
                      kioskUrl: urlSnapshot.data!,
                      title: typeSnapshot.data!,
                    );
                  }

                  // Fallback to selection screen
                  return const KioskModeSelectionScreen();
                },
              );
            },
          );
        }

        // Show kiosk mode selection screen for the first time
        return AnimatedSplashScreen(
          duration: const Duration(milliseconds: 2000),
          child: const KioskModeSelectionScreen(),
        );
      },
    );
  }
}
