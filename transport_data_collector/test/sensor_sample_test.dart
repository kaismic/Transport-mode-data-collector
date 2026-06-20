import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:transport_data_collector/features/recording/models/sensor_sample.dart';

void main() {
  test('serializes sensor values with at most eight decimal places', () {
    const sample = SensorSample(
      timestampMs: 123,
      accelX: 1.123456789012345,
      accelY: -2.987654321098765,
      accelZ: 0.000000004,
      gyroX: -0.000000004,
      gyroY: 5,
      gyroZ: 6.123456784,
      magX: 7.123456785,
      magY: -8.123456785,
      magZ: 9.000000001,
      pressure: 1013.123456789,
    );

    expect(sample.toJson(), {
      'ts': 123,
      'ax': 1.12345679,
      'ay': -2.98765432,
      'az': 0.0,
      'gx': 0.0,
      'gy': 5.0,
      'gz': 6.12345678,
      'mx': 7.12345679,
      'my': -8.12345679,
      'mz': 9.0,
      'p': 1013.12345679,
    });

    expect(
      jsonEncode(sample.toJson()),
      '{"ts":123,"ax":1.12345679,"ay":-2.98765432,"az":0.0,"gx":0.0,'
      '"gy":5.0,"gz":6.12345678,"mx":7.12345679,"my":-8.12345679,'
      '"mz":9.0,"p":1013.12345679}',
    );
  });

  test('omits unavailable optional sensor values', () {
    const sample = SensorSample(
      timestampMs: 123,
      accelX: 1,
      accelY: 2,
      accelZ: 3,
      gyroX: 4,
      gyroY: 5,
      gyroZ: 6,
    );

    expect(sample.toJson().keys, ['ts', 'ax', 'ay', 'az', 'gx', 'gy', 'gz']);
  });
}
