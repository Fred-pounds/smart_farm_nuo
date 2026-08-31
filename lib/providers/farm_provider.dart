import 'dart:async';
import 'package:flutter/foundation.dart';
import '../logic/pump_command_machine.dart';
import '../logic/rain_outlook.dart';
import '../models/farm_data.dart';
import '../models/pump_command.dart';
import '../models/weather.dart';
import '../services/farm_service.dart';

enum FarmConnectionState { connecting, connected, error }

/// Bridges the farm stream to the UI, and owns the pump command lifecycle.
///
/// Two separate facts live here and must not be conflated:
///
/// * [data] — what the farm reports, including `pumpStatus`, the pump's
///   actual state as measured by the ESP32.
/// * [command] — how far the user's most recent request has travelled.
///
/// The rules for the second live in [PumpCommandMachine] as pure functions.
/// This class only supplies the clock and performs the writes.
class FarmProvider extends ChangeNotifier {
  final FarmService _service = FarmService();

  /// How often time-based command transitions are re-evaluated.
  static const Duration _tickInterval = Duration(milliseconds: 500);

  FarmData _data = FarmData.initial;
  FarmConnectionState _connection = FarmConnectionState.connecting;
  String? _errorMessage;
  StreamSubscription<FarmData>? _sub;

  PumpCommandState _command = PumpCommandState.idle;
  Timer? _ticker;

  String? _weatherPublicationNote;

  /// Why the controller's rain outlook is not currently being updated, or
  /// null when it is up to date. Surfaced so a silent third layer is visible
  /// rather than assumed to be working.
  String? get weatherPublicationNote => _weatherPublicationNote;

  FarmData get data => _data;
  FarmConnectionState get connection => _connection;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _connection == FarmConnectionState.connected;

  /// The in-flight pump command, if any. Never a substitute for
  /// `data.pumpStatus`.
  PumpCommandState get command => _command;

  /// Whether the pump would accept a command right now. The control surface
  /// uses this to disable itself, so the button and the rule never disagree.
  bool get canCommandPump => PumpCommandMachine.canAccept(
    current: _command,
    now: DateTime.now(),
    isAutomatic: _data.isAutomatic,
    isConnected: isConnected,
  );

  /// Why the pump cannot be commanded, or null if it can. Drives the
  /// explanation shown in place of the control.
  String? get pumpRefusalReason => PumpCommandMachine.refusalReason(
    current: _command,
    now: DateTime.now(),
    isAutomatic: _data.isAutomatic,
    isConnected: isConnected,
  );

  FarmProvider() {
    _service.init();
    _sub = _service.stream.listen(
      (data) {
        _data = data;
        _connection = FarmConnectionState.connected;
        _errorMessage = null;

        // The device just told us what the pump is really doing; that is the
        // only evidence that can settle a pending command.
        _command = PumpCommandMachine.deviceReported(
          current: _command,
          pumpStatus: data.pumpStatus,
          now: DateTime.now(),
        );
        _syncTicker();
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
      // Mode is app-owned configuration, not a device measurement: once the
      // write is acknowledged it is true, and adopting it immediately lets a
      // follow-up pump command see the new mode without waiting for the echo.
      _data = _data.copyWith(mode: mode);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to set mode: $e';
      notifyListeners();
    }
  }

  /// Requests a pump state change. This creates *intent* only.
  ///
  /// The pump is not considered changed until the ESP32 reports it, which
  /// arrives later through the farm stream. Refused requests never reach the
  /// backend.
  Future<void> requestPump(bool on) async {
    final requested = PumpCommandMachine.request(
      current: _command,
      desired: on,
      deviceState: _data.pumpStatus,
      now: DateTime.now(),
      isAutomatic: _data.isAutomatic,
      isConnected: isConnected,
    );
    _setCommand(requested);

    if (requested.phase != PumpCommandPhase.sending) return;

    try {
      await _service.setPump(on);
      _setCommand(
        PumpCommandMachine.writeSucceeded(
          current: _command,
          now: DateTime.now(),
        ),
      );
    } catch (e) {
      _setCommand(
        PumpCommandMachine.writeFailed(
          current: _command,
          now: DateTime.now(),
          error: e.toString(),
        ),
      );
    }
  }

  /// Hands the controller the rain outlook derived from [report].
  ///
  /// This closes the third layer of the irrigation decision: the ESP32 reads
  /// `/farm/weather/*` but has no network path to a forecast, so unless the
  /// app publishes, `rainExpected` stays false forever and rain delay never
  /// happens. Call this whenever the forecast changes.
  ///
  /// Safe to call often — [WeatherPublisher] suppresses redundant writes and
  /// decides on its own when a stale outlook must be retracted.
  Future<void> publishRainOutlook(WeatherReport? report) async {
    final decision = WeatherPublisher.decide(
      report: report,
      now: DateTime.now(),
      currentRainExpected: _data.rainExpected,
      currentProbability: _data.rainProbability,
    );

    _weatherPublicationNote = decision.skipReason;
    if (!decision.shouldWrite) {
      notifyListeners();
      return;
    }

    try {
      await _service.publishWeather(
        rainExpected: decision.rainExpected,
        rainProbability: decision.rainProbability,
      );
    } catch (e) {
      _weatherPublicationNote =
          'The forecast could not be sent to the controller, so it is '
          'irrigating on soil and air readings alone.';
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

  void _setCommand(PumpCommandState next) {
    _command = next;
    _syncTicker();
    notifyListeners();
  }

  /// Runs the ticker only while a phase can change with the passage of time,
  /// so an idle app is not waking up twice a second for nothing.
  void _syncTicker() {
    final needsClock =
        _command.phase == PumpCommandPhase.awaitingDevice ||
        _command.phase == PumpCommandPhase.confirmed ||
        _command.phase == PumpCommandPhase.rejected;

    if (needsClock) {
      _ticker ??= Timer.periodic(_tickInterval, (_) => _onTick());
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _onTick() {
    final next = PumpCommandMachine.tick(
      current: _command,
      now: DateTime.now(),
    );
    if (identical(next, _command)) return;

    _command = next;
    _syncTicker();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
