import 'dart:async';
import 'package:flutter/widgets.dart';
import 'sync_engine.dart';

class SyncScheduler with WidgetsBindingObserver {
  Timer? _timer;
  final SyncEngine _engine;
  final Duration interval;

  bool _disposed = false;

  SyncScheduler(this._engine, {this.interval = const Duration(minutes: 15)});

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _scheduleTimer();
  }

  void stop() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  bool get isRunning => _timer?.isActive == true;

  void _scheduleTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _syncIfSignedIn());
  }

  Future<void> _syncIfSignedIn() async {
    if (_disposed) return;
    try {
      await _engine.sync();
    } catch (e) {
      debugPrint('SyncScheduler: sync error — $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncIfSignedIn();
    }
  }
}
