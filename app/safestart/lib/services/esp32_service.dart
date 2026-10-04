import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import 'esp32_connection.dart';
import 'esp32_status.dart';
export 'esp32_status.dart';

class Esp32Service {
  Esp32Service({
    this.client,
    this.requestTimeout = const Duration(seconds: 2),
    Esp32Connection? connection,
  }) : _connection =
           connection ?? (client == null ? Esp32Connection.shared : null);
  // Default hostname also used by explicitly injected test transports.
  static const String baseUrl = 'http://safestart.local';
  final Esp32Connection? _connection;
  final http.Client? client;
  final Duration requestTimeout;
  Future<http.Response> _request(bool start, {bool office = false}) async {
    try {
      final test = office ? 'office' : 'vehicle';
      final uri = Uri.parse('$baseUrl/${start ? '$test/start' : 'status'}');
      final response = _connection != null
          ? await _connection.sendStart(office: office)
          : await (start
                    ? (client?.post(uri) ?? http.post(uri))
                    : (client?.get(uri) ?? http.get(uri)))
                .timeout(requestTimeout);
      if (start && response.statusCode == 409) {
        throw Esp32Exception(
          'A ${office ? 'Office' : 'Vehicle'} test is already running. Wait for it to finish before retrying.',
        );
      }
      if (response.statusCode != 200) {
        throw Esp32Exception(
          'SafeStart device ${start ? 'rejected the start command' : 'status request failed'} (HTTP ${response.statusCode}).',
        );
      }
      return response;
    } on TimeoutException {
      throw const Esp32Exception(
        'SafeStart device request timed out. Check the Wi-Fi connection and try again.',
      );
    } on Esp32Exception {
      rethrow;
    } catch (_) {
      throw const Esp32Exception(
        'Unable to communicate with the SafeStart device. Check that the ESP32 and phone are connected to the same Wi-Fi network.',
      );
    }
  }

  Future<void> startVehicleTest() => _startTest(office: false);
  Future<void> startOfficeTest() => _startTest(office: true);

  Future<void> _startTest({required bool office}) async {
    final response = await _request(true, office: office);
    // START returns an acknowledgement, not the GET /status schema.
    final dynamic acknowledgement;
    try {
      acknowledgement = jsonDecode(response.body);
    } catch (_) {
      throw const Esp32Exception(
        'Invalid start response from the SafeStart device.',
      );
    }
    if (acknowledgement is! Map<String, dynamic>) {
      throw const Esp32Exception(
        'Invalid start response from the SafeStart device.',
      );
    }
    if (acknowledgement['success'] != true) {
      throw Esp32Exception(
        'SafeStart device rejected the ${office ? 'Office' : 'Vehicle'} start command.',
      );
    }
  }

  Future<Esp32Status> getStatus() async {
    if (_connection != null) return _connection.fetchStatus();
    final response = await _request(false);
    try {
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw const FormatException(
          'Invalid status root: expected JSON object',
        );
      }
      return Esp32Status.fromJson(data);
    } on FormatException catch (error) {
      final diagnostic = 'GET /status: ${error.message}';
      if (kDebugMode) debugPrint(diagnostic);
      throw Esp32Exception(
        'Invalid JSON or status response from the SafeStart device.',
        diagnostic: diagnostic,
      );
    }
  }
}
