import 'package:flutter/foundation.dart';

@immutable
class Error {
  final String message;
  final int lifespan; // -1 for indefinite, otherwise number of seconds to retain this error.

  const Error({required this.message, required this.lifespan});
}