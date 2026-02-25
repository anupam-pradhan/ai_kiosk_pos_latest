import 'package:flutter/services.dart';

/// Service to manage NFC and Stripe Terminal Tap to Pay integration
/// Provides unified interface for NFC reading with Stripe Terminal
class NFCTerminalService {
  static const platform = MethodChannel('kiosk.stripe.terminal');

  /// Warm up the NFC stack on app startup
  /// This should be called once when the app launches to pre-initialize
  /// the Stripe Terminal reader discovery in the background.
  /// Non-blocking and non-critical - failures are logged but ignored.
  static Future<void> initializeNfcOnStartup() async {
    try {
      final result = await platform.invokeMethod<Map>('prewarmupNfc', {});
      print('✅ NFC prewarmup started: ${result?['status']}');
    } catch (e) {
      // Prewarmup is non-critical - log but don't throw
      print('⚠️ NFC prewarmup warning (non-critical): $e');
    }
  }

  /// Check if NFC is available and enabled
  static Future<bool> isNfcAvailable() async {
    try {
      final result = await platform.invokeMethod<Map>('getNfcStatus');
      return result?['enabled'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Request microphone permission (required for Tap to Pay)
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

  /// Prepare Tap to Pay with proper initialization
  /// [terminalBaseUrl] - Your backend base URL for Stripe connection tokens
  /// [locationId] - Stripe Terminal location ID
  /// [isSimulated] - Whether to use simulated reader (debug only)
  static Future<bool> prepareTapToPay({
    required String terminalBaseUrl,
    required String locationId,
    bool isSimulated = false,
  }) async {
    try {
      await platform.invokeMethod('prepareTapToPay', {
        'terminalBaseUrl': terminalBaseUrl,
        'locationId': locationId,
        'isSimulated': isSimulated,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Process NFC payment using Stripe Terminal Tap to Pay
  /// Combines NFC card reading with Stripe payment processing
  /// [terminalBaseUrl] - Your backend base URL
  /// [clientSecret] - PaymentIntent client secret from your backend
  /// [locationId] - Stripe Terminal location ID
  /// [orderId] - Optional order ID for tracking
  /// [isSimulated] - Whether to use simulated reader (debug only)
  static Future<Map<String, dynamic>> processNFCPayment({
    required String terminalBaseUrl,
    required String clientSecret,
    required String locationId,
    String? orderId,
    bool isSimulated = false,
  }) async {
    try {
      // Request microphone permission first
      final hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        return {'success': false, 'error': 'Microphone permission denied'};
      }

      // Check NFC availability
      final nfcAvailable = await isNfcAvailable();
      if (!nfcAvailable) {
        return {
          'success': false,
          'error': 'NFC is not available on this device',
        };
      }

      // Prepare Tap to Pay
      final prepared = await prepareTapToPay(
        terminalBaseUrl: terminalBaseUrl,
        locationId: locationId,
        isSimulated: isSimulated,
      );
      if (!prepared) {
        return {'success': false, 'error': 'Failed to prepare Tap to Pay'};
      }

      // Start payment with NFC
      final result = await platform.invokeMethod<Map>('startTapToPay', {
        'terminalBaseUrl': terminalBaseUrl,
        'clientSecret': clientSecret,
        'locationId': locationId,
        'orderId': orderId,
        'isSimulated': isSimulated,
      });

      return Map<String, dynamic>.from(
        result ?? {'success': false, 'error': 'Unknown error'},
      );
    } catch (e) {
      return {'success': false, 'error': 'NFC Payment failed: $e'};
    }
  }

  /// Get NFC capability information
  static Future<Map<String, dynamic>> getNfcCapabilityInfo() async {
    try {
      final result = await platform.invokeMethod<Map>('getNfcStatus');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      return {'enabled': false, 'error': e.toString()};
    }
  }

  /// Open NFC settings on device
  static Future<void> openNfcSettings() async {
    try {
      await platform.invokeMethod('openNfcSettings');
    } catch (e) {
      throw Exception('Failed to open NFC settings: $e');
    }
  }
}
