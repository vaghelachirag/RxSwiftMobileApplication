import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/route_model.dart';

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
  });

  final RouteLoadStatus loadStatus;
  final RouteStartStatus startStatus;
  final TodayRoute? route;
  final String? errorMessage;

  bool get isLoading => loadStatus == RouteLoadStatus.loading;
  bool get isLoaded => loadStatus == RouteLoadStatus.loaded;
  bool get isRouteActive => startStatus == RouteStartStatus.active;
  bool get isRouteCompleted => startStatus == RouteStartStatus.completed;

  int get completedStops =>
      route?.stops.where((s) => s.status == StopStatus.completed).length ?? 0;

  TodayRouteState copyWith({
    RouteLoadStatus? loadStatus,
    RouteStartStatus? startStatus,
    TodayRoute? route,
    String? errorMessage,
  }) {
    return TodayRouteState(
      loadStatus: loadStatus ?? this.loadStatus,
      startStatus: startStatus ?? this.startStatus,
      route: route ?? this.route,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Notifier
// ─────────────────────────────────────────────────────────────

class TodayRouteNotifier extends StateNotifier<TodayRouteState> {
  TodayRouteNotifier() : super(const TodayRouteState()) {
    loadRoute();
  }

  Future<void> loadRoute() async {
    state = state.copyWith(loadStatus: RouteLoadStatus.loading);

    // Simulate API fetch
    await Future.delayed(const Duration(milliseconds: 900));

    // Mock data matching the screenshot
    const mockRoute = TodayRoute(
      totalStops: 4,
      pickupTime: '10:00 PM',
      stops: [
        RouteStop(
          id: '1',
          stopNumber: 1,
          patientName: 'John Smith',
          address: '456 Tuscany Dr NW',
          scheduledTime: '12:30 PM',
        ),
        RouteStop(
          id: '2',
          stopNumber: 2,
          patientName: 'Sarah Johnson',
          address: '789 Aspen Dr SW',
          scheduledTime: '01:15 PM',
        ),
        RouteStop(
          id: '3',
          stopNumber: 3,
          patientName: 'Robert Brown',
          address: '123 Rocky Ridge Rd NW',
          scheduledTime: '02:00 PM',
        ),
        RouteStop(
          id: '4',
          stopNumber: 4,
          patientName: 'Linda Wilson',
          address: '321 Crowfoot Cir NW',
          scheduledTime: '02:45 PM',
        ),
      ],
    );

    state = state.copyWith(
      loadStatus: RouteLoadStatus.loaded,
      route: mockRoute,
    );
  }

  Future<void> startRoute() async {
    state = state.copyWith(startStatus: RouteStartStatus.starting);
    await Future.delayed(const Duration(milliseconds: 600));
    state = state.copyWith(startStatus: RouteStartStatus.active);

    // Mark first stop as in-progress
    _setStopStatus('1', StopStatus.inProgress);
  }

  void markStopCompleted(String stopId) {
    _setStopStatus(stopId, StopStatus.completed);

    // Auto-progress: set next pending stop to inProgress
    final stops = state.route?.stops ?? [];
    final nextStop = stops.firstWhere(
          (s) => s.status == StopStatus.pending,
      orElse: () => stops.last,
    );
    if (nextStop.status == StopStatus.pending) {
      _setStopStatus(nextStop.id, StopStatus.inProgress);
    }

    // Check if all completed
    final updated = state.route!.stops
        .where((s) => s.status == StopStatus.completed || s.id == stopId)
        .length;
    if (updated == stops.length) {
      state = state.copyWith(startStatus: RouteStartStatus.completed);
    }
  }

  void _setStopStatus(String stopId, StopStatus status) {
    if (state.route == null) return;
    final updatedStops = state.route!.stops
        .map((s) => s.id == stopId ? s.copyWith(status: status) : s)
        .toList();
    state = state.copyWith(
      route: state.route!.copyWith(stops: updatedStops),
    );
  }

  void refresh() => loadRoute();
}

// ─────────────────────────────────────────────────────────────
//  Provider
// ─────────────────────────────────────────────────────────────

final todayRouteProvider =
StateNotifierProvider<TodayRouteNotifier, TodayRouteState>(
      (ref) => TodayRouteNotifier(),
);