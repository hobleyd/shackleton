import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shackleton/providers/location_update.dart';

import '../../providers/photo_location.dart';

class PhotoMap extends ConsumerStatefulWidget {
  const PhotoMap({super.key});

  @override
  ConsumerState<PhotoMap> createState() => _PhotoMap();
}

class _PhotoMap extends ConsumerState<PhotoMap> {
  late TextEditingController _searchController;
  late MapController _mapController;
  late FocusNode _searchFocus;
  Timer? _debounce;

  List<OSMdata> _locationOptions = [];
  LatLng? _selectedLocation;

  @override
  Widget build(BuildContext context,) {
    return Consumer(builder: (context, watch, child) {
      var markers = ref.watch(photoLocationProvider);
      return markers.when(
        error: (error, stackTrace) {
          return Text('Failed to get settings.', style: Theme.of(context).textTheme.bodySmall);
        },
        loading: () {
          return const Center(heightFactor: 1.0, child: CircularProgressIndicator());
        },
        data: (List<Marker> photos) {
          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: photos.isNotEmpty ? photos.first.point : const LatLng(-25.6999972, 140.7333304),
                  initialZoom: 6,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all - InteractiveFlag.rotate,
                  ),
                  onTap: (TapPosition pos, LatLng point) => _locationTapped(ref, pos, point),
                ),
                mapController: _mapController,
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'au.com.sharpblue.shackleton',
                  ),
                  MarkerLayer(markers: [...photos, if (_selectedLocation != null) Marker(point: _selectedLocation!, height: 6, width: 6, child: const Icon(Icons.flag, color: Colors.blue))]),
                ],
              ),
              if (_locationOptions.isNotEmpty)
                Positioned(
                  bottom: 60,
                  left: 10,
                  right: 10,
                  top: 10,
                  child: CustomScrollView(
                    slivers: [
                      SliverList(
                        delegate: SliverChildListDelegate(
                          _locationOptions.map((loc) => ListTile(
                                    dense: true,
                                    title: Text(loc.displayname, style: Theme.of(context).textTheme.bodySmall),
                                    subtitle: Text('${loc.lat},${loc.lon}', style: Theme.of(context).textTheme.titleSmall),
                                    onTap: () {
                                      _selectedLocation = LatLng(loc.lat, loc.lon);
                                      _mapController.move(_selectedLocation!, 15.0);
                                      _searchController.text = '';
                                      _locationOptions.clear();
                                      _searchFocus.unfocus();
                                      setState(() {});
                                    },
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 10,
                right: 10,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, right: 10, bottom: 20),
                  child: TextField(
                    autofocus: false,
                    controller: _searchController,
                    decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(width: 2, color: Colors.grey),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        // Set border for focused state
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(width: 2, color: Colors.teal),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        hintText: 'Search places...',
                        isDense: true),
                    focusNode: _searchFocus,
                    keyboardType: TextInputType.text,
                    maxLines: 1,
                    onChanged: (searchTerm) {
                      if (_debounce?.isActive ?? false) _debounce?.cancel();

                      _debounce = Timer(const Duration(milliseconds: 1000), () async {
                        var client = http.Client();
                        try {
                          String url = Uri.encodeFull('https://nominatim.openstreetmap.org/search?q=$searchTerm&format=json&polygon_geojson=1&addressdetails=1');
                          var response = await client.get(Uri.parse(url));
                          var decodedResponse = jsonDecode(response.body) as List<dynamic>;

                          _locationOptions =
                              decodedResponse.map((e) => OSMdata(displayname: e['display_name'], lat: double.parse(e['lat']), lon: double.parse(e['lon']))).toList();
                          setState(() {});
                        } finally {
                          client.close();
                        }

                        setState(() {});
                      });
                    },
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
            ],
          );
        },
      );
    });
  }

  @override
  void initState() {
    super.initState();

    _searchFocus = FocusNode();
    _mapController = MapController();
    _searchController = TextEditingController();
  }

  void _locationTapped(WidgetRef ref, TapPosition pos, LatLng point) {
    ref.read(locationUpdateProvider.notifier).setLocation(point);
  }
}

class OSMdata {
  final String displayname;
  final double lat;
  final double lon;

  OSMdata({required this.displayname, required this.lat, required this.lon});

  @override
  String toString() {
    return '$displayname, $lat, $lon';
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is OSMdata && other.displayname == displayname;
  }

  @override
  int get hashCode => Object.hash(displayname, lat, lon);
}