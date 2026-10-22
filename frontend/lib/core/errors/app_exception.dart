/// Core error hierarchy. Features throw and UI renders these types.
class AppException implements Exception {
  const AppException(this.message, {this.code = 'error'});

  final String message;
  final String code;

  @override
  String toString() => '[$code] $message';
}

class ApiException extends AppException {
  const ApiException(super.message, {super.code, this.status, this.details});

  final int? status;
  final Map<String, dynamic>? details;
}

/// The request was valid but the resource is busy for the moment (HTTP 409).
///
/// Raised when a conversation is still answering the previous message. The
/// client did nothing wrong, so the draft is kept and "try again in a moment"
/// is the correct response rather than a failure.
class ConflictException extends ApiException {
  const ConflictException(super.message) : super(code: 'conflict', status: 409);
}

/// Raised when the backend cannot be reached (server down, CORS, network).
class NetworkUnavailableException extends AppException {
  const NetworkUnavailableException([super.message = 'Cannot reach the backend']) : super(code: 'network_unavailable');
}
