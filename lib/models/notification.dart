import 'package:flutter/foundation.dart';

enum NotificationType { ERROR, INFO }

@immutable
class Notification {
  final NotificationType type;
  final String message;
  final int lifespan; // -1 for indefinite, otherwise number of seconds to retain this error.

  const Notification({required this.message, required this.type, required this.lifespan});
}