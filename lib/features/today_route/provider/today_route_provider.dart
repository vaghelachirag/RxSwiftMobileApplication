
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_result.dart';
import '../../../uttils/app_constants.dart';
import '../data/route_repository.dart';
import '../model/route_model.dart';

// ─────────────────────────────────────────────────────────────
//  State
// ─────────────────────────────────────────────────────────────

enum RouteLoadStatus { idle, loading, loaded, error }

enum RouteStartStatus { idle, starting, active, completed }

class TodayRouteState {
  const TodayRouteState({
    this.loadStatus = RouteLoadStatus.idle,
    this.startStatus = RouteStartStatus.idle,
    this.route,
    this.errorMessage,
    // ── pickup ──
    this.isPickupLoading = false,
    this.activePickupOrderId,
    this.pickupErrorMessage,
  });

  final RouteLoadStatus loadStatus;
  final RouteStartStatus startStatus;
  final TodayRoute? route;
  final String? errorMessage;

  /// True while a pickup API call is in flight.
  final bool isPickupLoading;

  /// The orderId currently being picked up. Lets the UI disable only the
  /// matching stop's button rather than every Pickup button.
  final String? activePickupOrderId;

  /// Last pickup error message, surfaced to the screen as a SnackBar.
  final String? pickupErrorMessage;

  bool get isLoading => loadStatus == RouteLoadStatus.loading;
  bool get isLoaded => loadStatus == RouteLoadStatus.loaded;
  bool get isError => loadStatus == RouteLoadStatus.error;
  bool get isRouteActive => startStatus == RouteStartStatus.active;
  bool get isRouteCompleted => startStatus == RouteStartStatus.completed;

  int get completedStops =>
      route?.stops.where((s) => s.status == StopStatus.completed).length ?? 0;

  TodayRouteState copyWith({
    RouteLoadStatus? loadStatus,
    RouteStartStatus? startStatus,
    TodayRoute? route,
    String? errorMessage,
    bool clearError = false,
    // pickup
    bool? isPickupLoading,
    String? activePickupOrderId,
    bool clearActivePickup = false,
    String? pickupErrorMessage,
    bool clearPickupError = false,
  }) {
    return TodayRouteState(
      loadStatus: loadStatus ?? this.loadStatus,
      startStatus: startStatus ?? this.startStatus,
      route: route ?? this.route,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isPickupLoading: isPickupLoading ?? this.isPickupLoading,
      activePickupOrderId: clearActivePickup
          ? null
          : (activePickupOrderId ?? this.activePickupOrderId),
      pickupErrorMessage: clearPickupError
          ? null
          : (pickupErrorMessage ?? this.pickupErrorMessage),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Notifier
// ─────────────────────────────────────────────────────────────

class TodayRouteNotifier extends StateNotifier<TodayRouteState> {
  TodayRouteNotifier(this._repository) : super(const TodayRouteState()) {
    loadRoute();
  }

  final RouteRepository _repository;

  Future<void> loadRoute() async {
    state = state.copyWith(
      loadStatus: RouteLoadStatus.loading,
      clearError: true,
    );

    final result = await _repository.getTodayRoute();

    switch (result) {
      case ApiSuccess(:final data):
        state = state.copyWith(
          loadStatus: RouteLoadStatus.loaded,
          route: data,
        );
      case ApiFailure(:final exception):
        state = state.copyWith(
          loadStatus: RouteLoadStatus.error,
          errorMessage: exception.message,
        );
    }
  }

  Future<void> startRoute() async {
    if (state.route == null || state.route!.stops.isEmpty) return;
    if (state.startStatus == RouteStartStatus.starting) return; // double-tap

    state = state.copyWith(
      startStatus: RouteStartStatus.starting,
      clearError: true,
    );

    final result = await _repository.updateDriverStatus(
      status: ApiConstants.driverOnRouteStatus,
    );

    switch (result) {
      case ApiSuccess():
        state = state.copyWith(startStatus: RouteStartStatus.active);
        // Mark the first stop in-progress.
        _setStopStatus(state.route!.stops.first.id, StopStatus.inProgress);
      case ApiFailure(:final exception):
      // Revert to idle so the driver can retry the Start button.
        state = state.copyWith(
          startStatus: RouteStartStatus.idle,
          errorMessage: exception.message,
        );
    }
  }


  Future<bool> pickupOrder(String orderId) async {
    // Validate input.
    if (orderId.isEmpty) {
      state = state.copyWith(
        pickupErrorMessage: 'Invalid order. Please refresh and try again.',
      );
      return false;
    }

    // Guard against duplicate taps on the same order.
    if (state.isPickupLoading && state.activePickupOrderId == orderId) {
      return false;
    }

    state = state.copyWith(
      isPickupLoading: true,
      activePickupOrderId: orderId,
      clearPickupError: true,
    );

    final result = await _repository.pickupOrder(orderId: orderId);

    switch (result) {
      case ApiSuccess(:final data):
        state = state.copyWith(
          isPickupLoading: false,
          clearActivePickup: true,
        );
        return data;
      case ApiFailure(:final exception):
        state = state.copyWith(
          isPickupLoading: false,
          clearActivePickup: true,
          pickupErrorMessage: exception.message,
        );
        return false;
    }
  }

  void markStopCompleted(String stopId) {
    _setStopStatus(stopId, StopStatus.completed);

    final stops = state.route?.stops ?? [];
    final hasPending = stops.any((s) => s.status == StopStatus.pending);
    if (hasPending) {
      final next = stops.firstWhere((s) => s.status == StopStatus.pending);
      _setStopStatus(next.id, StopStatus.inProgress);
    }

    final allDone =
    state.route!.stops.every((s) => s.status == StopStatus.completed);
    if (allDone) {
      state = state.copyWith(startStatus: RouteStartStatus.completed);
    }
  }

  void _setStopStatus(String stopId, StopStatus status) {
    if (state.route == null) return;
    final updated = state.route!.stops
        .map((s) => s.id == stopId ? s.copyWith(status: status) : s)
        .toList();
    state = state.copyWith(route: state.route!.copyWith(stops: updated));
  }

  /// Opens the stop in Google Maps. Uses coordinates when present, otherwise
  /// falls back to a text address search.
  Future<bool> openInGoogleMaps(RouteStop stop) async {
    final Uri uri;
    if (stop.hasCoordinates) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${stop.latitude},${stop.longitude}',
      );
    } else {
      final q = Uri.encodeComponent(stop.address);
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    }
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  void refresh() => loadRoute();
}

// ─────────────────────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────────────────────

final todayRouteProvider =
StateNotifierProvider<TodayRouteNotifier, TodayRouteState>(
      (ref) => TodayRouteNotifier(ref.watch(routeRepositoryProvider)),
);