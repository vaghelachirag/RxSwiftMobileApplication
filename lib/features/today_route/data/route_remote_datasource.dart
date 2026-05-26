// ============================================================================
// data/route_remote_datasource.dart
// HTTP-only layer for the today-route endpoint. Mirrors AuthRemoteDatasource.
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../model/route_model.dart';

/// Endpoint constants. Move into your shared ApiConstants if you prefer.
///
/// NOTE: This path is appended to ApiConstants.baseUrl. The full URL must be
/// http://103.235.105.96:8086/api/driver/today-route (per Swagger/curl), so:
///   - if baseUrl = 'http://103.235.105.96:8086'      -> use '/api/driver/today-route'
///   - if baseUrl = 'http://103.235.105.96:8086/api'  -> use '/driver/today-route'
/// Pick the one matching your ApiConstants.baseUrl.
class RouteApiConstants {
  RouteApiConstants._();
  static const String todayRoute = '/driver/today-route';
  static const String driverStatus = '/driver/status';
}

class RouteRemoteDatasource {
  const RouteRemoteDatasource(this._dioClient);
  final DioClient _dioClient;

  Future<ApiResult<TodayRoute>> getTodayRoute() {
    return _dioClient.get<TodayRoute>(
      RouteApiConstants.todayRoute,
      fromJson: (json) => TodayRoute.fromJson(json as Map<String, dynamic>),
    );
  }

  /// Marks the driver active. Called when the route screen opens.
  ///
  /// PATCH /api/driver/status  body: {"status": "<code>"}
  /// The API expects a string status code (e.g. "2"). The response `data` is
  /// a bool. Default "2" matches the documented "active/online" value — change
  /// if your status enum differs.
  Future<ApiResult<bool>> updateDriverStatus({
    String status = '2',
  }) {
    return _dioClient.patch<bool>(
      RouteApiConstants.driverStatus,
      data: {'status': status},
      fromJson: (json) => json as bool,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────

final routeRemoteDatasourceProvider = Provider<RouteRemoteDatasource>((ref) {
  return RouteRemoteDatasource(ref.watch(dioClientProvider));
});