import 'dart:math';

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
      'ax': accelX,
      'ay': accelY,
      'az': accelZ,
      'gx': gyroX,
      'gy': gyroY,
      'gz': gyroZ,
      if (magX != null) 'mx': magX,
      if (magY != null) 'my': magY,
      if (magZ != null) 'mz': magZ,
      if (pressure != null) 'p': pressure,
    };
  }
}
