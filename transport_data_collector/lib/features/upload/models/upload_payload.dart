import 'dart:convert';
import 'dart:io';

import '../../../core/database/app_database.dart';
import '../../recording/models/sensor_sample.dart';

const _appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '1.0.0+1',
);

class UploadPayload {
  const UploadPayload({
    required this.deviceUuid,
    required this.sessionId,
    required this.vehicleType,
    required this.startedAtMs,
    required this.stoppedAtMs,
    required this.trimmedStartMs,
    required this.trimmedEndMs,
    required this.uploadedAtMs,
    required this.sensorManifest,
    required this.samples,
    this.collectionVersion = 1,
    this.appVersion = _appVersion,
    this.schemaVersion = 1,
  });

  final String deviceUuid;
  final String sessionId;
  final String vehicleType;
  final int startedAtMs;
  final int stoppedAtMs;
  final int trimmedStartMs;
  final int trimmedEndMs;
  final int uploadedAtMs;
  final int collectionVersion;
  final String appVersion;
  final int schemaVersion;
  final String sensorManifest;
  final List<SensorSample> samples;

  factory UploadPayload.fromSessionAndSamples({
    required Session session,
    required List<Sample> samples,
  }) {
    final stoppedAtMs = session.stoppedAtMs;
    if (stoppedAtMs == null) {
      throw StateError('Session ${session.id} has not been stopped.');
    }

    final trimStart = session.trimmedStartMs ?? session.startedAtMs;
    final trimEnd = session.trimmedEndMs ?? stoppedAtMs;
    final trimmedSamples = samples
        .where((s) => s.timestampMs >= trimStart && s.timestampMs <= trimEnd)
        .map(
          (s) => SensorSample(
            timestampMs: s.timestampMs,
            accelX: s.accelX,
            accelY: s.accelY,
            accelZ: s.accelZ,
            gyroX: s.gyroX,
            gyroY: s.gyroY,
            gyroZ: s.gyroZ,
            magX: s.magX,
            magY: s.magY,
            magZ: s.magZ,
            pressure: s.pressure,
          ),
        )
        .toList();

    return UploadPayload(
      deviceUuid: session.deviceUuid,
      sessionId: session.id,
      vehicleType: session.vehicleType,
      startedAtMs: session.startedAtMs,
      stoppedAtMs: stoppedAtMs,
      trimmedStartMs: trimStart,
      trimmedEndMs: trimEnd,
      uploadedAtMs: DateTime.now().millisecondsSinceEpoch,
      sensorManifest: session.sensorManifest,
      samples: trimmedSamples,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_uuid': deviceUuid,
      'session_id': sessionId,
      'vehicle_type': vehicleType,
      'started_at_ms': startedAtMs,
      'stopped_at_ms': stoppedAtMs,
      'trimmed_start_ms': trimmedStartMs,
      'trimmed_end_ms': trimmedEndMs,
      'uploaded_at_ms': uploadedAtMs,
      'collection_version': collectionVersion,
      'app_version': appVersion,
      'schema_version': schemaVersion,
      'sensor_manifest': jsonDecode(sensorManifest),
      'samples': samples.map((sample) => sample.toJson()).toList(),
    };
  }

  List<int> toGzipBytes() {
    final jsonBytes = utf8.encode(jsonEncode(toJson()));
    return GZipCodec().encode(jsonBytes);
  }
}
