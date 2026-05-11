import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:rxswift/features/navigation/provider/navigation_provider.dart';
import '../../model/navigation_model.dart';
import '../../theme/app_theme.dart';
import '../today_route/today_route_screen.dart';

// ─────────────────────────────────────────────────────────────
//  Navigation Map Screen
// ─────────────────────────────────────────────────────────────

class NavigationMapScreen extends ConsumerStatefulWidget {
  const NavigationMapScreen({super.key});

  @override
  ConsumerState<NavigationMapScreen> createState() =>
      _NavigationMapScreenState();
}

class _NavigationMapScreenState extends ConsumerState<NavigationMapScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bottomCardController;
  late Animation<Offset> _bottomCardSlide;
  late Animation<double> _bottomCardFade;

  @override
  void initState() {
    super.initState();
    _bottomCardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _bottomCardSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _bottomCardController, curve: Curves.easeOut));
    _bottomCardFade = CurvedAnimation(
        parent: _bottomCardController, curve: Curves.easeOut);

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _bottomCardController.forward();
    });
  }

  @override
  void dispose() {
    _bottomCardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(navigationProvider);

    // Listen for trip ended — pop back to route list
    ref.listen<NavigationState>(navigationProvider, (prev, next) {
      if (next.isEnded && mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const TodayRouteScaffold(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            // ── 1. Google Map (full screen) ───────────────
            _MapView(state: state),

            // ── 2. Top navigation header ──────────────────
            _TopHeader(currentStop: state.currentStop),

            // ── 3. Loading overlay ────────────────────────
            if (state.isLoadingMap) const _MapLoadingOverlay(),

            // ── 4. Bottom info card + End Trip button ─────
            if (!state.isLoadingMap)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SlideTransition(
                  position: _bottomCardSlide,
                  child: FadeTransition(
                    opacity: _bottomCardFade,
                    child: _BottomInfoCard(state: state),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Google Map View
// ─────────────────────────────────────────────────────────────

class _MapView extends ConsumerWidget {
  const _MapView({required this.state});
  final NavigationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoadingMap || state.stops.isEmpty) {
      return Container(color: const Color(0xFFE8F0E8));
    }

    final markers = _buildMarkers(state);
    final polylines = _buildPolyline(state);

    // Camera targets the current stop
    final target = state.driverLocation ?? state.stops.first.location;
    final initialCamera = CameraPosition(
      target: target,
      zoom: 13.0,
      tilt: 0,
    );

    return GoogleMap(
      initialCameraPosition: initialCamera,
      onMapCreated: (controller) {
        ref.read(navigationProvider.notifier).onMapCreated(controller);
        // Apply custom map style (green theme)
        controller.setMapStyle(_greenMapStyle);
        // Animate to show full route
        if (state.polylinePoints.isNotEmpty) {
          final bounds = _boundsFromLatLngList(state.polylinePoints);
          controller.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 80),
          );
        }
      },
      markers: markers,
      polylines: polylines,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      trafficEnabled: false,
      padding: EdgeInsets.only(
        top: 130,
        bottom: MediaQuery.of(context).size.height * 0.28,
      ),
    );
  }

  Set<Marker> _buildMarkers(NavigationState state) {
    final markers = <Marker>{};

    // Destination pin (red — matches screenshot)
    if (state.currentStop != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: state.currentStop!.location,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(
            title: state.currentStop!.patientName,
            snippet: state.currentStop!.address,
          ),
        ),
      );
    }

    // Remaining stops (smaller blue markers)
    for (int i = 0; i < state.stops.length; i++) {
      if (i == state.currentStopIndex) continue;
      final stop = state.stops[i];
      markers.add(
        Marker(
          markerId: MarkerId('stop_${stop.id}'),
          position: stop.location,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          alpha: 0.7,
          infoWindow: InfoWindow(
            title: '${stop.stopNumber}. ${stop.patientName}',
            snippet: stop.address,
          ),
        ),
      );
    }

    // Driver location (circular avatar — matches screenshot)
    if (state.driverLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: state.driverLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueCyan,
          ),
          anchor: const Offset(0.5, 0.5),
          zIndex: 2,
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolyline(NavigationState state) {
    if (state.polylinePoints.isEmpty) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: state.polylinePoints,
        color: const Color(0xFF2979FF), // bright blue matching screenshot
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in list) {
      if (minLat == null || p.latitude < minLat) minLat = p.latitude;
      if (maxLat == null || p.latitude > maxLat) maxLat = p.latitude;
      if (minLng == null || p.longitude < minLng) minLng = p.longitude;
      if (maxLng == null || p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Top Header   "Navigate  ←  456 Tuscany Dr NW · Calgary, AB"
// ─────────────────────────────────────────────────────────────

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.currentStop});
  final NavigationStop? currentStop;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── Title row ──────────────────────────────
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20),
                      color: AppColors.primary,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Text(
                        'Navigate',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // balance back button
                  ],
                ),
              ),

              // ── Green destination banner ───────────────
              if (currentStop != null)
                Container(
                  width: double.infinity,
                  color: AppColors.teal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.turn_right_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentStop!.address,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Calgary, AB',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Bottom Info Card  "12 min · 5.4 km · 12:30 PM ETA  [End Trip]"
// ─────────────────────────────────────────────────────────────

class _BottomInfoCard extends ConsumerWidget {
  const _BottomInfoCard({required this.state});
  final NavigationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPad + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag pill ──────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // ── ETA info ──────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Big ETA minutes
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        '${state.estimatedMinutes} min',
                        key: ValueKey(state.estimatedMinutes),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Distance · ETA time
                    Row(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: Text(
                            '${state.distanceKm.toStringAsFixed(1)} km',
                            key: ValueKey(state.distanceKm),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Padding(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '•',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textHint,
                            ),
                          ),
                        ),
                        Text(
                          '${state.etaTime} ETA',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── End Trip button ───────────────────────
              _EndTripButton(
                onPressed: () async {
                  final confirmed = await _showEndTripDialog(context);
                  if (confirmed == true) {
                    ref.read(navigationProvider.notifier).endTrip();
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Stop progress indicator ────────────────────
          _StopProgressRow(state: state),
        ],
      ),
    );
  }

  Future<bool?> _showEndTripDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          'End Trip?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Are you sure you want to end the current trip? Any undelivered stops will remain pending.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              elevation: 0,
            ),
            child: const Text(
              'End Trip',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  End Trip Button  (teal, rounded, matches screenshot)
// ─────────────────────────────────────────────────────────────

class _EndTripButton extends StatelessWidget {
  const _EndTripButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: const Text(
          'End Trip',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Stop progress row  (dots showing all stops)
// ─────────────────────────────────────────────────────────────

class _StopProgressRow extends StatelessWidget {
  const _StopProgressRow({required this.state});
  final NavigationState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < state.stops.length; i++) ...[
          _StopDot(
            stop: state.stops[i],
            isCurrent: i == state.currentStopIndex,
            isPast: i < state.currentStopIndex,
          ),
          if (i < state.stops.length - 1)
            Expanded(
              child: Container(
                height: 2,
                color: i < state.currentStopIndex
                    ? AppColors.teal
                    : AppColors.border,
              ),
            ),
        ],
      ],
    );
  }
}

class _StopDot extends StatelessWidget {
  const _StopDot({
    required this.stop,
    required this.isCurrent,
    required this.isPast,
  });
  final NavigationStop stop;
  final bool isCurrent;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final color = isPast
        ? AppColors.teal
        : isCurrent
        ? AppColors.primary
        : AppColors.border;

    return Tooltip(
      message: stop.patientName,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(isCurrent ? 0.15 : isPast ? 0.12 : 0.06),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: Center(
          child: isPast
              ? Icon(Icons.check_rounded, size: 14, color: color)
              : Text(
            '${stop.stopNumber}',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Map loading overlay
// ─────────────────────────────────────────────────────────────

class _MapLoadingOverlay extends StatelessWidget {
  const _MapLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE4EFE4),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.teal),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Calculating route…',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Custom green map style JSON
// ─────────────────────────────────────────────────────────────

const _greenMapStyle = '''
[
  {
    "featureType": "poi",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "transit",
    "stylers": [{"visibility": "simplified"}]
  },
  {
    "featureType": "landscape.natural",
    "elementType": "geometry.fill",
    "stylers": [{"color": "#dde8d8"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry.fill",
    "stylers": [{"color": "#b3d4e8"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.fill",
    "stylers": [{"color": "#f5e6b2"}]
  },
  {
    "featureType": "road.local",
    "elementType": "geometry.fill",
    "stylers": [{"color": "#ffffff"}]
  },
  {
    "featureType": "administrative.neighborhood",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#777777"}]
  }
]
''';