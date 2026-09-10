import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_data_collector/features/upload/models/upload_exception.dart';
import 'package:transport_data_collector/features/upload/models/upload_payload.dart';
import 'package:transport_data_collector/features/upload/services/upload_service.dart';

void main() {
  for (var failures = 0; failures <= 3; failures++) {
    test(
      'completes one upload after $failures generic 403 responses',
      () async {
        final harness = _Harness(
          (attempt) => attempt <= failures
              ? _response(403, {'message': 'Forbidden'})
              : _response(200, {'presigned_url': 'https://s3.example/upload'}),
        );
        addTearDown(harness.close);

        await harness.upload();

        expect(harness.presignAttempts, failures + 1);
        expect(harness.delays, [
          for (var i = 0; i < failures; i++) Duration(seconds: 1 << i),
        ]);
        expect(harness.events, [
          for (var i = 0; i <= failures; i++) 'presign',
          'put',
          'confirm',
        ]);
        final requests = harness.apiAdapter.requests.where(
          (request) => request.path.endsWith('request-upload'),
        );
        for (final request in requests) {
          expect(request.data['invite_code'], 'KAIS-TEST');
          expect(request.data['session_id'], _payload.sessionId);
          expect(request.data, requests.first.data);
          expect(request.uri.path, '/Prod/sessions/request-upload');
        }
      },
    );
  }

  test(
    'stops after four 403 responses without uploading or confirming',
    () async {
      final harness = _Harness((_) => _response(403, {'message': 'Forbidden'}));
      addTearDown(harness.close);

      await expectLater(
        harness.upload(),
        throwsA(
          isA<PresignRequestException>().having(
            (error) => error.message,
            'message',
            'Could not start upload (HTTP 403): Forbidden',
          ),
        ),
      );

      expect(harness.presignAttempts, 4);
      expect(harness.events, List.filled(4, 'presign'));
      expect(harness.delays.length, 3);
    },
  );

  for (final body in [
    {
      'code': 'INVALID_INVITE_CODE',
      'message': 'Invalid or inactive invite code',
    },
    {'message': 'Invalid or inactive invite code'},
  ]) {
    test('invalid invite is actionable and never retried: $body', () async {
      final harness = _Harness((_) => _response(403, body));
      addTearDown(harness.close);

      await expectLater(
        harness.upload(),
        throwsA(
          isA<PresignRequestException>().having(
            (error) => error.message,
            'message',
            contains('Change it from the home'),
          ),
        ),
      );

      expect(harness.events, ['presign']);
      expect(harness.delays, isEmpty);
    });
  }

  test('misconfigured API route is reported without retries', () async {
    final harness = _Harness(
      (_) => _response(403, {'Message': 'Missing Authentication Token'}),
    );
    addTearDown(harness.close);

    await expectLater(
      harness.upload(),
      throwsA(
        isA<PresignRequestException>().having(
          (error) => error.message,
          'message',
          contains('API address is incorrect'),
        ),
      ),
    );
    expect(harness.events, ['presign']);
    expect(harness.delays, isEmpty);
  });

  for (final status in [400, 409, 500, 504]) {
    test('does not replay HTTP $status failures', () async {
      final harness = _Harness(
        (_) => _response(status, {'message': 'Rejected'}),
      );
      addTearDown(harness.close);

      await expectLater(
        harness.upload(),
        throwsA(isA<PresignRequestException>()),
      );
      expect(harness.events, ['presign']);
      expect(harness.delays, isEmpty);
    });
  }

  test('does not replay ambiguous timeouts', () async {
    final harness = _Harness(
      (_) => throw DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.receiveTimeout,
      ),
    );
    addTearDown(harness.close);

    await expectLater(
      harness.upload(),
      throwsA(isA<PresignRequestException>()),
    );
    expect(harness.events, ['presign']);
    expect(harness.delays, isEmpty);
  });

  test(
    'handles non-JSON forbidden responses without the Dio diagnostic',
    () async {
      final harness = _Harness(
        (_) => ResponseBody.fromString(
          '<html>Forbidden</html>',
          403,
          headers: {
            Headers.contentTypeHeader: ['text/html'],
          },
        ),
      );
      addTearDown(harness.close);

      await expectLater(
        harness.upload(),
        throwsA(
          isA<PresignRequestException>().having(
            (error) => error.message,
            'message',
            'Could not start upload (HTTP 403): Check your connection and try again.',
          ),
        ),
      );
      expect(harness.events, List.filled(4, 'presign'));
    },
  );
}

class _Harness {
  _Harness(ResponseBody Function(int) presign) {
    apiAdapter = _Adapter((request) {
      if (request.path.endsWith('request-upload')) {
        events.add('presign');
        return presign(++presignAttempts);
      }
      events.add('confirm');
      return _response(200, {});
    });
    api.httpClientAdapter = apiAdapter;
    s3.httpClientAdapter = _Adapter((request) {
      events.add('put');
      expect(request.headers['content-type'], 'application/json');
      expect(request.headers['content-encoding'], 'gzip');
      return _response(200, {});
    });
    service = UploadService(
      api: api,
      s3: s3,
      delay: (duration) async {
        delays.add(duration);
      },
    );
  }

  final api = Dio(BaseOptions(baseUrl: 'https://api.example/Prod'));
  final s3 = Dio();
  late final _Adapter apiAdapter;
  late final UploadService service;
  final events = <String>[];
  final delays = <Duration>[];
  var presignAttempts = 0;

  Future<void> upload() =>
      service.uploadSession(payload: _payload, inviteCode: '  kais-test  ');

  void close() {
    api.close();
    s3.close();
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (requestStream != null) await requestStream.drain<void>();
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _response(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

const _payload = UploadPayload(
  deviceUuid: '22222222-2222-4222-8222-222222222222',
  sessionId: '11111111-1111-4111-8111-111111111111',
  vehicleType: 'train',
  phonePosition: 'pocket',
  startedAtMs: 1000,
  stoppedAtMs: 3000,
  trimmedStartMs: 1500,
  trimmedEndMs: 2500,
  uploadedAtMs: 4000,
  sensorManifest: '{}',
  appVersion: '1.0.1+2',
  samples: [],
);
