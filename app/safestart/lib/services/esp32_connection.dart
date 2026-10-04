import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'esp32_status.dart';

typedef DeviceRequest = Future<http.Response> Function(
  Uri uri,
  String method,
  Duration timeout,
);

/// One verified address shared by Dashboard, Vehicle and Office.
class Esp32Connection extends ChangeNotifier {
  Esp32Connection({
    DeviceRequest? request,
    Future<List<String>> Function()? resolveHostname,
    Future<List<String>> Function()? localCandidates,
    DateTime Function()? now,
    this.requestTimeout = const Duration(seconds: 2),
    this.probeTimeout = const Duration(milliseconds: 400),
    this.pollInterval = const Duration(milliseconds: 2500),
  }) : _requestOverride = request,
       _resolveHostname = resolveHostname ?? _resolveLocalHostname,
       _localCandidates = localCandidates ?? _androidCandidates,
       _now = now ?? DateTime.now;
  static final shared = Esp32Connection();
  static const hostname = 'safestart.local';
  static const _network = MethodChannel('safestart/network');
  final DeviceRequest? _requestOverride;
  final Future<List<String>> Function() _resolveHostname, _localCandidates;
  final DateTime Function() _now;
  final Duration requestTimeout, probeTimeout, pollInterval;
  final Set<http.Client> _clients = {};
  final Map<Timer, VoidCallback> _pendingTimeouts = {};
  Uri? _address;
  bool _connected = false, _disposed = false;
  int _epoch = 0,
      _failures = 0,
      _monitors = 0,
      _foreground = 0,
      _monitorEpoch = 0;
  DateTime? _retryAfter;
  Future<Esp32Status>? _fetch;
  Timer? _timer;
  bool get connected => _connected;
  Uri? get activeAddress => _address;

  static void _log(String message) {
    if (kDebugMode) debugPrint('SafeStart connection: $message');
  }

  static bool isPrivateAddress(String host) {
    final ip = InternetAddress.tryParse(host);
    if (ip == null || ip.type != InternetAddressType.IPv4) return false;
    final bytes = ip.rawAddress;
    return bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168);
  }

  static Future<List<String>> _resolveLocalHostname() async {
    try {
      final addresses = await _network.invokeListMethod<String>(
        'resolveHostname',
      );
      _log('Native resolution $hostname: ${addresses ?? []}');
      return (addresses ?? []).where(isPrivateAddress).toList();
    } on MissingPluginException {
      return [];
    }
  }

  static Future<List<String>> _androidCandidates() async {
    try {
      return (await _network.invokeListMethod<String>('localCandidates')) ?? [];
    } on MissingPluginException {
      return [];
    }
  }

  Future<T> _bounded<T>(Future<T> operation, Duration duration, int epoch) {
    if (_disposed || epoch != _epoch) {
      // Consume a late underlying error even when cancellation won the race.
      unawaited(operation.then<void>((_) {}, onError: (Object error) {}));
      return Future<T>.error(
        const Esp32Exception('SafeStart discovery was cancelled.'),
      );
    }
    final completion = Completer<T>();
    late Timer timer;
    timer = Timer(duration, () {
      _pendingTimeouts.remove(timer);
      completion.completeError(
        TimeoutException('SafeStart request timed out.'),
      );
    });
    _pendingTimeouts[timer] = () {
      if (!completion.isCompleted) {
        completion.completeError(
          const Esp32Exception('SafeStart discovery was cancelled.'),
        );
      }
    };
    unawaited(
      operation.then<void>(
        (value) {
          timer.cancel();
          _pendingTimeouts.remove(timer);
          if (!completion.isCompleted) completion.complete(value);
        },
        onError: (Object error, StackTrace trace) {
          timer.cancel();
          _pendingTimeouts.remove(timer);
          if (!completion.isCompleted) completion.completeError(error, trace);
        },
      ),
    );
    return completion.future;
  }

  void _cancelWork() {
    _epoch++;
    _fetch = null;
    for (final entry in _pendingTimeouts.entries.toList()) {
      entry.key.cancel();
      entry.value();
    }
    _pendingTimeouts.clear();
    for (final client in _clients.toList()) {
      client.close();
    }
  }

  Future<http.Response> _request(
    Uri uri,
    String method,
    Duration timeout, {
    int? epoch,
  }) async {
    if (_requestOverride != null) {
      return _bounded(
        _requestOverride(uri, method, timeout),
        timeout,
        epoch ?? _epoch,
      );
    }
    final client = http.Client();
    _clients.add(client);
    try {
      final request = http.Request(method, uri)..followRedirects = false;
      return await _bounded(
        client.send(request).then(http.Response.fromStream),
        timeout,
        epoch ?? _epoch,
      );
    } finally {
      _clients.remove(client);
      client.close();
    }
  }

  static Esp32Status verify(http.Response response) {
    if (response.statusCode != 200) {
      throw FormatException('HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Expected status JSON object');
    }
    for (final field in [
      'vehicleReading',
      'vehicleStatus',
      'vehicleTestState',
      'vehicleTestResult',
      'vehicleResultReading',
      'vehicleTestActive',
      'officeReading',
      'officeStatus',
      'officeTestState',
      'officeTestResult',
      'officeResultReading',
      'officeTestActive',
      'gate',
      'wifi',
    ]) {
      if (!data.containsKey(field)) throw FormatException('Missing $field');
    }
    final status = Esp32Status.fromJson(data);
    if (![
      'IDLE',
      'COUNTDOWN',
      'SAMPLING',
      'COMPLETED',
    ].contains(status.officeTestState)) {
      throw FormatException(
        'Invalid officeTestState: ${status.officeTestState}',
      );
    }
    if (![
          'NOT_TESTED',
          'PENDING',
          'SAFE',
          'CAUTION',
          'DANGER',
        ].contains(status.officeTestResult) ||
        (status.officeTestState == 'COMPLETED' &&
            (!['SAFE', 'CAUTION', 'DANGER'].contains(status.officeTestResult) ||
                status.officeTestActive))) {
      throw FormatException(
        'Invalid officeTestResult/officeTestActive for ${status.officeTestState}',
      );
    }
    if (!['SAFE', 'CAUTION', 'DANGER'].contains(status.vehicleStatus) ||
        !['SAFE', 'CAUTION', 'DANGER'].contains(status.officeStatus) ||
        !['OPEN', 'CLOSED'].contains(status.gate) ||
        !['CONNECTED', 'DISCONNECTED'].contains(status.wifi)) {
      throw const FormatException('Invalid device status/gate/wifi');
    }
    return status;
  }

  void _online(Uri address) {
    final changed = !_connected || _address != address;
    if (changed) _log('Verified base URL: $address');
    _address = address;
    _connected = true;
    _failures = 0;
    _retryAfter = null;
    if (changed && !_disposed) notifyListeners();
  }

  void _offline() {
    final changed = _connected;
    _connected = false;
    _address = null;
    if (changed && !_disposed) notifyListeners();
  }

  Future<Esp32Status?> _probe(String host, int epoch, Duration timeout) async {
    if ((host != hostname && !isPrivateAddress(host)) ||
        _epoch != epoch ||
        _disposed) {
      return null;
    }
    final address = Uri(scheme: 'http', host: host);
    final url = address.resolve('/status');
    _log('Testing GET $url');
    try {
      final response = await _request(url, 'GET', timeout, epoch: epoch);
      _log('$url HTTP ${response.statusCode}');
      final status = verify(response);
      if (_epoch != epoch || _disposed) return null;
      return status;
    } catch (error) {
      final detail = error is FormatException
          ? error.message
          : error is SocketException
          ? error.message
          : error is TimeoutException
          ? error.message
          : 'request failed';
      _log('$url failed (${error.runtimeType}): $detail');
      return null;
    }
  }

  Future<Esp32Status> fetchStatus({bool monitor = false}) async {
    if (_disposed) {
      throw const Esp32Exception('SafeStart connection is closed.');
    }
    if (!monitor) _foreground++;
    try {
      var operation = _fetch;
      if (operation == null) {
        operation = _findStatus(_epoch);
        _fetch = operation;
        unawaited(
          operation.then<void>(
            (_) {
              if (identical(_fetch, operation)) _fetch = null;
            },
            onError: (Object error) {
              if (identical(_fetch, operation)) _fetch = null;
            },
          ),
        );
      }
      return await operation;
    } finally {
      if (!monitor) _foreground--;
    }
  }

  Future<Esp32Status> _findStatus(int epoch) async {
    final cached = _address;
    if (cached != null) {
      final status = await _probe(cached.host, epoch, requestTimeout);
      if (status != null) {
        _online(cached);
        return status;
      }
      if (epoch != _epoch) {
        throw const Esp32Exception('SafeStart discovery was cancelled.');
      }
      _offline();
    }
    if (_retryAfter != null && _now().isBefore(_retryAfter!)) {
      throw const Esp32Exception(
        'SafeStart device is offline. Reconnecting automatically.',
      );
    }
    final seen = <String>{if (cached != null) cached.host};
    // Try the same URL reachable in Chrome before relying on native resolution.
    if (seen.add(hostname)) {
      final status = await _probe(hostname, epoch, requestTimeout);
      if (status != null) {
        _online(Uri(scheme: 'http', host: hostname));
        return status;
      }
    }
    try {
      final resolved = await _bounded(
        _resolveHostname(),
        requestTimeout,
        epoch,
      );
      _log('Resolved $hostname candidates: $resolved');
      for (final host in resolved) {
        if (!isPrivateAddress(host) || !seen.add(host)) continue;
        final status = await _probe(host, epoch, requestTimeout);
        if (status != null) {
          _online(Uri(scheme: 'http', host: host));
          return status;
        }
      }
    } catch (error) {
      _log('Native resolution $hostname failed (${error.runtimeType})');
    }
    if (epoch != _epoch || _disposed) {
      throw const Esp32Exception('SafeStart discovery was cancelled.');
    }
    List<String> candidates = [];
    try {
      candidates = (await _bounded(_localCandidates(), requestTimeout, epoch))
          .where(isPrivateAddress)
          .where((host) => seen.add(host))
          .take(508)
          .toList();
    } catch (_) {
      /* Network unavailable or no local interfaces. */
    }
    Esp32Status? found;
    var index = 0;
    // At most 12 concurrent harmless probes, stopping when one device verifies.
    Future<void> worker() async {
      while (found == null &&
          index < candidates.length &&
          epoch == _epoch &&
          !_disposed) {
        final host = candidates[index++];
        final value = await _probe(host, epoch, probeTimeout);
        if (value != null && found == null) {
          found = value;
          _online(Uri(scheme: 'http', host: host));
        }
      }
    }

    await Future.wait(
      List.generate(math.min(12, candidates.length), (_) => worker()),
    );
    if (found != null) return found!;
    if (epoch == _epoch && !_disposed) {
      _offline();
      _failures++;
      _retryAfter = _now().add(
        Duration(seconds: math.min(60, 10 * (1 << math.min(_failures - 1, 3)))),
      );
    }
    throw const Esp32Exception(
      'Unable to communicate with the SafeStart device. Check that the ESP32 and phone are connected to the same Wi-Fi network.',
    );
  }

  Future<http.Response> sendStart({required bool office}) async {
    // Never replay a POST after a timeout: hardware may already have accepted it.
    _foreground++;
    try {
      await fetchStatus();
      final address = _address;
      if (address == null) {
        throw const Esp32Exception('SafeStart device is offline.');
      }
      try {
        final response = await _request(
          address.resolve(office ? '/office/start' : '/vehicle/start'),
          'POST',
          requestTimeout,
        );
        if (response.statusCode != 200 && response.statusCode != 409) {
          _offline();
        }
        return response;
      } catch (_) {
        _offline();
        rethrow;
      }
    } finally {
      _foreground--;
    }
  }

  void startMonitoring() {
    if (_disposed) return;
    if (++_monitors == 1) unawaited(_tick(++_monitorEpoch));
  }

  Future<void> _tick(int monitorEpoch) async {
    try {
      await fetchStatus(monitor: true);
    } catch (_) {
      /* Offline is visible. */
    }
    if (_monitors > 0 && !_disposed && monitorEpoch == _monitorEpoch) {
      _timer = Timer(pollInterval, () => unawaited(_tick(monitorEpoch)));
    }
  }

  void stopMonitoring() {
    if (_monitors == 0) return;
    if (--_monitors == 0) {
      _monitorEpoch++;
      _timer?.cancel();
      _timer = null;
      if (_foreground == 0) {
        _cancelWork();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _cancelWork();
    super.dispose();
  }
}
