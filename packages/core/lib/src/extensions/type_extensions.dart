extension TypeExtension<T> on T? {
  R? mapNotNull<R>(R Function(T value) convert) {
    if (this == null) return null;
    return convert(this as T);
  }
}
