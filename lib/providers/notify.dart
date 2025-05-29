import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shackleton/interfaces/notification_listener.dart';

import '../models/notification.dart';

part 'notify.g.dart';

@Riverpod(keepAlive: true)
class Notify extends _$Notify {
  List<NotificationListener> _listeners = [];

  @override
  List<Notification> build() {
    return [];
  }

  void addListener(NotificationListener listener) {
    _listeners.add(listener);
  }

  void clear() {
    state = [];

    notifyListeners(false);
  }

  void notifyListeners(bool isVisible) {
    for (var listener in _listeners) {
      listener.setNotificationVisibility(isVisible: isVisible);
    }
  }

  void removeError(Notification e) {
    List<Notification> errors = List.from(state);
    errors.remove(e);

    if (errors.isEmpty) {
      notifyListeners(false);
    }

    state = errors;
  }

  Notification addNotification({ required String message, NotificationType type = NotificationType.ERROR, int lifespan = -1 }) {
    Notification e = Notification(message: message, type: type, lifespan: lifespan);
    List<Notification> errors = List.from(state);
    errors.insert(0, e);
    notifyListeners(true);

    if (lifespan > 0) {
      Future.delayed(Duration(milliseconds: 1000 * lifespan), () {
        removeError(e);
      });
    }

    state = errors;

    return e;
  }
}


