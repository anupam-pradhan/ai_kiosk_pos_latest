import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage kiosk mode selection persistence
class KioskModeService {
  static const String _kioskModeKey = 'kiosk_mode_selected';
  static const String _kioskTypeKey = 'kiosk_mode_type';
  static const String _kioskUrlKey = 'kiosk_mode_url';

  /// Check if a kiosk mode has been previously selected
  static Future<bool> isKioskModeSelected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kioskModeKey) ?? false;
  }

  /// Get the previously selected kiosk mode type
  static Future<String?> getKioskModeType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kioskTypeKey);
  }

  /// Get the previously selected kiosk mode URL
  static Future<String?> getKioskModeUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kioskUrlKey);
  }

  /// Save the selected kiosk mode
  static Future<void> setKioskMode(String kioskType, String kioskUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kioskModeKey, true);
    await prefs.setString(_kioskTypeKey, kioskType);
    await prefs.setString(_kioskUrlKey, kioskUrl);
  }

  /// Clear the saved kiosk mode (for development/debugging)
  static Future<void> clearKioskMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kioskModeKey);
    await prefs.remove(_kioskTypeKey);
    await prefs.remove(_kioskUrlKey);
  }
}
