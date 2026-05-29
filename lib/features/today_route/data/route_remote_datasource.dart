// ============================================================================
// lib/features/today_route/data/route_remote_datasource.dart
//
// Network layer for the driver-route feature.
//
// Uses the central DioClient — NOT a raw Dio instance — so every call gets:
//   • Bearer token via the auth interceptor
//   • Connectivity guard (NoInternetException on offline)
//   • Envelope unwrapping (response.data automatically becomes the `data:` field)
//   • DioException → NetworkException conversion via networkExceptionFromError
//
// Result: each datasource method is a one-liner around DioClient.get/patch<T>
// and returns ApiResult<T> directly.
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../uttils/RouteApiConstants.dart';
import '../model/route_model.dart';

class RouteRemoteDatasource {
  RouteRemoteDatasource(this._dioClient);
  final DioClient _dioClient;

  // ── Today's route ──────────────────────────────────────────
  // DioClient unwraps the {success, message, data} envelope, so `json` here
  // is already the inner `data` object.
  Future<ApiResult<TodayRoute>> getTodayRoute() {
    return _dioClient.get<TodayRoute>(
      RouteApiConstants.todayRoute,
      fromJson: (json) => TodayRoute.fromJson(json as Map<String, dynamic>),
    );
  }

  // ── Update driver status (e.g. "2" → on route) ─────────────
  // Response shape isn't important to the caller — collapse to `true`.
  Future<ApiResult<bool>> updateDriverStatus({required String status}) {
    return _dioClient.patch<bool>(
      RouteApiConstants.driverStatus,
      data: {'status': status},
      fromJson: (_) => true,
    );
  }

  // ── Pickup a specific order ────────────────────────────────
  // PATCH /driver/orders/{orderId}/pickup — no body required.
  // Response may be empty, a bool, or an envelope — _parsePickupResponse
  // handles every shape safely.
  Future<ApiResult<bool>> pickupOrder({required String orderId}) {
    return _dioClient.patch<bool>(
      RouteApiConstants.pickupOrder(orderId),
      fromJson: _parsePickupResponse,
    );
  }

  bool _parsePickupResponse(dynamic data) {
    if (data is bool) return data;
    if (data == null) return true; // 2xx with empty body → success
    if (data is Map<String, dynamic>) {
      return data['success'] == true ||
          data['status'] == true ||
          data['statusCode'] == 200 ||
          data['statusCode'] == 201 ||
          data['statusCode'] == 204;
    }
    return true; // any other 2xx body still counts as success
  }
}

// ─────────────────────────────────────────────────────────────
//  Provider
//
//  IMPORTANT: this passes the shared DioClient (with interceptors) — NOT a
//  bare `Dio()`. Bare Dio bypasses the auth + connectivity + envelope logic.
// ─────────────────────────────────────────────────────────────
final routeRemoteDatasourceProvider = Provider<RouteRemoteDatasource>(
      (ref) => RouteRemoteDatasource(ref.watch(dioClientProvider)),
);