// ============================================================================
// features/today_route/route_map/widgets/route_map_google_view.dart
//
// ADDITIVE — a real GoogleMap that shows ALL stops + the actual road route
// through every point (fetched via allPointsRouteProvider). Mirrors the
// GoogleMap configuration used in navigation_screen.dart.
//
// This does NOT replace the existing stylised `RouteMapView`. To use it,
// swap `RouteMapView(...)` for `RouteMapGoogleView(...)` in route_map_screen,
// OR keep both and toggle. Nothing else needs to change.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../route_map/theme/route_map_theme.dart';
import '../../../route_map/widgets/route_map_atoms.dart';
import '../../model/route_model.dart';
import '../../numbered_marker_factory.dart';
import '../provider/all_points_route_provider.dart';

class RouteMapGoogleView extends ConsumerStatefulWidget {
  const RouteMapGoogleView({
    super.key,
    required this.route,
    required this.selectedIndex,
    required this.onMarkerTap,
    required this.onRecenter,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final TodayRoute route;
  final int selectedIndex;
  final ValueChanged<int> onMarkerTap;
  final VoidCallback onRecenter;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  ConsumerState<RouteMapGoogleView> createState() =>
      _RouteMapGoogleViewState();
}

class _RouteMapGoogleViewState extends ConsumerState<RouteMapGoogleView> {
  GoogleMapController? _controller;

  final Map<MarkerId, Marker> _markers = {};
  bool _markersLoaded = false;

  @override
  void initState() {
    super.initState();
    _rebuildMarkers();
  }

  @override
  void didUpdateWidget(covariant RouteMapGoogleView old) {
    super.didUpdateWidget(old);
    // Rebuild when the route or the selected stop changes (colors/sizes shift).
    if (old.route != widget.route ||
        old.selectedIndex != widget.selectedIndex) {
      _rebuildMarkers();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // ── Build custom NUMBERED markers asynchronously ─────────────
  Future<void> _rebuildMarkers() async {
    final factory = NumberedMarkerFactory.instance;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final stops = widget.route.stops;
    final markers = <MarkerId, Marker>{};

    for (int i = 0; i < stops.length; i++) {
      final s = stops[i];
      if (!s.hasCoordinates) continue;

      final icon = await factory.stopPin(
        s,
        devicePixelRatio: dpr,
        selected: i == widget.selectedIndex,
      );

      final active = s.status == StopStatus.inProgress;
      final id = MarkerId('stop_${s.id}');
      markers[id] = Marker(
        markerId: id,
        position: LatLng(s.latitude, s.longitude),
        icon: icon,
        anchor: const Offset(0.5, 1.0), // tip of the pin sits on the point
        zIndex: active
            ? 3
            : i == widget.selectedIndex
            ? 2
            : 1,
        infoWindow: InfoWindow(
          title: '${s.stopNumber}. ${s.patientName}',
          snippet: '${s.stopType.label} · ${s.pharmacyName}',
        ),
        onTap: () => widget.onMarkerTap(i),
      );
    }

    // Start (driver origin) point.
    final r = widget.route;
    if (r.startLatitude != 0 && r.startLongitude != 0) {
      final startIcon = await factory.startPin(devicePixelRatio: dpr);
      const id = MarkerId('start');
      markers[id] = Marker(
        markerId: id,
        position: LatLng(r.startLatitude, r.startLongitude),
        icon: startIcon,
        anchor: const Offset(0.5, 0.5),
        zIndex: 4,
        infoWindow: const InfoWindow(title: 'Start'),
      );
    }

    if (!mounted) return;
    setState(() {
      _markers
        ..clear()
        ..addAll(markers);
      _markersLoaded = true;
    });
  }

  Set<Polyline> _buildPolyline(List<LatLng> points) {
    if (points.isEmpty) return const {};
    return {
      Polyline(
        polylineId: const PolylineId('all_points_route'),
        points: points,
        color: RouteColors.teal,
        width: 6,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  LatLng _initialTarget() {
    final r = widget.route;
    if (r.startLatitude != 0 && r.startLongitude != 0) {
      return LatLng(r.startLatitude, r.startLongitude);
    }
    final first = r.stops.firstWhere(
          (s) => s.hasCoordinates,
      orElse: () => r.stops.first,
    );
    return LatLng(first.latitude, first.longitude);
  }

  /// Fit the camera to show every point once the route is known.
  Future<void> _fitToRoute(List<LatLng> pts) async {
    final c = _controller;
    if (c == null || pts.isEmpty) return;
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    await c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 64));
  }

  @override
  Widget build(BuildContext context) {
    final routeAsync = ref.watch(allPointsRouteProvider(widget.route));
    final polylinePoints =
    routeAsync.maybeWhen(data: (r) => r.polylinePoints, orElse: () => const <LatLng>[]);

    // When the road route arrives, frame all points.
    ref.listen(allPointsRouteProvider(widget.route), (_, next) {
      next.whenData((r) => _fitToRoute(r.polylinePoints));
    });

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            initialCameraPosition:
            CameraPosition(target: _initialTarget(), zoom: 12),
            onMapCreated: (c) {
              _controller = c;
              if (polylinePoints.isNotEmpty) _fitToRoute(polylinePoints);
            },
            markers: _markersLoaded
                ? Set<Marker>.of(_markers.values)
                : const {},
            polylines: _buildPolyline(polylinePoints),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            trafficEnabled: false,
            padding: EdgeInsets.only(
              top: 12,
              bottom: MediaQuery.of(context).size.height * 0.28,
            ),
          ),
        ),

        // Loading shimmer while the multi-leg route is being fetched.
        if (routeAsync.isLoading)
          const Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: Center(child: _RouteLoadingChip()),
          ),

        // Legend (top-left), same as the stylised view.
        const Positioned(top: 12, left: 12, child: MapLegend()),

        // Zoom controls (bottom-right).
        Positioned(
          right: 12,
          bottom: 12,
          child: Column(
            children: [
              MapControlButton(
                icon: Icons.add,
                onTap: () {
                  _controller?.animateCamera(CameraUpdate.zoomIn());
                  widget.onZoomIn();
                },
              ),
              const SizedBox(height: 6),
              MapControlButton(
                icon: Icons.remove,
                onTap: () {
                  _controller?.animateCamera(CameraUpdate.zoomOut());
                  widget.onZoomOut();
                },
              ),
            ],
          ),
        ),

        // Recenter / fit-all (bottom-left).
        Positioned(
          left: 12,
          bottom: 12,
          child: MapControlButton(
            icon: Icons.my_location_rounded,
            iconColor: RouteColors.teal,
            onTap: () {
              _fitToRoute(polylinePoints);
              widget.onRecenter();
            },
          ),
        ),
      ],
    );
  }
}

class _RouteLoadingChip extends StatelessWidget {
  const _RouteLoadingChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(RouteRadius.full),
        boxShadow: RouteShadows.floating,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: RouteColors.teal),
          ),
          SizedBox(width: 8),
          Text(
            'Building route…',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: RouteColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}