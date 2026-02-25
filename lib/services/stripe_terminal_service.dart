import 'package:flutter/services.dart';

/// Service to manage Stripe Terminal Tap to Pay
/// Works with the native Android implementation using Stripe Terminal SDK 5.2.0
class StripeService {
  static const platform = MethodChannel('kiosk.stripe.terminal');

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
  /// [terminalBaseUrl] - Your backend base URL for Stripe connection tokens
  /// [locationId] - Stripe Terminal location ID
  /// [isSimulated] - Whether to use simulated reader (debug only)
  static Future<Map<String, dynamic>> prepareTapToPay({
    required String terminalBaseUrl,
    required String locationId,
    bool isSimulated = false,
  }) async {
    try {
      final result = await platform.invokeMethod<Map>('prepareTapToPay', {
        'terminalBaseUrl': terminalBaseUrl,
        'locationId': locationId,
        'isSimulated': isSimulated,
      });
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      throw Exception('Failed to prepare Tap to Pay: $e');
    }
  }

  /// Start Tap to Pay payment
  /// [terminalBaseUrl] - Your backend base URL
  /// [clientSecret] - PaymentIntent client secret from your backend
  /// [locationId] - Stripe Terminal location ID
  /// [orderId] - Optional order ID for tracking
  /// [isSimulated] - Whether to use simulated reader (debug only)
  static Future<Map<String, dynamic>> startTapToPay({
    required String terminalBaseUrl,
    required String clientSecret,
    required String locationId,
    String? orderId,
    bool isSimulated = false,
  }) async {
    try {
      final result = await platform.invokeMethod<Map>('startTapToPay', {
        'terminalBaseUrl': terminalBaseUrl,
        'clientSecret': clientSecret,
        'locationId': locationId,
        'orderId': orderId,
        'isSimulated': isSimulated,
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
}
