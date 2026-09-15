import 'package:flutter_test/flutter_test.dart';
import 'package:transport_data_collector/features/recording/services/sensor_rate_control.dart';

void main() {
  const maximumSamplingPeriod = Duration(microseconds: 16667);

  group('SensorRateGate', () {
    late int nowUs;
    late SensorRateGate<String> gate;

    setUp(() {
      nowUs = 0;
      gate = SensorRateGate<String>(
        minimumInterval: maximumSamplingPeriod,
        nowMicroseconds: () => nowUs,
      );
    });

    test('accepts the first event and rejects events below the limit', () {
      expect(gate.shouldAccept('accelerometer'), isTrue);

      nowUs = maximumSamplingPeriod.inMicroseconds - 1;
      expect(gate.shouldAccept('accelerometer'), isFalse);

      nowUs = maximumSamplingPeriod.inMicroseconds;
      expect(gate.shouldAccept('accelerometer'), isTrue);
    });

    test('tracks each sensor independently', () {
      expect(gate.shouldAccept('accelerometer'), isTrue);
      expect(gate.shouldAccept('gyroscope'), isTrue);

      nowUs = 1000;
      expect(gate.shouldAccept('accelerometer'), isFalse);
      expect(gate.shouldAccept('gyroscope'), isFalse);
      expect(gate.shouldAccept('magnetometer'), isTrue);
      expect(gate.shouldAccept('barometer'), isTrue);
    });

    test('passes through streams that are slower than the limit', () {
      for (var event = 0; event < 10; event++) {
        expect(gate.shouldAccept('barometer'), isTrue);
        nowUs += const Duration(milliseconds: 200).inMicroseconds;
      }
    });
  });

  group('SensorRateWindow', () {
    test('calculates frequency from intervals rather than event count', () {
      var nowUs = 0;
      final window = SensorRateWindow<String>(nowMicroseconds: () => nowUs);

      window.mark('accelerometer');
      expect(window.hzFor('accelerometer'), isNull);

      nowUs = Duration.microsecondsPerSecond;
      window.mark('accelerometer');

      expect(window.hzFor('accelerometer'), 1);
    });

    test('reports an accepted stream at no more than 60 Hz', () {
      var nowUs = 0;
      final window = SensorRateWindow<String>(nowMicroseconds: () => nowUs);

      for (var event = 0; event < 120; event++) {
        window.mark('accelerometer');
        nowUs += maximumSamplingPeriod.inMicroseconds;
      }

      final observedHz = window.hzFor('accelerometer');
      expect(observedHz, isNotNull);
      expect(observedHz!, lessThanOrEqualTo(60));
      expect(observedHz, closeTo(60, 0.01));
    });
  });
}
