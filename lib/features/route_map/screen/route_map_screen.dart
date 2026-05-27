// ============================================================================
// features/today_route/route_map/screen/route_map_screen.dart
//
// Route Map Navigation Screen — now backed by the REAL Today's Route API.
//
// Data source : todayRouteProvider (loaded by TodayRouteScreen before this
//               screen is pushed). We read the live route + stops from it.
// UI state    : routeMapUiProvider (selected stop, sheet open/closed).
// Actions     : markStopCompleted / openInGoogleMaps on TodayRouteNotifier.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Real destination screens.
// NOTE: confirm these two package paths against your project. The delivery
// provider lives at `package:rxswift/features/delivery_confirm/provider/...`,
// so the screen is assumed to sit under that feature's presentation folder.
// If your paths differ, fix ONLY these two import lines.
// Old GPS navigation engine screen (unchanged). Confirm this path against your
// project — navigation_screen.dart imports
// `package:rxswift/features/navigation/provider/navigation_provider.dart`,
// so the screen sits under that feature.
import '../../delivery_confirm/delivery_confirm_screen.dart';
import '../../failed_delivery/presentation/screens/failed_delivery_screen.dart';
import '../../navigation/navigation_screen.dart';
import '../../today_route/model/route_model.dart';
import '../../today_route/provider/today_route_provider.dart';
import '../navigation_bridge/navigation_bridge.dart';
import '../provider/map_projection.dart';
import '../provider/route_map_provider.dart';
import '../theme/route_map_theme.dart';
import '../widgets/route_header.dart';
import '../widgets/route_map_view.dart';
import '../widgets/stop_bottom_sheet.dart';

class RouteMapScreen extends ConsumerWidget {
  const RouteMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeState = ref.watch(todayRouteProvider);

    return Scaffold(
      backgroundColor: RouteColors.tealDark,
      body: switch (routeState.loadStatus) {
        RouteLoadStatus.loading || RouteLoadStatus.idle =>
        const _CenteredOnTeal(child: CircularProgressIndicator(color: Colors.white)),
        RouteLoadStatus.error => _ErrorView(
          message: routeState.errorMessage ?? 'Could not load your route.',
          onRetry: () => ref.read(todayRouteProvider.notifier).refresh(),
          onBack: () => Navigator.of(context).maybePop(),
        ),
        RouteLoadStatus.loaded => routeState.route == null ||
            routeState.route!.stops.isEmpty
            ? _EmptyView(onBack: () => Navigator.of(context).maybePop())
            : _LoadedBody(routeState: routeState),
      },
    );
  }
}

class _LoadedBody extends ConsumerWidget {
  const _LoadedBody({required this.routeState});
  final TodayRouteState routeState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = routeState.route!;
    final ui = ref.watch(routeMapUiProvider);
    final uiNotifier = ref.read(routeMapUiProvider.notifier);
    final routeNotifier = ref.read(todayRouteProvider.notifier);

    // Keep selection in range if the stop list changes.
    final selectedIndex = ui.selectedIndex.clamp(0, route.stops.length - 1);
    final stop = route.stops[selectedIndex];

    final projection = MapProjection.fromRoute(route);

    Future<void> completeAndAdvance(RouteStop s) async {
      routeNotifier.markStopCompleted(s.id);
      // After the data updates, move selection to the new in-progress stop.
      uiNotifier.syncSelectionToProgress();
    }

    return Column(
      children: [
        RouteHeader(
          state: routeState,
          onBack: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: RouteMapView(
                  route: route,
                  selectedIndex: selectedIndex,
                  projection: projection,
                  onMarkerTap: uiNotifier.selectStop,
                  onRecenter: () =>
                      _toast(context, 'Centering on your location'),
                  onZoomIn: () => _toast(context, 'Zoom in'),
                  onZoomOut: () => _toast(context, 'Zoom out'),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: StopBottomSheet(
                  stop: stop,
                  indexLabel:
                  'Stop ${selectedIndex + 1} of ${route.stops.length}',
                  expanded: ui.sheetExpanded,
                  canGoPrev: selectedIndex > 0,
                  canGoNext: selectedIndex < route.stops.length - 1,
                  onToggle: uiNotifier.toggleSheet,
                  onPrev: uiNotifier.prevStop,
                  onNext: uiNotifier.nextStop,
                  onNavigate: () =>
                      _startTurnByTurnNavigation(context, route.stops),
                  onPickup: () async {
                    await _showPickupSuccess(context);
                    await completeAndAdvance(stop);
                  },
                  onDelivered: () => _openDeliveryConfirmation(
                    context,
                    stop,
                    onConfirmed: () => completeAndAdvance(stop),
                  ),
                  onFailed: () => _openFailedDelivery(context, stop),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: RouteColors.tealDark,
          duration: const Duration(milliseconds: 1400),
        ),
      );
  }

  Future<void> _showPickupSuccess(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: RouteColors.teal.withOpacity(0.96),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => const _PickupSuccessContent(),
    );
  }

  // ── Navigate → real GPS turn-by-turn engine, one stop at a time ──
  //
  // Pushes the existing NavigationMapScreen (live GPS + Google Directions,
  // navigates to the current stop and auto-advances on arrival) but wraps it
  // in a ProviderScope that overrides the engine's `navigationProvider` so it
  // runs against the REAL route stops instead of the engine's demo data.
  //
  // The old screen and old provider are untouched; the override does the
  // seeding via navigation_bridge.dart.
  void _startTurnByTurnNavigation(
      BuildContext context, List<RouteStop> stops) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderScope(
          overrides: [buildNavigationOverride(stops)],
          child: const NavigationMapScreen(),
        ),
      ),
    );
  }

  // ── Delivered → real DeliveryConfirmationScreen ───────────────
  //
  // Both destination screens read their own order from their own providers
  // (deliveryOrderProvider / failedDeliveryOrderProvider) and take no
  // constructor args, so we just push them.
  //
  // 👉 INJECT THE SELECTED STOP HERE if your order providers need to be told
  //    which stop is active. For example, if you expose a setter:
  //
  //      ref.read(deliveryOrderProvider.notifier).setFromStop(stop);
  //
  //    add that call right before the push (uncomment + adapt to your API).
  Future<void> _openDeliveryConfirmation(
      BuildContext context,
      RouteStop stop, {
        required VoidCallback onConfirmed,
      }) async {
    // ref.read(deliveryOrderProvider.notifier).setFromStop(stop); // ← your hook

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const DeliveryConfirmationScreen()),
    );

    // Advance the route only when the delivery was actually completed.
    //
    // For this to fire, the confirmation screen must return `true` when done.
    // In your delivery_confirmation_screen.dart, change the success "Done"
    // button from:
    //     onDone: () => Navigator.of(context).maybePop(),
    // to:
    //     onDone: () => Navigator.of(context).maybePop(true),
    //
    // If the driver just backs out, it returns null and the stop is untouched.
    if (result == true) onConfirmed();
  }

  // ── Failed → real FailedDeliveryScreen ────────────────────────
  Future<void> _openFailedDelivery(BuildContext context, RouteStop stop) async {
    // ref.read(failedDeliveryOrderProvider.notifier).setFromStop(stop); // ← your hook

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FailedDeliveryScreen()),
    );
    // Optionally mark the stop as skipped/failed here based on the result.
  }
}

// ── Loading / error / empty scaffolds ───────────────────────

class _CenteredOnTeal extends StatelessWidget {
  const _CenteredOnTeal({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Container(color: RouteColors.tealDark, child: Center(child: child));
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: RouteColors.tealDark,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                ),
              ),
              const Spacer(),
              const Icon(Icons.cloud_off_rounded,
                  size: 56, color: Colors.white70),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: RouteColors.tealDark,
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: RouteColors.tealDark,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                ),
              ),
              const Spacer(),
              const Icon(Icons.inbox_rounded, size: 56, color: Colors.white70),
              const SizedBox(height: 14),
              const Text(
                'No stops on your route yet.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickupSuccessContent extends StatefulWidget {
  const _PickupSuccessContent();
  @override
  State<_PickupSuccessContent> createState() => _PickupSuccessContentState();
}

class _PickupSuccessContentState extends State<_PickupSuccessContent> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child:
            const Icon(Icons.check_rounded, size: 38, color: Colors.white),
          ),
          const SizedBox(height: 14),
          const Text(
            'Picked Up!',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Moving to next stop…',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}