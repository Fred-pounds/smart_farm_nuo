import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/farm_data.dart';

class FarmService {
  static final FarmService _instance = FarmService._internal();
  factory FarmService() => _instance;
  FarmService._internal();

  final _db = FirebaseDatabase.instance.ref('farm');

  // Streams for each field so we can merge them into one FarmData stream.
  late final StreamController<FarmData> _controller =
      StreamController<FarmData>.broadcast();

  FarmData _current = FarmData.initial;
  final List<StreamSubscription> _subs = [];
  bool _initialized = false;

  Stream<FarmData> get stream => _controller.stream;

  void init() {
    if (_initialized) return;
    _initialized = true;

    _subs.add(_db.child('mode').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val != null) {
        _current = _current.copyWith(mode: val.toString());
        _controller.add(_current);
      }
    }));

    _subs.add(_db.child('pump').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val != null) {
        _current = _current.copyWith(pump: val as bool? ?? false);
        _controller.add(_current);
      }
    }));

    _subs.add(_db.child('pumpStatus').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val != null) {
        _current = _current.copyWith(pumpStatus: val as bool? ?? false);
        _controller.add(_current);
      }
    }));

    _subs.add(_db.child('soilMoisture').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val != null) {
        _current = _current.copyWith(soilMoisture: (val as num).toInt());
        _controller.add(_current);
      }
    }));

    _subs.add(_db.child('threshold').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val != null) {
        _current = _current.copyWith(threshold: (val as num).toInt());
        _controller.add(_current);
      }
    }));
  }

  Future<void> setMode(String mode) =>
      _db.child('mode').set(mode);

  Future<void> setPump(bool on) =>
      _db.child('pump').set(on);

  Future<void> setThreshold(int value) =>
      _db.child('threshold').set(value);

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _controller.close();
    _initialized = false;
  }
}
