import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'animated_splash.dart';
import 'config/app_config.dart';
import 'screens/kiosk_mode_selection_screen.dart';
import 'screens/kiosk_webview_screen.dart';
import 'services/kiosk_mode_service.dart';
import 'services/nfc_terminal_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // If .env file doesn't exist, continue with defaults
    if (kDebugMode) {
      print('Warning: .env file not found, using defaults');
    }
  }

  // Print configuration in debug mode
  AppConfig.printConfig();

  // Initialize Stripe Terminal with prewarmup for faster payment sheet opening
  try {
    // Stripe Terminal is initialized in native code (Android/KioskApplication.kt)
    if (kDebugMode) {
      print('Stripe Terminal SDK 5.2.0 initialized');
    }

    // Start NFC prewarmup in background on app startup
    // This initializes the reader discovery early so NFC is ready when user needs it
    NFCTerminalService.initializeNfcOnStartup();
  } catch (e) {
    if (kDebugMode) {
      print('Warning: Stripe initialization: $e');
    }
  }

  runApp(const KioskApp());
}

class KioskApp extends StatelessWidget {
  const KioskApp({super.key});

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
