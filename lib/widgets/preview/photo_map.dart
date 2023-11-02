import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shackleton/providers/photo_location.dart';

class PhotoMap extends ConsumerWidget {
  const PhotoMap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(builder: (context, watch, child) {
      var markers = ref.watch(photoLocationProvider);
      return markers.when(error: (error, stackTrace) {
        return Text('Failed to get settings.', style: Theme.of(context).textTheme.bodySmall);
      }, loading: () {
        return const Center(heightFactor: 1.0, child: CircularProgressIndicator());
      }, data: (List<Marker> photos) {
        return FlutterMap(
          options: MapOptions(
            initialCenter: photos.isNotEmpty ? photos.first.point : const LatLng(-25.6999972, 140.7333304),
            initialZoom: 6,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all - InteractiveFlag.rotate,),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'au.com.sharpblue.shackleton',
            ),
            MarkerLayer(markers: photos),
          ],
        );
      },
      );
    });
  }
}
