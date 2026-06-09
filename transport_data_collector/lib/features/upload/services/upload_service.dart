import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../models/upload_exception.dart';
import '../models/upload_payload.dart';

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

class UploadService {
  UploadService({Dio? api, Dio? s3})
    : _hasConfiguredApiBaseUrl =
          api != null ||
          (_apiBaseUrl.isNotEmpty && !_apiBaseUrl.contains('xxxx')),
      _api =
          api ??
          Dio(
            BaseOptions(
              baseUrl: _apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          ),
      _s3 =
          s3 ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 120),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

  final Dio _api;
  final Dio _s3;
  final bool _hasConfiguredApiBaseUrl;

  Future<void> uploadSession({
    required UploadPayload payload,
    required String inviteCode,
  }) async {
    final presignedUrl = await _requestPresignedUrl(
      payload: payload,
      inviteCode: inviteCode,
    );
    await _putToS3(presignedUrl, payload);
    await confirmUpload(
      sessionId: payload.sessionId,
      uploadedAtMs: payload.uploadedAtMs,
    );
  }

  Future<void> confirmUpload({
    required String sessionId,
    required int uploadedAtMs,
  }) async {
    try {
      await _api.post<void>(
        '/sessions/confirm-upload',
        data: {'session_id': sessionId, 'uploaded_at_ms': uploadedAtMs},
      );
    } on DioException catch (error) {
      throw ConfirmException(
        'Upload succeeded but confirm failed: ${error.message}',
      );
    }
  }

  Future<String> _requestPresignedUrl({
    required UploadPayload payload,
    required String inviteCode,
  }) async {
    if (!_hasConfiguredApiBaseUrl) {
      throw const PresignRequestException(
        'API_BASE_URL is not configured. Run the Flutter: Development launch '
        'configuration or pass --dart-define-from-file=config/dev.env.',
      );
    }

    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/sessions/request-upload',
        data: {
          'invite_code': inviteCode,
          'session_id': payload.sessionId,
          'device_uuid': payload.deviceUuid,
          'vehicle_type': payload.vehicleType,
          'started_at_ms': payload.startedAtMs,
          'stopped_at_ms': payload.stoppedAtMs,
          'trimmed_start_ms': payload.trimmedStartMs,
          'trimmed_end_ms': payload.trimmedEndMs,
          'uploaded_at_ms': payload.uploadedAtMs,
          'collection_version': payload.collectionVersion,
          'app_version': payload.appVersion,
          'schema_version': payload.schemaVersion,
          'sensor_manifest': jsonDecode(payload.sensorManifest),
          'sample_count': payload.samples.length,
        },
      );
      final url = response.data?['presigned_url'];
      if (url is! String || url.isEmpty) {
        throw const PresignRequestException('API did not return a upload URL.');
      }
      return url;
    } on PresignRequestException {
      rethrow;
    } on DioException catch (error) {
      throw PresignRequestException(
        'Failed to get presigned URL: ${error.message}',
      );
    }
  }

  Future<void> _putToS3(String presignedUrl, UploadPayload payload) async {
    final gzipBytes = payload.toGzipBytes();
    try {
      await _s3.put<void>(
        presignedUrl,
        data: Stream.fromIterable([gzipBytes]),
        options: Options(
          headers: {
            HttpHeaders.contentTypeHeader: 'application/json',
            HttpHeaders.contentEncodingHeader: 'gzip',
            HttpHeaders.contentLengthHeader: gzipBytes.length,
          },
        ),
      );
    } on DioException catch (error) {
      throw S3PutException('S3 PUT failed: ${error.message}');
    }
  }
}
