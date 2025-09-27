class AuthException implements Exception {
  final String code;
  final String message;

  AuthException({
    required this.code,
    required this.message,
  });

  @override
  String toString() => message;
}
