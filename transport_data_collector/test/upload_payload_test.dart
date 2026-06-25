import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transport_data_collector/features/recording/models/sensor_sample.dart';
import 'package:transport_data_collector/features/upload/models/upload_payload.dart';

void main() {
  test('writes an equivalent gzip payload to a temporary file', () async {
    const payload = UploadPayload(
      deviceUuid: 'device-id',
      sessionId: 'session-id',
      vehicleType: 'train',
      phonePosition: 'pocket',
      startedAtMs: 1000,
      stoppedAtMs: 3000,
      trimmedStartMs: 1500,
      trimmedEndMs: 2500,
      uploadedAtMs: 4000,
      sensorManifest: '{"accelerometer":true}',
      appVersion: '1.0.1+2',
      samples: [
        SensorSample(
          timestampMs: 2000,
          accelX: 1.123456789,
          accelY: 2,
          accelZ: 3,
          gyroX: 4,
          gyroY: 5,
          gyroZ: 6,
          pressure: 1013.25,
        ),
      ],
    );

    final gzipFile = await payload.writeToTemporaryGzipFile();
    final file = File(gzipFile.path);

    expect(await file.exists(), isTrue);
    expect(gzipFile.length, await file.length());
    final decoded = jsonDecode(
      utf8.decode(gzip.decode(await file.readAsBytes())),
    );
    expect(decoded, payload.toJson());

    await gzipFile.delete();
    expect(await file.exists(), isFalse);
    expect(await file.parent.exists(), isFalse);
  });
}
