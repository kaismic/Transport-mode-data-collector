import 'package:flutter_test/flutter_test.dart';
import 'package:transport_data_collector/core/time_format.dart';

void main() {
  test('formats short and long durations', () {
    expect(formatDuration(const Duration(minutes: 3, seconds: 7)), '03:07');
    expect(
      formatDuration(const Duration(hours: 1, minutes: 3, seconds: 7)),
      '1:03:07',
    );
  });
}
