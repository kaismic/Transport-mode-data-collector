import 'dart:convert';

class SensorInfo {
  const SensorInfo({required this.available, this.observedHz});

  final bool available;
  final double? observedHz;

  Map<String, dynamic> toMap() {
    return {
      'available': available,
      if (observedHz != null) 'observed_hz': observedHz,
    };
  }
}

class SensorManifest {
  const SensorManifest({
    required this.accelerometer,
    required this.gyroscope,
    required this.magnetometer,
    required this.barometer,
  });

  factory SensorManifest.empty() {
    return const SensorManifest(
      accelerometer: SensorInfo(available: false),
      gyroscope: SensorInfo(available: false),
      magnetometer: SensorInfo(available: false),
      barometer: SensorInfo(available: false),
    );
  }

  final SensorInfo accelerometer;
  final SensorInfo gyroscope;
  final SensorInfo magnetometer;
  final SensorInfo barometer;

  Map<String, dynamic> toMap() {
    return {
      'accelerometer': accelerometer.toMap(),
      'gyroscope': gyroscope.toMap(),
      'magnetometer': magnetometer.toMap(),
      'barometer': barometer.toMap(),
    };
  }

  String toJson() => jsonEncode(toMap());
}
