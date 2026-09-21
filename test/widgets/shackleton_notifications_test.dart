import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/providers/notify.dart';
import 'package:shackleton/widgets/shackleton_notifications.dart';

void main() {
  Widget buildApp(ProviderContainer container) => UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: ShackletonNotifications()),
        ),
      );

  group('ShackletonNotifications', () {
    testWidgets('is hidden until a notification is added', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildApp(container));
      await tester.pump();

      expect(find.text('Clear'), findsNothing);
    });

    testWidgets('slides into view and shows the message when a notification is added', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(buildApp(container));
      await tester.pump();

      container.read(notifyProvider.notifier).addNotification(message: 'exiftool not installed');
      await tester.pumpAndSettle();

      expect(find.text('exiftool not installed'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
    });

    testWidgets('shows every notification in the list', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(buildApp(container));
      await tester.pump();

      container.read(notifyProvider.notifier).addNotification(message: 'first');
      container.read(notifyProvider.notifier).addNotification(message: 'second');
      await tester.pumpAndSettle();

      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('the Clear button empties the notification list', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(buildApp(container));
      await tester.pump();
      container.read(notifyProvider.notifier).addNotification(message: 'oops');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(container.read(notifyProvider), isEmpty);
    });
  });
}
