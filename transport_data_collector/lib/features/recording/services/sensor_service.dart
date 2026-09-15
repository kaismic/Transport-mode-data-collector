import 'dart:async';

import 'package:sensors_plus/sensors_plus.dart';

import '../models/sensor_manifest.dart';
import '../models/sensor_sample.dart';
import 'sensor_rate_control.dart';

class SensorService {
  SensorService() {
    _start();
  }

  static const _maximumSamplingPeriod = Duration(microseconds: 16667);

  final _controller = StreamController<SensorSample>.broadcast();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _clock = Stopwatch()..start();

  late final _rateGate = SensorRateGate<_SensorKind>(
    minimumInterval: _maximumSamplingPeriod,
    nowMicroseconds: () => _clock.elapsedMicroseconds,
  );
  late final _window = SensorRateWindow<_SensorKind>(
    nowMicroseconds: () => _clock.elapsedMicroseconds,
  );

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
      gyroscopeEventStream(
        samplingPeriod: SensorInterval.normalInterval,
      ).listen((event) {
        _gyroscopeAvailable = true;
        if (!_rateGate.shouldAccept(_SensorKind.gyroscope)) return;
        _latestGyro = event;
        _window.mark(_SensorKind.gyroscope);
      }, onError: (_) => _gyroscopeAvailable = false),
    );

    _subscriptions.add(
      magnetometerEventStream(
        samplingPeriod: SensorInterval.normalInterval,
      ).listen((event) {
        _magnetometerAvailable = true;
        if (!_rateGate.shouldAccept(_SensorKind.magnetometer)) return;
        _latestMag = event;
        _window.mark(_SensorKind.magnetometer);
      }, onError: (_) => _magnetometerAvailable = false),
    );

    _subscriptions.add(
      barometerEventStream(
        samplingPeriod: SensorInterval.normalInterval,
      ).listen((event) {
        _barometerAvailable = true;
        if (!_rateGate.shouldAccept(_SensorKind.barometer)) return;
        _latestPressure = event.pressure;
        _window.mark(_SensorKind.barometer);
      }, onError: (_) => _barometerAvailable = false),
    );

    _subscriptions.add(
      accelerometerEventStream(samplingPeriod: _maximumSamplingPeriod).listen((
        event,
      ) {
        _accelerometerAvailable = true;
        if (!_rateGate.shouldAccept(_SensorKind.accelerometer)) return;
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
