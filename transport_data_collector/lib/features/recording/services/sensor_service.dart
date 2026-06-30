import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

import '../models/sensor_manifest.dart';
import '../models/sensor_sample.dart';

class SensorService {
  SensorService() {
    _start();
  }

  final _controller = StreamController<SensorSample>.broadcast();
  final _window = _SensorRateWindow();
  final _subscriptions = <StreamSubscription<dynamic>>[];

  GyroscopeEvent? _latestGyro;
  MagnetometerEvent? _latestMag;
  double? _latestPressure;
  var _barometerAvailable = false;
  var _magnetometerAvailable = false;
  var _gyroscopeAvailable = false;
  var _accelerometerAvailable = false;

  Stream<SensorSample> get sampleStream => _controller.stream;

  SensorManifest get manifest {
    return SensorManifest(
      accelerometer: SensorInfo(
        available: _accelerometerAvailable,
        observedHz: _window.hzFor(_SensorKind.accelerometer),
      ),
      gyroscope: SensorInfo(
        available: _gyroscopeAvailable,
        observedHz: _window.hzFor(_SensorKind.gyroscope),
      ),
      magnetometer: SensorInfo(
        available: _magnetometerAvailable,
        observedHz: _window.hzFor(_SensorKind.magnetometer),
      ),
      barometer: SensorInfo(
        available: _barometerAvailable,
        observedHz: _window.hzFor(_SensorKind.barometer),
      ),
    );
  }

  void _start() {
    _subscriptions.add(
      gyroscopeEventStream(samplingPeriod: SensorInterval.normalInterval).listen((event) {
        _gyroscopeAvailable = true;
        _latestGyro = event;
        _window.mark(_SensorKind.gyroscope);
      }, onError: (_) => _gyroscopeAvailable = false),
    );

    _subscriptions.add(
      magnetometerEventStream(samplingPeriod: SensorInterval.normalInterval).listen((event) {
        _magnetometerAvailable = true;
        _latestMag = event;
        _window.mark(_SensorKind.magnetometer);
      }, onError: (_) => _magnetometerAvailable = false),
    );

    _subscriptions.add(
      barometerEventStream(samplingPeriod: SensorInterval.normalInterval).listen((event) {
        _barometerAvailable = true;
        _latestPressure = event.pressure;
        _window.mark(_SensorKind.barometer);
      }, onError: (_) => _barometerAvailable = false),
    );

    _subscriptions.add(
      accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen((event) {
        _accelerometerAvailable = true;
        _window.mark(_SensorKind.accelerometer);
        final gyro = _latestGyro;
        final mag = _latestMag;
        _controller.add(
          SensorSample(
            timestampMs: DateTime.now().millisecondsSinceEpoch,
            accelX: event.x,
            accelY: event.y,
            accelZ: event.z,
            gyroX: gyro?.x ?? 0,
            gyroY: gyro?.y ?? 0,
            gyroZ: gyro?.z ?? 0,
            magX: mag?.x,
            magY: mag?.y,
            magZ: mag?.z,
            pressure: _latestPressure,
          ),
        );
      }, onError: (_) => _accelerometerAvailable = false),
    );
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _controller.close();
  }
}

enum _SensorKind { accelerometer, gyroscope, magnetometer, barometer }

class _SensorRateWindow {
  final _events = <_SensorKind, List<int>>{};

  void mark(_SensorKind kind) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final events = _events.putIfAbsent(kind, () => <int>[]);
    events.add(now);
    events.removeWhere((timestamp) => now - timestamp > 2000);
  }

  double? hzFor(_SensorKind kind) {
    final events = _events[kind];
    if (events == null || events.length < 2) return null;
    final durationMs = events.last - events.first;
    if (durationMs <= 0) return null;
    return events.length * 1000 / durationMs;
  }
}
