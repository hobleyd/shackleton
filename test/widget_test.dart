import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: ShackletonApp()));

    // Verify that our counter starts at 0.
    expect(find.text('Name'), findsOneWidget);

    // Tap the '+' icon and trigger a frame.
    await tester.drag(find.byKey(const Key('resize')), const Offset(100, 0));
    await tester.pumpAndSettle();

    // Verify that our counter has incremented.
    expect(find.text('Name'), findsOneWidget);
  });
}
