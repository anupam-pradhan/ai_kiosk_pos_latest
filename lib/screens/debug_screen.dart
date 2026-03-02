import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/debug_log_service.dart';

/// Debug overlay screen for viewing Stripe Terminal logs and device info
/// Access by triple-tapping the app bar or through debug menu
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final DebugLogService _debugService = DebugLogService();

  List<String> _logs = [];
  String _deviceInfo = 'Loading...';
  String _nfcStatus = 'Checking...';
  String _terminalStatus = 'Unknown';
  StreamSubscription<String>? _logSubscription;

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
    _loadNfcStatus();
    _startLogCollection();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final info = await DebugLogService.channel.invokeMethod('getDeviceInfo');
      if (mounted) {
        setState(() {
          _deviceInfo = info.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deviceInfo = 'Error: $e';
        });
      }
    }
  }

  Future<void> _loadNfcStatus() async {
    try {
      final result = await DebugLogService.channel.invokeMethod<Map>(
        'getNfcStatus',
      );
      if (mounted) {
        setState(() {
          _nfcStatus = result?['enabled'] == true ? '✅ Enabled' : '❌ Disabled';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _nfcStatus = 'Error: $e';
        });
      }
    }
  }

  void _startLogCollection() {
    // Load existing logs from the service
    _logs = List.from(_debugService.logs);

    // Listen for new logs from the centralized service
    _logSubscription = _debugService.logStream.listen((log) {
      if (mounted) {
        setState(() {
          _logs.add(log);
          if (_logs.length > 200) {
            _logs.removeAt(0);
          }
        });
      }
    });
  }

  void _copyLogsToClipboard() {
    final allLogs = _logs.join('\n');
    Clipboard.setData(
      ClipboardData(
        text:
            '''
DEVICE INFO:
$_deviceInfo

NFC STATUS: $_nfcStatus
TERMINAL STATUS: $_terminalStatus

LOGS:
$allLogs
''',
      ),
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logs copied to clipboard!')));
  }

  void _clearLogs() {
    _debugService.clearLogs();
    setState(() {
      _logs.clear();
    });
  }

  Future<void> _testTerminal() async {
    _debugService.log('🧪 Testing Terminal...');
    setState(() {
      _terminalStatus = 'Testing...';
    });

    try {
      final result = await DebugLogService.channel.invokeMethod(
        'prewarmupNfc',
        {},
      );
      if (mounted) {
        setState(() {
          _terminalStatus = result['status'] ?? 'Unknown';
        });
        _debugService.log('✅ Terminal test: ${result['status']}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _terminalStatus = 'Error: $e';
        });
        _debugService.log('❌ Terminal test failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Console'),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy logs',
            onPressed: _copyLogsToClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Clear logs',
            onPressed: _clearLogs,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Test Terminal',
            onPressed: _testTerminal,
          ),
        ],
      ),
      body: Container(
        color: Colors.black,
        child: Column(
          children: [
            // Device Info Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.grey[900],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📱 DEVICE INFO',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _deviceInfo,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            // Status Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.grey[850],
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📡 NFC Status',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _nfcStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💳 Terminal Status',
                          style: TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _terminalStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Logs Section
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        '📋 LOGS (${_logs.length}/${DebugLogService.maxLogs})',
                        style: TextStyle(
                          color: Colors.yellowAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _logs.isEmpty
                          ? Center(
                              child: Text(
                                'No logs yet. Try testing the terminal or making a payment.',
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              itemCount: _logs.length,
                              reverse: true,
                              itemBuilder: (context, index) {
                                final log = _logs[_logs.length - 1 - index];
                                Color logColor = Colors.white70;

                                // Color code logs
                                if (log.contains('error') ||
                                    log.contains('failed') ||
                                    log.contains('❌')) {
                                  logColor = Colors.redAccent;
                                } else if (log.contains('success') ||
                                    log.contains('✅') ||
                                    log.contains('initialized')) {
                                  logColor = Colors.greenAccent;
                                } else if (log.contains('warning') ||
                                    log.contains('⚠️')) {
                                  logColor = Colors.orangeAccent;
                                } else if (log.contains('SUNMI')) {
                                  logColor = Colors.cyanAccent;
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    log,
                                    style: TextStyle(
                                      color: logColor,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),

            // Help Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.grey[900],
              child: Text(
                'Tip: Copy logs and share with support if needed',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    super.dispose();
  }
}
