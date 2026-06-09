sealed class UploadException implements Exception {
  const UploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PresignRequestException extends UploadException {
  const PresignRequestException(super.message);
}

class S3PutException extends UploadException {
  const S3PutException(super.message);
}

class ConfirmException extends UploadException {
  const ConfirmException(super.message);
}
