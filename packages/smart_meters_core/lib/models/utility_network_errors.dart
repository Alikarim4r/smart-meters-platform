/// Typed errors for utility network v2 repository operations.
sealed class UtilityNetworkException implements Exception {
  const UtilityNetworkException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkVersionConflict extends UtilityNetworkException {
  const NetworkVersionConflict({
    required this.expectedLockVersion,
    this.actualLockVersion,
    String? message,
    Object? cause,
  }) : super(
         message ??
             'Network draft version conflict'
                 '${actualLockVersion == null ? '' : ': expected $expectedLockVersion, actual $actualLockVersion'}',
         cause: cause,
       );

  final int expectedLockVersion;
  final int? actualLockVersion;
}

class NetworkPermissionError extends UtilityNetworkException {
  const NetworkPermissionError([
    String message = 'Not allowed to manage or read this utility network',
    Object? cause,
  ]) : super(message, cause: cause);
}

class NetworkValidationError extends UtilityNetworkException {
  const NetworkValidationError(
    String message, {
    this.issues = const [],
    Object? cause,
  }) : super(message, cause: cause);

  final List<Object> issues;
}

class NetworkNotFoundError extends UtilityNetworkException {
  const NetworkNotFoundError([
    String message = 'Utility network or revision not found',
    Object? cause,
  ]) : super(message, cause: cause);
}

class NetworkNotPublishedError extends UtilityNetworkException {
  const NetworkNotPublishedError([
    String message = 'Utility network has not been published',
    Object? cause,
  ]) : super(message, cause: cause);
}

class NetworkNoDraftError extends UtilityNetworkException {
  const NetworkNoDraftError([
    String message = 'Utility network has no draft revision',
    Object? cause,
  ]) : super(message, cause: cause);
}

class NetworkParentConflictError extends UtilityNetworkException {
  const NetworkParentConflictError([
    String message = 'Downstream meter parent conflict',
    Object? cause,
  ]) : super(message, cause: cause);
}

class NetworkRpcError extends UtilityNetworkException {
  const NetworkRpcError(String message, {Object? cause})
    : super(message, cause: cause);
}
