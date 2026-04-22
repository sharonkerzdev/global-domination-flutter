class ContentLoadException implements Exception {
  final String message;
  const ContentLoadException(this.message);

  @override
  String toString() => 'ContentLoadException: $message';
}
