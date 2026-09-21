import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/models/app_statistics.dart';
import 'package:shackleton/repositories/app_statistics_repository.dart';
import 'package:shackleton/widgets/shackleton_statistics.dart';

// Real AppStatisticsRepository.build() queries sqflite_common_ffi, which
// communicates over a real isolate. That combination hangs indefinitely
// under TestWidgetsFlutterBinding (testWidgets), even though the exact
// same DB access is instant in a plain test() body -- so widget tests must
// never let a DB-backed provider build for real; stub it instead.
class _StubAppStatisticsRepository extends AppStatisticsRepository {
  final AppStatistics stats;
  final Duration delay;

  _StubAppStatisticsRepository(this.stats, {this.delay = Duration.zero});

  @override
  Future<AppStatistics> build() async {
    if (delay > Duration.zero) await Future.delayed(delay);
    return stats;
  }
}

void main() {
  Widget buildApp(ProviderContainer container) => UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: ShackletonStatistics()),
        ),
      );

  testWidgets('shows a loading indicator, then the tag/file counts', (tester) async {
    final stats = AppStatistics();
    final container = ProviderContainer(overrides: [
      appStatisticsRepositoryProvider.overrideWith(
        () => _StubAppStatisticsRepository(stats, delay: const Duration(milliseconds: 10)),
      ),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(buildApp(container));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Not pumpAndSettle(): the spinner animates indefinitely while loading,
    // so settling never completes.
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('0'), findsOneWidget);
    expect(find.text('0 '), findsOneWidget);
  });

  testWidgets('reflects non-zero tag and file counts', (tester) async {
    final stats = AppStatistics()
      ..tagCount = 1
      ..fileCount = 2;
    final container = ProviderContainer(overrides: [
      appStatisticsRepositoryProvider.overrideWith(() => _StubAppStatisticsRepository(stats)),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(buildApp(container));
    await tester.pump();

    expect(find.text('1'), findsOneWidget); // tag count (no trailing space)
    expect(find.text('2 '), findsOneWidget); // file count (trailing space in source)
  });
}
