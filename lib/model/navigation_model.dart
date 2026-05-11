import 'package:google_maps_flutter/google_maps_flutter.dart';

// ─────────────────────────────────────────────────────────────
//  Navigation Models
// ─────────────────────────────────────────────────────────────

enum NavigationStatus { idle, navigating, arrived, ended }

class NavigationStop {
  const NavigationStop({
    required this.id,
    required this.stopNumber,
    required this.patientName,
    required this.address,
    required this.scheduledTime,
    required this.location,
  });

  final String id;
  final int stopNumber;
  final String patientName;
  final String address;
  final String scheduledTime;
  final LatLng location;
}

class NavigationState {
  const NavigationState({
    this.status = NavigationStatus.idle,
    this.stops = const [],
    this.currentStopIndex = 0,
    this.driverLocation,
    this.polylinePoints = const [],
    this.estimatedMinutes = 0,
    this.distanceKm = 0.0,
    this.etaTime = '',
    this.isLoadingMap = true,
    this.mapController,
  });

  final NavigationStatus status;
  final List<NavigationStop> stops;
  final int currentStopIndex;
  final LatLng? driverLocation;
  final List<LatLng> polylinePoints;
  final int estimatedMinutes;
  final double distanceKm;
  final String etaTime;
  final bool isLoadingMap;
  final GoogleMapController? mapController;

  NavigationStop? get currentStop =>
      stops.isNotEmpty && currentStopIndex < stops.length
          ? stops[currentStopIndex]
          : null;

  bool get isNavigating => status == NavigationStatus.navigating;
  bool get isEnded => status == NavigationStatus.ended;

  NavigationState copyWith({
    NavigationStatus? status,
    List<NavigationStop>? stops,
    int? currentStopIndex,
    LatLng? driverLocation,
    List<LatLng>? polylinePoints,
    int? estimatedMinutes,
    double? distanceKm,
    String? etaTime,
    bool? isLoadingMap,
    GoogleMapController? mapController,
  }) {
    return NavigationState(
      status: status ?? this.status,
      stops: stops ?? this.stops,
      currentStopIndex: currentStopIndex ?? this.currentStopIndex,
      driverLocation: driverLocation ?? this.driverLocation,
      polylinePoints: polylinePoints ?? this.polylinePoints,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      distanceKm: distanceKm ?? this.distanceKm,
      etaTime: etaTime ?? this.etaTime,
      isLoadingMap: isLoadingMap ?? this.isLoadingMap,
      mapController: mapController ?? this.mapController,
    );
  }
}