enum SdkErrorKind { validation, storage, platform, network, conflict, unknown }

sealed class SdkResult<T> {
  const SdkResult();
  bool get isSuccess => this is SdkSuccess<T>;
  T? get value => switch (this) {
    SdkSuccess<T> success => success.value,
    SdkFailure<T> _ => null,
  };
}

final class SdkSuccess<T> extends SdkResult<T> {
  const SdkSuccess(this.value);
  @override
  final T value;
  @override
  String toString() => 'SdkSuccess<$T>($value)';
  @override
  bool operator ==(Object other) =>
      other is SdkSuccess<T> && other.value == value;
  @override
  int get hashCode => Object.hash(T, value);
}

final class SdkFailure<T> extends SdkResult<T> {
  const SdkFailure({
    required this.kind,
    required this.message,
    this.retryable = false,
    this.cause,
    this.stackTrace,
  });
  final SdkErrorKind kind;

  /// Safe message for consumers; never include raw secrets or payloads here.
  final String message;
  final bool retryable;
  final Object? cause;
  final StackTrace? stackTrace;
  @override
  String toString() =>
      'SdkFailure<$T>($kind, retryable: $retryable, message: $message)';
  @override
  bool operator ==(Object other) =>
      other is SdkFailure<T> &&
      other.kind == kind &&
      other.message == message &&
      other.retryable == retryable;
  @override
  int get hashCode => Object.hash(T, kind, message, retryable);
}
