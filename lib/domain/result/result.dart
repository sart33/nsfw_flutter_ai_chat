/// A simple Result monad: either [Success] carrying data or [Failure] carrying
/// an error message (and optional exception).
sealed class Result<T> {
  const Result();

  /// Create a successful result.
  factory Result.success(T data) = Success<T>;

  /// Create a failed result.
  factory Result.failure(String message, [Exception? exception]) =
      Failure<T>;

  /// Pattern-match on the result.
  R when<R>({
    required R Function(T data) success,
    required R Function(String message, Exception? exception) failure,
  }) {
    return switch (this) {
      Success<T>(data: final d) => success(d),
      Failure<T>(message: final m, exception: final e) => failure(m, e),
    };
  }

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
}

/// Successful result wrapping [data].
class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

/// Failed result carrying a human-readable [message] and an optional
/// [exception] for logging.
class Failure<T> extends Result<T> {
  final String message;
  final Exception? exception;
  const Failure(this.message, [this.exception]);
}
