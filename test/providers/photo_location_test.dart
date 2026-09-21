import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shackleton/models/file_metadata.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/providers/contents/selected_grid_entities.dart';
import 'package:shackleton/providers/metadata.dart';
import 'package:shackleton/providers/photo_location.dart';

// See selected_grid_metadata_test.dart -- Metadata.build() does real,
// unawaited exiftool/DB work, so stub it with metadata keyed by path.
final Map<String, FileMetaData> _stubMetadataByPath = {};

class _StubMetadata extends Metadata {
  @override
  FileMetaData build(FileOfInterest entity) =>
      _stubMetadataByPath[entity.path] ?? FileMetaData(entity: entity, tags: const []);
}

void main() {
  late ProviderContainer container;
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('photo_location_test_');
    _stubMetadataByPath.clear();
    container = ProviderContainer(overrides: [
      metadataProvider.overrideWith2((entity) => _StubMetadata()),
    ]);
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  FileOfInterest file(String name) => FileOfInterest(entity: File('${tempDir.path}/$name'));

  group('PhotoLocation', () {
    // photo_location is autoDispose with an async build(); container.read()
    // alone leaves no listener, so it can be torn down before the Future
    // resolves (same class of bug fixed in metadata_provider_test.dart) --
    // each test below keeps a listener open across the await.
    test('is empty when nothing is selected', () async {
      final sub = container.listen(photoLocationProvider, (_, _) {});
      addTearDown(sub.close);

      final markers = await container.read(photoLocationProvider.future);

      expect(markers, isEmpty);
    });

    test('adds a marker for a selected entity with a GPS location', () async {
      final sub = container.listen(photoLocationProvider, (_, _) {});
      addTearDown(sub.close);
      final a = file('a.jpg');
      _stubMetadataByPath[a.path] = FileMetaData(
        entity: a,
        tags: const [],
        gpsLocation: const LatLng(27.47, 153.02),
      );
      container.read(selectedGridEntitiesProvider.notifier).add(a);

      final markers = await container.read(photoLocationProvider.future);

      expect(markers, hasLength(1));
      expect(markers.first.point, const LatLng(27.47, 153.02));
    });

    test('skips selected entities without a GPS location', () async {
      final sub = container.listen(photoLocationProvider, (_, _) {});
      addTearDown(sub.close);
      final a = file('a.jpg');
      _stubMetadataByPath[a.path] = FileMetaData(entity: a, tags: const []);
      container.read(selectedGridEntitiesProvider.notifier).add(a);

      final markers = await container.read(photoLocationProvider.future);

      expect(markers, isEmpty);
    });
  });
}
