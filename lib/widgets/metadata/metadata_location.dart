import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';


import '../../misc/utils.dart';
import '../../models/file_metadata.dart';
import '../../providers/location_update.dart';
import '../../providers/metadata.dart';
import '../../providers/selected_entities/selected_entities.dart';
import '../../providers/selected_entities/selected_metadata.dart';

class MetadataLocation extends ConsumerWidget {
  final FileType selectedListType;
  final FileType completeListType;

  const MetadataLocation({Key? key, required this.selectedListType, required this.completeListType}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref,) {
    LatLng newLocation = ref.watch(locationUpdateProvider);
    List<FileMetaData> metadata = ref.watch(selectedMetadataProvider(selectedListType, completeListType));

    var map = {};
    for (var m in metadata) {
      if (m.gpsLocation != null) {
        map[m.gpsLocation] = !map.containsKey(m.gpsLocation) ? (1) : (map[m.gpsLocation] + 1);
      }
    }

    String latitudeText =
      switch (map.length) {
        0 => "No location set.",
        1 => getLocation(metadata.first, true).replaceAll(' deg', '°'),
        _ => "Various...",
      };

    String longitudeText =
      switch (map.length) {
        0 => "No location set.",
        1 => getLocation(metadata.first, false).replaceAll(' deg', '°'),
        _ => "Various...",
      };

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 80, child: Text('Latitude: ', textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelSmall),),
            const SizedBox(width: 5),
            Expanded(child: Text(latitudeText, style: Theme.of(context).textTheme.bodySmall),),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 80, child: Text('Longitude: ', textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelSmall),),
            const SizedBox(width: 5),
            Expanded(child: Text(longitudeText, style: Theme.of(context).textTheme.bodySmall),),
          ],
        ),
        if (newLocation.latitude != 0 && newLocation.longitude != 0 )
          ...[
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _acceptLocation(ref, metadata, newLocation),
              child: Text('Accept new location', style: Theme.of(context).textTheme.labelSmall),
            ),
          ]
      ],
    );
  }

  void _acceptLocation(WidgetRef ref, List<FileMetaData> metadata, LatLng location) {
    for (var meta in metadata) {
      var m = ref.read(metadataProvider(meta.entity!).notifier);
      m.setLocation(location);
    }

    ref.read(locationUpdateProvider.notifier).reset();
  }
}
