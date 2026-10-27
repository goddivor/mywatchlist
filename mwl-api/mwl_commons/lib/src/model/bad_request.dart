/// A request parameter is missing or invalid: the backend answers 400 with
/// [message] instead of guessing a value or crashing the handler.
class BadRequest implements Exception {
  const BadRequest(this.message);

  final String message;

  @override
  String toString() => 'BadRequest: $message';
}
