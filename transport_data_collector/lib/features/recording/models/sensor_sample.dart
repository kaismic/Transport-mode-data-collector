import 'dart:math';

const _sensorOutputDecimalPlaces = 8;

class SensorSample {
  const SensorSample({
    required this.timestampMs,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    this.magX,
    this.magY,
    this.magZ,
    this.pressure,
  });

  final int timestampMs;
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final double? magX;
  final double? magY;
  final double? magZ;
  final double? pressure;

  double get accelMagnitude {
    return sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ);
  }

  Map<String, dynamic> toJson() {
    return {
      'ts': timestampMs,
      'ax': _toOutputPrecision(accelX),
      'ay': _toOutputPrecision(accelY),
      'az': _toOutputPrecision(accelZ),
      'gx': _toOutputPrecision(gyroX),
      'gy': _toOutputPrecision(gyroY),
      'gz': _toOutputPrecision(gyroZ),
      if (magX != null) 'mx': _toOutputPrecision(magX!),
      if (magY != null) 'my': _toOutputPrecision(magY!),
      if (magZ != null) 'mz': _toOutputPrecision(magZ!),
      if (pressure != null) 'p': _toOutputPrecision(pressure!),
    };
  }
}

double _toOutputPrecision(double value) {
  final rounded = double.parse(
    value.toStringAsFixed(_sensorOutputDecimalPlaces),
  );
  return rounded == 0 ? 0 : rounded;
}
