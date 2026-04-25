import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  double lat = 0.0;
  double long = 0.0;
  MapboxMap? mapboxMapController;

  Future<geo.Position> _getCurrentLocation() async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled');
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();

    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        return Future.error('Location are denied');
      }
    }

    if (permission == geo.LocationPermission.deniedForever) {
      return Future.error("Location permissions are permanently disabled ");
    }

    geo.Position value = await geo.Geolocator.getCurrentPosition();
    setState(() {
      lat = value.latitude;
      long = value.longitude;
    });

    mapboxMapController?.setCamera(
      CameraOptions(
        center: Point(coordinates: Position(long, lat)),
        zoom: 14.0,
      ),
    );

    return value;
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    CameraOptions cameraOptions = CameraOptions(
      center: Point(
        coordinates: Position(19.14273214558291, 72.84395646537473),
      ),
      zoom: 14,
    );

    void _onMapCreated(MapboxMap controller) {
      setState(() {
        mapboxMapController = controller;
      });
      mapboxMapController?.location.updateSettings(
        LocationComponentSettings(enabled: true, pulsingEnabled: true),
      );
    }

    return Scaffold(
      body: MapWidget(
        cameraOptions: cameraOptions,
        onMapCreated: (controller) {
          _onMapCreated(controller);
        },
      ),
    );
  }
}
