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
    super.message = 'Not allowed to manage or read this utility network',
    Object? cause,
  ]) : super(cause: cause);
}

class NetworkValidationError extends UtilityNetworkException {
  const NetworkValidationError(
    super.message, {
    this.issues = const [],
    super.cause,
  });

  final List<Object> issues;
}

class NetworkNotFoundError extends UtilityNetworkException {
  const NetworkNotFoundError([
    super.message = 'Utility network or revision not found',
    Object? cause,
  ]) : super(cause: cause);
}

class NetworkNotPublishedError extends UtilityNetworkException {
  const NetworkNotPublishedError([
    super.message = 'Utility network has not been published',
    Object? cause,
  ]) : super(cause: cause);
}

class NetworkNoDraftError extends UtilityNetworkException {
  const NetworkNoDraftError([
    super.message = 'Utility network has no draft revision',
    Object? cause,
  ]) : super(cause: cause);
}

class NetworkParentConflictError extends UtilityNetworkException {
  const NetworkParentConflictError([
    super.message = 'Downstream meter parent conflict',
    Object? cause,
  ]) : super(cause: cause);
}

class NetworkRpcError extends UtilityNetworkException {
  const NetworkRpcError(super.message, {super.cause});
}
