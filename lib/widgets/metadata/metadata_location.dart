import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shackleton/providers/location_update.dart';
import 'package:shackleton/providers/metadata.dart';

import '../../misc/utils.dart';
import '../../models/file_metadata.dart';
import '../../models/file_of_interest.dart';
import '../../providers/selected_entities.dart';

class MetadataLocation extends ConsumerWidget {
  final Set<FileOfInterest> entities;

  const MetadataLocation({Key? key, required this.entities}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref,) {
    LatLng newLocation = ref.watch(locationUpdateProvider);
    FileMetaData? metadata = entities.isNotEmpty ? ref.watch(metadataProvider(entities.first)) : null;

    String  latitudeText = entities.length > 1 ? 'Various...' : getLocation(metadata, true).replaceAll(' deg', '°');
    String longitudeText = entities.length > 1 ? 'Various...' : getLocation(metadata, false).replaceAll(' deg', '°');

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 80, child: Text('Latitude: ', textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelSmall),),
            const SizedBox(width: 5),
            Expanded(child: Text(latitudeText.isEmpty ? 'Not set...' : latitudeText, style: Theme.of(context).textTheme.bodySmall),),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 80, child: Text('Longitude: ', textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelSmall),),
            const SizedBox(width: 5),
            Expanded(child: Text(longitudeText.isEmpty ? 'Not set...' : longitudeText, style: Theme.of(context).textTheme.bodySmall),),
          ],
        ),
        if (newLocation.latitude != 0 && newLocation.longitude != 0 )
          ...[
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _acceptLocation(ref, newLocation),
              child: Text('Accept new location', style: Theme.of(context).textTheme.labelSmall),
            ),
          ]
      ],
    );
  }

  void _acceptLocation(WidgetRef ref, LatLng location) {
    var selectedEntities = ref.read(selectedEntitiesProvider(FileType.previewPane));

    for (var entity in selectedEntities) {
      var metadata = ref.read(metadataProvider(entity).notifier);
      metadata.setLocation(entity, location);
    }

    ref.read(locationUpdateProvider.notifier).reset();
  }
}
