

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Engine's directions service provider (unchanged). Same path the screen uses.
import 'package:rxswift/features/navigation/provider/navigation_provider.dart'
    show directionsServiceProvider;
// DirectionsException type. directions_service.dart lives at lib/service/.
import 'package:rxswift/service/directions_service.dart';

import '../../model/route_model.dart';

/// The fully-resolved road route across every stop.
class AllPointsRoute {
  const AllPointsRoute({
    required this.polylinePoints,
    required this.totalDistanceKm,
    required this.totalMinutes,
  });

  /// Road-following points spanning start → all stops, ready for a Polyline.
  final List<LatLng> polylinePoints;
  final double totalDistanceKm;
  final int totalMinutes;

  static const empty = AllPointsRoute(
    polylinePoints: [],
    totalDistanceKm: 0,
    totalMinutes: 0,
  );
}

/// Builds the ordered list of waypoints: optional [start] then each stop with
/// usable coordinates, in sequence.
List<LatLng> _waypoints(TodayRoute route) {
  final pts = <LatLng>[];
  if (route.startLatitude != 0 && route.startLongitude != 0) {
    pts.add(LatLng(route.startLatitude, route.startLongitude));
  }
  for (final s in route.stops) {
    if (s.hasCoordinates) pts.add(LatLng(s.latitude, s.longitude));
  }
  return pts;
}

/// Fetches and concatenates the road route across all legs.
///
/// `.family` keyed by the route, so it refetches if the route changes.
/// AutoDispose so it tears down when the map screen is gone.
final allPointsRouteProvider = FutureProvider.autoDispose
    .family<AllPointsRoute, TodayRoute>((ref, route) async {
  final directions = ref.read(directionsServiceProvider);
  final waypoints = _waypoints(route);

  if (waypoints.length < 2) return AllPointsRoute.empty;

  final combined = <LatLng>[];
  double totalKm = 0;
  int totalMin = 0;

  for (int i = 0; i < waypoints.length - 1; i++) {
    try {
      final leg = await directions.getRoute(
        origin: waypoints[i],
        destination: waypoints[i + 1],
      );
      // Avoid duplicating the shared vertex between consecutive legs.
      if (combined.isNotEmpty && leg.polylinePoints.isNotEmpty) {
        combined.addAll(leg.polylinePoints.skip(1));
      } else {
        combined.addAll(leg.polylinePoints);
      }
      totalKm += leg.distanceKm;
      totalMin += leg.durationMinutes;
    } on DirectionsException {
      // If a leg fails, fall back to a straight segment so the route stays
      // continuous rather than breaking entirely.
      combined.add(waypoints[i]);
      combined.add(waypoints[i + 1]);
    }
  }

  return AllPointsRoute(
    polylinePoints: combined,
    totalDistanceKm: totalKm,
    totalMinutes: totalMin,
  );
});