import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shackleton/domain/services/i_disk_service.dart';
import 'package:shackleton/models/shackleton_disk.dart';
import 'package:shackleton/providers/disk_service_provider.dart';
import 'package:shackleton/providers/disk_size_details.dart';
import 'package:shackleton/providers/notify.dart';

class MockDiskService extends Mock implements IDiskService {}

void main() {
  late ProviderContainer container;
  late MockDiskService mockDiskService;

  const diskA = ShackletonDisk(
    devicePath: '/dev/disk1',
    mountPath: '/Volumes/A',
    totalSize: 1000,
    usedSpace: 500,
    usedPercentage: 0.5,
    availableSpace: 500,
  );

  setUpAll(() {
    registerFallbackValue(diskA);
  });

  setUp(() {
    mockDiskService = MockDiskService();
    when(() => mockDiskService.driveChanges).thenAnswer((_) => const Stream.empty());
    container = ProviderContainer(overrides: [
      diskServiceProvider.overrideWithValue(mockDiskService),
    ]);
  });

  tearDown(() {
    container.dispose();
  });

  group('DiskSizeDetails', () {
    test('build returns the disks reported by the service', () async {
      when(() => mockDiskService.getDisks()).thenAnswer((_) async => [diskA]);

      final disks = await container.read(diskSizeDetailsProvider.future);

      expect(disks, [diskA]);
    });

    test('scanDisks refreshes the state', () async {
      when(() => mockDiskService.getDisks()).thenAnswer((_) async => []);
      await container.read(diskSizeDetailsProvider.future);
      when(() => mockDiskService.getDisks()).thenAnswer((_) async => [diskA]);

      container.read(diskSizeDetailsProvider.notifier).scanDisks();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(container.read(diskSizeDetailsProvider).value, [diskA]);
    });

    test('unmountPath posts a notification when the service reports an error', () async {
      when(() => mockDiskService.getDisks()).thenAnswer((_) async => []);
      await container.read(diskSizeDetailsProvider.future);
      when(() => mockDiskService.unmountPath('/Volumes/A')).thenAnswer((_) async => 'busy');

      await container.read(diskSizeDetailsProvider.notifier).unmountPath('/Volumes/A');

      final notifications = container.read(notifyProvider);
      expect(notifications.map((n) => n.message), contains('busy'));
    });

    test('unmountPath posts nothing on success', () async {
      when(() => mockDiskService.getDisks()).thenAnswer((_) async => []);
      await container.read(diskSizeDetailsProvider.future);
      when(() => mockDiskService.unmountPath('/Volumes/A')).thenAnswer((_) async => null);

      await container.read(diskSizeDetailsProvider.notifier).unmountPath('/Volumes/A');

      expect(container.read(notifyProvider), isEmpty);
    });

    test('ejectDisk rescans the disks on success', () async {
      when(() => mockDiskService.getDisks()).thenAnswer((_) async => []);
      await container.read(diskSizeDetailsProvider.future);
      when(() => mockDiskService.ejectDisk(diskA)).thenAnswer((_) async => null);
      when(() => mockDiskService.getDisks()).thenAnswer((_) async => [diskA]);

      await container.read(diskSizeDetailsProvider.notifier).ejectDisk(diskA);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(container.read(diskSizeDetailsProvider).value, [diskA]);
    });

    test('ejectDisk posts a notification and does not rescan on failure', () async {
      when(() => mockDiskService.getDisks()).thenAnswer((_) async => []);
      await container.read(diskSizeDetailsProvider.future);
      when(() => mockDiskService.ejectDisk(diskA)).thenAnswer((_) async => 'disk in use');

      await container.read(diskSizeDetailsProvider.notifier).ejectDisk(diskA);

      final notifications = container.read(notifyProvider);
      expect(notifications.map((n) => n.message), contains('disk in use'));
      expect(container.read(diskSizeDetailsProvider).value, isEmpty);
    });
  });
}
