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

    String  latitudeText = "Not set...";
    String longitudeText = "Not set...";

    if (metadata.isNotEmpty) {
      latitudeText  = metadata.length > 1 ? 'Various...' : getLocation(metadata.first, true).replaceAll(' deg', '°');
      longitudeText = metadata.length > 1 ? 'Various...' : getLocation(metadata.first, false).replaceAll(' deg', '°');
    }
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
