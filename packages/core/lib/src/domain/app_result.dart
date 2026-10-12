import 'app_failure.dart';

sealed class AppResult<T> {
  const AppResult();

  bool get isSuccess => this is AppSuccess<T>;
  bool get isFailure => this is AppFailureResult<T>;

  T get value => (this as AppSuccess<T>).data;
  AppFailure get error => (this as AppFailureResult<T>).failure;

  static AppResult<T> success<T>(T data) => AppSuccess<T>(data);
  static AppResult<T> failure<T>(AppFailure failure) => AppFailureResult<T>(failure);

  R fold<R>(R Function(T) onSuccess, R Function(AppFailure) onFailure) {
    return switch (this) {
      AppSuccess<T>(data: final d) => onSuccess(d),
      AppFailureResult<T>(failure: final f) => onFailure(f),
    };
  }
}

final class AppSuccess<T> extends AppResult<T> {
  const AppSuccess(this.data);
  final T data;
}

final class AppFailureResult<T> extends AppResult<T> {
  const AppFailureResult(this.failure);
  final AppFailure failure;

  @override
  AppFailure get error => failure;
}
