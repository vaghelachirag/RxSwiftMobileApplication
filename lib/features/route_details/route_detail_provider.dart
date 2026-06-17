import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────
//  State
// ─────────────────────────────────────────────────────────────

class RouteDetailState {
  const RouteDetailState({
    this.isNavigating = false,
    this.isArriving = false,
  });

  /// True while the "Navigate" action is being handled (optional loading guard).
  final bool isNavigating;

  /// True while the "Arrived" action is being handled.
  final bool isArriving;

   RouteDetailState copyWith({
    bool? isNavigating,
    bool? isArriving,
  }) {
    return RouteDetailState(
      isNavigating: isNavigating ?? this.isNavigating,
      isArriving: isArriving ?? this.isArriving,
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Notifier
// ─────────────────────────────────────────────────────────────

class RouteDetailNotifier extends StateNotifier<RouteDetailState> {
  RouteDetailNotifier() : super(const RouteDetailState());

  void setNavigating(bool value) =>
      state = state.copyWith(isNavigating: value);

  void setArriving(bool value) =>
      state = state.copyWith(isArriving: value);
}

// ─────────────────────────────────────────────────────────────
//  Provider  (family keyed on orderId)
// ─────────────────────────────────────────────────────────────

final routeDetailProvider = StateNotifierProvider.family<
    RouteDetailNotifier, RouteDetailState, String>(
      (ref, orderId) => RouteDetailNotifier(),
);