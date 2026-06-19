import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_result.dart';
import '../today_route/model/route_model.dart';
import 'data/route_detail_repository.dart';
import 'model/order_detail_model.dart';

// ─────────────────────────────────────────────────────────────
//  State
// ─────────────────────────────────────────────────────────────

enum OrderDetailLoadStatus { idle, loading, loaded, error }

class RouteDetailState {
  const RouteDetailState({
    this.isNavigating = false,
    this.isArriving = false,
    this.loadStatus = OrderDetailLoadStatus.idle,
    this.orderDetail,
    this.errorMessage,
  });

  /// True while the "Navigate" action is being handled (optional loading guard).
  final bool isNavigating;

  /// True while the "Arrived" action is being handled.
  final bool isArriving;

  /// Status of the GET /driver/orders/{orderId} call.
  final OrderDetailLoadStatus loadStatus;

  /// Full order detail fetched from the API.
  final OrderDetail? orderDetail;

  /// Last order-detail load error message, if any.
  final String? errorMessage;

  bool get isLoading => loadStatus == OrderDetailLoadStatus.loading;
  bool get isError => loadStatus == OrderDetailLoadStatus.error;

  RouteDetailState copyWith({
    bool? isNavigating,
    bool? isArriving,
    OrderDetailLoadStatus? loadStatus,
    OrderDetail? orderDetail,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RouteDetailState(
      isNavigating: isNavigating ?? this.isNavigating,
      isArriving: isArriving ?? this.isArriving,
      loadStatus: loadStatus ?? this.loadStatus,
      orderDetail: orderDetail ?? this.orderDetail,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Notifier
// ─────────────────────────────────────────────────────────────

class RouteDetailNotifier extends StateNotifier<RouteDetailState> {
  RouteDetailNotifier(this._repository, this._orderId)
      : super(const RouteDetailState());

  final RouteDetailRepository _repository;
  final String _orderId;

  void setNavigating(bool value) =>
      state = state.copyWith(isNavigating: value);

  void setArriving(bool value) =>
      state = state.copyWith(isArriving: value);

  // ── Order detail ────────────────────────────────────────────────────

  Future<void> fetchOrderDetail() async {
    if (_orderId.isEmpty) return;

    state = state.copyWith(
      loadStatus: OrderDetailLoadStatus.loading,
      clearError: true,
    );

    final result = await _repository.getOrderDetail(_orderId);

    switch (result) {
      case ApiSuccess(:final data):
        state = state.copyWith(
          loadStatus: OrderDetailLoadStatus.loaded,
          orderDetail: data,
        );
      case ApiFailure(:final exception):
        state = state.copyWith(
          loadStatus: OrderDetailLoadStatus.error,
          errorMessage: exception.message,
        );
    }
  }

  // ── Maps ─────────────────────────────────────────────────────────────

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
  (ref, orderId) => RouteDetailNotifier(
    ref.watch(routeDetailRepositoryProvider),
    orderId,
  )..fetchOrderDetail(),
);
