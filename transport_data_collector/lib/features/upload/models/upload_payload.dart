import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../../../core/database/app_database.dart';
import '../../recording/models/sensor_sample.dart';

class UploadPayload {
  const UploadPayload({
    required this.deviceUuid,
    required this.sessionId,
    required this.vehicleType,
    required this.phonePosition,
    required this.startedAtMs,
    required this.stoppedAtMs,
    required this.trimmedStartMs,
    required this.trimmedEndMs,
    required this.uploadedAtMs,
    required this.sensorManifest,
    required this.samples,
    required this.appVersion,
    this.collectionVersion = 1,
    this.schemaVersion = 2,
  });

  final String deviceUuid;
  final String sessionId;
  final String vehicleType;
  final String phonePosition;
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
    required String appVersion,
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
      phonePosition: session.phonePosition,
      startedAtMs: session.startedAtMs,
      stoppedAtMs: stoppedAtMs,
      trimmedStartMs: trimStart,
      trimmedEndMs: trimEnd,
      uploadedAtMs: DateTime.now().millisecondsSinceEpoch,
      sensorManifest: session.sensorManifest,
      samples: trimmedSamples,
      appVersion: appVersion,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ..._metadataJson(),
      'samples': samples.map((sample) => sample.toJson()).toList(),
    };
  }

  Future<GzipUploadFile> writeToTemporaryGzipFile() {
    return Isolate.run(() => _writeToTemporaryGzipFile(this));
  }

  Map<String, dynamic> _metadataJson() {
    return {
      'device_uuid': deviceUuid,
      'session_id': sessionId,
      'vehicle_type': vehicleType,
      'phone_position': phonePosition,
      'started_at_ms': startedAtMs,
      'stopped_at_ms': stoppedAtMs,
      'trimmed_start_ms': trimmedStartMs,
      'trimmed_end_ms': trimmedEndMs,
      'uploaded_at_ms': uploadedAtMs,
      'collection_version': collectionVersion,
      'app_version': appVersion,
      'schema_version': schemaVersion,
      'sensor_manifest': jsonDecode(sensorManifest),
    };
  }
}

class GzipUploadFile {
  const GzipUploadFile({required this.path, required this.length});

  final String path;
  final int length;

  Stream<List<int>> openRead() => File(path).openRead();

  Future<void> delete() async {
    final file = File(path);
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      return;
    }

    final directory = file.parent;
    try {
      if (await directory.exists()) {
        await directory.delete();
      }
    } on FileSystemException {
      // A stale temp directory is preferable to treating a completed upload
      // as failed and uploading the same session again.
    }
  }
}

Future<GzipUploadFile> _writeToTemporaryGzipFile(UploadPayload payload) async {
  final directory = await Directory.systemTemp.createTemp(
    'transport-data-upload-',
  );
  final file = File(
    '${directory.path}${Platform.pathSeparator}payload.json.gz',
  );

  try {
    final fileSink = file.openWrite();
    final gzipSink = GZipCodec().encoder.startChunkedConversion(fileSink);
    final textSink = utf8.encoder.startChunkedConversion(gzipSink);
    final metadata = jsonEncode(payload._metadataJson());

    textSink.add('${metadata.substring(0, metadata.length - 1)},"samples":[');
    for (var index = 0; index < payload.samples.length; index++) {
      if (index > 0) textSink.add(',');
      textSink.add(jsonEncode(payload.samples[index].toJson()));
    }
    textSink.add(']}');
    textSink.close();
    await fileSink.done;

    return GzipUploadFile(path: file.path, length: await file.length());
  } catch (_) {
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } on FileSystemException {
      // Preserve the encoding error if best-effort cleanup also fails.
    }
    rethrow;
  }
}
