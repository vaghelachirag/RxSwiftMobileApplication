import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../model/navigation_model.dart';

// ─────────────────────────────────────────────────────────────
//  Calgary NW coordinates (matches the mock route stops)
// ─────────────────────────────────────────────────────────────

const _mockStops = [
  NavigationStop(
    id: '1',
    stopNumber: 1,
    patientName: 'John Smith',
    address: '456 Tuscany Dr NW',
    scheduledTime: '12:30 PM',
    location: LatLng(51.1339, -114.2261),
  ),
  NavigationStop(
    id: '2',
    stopNumber: 2,
    patientName: 'Sarah Johnson',
    address: '789 Aspen Dr SW',
    scheduledTime: '01:15 PM',
    location: LatLng(51.0477, -114.1739),
  ),
  NavigationStop(
    id: '3',
    stopNumber: 3,
    patientName: 'Robert Brown',
    address: '123 Rocky Ridge Rd NW',
    scheduledTime: '02:00 PM',
    location: LatLng(51.1220, -114.2100),
  ),
  NavigationStop(
    id: '4',
    stopNumber: 4,
    patientName: 'Linda Wilson',
    address: '321 Crowfoot Cir NW',
    scheduledTime: '02:45 PM',
    location: LatLng(51.1015, -114.1989),
  ),
];

// Driver starts near Tuscany (stop 1) area
const _driverStart = LatLng(51.1180, -114.2090);

// ─────────────────────────────────────────────────────────────
//  Notifier
// ─────────────────────────────────────────────────────────────

class NavigationNotifier extends StateNotifier<NavigationState> {
  NavigationNotifier()
      : super(const NavigationState(stops: _mockStops)) {
    _initNavigation();
  }

  Timer? _simulationTimer;
  int _simStep = 0;

  Future<void> _initNavigation() async {
    // Simulate route calculation delay
    await Future.delayed(const Duration(milliseconds: 800));

    final routePoints = _buildRoutePolyline();

    state = state.copyWith(
      status: NavigationStatus.navigating,
      driverLocation: _driverStart,
      polylinePoints: routePoints,
      estimatedMinutes: 12,
      distanceKm: 5.4,
      etaTime: '12:30 PM',
      isLoadingMap: false,
    );

    _startDriverSimulation();
  }

  /// Builds a realistic-looking curved polyline through all stops
  List<LatLng> _buildRoutePolyline() {
    // Intermediate waypoints to make route look natural on map
    return [
      _driverStart,
      const LatLng(51.1210, -114.2150),
      const LatLng(51.1280, -114.2200),
      _mockStops[0].location, // Stop 1 — Tuscany Dr NW
      const LatLng(51.1100, -114.2050),
      const LatLng(51.0900, -114.1950),
      const LatLng(51.0700, -114.1820),
      _mockStops[1].location, // Stop 2 — Aspen Dr SW
      const LatLng(51.0800, -114.1890),
      const LatLng(51.1000, -114.2020),
      _mockStops[2].location, // Stop 3 — Rocky Ridge Rd NW
      const LatLng(51.1080, -114.2000),
      _mockStops[3].location, // Stop 4 — Crowfoot Cir NW
    ];
  }

  /// Simulates driver moving along the polyline
  void _startDriverSimulation() {
    final points = state.polylinePoints;
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_simStep < points.length - 1) {
        _simStep++;
        final newLoc = points[_simStep];
        // Update ETA as driver moves
        final remainingSteps = points.length - 1 - _simStep;
        final newEta = (remainingSteps * 0.5).ceil();
        state = state.copyWith(
          driverLocation: newLoc,
          estimatedMinutes: newEta.clamp(1, 12),
          distanceKm: ((remainingSteps * 0.42)).clamp(0.1, 5.4),
        );
      } else {
        timer.cancel();
      }
    });
  }

  void onMapCreated(GoogleMapController controller) {
    state = state.copyWith(mapController: controller);
  }

  Future<void> endTrip() async {
    _simulationTimer?.cancel();
    state = state.copyWith(status: NavigationStatus.ended);
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    state.mapController?.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────────────────────

final navigationProvider =
StateNotifierProvider.autoDispose<NavigationNotifier, NavigationState>(
      (ref) => NavigationNotifier(),
);