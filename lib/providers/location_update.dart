import 'package:latlong2/latlong.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'location_update.g.dart';

@riverpod
class LocationUpdate extends _$LocationUpdate {
  @override
  LatLng build() {
    return const LatLng(0, 0);
  }

  void reset() {
    state = const LatLng(0, 0);
  }

  void setLocation(LatLng location) {
    state = location;
  }
}
