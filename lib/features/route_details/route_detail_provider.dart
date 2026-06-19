import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../today_route/model/route_model.dart';

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
}

// ─────────────────────────────────────────────────────────────
//  Provider  (family keyed on orderId)
// ─────────────────────────────────────────────────────────────

final routeDetailProvider = StateNotifierProvider.family<
    RouteDetailNotifier, RouteDetailState, String>(
      (ref, orderId) => RouteDetailNotifier(),
);