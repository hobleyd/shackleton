import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/file_metadata.dart';
import '../../providers/selected_entities.dart';

import 'metadata.dart';

part 'photo_location.g.dart';

@riverpod
class PhotoLocation extends _$PhotoLocation {
  @override
  Future<List<Marker>> build() async {
    var selectedEntities = ref.watch(selectedEntitiesProvider(FileType.previewPane));
    List<Marker> markers = [];

    for (var e in selectedEntities) {
      FileMetaData metadata = ref.read(metadataProvider(e));

      LatLng? ll = metadata.gpsLocation;
      if (ll != null) {
        markers.add(Marker(point: ll, height: 6, width: 6, child: const Icon(Icons.flag, color: Colors.red)));
      }
    }
    return markers;
  }
}
