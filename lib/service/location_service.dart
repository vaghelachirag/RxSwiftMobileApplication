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

/// Wraps Geolocator with the exact behaviour our navigation flow expects:
///   1. Verify location service is enabled
///   2. Verify (and if needed, request) permission
///   3. Provide single-shot current location
///   4. Provide a live stream of location updates with sensible throttling
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

  /// Single-shot current location. Call only after [ensureLocationAvailable]
  /// returns [LocationCheckResult.ready].
  ///
  /// Uses the [desiredAccuracy] / [timeLimit] signature, which is supported
  /// across geolocator 7.x – 11.x.
  Future<LatLng> getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );
    return LatLng(position.latitude, position.longitude);
  }

  /// Live updates. We throttle by distance (10 m) so we don't hammer the UI
  /// or trigger Directions API calls on every GPS tick.
  Stream<Position> liveLocationStream({int distanceFilterMeters = 10}) {
    final settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: distanceFilterMeters,
    );
    return Geolocator.getPositionStream(locationSettings: settings);
  }

  /// Helper to compute distance in metres between two coordinates.
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