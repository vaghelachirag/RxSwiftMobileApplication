// ============================================================================
// data/repository/route_repository.dart  (+ impl)
// Thin repository over the datasource. Mirrors AuthRepository/Impl.
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../../../uttils/app_constants.dart';
import '../model/route_model.dart';
import 'route_remote_datasource.dart';

abstract class RouteRepository {
  Future<ApiResult<TodayRoute>> getTodayRoute();
  Future<ApiResult<bool>> updateDriverStatus({String status});
}

class RouteRepositoryImpl implements RouteRepository {
  const RouteRepositoryImpl({required RouteRemoteDatasource datasource})
      : _datasource = datasource;

  final RouteRemoteDatasource _datasource;

  @override
  Future<ApiResult<TodayRoute>> getTodayRoute() {
    return _datasource.getTodayRoute();
  }

  @override
  Future<ApiResult<bool>> updateDriverStatus({String status = ApiConstants.driverActiveStatus}) {
    return _datasource.updateDriverStatus(status: status);
  }
}

// ── Provider ──────────────────────────────────────────────────

final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return RouteRepositoryImpl(
    datasource: ref.watch(routeRemoteDatasourceProvider),
  );
});