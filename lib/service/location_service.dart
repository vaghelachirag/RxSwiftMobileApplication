import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Result of a permission/availability check.
enum LocationCheckResult {
  ready,
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
}

class LocationService {
  /// Performs both the service-enabled check and the permission check.
  Future<LocationCheckResult> ensureLocationAvailable() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationCheckResult.serviceDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationCheckResult.permissionDenied;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationCheckResult.permissionPermanentlyDenied;
    }
    return LocationCheckResult.ready;
  }

  Future<LatLng> getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );
    return LatLng(position.latitude, position.longitude);
  }

  Stream<Position> liveLocationStream({int distanceFilterMeters = 10}) {
    final settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: distanceFilterMeters,
    );
    return Geolocator.getPositionStream(locationSettings: settings);
  }

  double distanceBetweenMeters(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  /// Open device location settings (used when service is disabled).
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// Open the app's settings page (used when permission is permanently denied).
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}