import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shackleton/providers/location_update.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('LocationUpdate', () {
    test('starts at (0, 0)', () {
      expect(container.read(locationUpdateProvider), const LatLng(0, 0));
    });

    test('setLocation updates the state', () {
      container.read(locationUpdateProvider.notifier).setLocation(const LatLng(27.47, 153.02));

      expect(container.read(locationUpdateProvider), const LatLng(27.47, 153.02));
    });

    test('reset returns to (0, 0)', () {
      final notifier = container.read(locationUpdateProvider.notifier);
      notifier.setLocation(const LatLng(27.47, 153.02));

      notifier.reset();

      expect(container.read(locationUpdateProvider), const LatLng(0, 0));
    });
  });
}
