import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:shackleton/misc/utils.dart';
import 'package:shackleton/models/file_metadata.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/providers/metadata.dart';

void main() {
  test('can add tags to empty set', () async {
    final FileOfInterest foi = FileOfInterest(entity: File('aaa'));
    final ProviderContainer container = ProviderContainer();

    container.listen(metadataProvider(foi), (previous, next) {
      expect(next.tags.length, 2);
    });

    container.read(metadataProvider(foi).notifier).updateTagsFromString('one, two', updateFile: false);
  });

  test('can add tags to populated set', () async {
    final FileOfInterest foi = FileOfInterest(entity: File('aaa'));
    final ProviderContainer container = ProviderContainer();

    int expectedTags = 0;
    final mockMetadataProvider = container.read(metadataProvider(foi));
    expect(mockMetadataProvider.tags.length, expectedTags);

    container.listen(metadataProvider(foi), (previous, next) {
      expect(next.tags.length, expectedTags);
    });

    expectedTags = 2;
    container.read(metadataProvider(foi).notifier).replaceTagsFromString('two, three', updateFile: false);

    expectedTags = 3;
    container.read(metadataProvider(foi).notifier).updateTagsFromString('one, two', updateFile: false);
  });

  test('validate longitude and latitude processing', () async {
    LatLng ll = LatLng(double.parse('43.6597083333333'), double.parse('-78.5631361111111'));

    FileMetaData fmd = FileMetaData(tags: const [], gpsLocation: ll);
    String latitude  = getLocation(fmd, true).replaceAll("'", "\\'").replaceAll('"', '\\"');
    String longitude = getLocation(fmd, false).replaceAll("'", "\\'").replaceAll('"', '\\"');

    expect(latitude, '43 deg 39\\\' 34.95\\" N');
    expect(longitude, '78 deg 33\\\' 47.29\\" W');
  });
}