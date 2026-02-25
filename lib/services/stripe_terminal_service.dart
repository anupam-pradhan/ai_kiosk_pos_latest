import 'package:flutter/services.dart';

/// Service to manage Stripe Terminal Tap to Pay
/// Works with the native Android implementation using Stripe Terminal SDK 5.2.0
class StripeService {
  static const platform = MethodChannel('kiosk.stripe.terminal');
  static const eventChannel = EventChannel('kiosk.stripe.terminal.events');

  /// Initialize Stripe Terminal (already done in native code)
  static Future<void> initializeStripe({
    required String publishableKey,
    String? baseUrl,
  }) async {
    try {
      await platform.invokeMethod('initialize', {
        'publishableKey': publishableKey,
        'baseUrl': baseUrl,
      });
    } catch (e) {
      throw Exception('Failed to initialize Stripe: $e');
    }
  }

  /// Warm up NFC stack on app startup for faster payment processing
  /// This initializes the Stripe Terminal reader discovery in the background
  /// without blocking the UI. Called automatically when app launches, but can
  /// be called explicitly if needed.
  static Future<Map<String, dynamic>> prewarmupNfc() async {
    try {
      final result = await platform.invokeMethod<Map>('prewarmupNfc', {});
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      // Prewarmup failures are non-critical
      print('NFC prewarmup warning: $e');
      return {'status': 'PREWARMUP_FAILED', 'error': e.toString()};
    }
  }

  /// Prepare Tap to Pay reader
  static Future<Map<String, dynamic>> prepareTapToPay({
    required String baseUrl,
  }) async {
    try {
      final result = await platform.invokeMethod<Map>('prepareTapToPay', {
        'baseUrl': baseUrl,
      });
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      throw Exception('Failed to prepare Tap to Pay: $e');
    }
  }

  /// Start Tap to Pay payment
  static Future<Map<String, dynamic>> startTapToPay({
    required String baseUrl,
    required double amount,
    String? currency = 'USD',
  }) async {
    try {
      final result = await platform.invokeMethod<Map>('startTapToPay', {
        'baseUrl': baseUrl,
        'amount': (amount * 100).toInt(), // Convert to cents
        'currency': currency,
      });
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      throw Exception('Tap to Pay failed: $e');
    }
  }

  /// Request microphone permission for Tap to Pay
  static Future<bool> requestMicrophonePermission() async {
    try {
      final result = await platform.invokeMethod<bool>(
        'requestMicrophonePermission',
      );
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get NFC status
  static Future<Map<String, dynamic>> getNfcStatus() async {
    try {
      final result = await platform.invokeMethod<Map>('getNfcStatus');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      return {'enabled': false, 'error': e.toString()};
    }
  }

  /// Open NFC settings
  static Future<void> openNfcSettings() async {
    try {
      await platform.invokeMethod('openNfcSettings');
    } catch (e) {
      throw Exception('Failed to open NFC settings: $e');
    }
  }

  /// Listen to Stripe Terminal progress updates
  static Stream<Map<String, dynamic>> getTtpProgressStream() {
    return eventChannel.receiveBroadcastStream().map(
      (event) => Map<String, dynamic>.from(event ?? {}),
    );
  }
}
