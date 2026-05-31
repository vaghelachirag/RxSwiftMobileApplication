// ============================================================================
// lib/features/today_route/route_map/repository/location_sync_repository.dart
//
// Handles:
//   1. Location permission check + request.
//   2. Location service (GPS) enabled check + open settings prompt.
//   3. Reading the current position (lat, lng, speed, heading).
//   4. Calling the remote datasource to push the location to the API.
//
// This class is intentionally free of Flutter UI — callers (provider/screen)
// handle any prompts or dialogs.
// ============================================================================

import 'package:geolocator/geolocator.dart';

import '../../../../core/network/api_result.dart';
import '../../model/location_sync_model.dart';
import '../data/location_sync_remote_datasource.dart';


// ── Typed result for the permission check ─────────────────────────────────

enum LocationReadiness {
  ready,           // permission granted, service on
  serviceDisabled, // GPS/location service is off
  permissionDenied,
  permissionPermanentlyDenied,
}

class LocationSyncRepository {
  LocationSyncRepository(this._remote);
  final LocationSyncRemoteDataSource _remote;

  // ── Permission & service check ────────────────────────────────────────────

  /// Returns the current readiness state without requesting anything.
  Future<LocationReadiness> checkReadiness() async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) return LocationReadiness.serviceDisabled;

    final permission = await Geolocator.checkPermission();
    return _permissionToReadiness(permission);
  }

  /// Requests permission if needed. Returns the final readiness state.
  Future<LocationReadiness> requestPermission() async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) return LocationReadiness.serviceDisabled;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return _permissionToReadiness(permission);
  }

  LocationReadiness _permissionToReadiness(LocationPermission p) {
    switch (p) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationReadiness.ready;
      case LocationPermission.deniedForever:
        return LocationReadiness.permissionPermanentlyDenied;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationReadiness.permissionDenied;
    }
  }

  /// Opens the device location settings so the driver can enable GPS.
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  /// Opens the app settings page (for permanently-denied permission).
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  // ── Location read + sync ──────────────────────────────────────────────────

  /// Reads the current position and pushes it to the API.
  /// Any exception (GPS timeout, network failure) is caught and ignored —
  /// the next timer tick will retry automatically.
  Future<void> syncOnce() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      final request = LocationSyncRequest(
        latitude: pos.latitude,
        longitude: pos.longitude,
        // speed comes in m/s from Geolocator — convert to km/h.
        speedKph: (pos.speed < 0 ? 0.0 : pos.speed) * 3.6,
        // heading is 0–360 degrees; -1 means unavailable → send 0.
        heading: pos.heading < 0 ? 0.0 : pos.heading,
      );

      // ApiResult.failure is silently discarded — no UI feedback needed.
      await _remote.updateLocation(request);
    } catch (_) {
      // Silent failure — next interval will retry.
    }
  }
}