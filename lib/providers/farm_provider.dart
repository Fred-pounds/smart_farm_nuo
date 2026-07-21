import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/farm_data.dart';
import '../services/farm_service.dart';

enum FarmConnectionState { connecting, connected, error }

class FarmProvider extends ChangeNotifier {
  final FarmService _service = FarmService();

  FarmData _data = FarmData.initial;
  FarmConnectionState _connection = FarmConnectionState.connecting;
  String? _errorMessage;
  StreamSubscription<FarmData>? _sub;

  FarmData get data => _data;
  FarmConnectionState get connection => _connection;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _connection == FarmConnectionState.connected;

  FarmProvider() {
    _service.init();
    _sub = _service.stream.listen(
      (data) {
        _data = data;
        _connection = FarmConnectionState.connected;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (e) {
        _connection = FarmConnectionState.error;
        _errorMessage = e.toString();
        notifyListeners();
      },
    );
  }

  Future<void> setMode(String mode) async {
    try {
      await _service.setMode(mode);
    } catch (e) {
      _errorMessage = 'Failed to set mode: $e';
      notifyListeners();
    }
  }

  Future<void> setPump(bool on) async {
    try {
      await _service.setPump(on);
    } catch (e) {
      _errorMessage = 'Failed to set pump: $e';
      notifyListeners();
    }
  }

  Future<void> setThreshold(int value) async {
    try {
      await _service.setThreshold(value);
    } catch (e) {
      _errorMessage = 'Failed to set threshold: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
