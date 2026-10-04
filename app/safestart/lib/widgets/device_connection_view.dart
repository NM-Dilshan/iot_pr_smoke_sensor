import 'package:flutter/material.dart';

import '../services/esp32_connection.dart';

/// Poll only while this route is visible and the app is in the foreground.
class DeviceConnectionView extends StatefulWidget {
  const DeviceConnectionView({
    super.key,
    this.connection,
    required this.builder,
  });
  final Esp32Connection? connection;
  final Widget Function(BuildContext, Esp32Connection) builder;
  @override
  State<DeviceConnectionView> createState() => _DeviceConnectionViewState();
}

class _DeviceConnectionViewState extends State<DeviceConnectionView>
    with WidgetsBindingObserver {
  late Esp32Connection _connection;
  bool _monitoring = false, _foreground = true;
  @override
  void initState() {
    super.initState();
    _connection = widget.connection ?? Esp32Connection.shared;
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didUpdateWidget(DeviceConnectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connection != widget.connection) {
      if (_monitoring) _connection.stopMonitoring();
      _monitoring = false;
      _connection = widget.connection ?? Esp32Connection.shared;
      _sync();
    }
  }

  void _sync() {
    final active = _foreground && TickerMode.valuesOf(context).enabled;
    if (active == _monitoring) return;
    _monitoring = active;
    if (active) {
      _connection.startMonitoring();
    } else {
      _connection.stopMonitoring();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_monitoring) _connection.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _connection,
    builder: (context, _) => widget.builder(context, _connection),
  );
}
