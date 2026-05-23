import 'dart:async';

import 'package:flutter/services.dart';

import '../debug_log_service.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal() {
    _channel.setMethodCallHandler(_handleNativeEvent);
  }

  static const MethodChannel _channel = MethodChannel('kiosk.printer.v2');
  final DebugLogService _debugService = DebugLogService();
  final StreamController<Map<String, dynamic>> _jobController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get jobStream => _jobController.stream;

  Future<dynamic> _handleNativeEvent(MethodCall call) async {
    if (call.method == 'onPrinterJobChanged' && call.arguments is Map) {
      final event = Map<String, dynamic>.from(call.arguments as Map);
      _jobController.add(event);
      final state = event['state']?.toString() ?? '';
      final message = event['message']?.toString() ?? '';
      _debugService.log('Printer job ${event['jobId'] ?? ''}: $state $message');
    }
    return null;
  }

  Future<Map<String, dynamic>> handleWebCommand(Map<String, dynamic> payload) {
    final type = payload['type']?.toString();
    switch (type) {
      case 'PRINTER_STATUS':
        return getPrinterStatusResult();
      case 'PRINTER_SCAN':
        return scanPrintersDetailed();
      case 'PRINTER_SAVE':
        return savePrinter(
          address: payload['address']?.toString() ?? '',
          printerType:
              payload['printerType']?.toString() ??
              payload['typeName']?.toString() ??
              payload['connectionType']?.toString() ??
              'bluetooth',
          name: payload['name']?.toString(),
        );
      case 'PRINTER_FORGET':
        return forgetPrinter();
      case 'PRINTER_TEST':
        return testPrintResult();
      case 'PRINTER_PRINT':
        return printRaw(
          payload['data']?.toString() ?? '',
          copies: _intValue(payload['copies'], fallback: 1),
          jobId: payload['jobId']?.toString(),
          jobType: payload['jobType']?.toString(),
        );
      case 'PRINTER_DRAWER':
        return openDrawer();
      case 'PRINTER_OPEN_SETTINGS':
        return openPrinterSettings(payload['target']?.toString() ?? 'app');
      default:
        return Future.value(
          _failure('UNKNOWN_COMMAND', 'Unknown printer command'),
        );
    }
  }

  Future<Map<String, dynamic>> scanPrintersDetailed() async {
    return _invoke('printerScan');
  }

  Future<Map<String, dynamic>> savePrinter({
    required String address,
    required String printerType,
    String? name,
  }) async {
    return _invoke('printerSave', {
      'address': address,
      'printerType': printerType,
      if (name != null && name.isNotEmpty) 'name': name,
    });
  }

  Future<Map<String, dynamic>> forgetPrinter() async {
    return _invoke('printerForget');
  }

  Future<Map<String, dynamic>> getPrinterStatusResult() async {
    return _invoke('printerStatus');
  }

  Future<Map<String, dynamic>> getPrinterStatus() async {
    final result = await getPrinterStatusResult();
    final status = result['status'];
    if (status is Map) return Map<String, dynamic>.from(status);
    return _emptyStatus();
  }

  Future<Map<String, dynamic>> printRaw(
    String base64Data, {
    int copies = 1,
    String? jobId,
    String? jobType,
  }) async {
    return _invoke('printerPrint', {
      'data': base64Data,
      'copies': copies,
      if (jobId != null && jobId.isNotEmpty) 'jobId': jobId,
      if (jobType != null && jobType.isNotEmpty) 'jobType': jobType,
    });
  }

  Future<Map<String, dynamic>> openDrawer() async {
    return _invoke('printerDrawer');
  }

  Future<Map<String, dynamic>> testPrintResult() async {
    return _invoke('printerTest');
  }

  Future<Map<String, dynamic>> openPrinterSettings(String target) async {
    return _invoke('printerOpenSettings', {'target': target});
  }

  Future<Map<String, dynamic>> requestBluetoothPermissions() async {
    try {
      final result = await DebugLogService.channel.invokeMethod<dynamic>(
        'requestBluetoothPermissions',
      );
      final granted = result is Map && result['granted'] == true;
      final status = await getPrinterStatus();
      return granted
          ? _success(status: status)
          : _failure(
              'BLUETOOTH_PERMISSION_DENIED',
              'Bluetooth permission was denied',
              status: status,
            );
    } on PlatformException catch (e) {
      return _failure(
        'BLUETOOTH_PERMISSION_DENIED',
        e.message ?? 'Bluetooth permission request failed',
      );
    }
  }

  Future<Map<String, dynamic>> _invoke(
    String method, [
    Map<String, dynamic>? args,
  ]) async {
    try {
      final result = await _channel.invokeMethod<dynamic>(method, args ?? {});
      if (result is Map) return Map<String, dynamic>.from(result);
      return _success(status: await getPrinterStatus());
    } on PlatformException catch (e) {
      return _failure(
        e.code.isNotEmpty ? e.code : 'PRINTER_DISCONNECTED',
        e.message ?? 'Printer operation failed',
      );
    }
  }

  int _intValue(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Map<String, dynamic> _success({Map<String, dynamic>? status}) {
    return {
      'ok': true,
      'jobId': '',
      'state': 'idle',
      'errorCode': '',
      'message': 'OK',
      'durationMs': 0,
      'status': status ?? _emptyStatus(),
    };
  }

  Map<String, dynamic> _failure(
    String code,
    String message, {
    Map<String, dynamic>? status,
  }) {
    return {
      'ok': false,
      'jobId': '',
      'state': 'failed',
      'errorCode': code,
      'code': code,
      'message': message,
      'error': message,
      'durationMs': 0,
      'status': status ?? _emptyStatus(),
    };
  }

  Map<String, dynamic> _emptyStatus() {
    return {
      'connected': false,
      'state': 'none',
      'name': '',
      'address': '',
      'type': '',
      'lastPrinterName': '',
      'lastPrinterAddress': '',
      'lastPrinterType': '',
      'bluetoothAvailable': false,
      'bluetoothEnabled': false,
      'bluetoothPermissionGranted': false,
      'locationPermissionGranted': false,
      'usbPermissionGranted': true,
      'printerStatusAvailable': false,
      'printerStatusMessage': '',
      'printerStatusIssues': const [],
      'printerStatusCheckedAt': 0,
      'paperEnd': false,
      'paperNearEnd': false,
      'coverOpen': false,
      'cutterError': false,
      'printerOffline': false,
      'mechanicalError': false,
      'printingStopped': false,
      'feedButtonPressed': false,
      'unrecoverableError': false,
      'autoRecoverableError': false,
    };
  }
}
