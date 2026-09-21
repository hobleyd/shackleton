import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/interfaces/notification_listener.dart';
import 'package:shackleton/models/notification.dart';
import 'package:shackleton/providers/notify.dart';

class RecordingListener implements NotificationListener {
  final List<bool> visibilityCalls = [];

  @override
  void setNotificationVisibility({bool isVisible = false}) {
    visibilityCalls.add(isVisible);
  }
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  Notify notifier() => container.read(notifyProvider.notifier);

  group('Notify', () {
    test('starts with no notifications', () {
      expect(container.read(notifyProvider), isEmpty);
    });

    test('addNotification inserts at the front of the list', () {
      notifier().addNotification(message: 'first');
      notifier().addNotification(message: 'second');

      final state = container.read(notifyProvider);
      expect(state.map((n) => n.message), ['second', 'first']);
    });

    test('addNotification defaults to error type and indefinite lifespan', () {
      final n = notifier().addNotification(message: 'oops');

      expect(n.type, NotificationType.error);
      expect(n.lifespan, -1);
    });

    test('addNotification notifies registered listeners as visible', () {
      final listener = RecordingListener();
      notifier().addListener(listener);

      notifier().addNotification(message: 'oops');

      expect(listener.visibilityCalls, [true]);
    });

    test('removeError removes only the matching notification', () {
      final a = notifier().addNotification(message: 'a');
      notifier().addNotification(message: 'b');

      notifier().removeError(a);

      expect(container.read(notifyProvider).map((n) => n.message), ['b']);
    });

    test('removeError notifies listeners as not visible once the list is empty', () {
      final listener = RecordingListener();
      notifier().addListener(listener);
      final a = notifier().addNotification(message: 'a');
      listener.visibilityCalls.clear();

      notifier().removeError(a);

      expect(listener.visibilityCalls, [false]);
    });

    test('removeError does not notify listeners when other notifications remain', () {
      final listener = RecordingListener();
      notifier().addListener(listener);
      final a = notifier().addNotification(message: 'a');
      notifier().addNotification(message: 'b');
      listener.visibilityCalls.clear();

      notifier().removeError(a);

      expect(listener.visibilityCalls, isEmpty);
    });

    test('clear empties the state and notifies listeners as not visible', () {
      final listener = RecordingListener();
      notifier().addListener(listener);
      notifier().addNotification(message: 'a');
      listener.visibilityCalls.clear();

      notifier().clear();

      expect(container.read(notifyProvider), isEmpty);
      expect(listener.visibilityCalls, [false]);
    });

    test('a notification with a positive lifespan is auto-removed after it elapses', () {
      fakeAsync((async) {
        notifier().addNotification(message: 'temporary', lifespan: 2);
        expect(container.read(notifyProvider), hasLength(1));

        async.elapse(const Duration(seconds: 2));

        expect(container.read(notifyProvider), isEmpty);
      });
    });
  });
}
