extension TypeExtension<T> on T? {
  R? mapNotNull<R>(R Function(T value) convert) {
    if (this == null) return null;
    return convert(this as T);
  }

  Future<R?> mapNotNullAsync<R>(Future<R> Function(T value) convert) {
    if (this == null) return Future.value(null);
    return convert(this as T);
  }
}
