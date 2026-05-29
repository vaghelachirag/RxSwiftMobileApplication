// ============================================================================
// lib/features/today_route/data/route_repository.dart
//
// Thin pass-through layer between the notifier and the datasource. Exists so
// the notifier never imports `dio`/`api_result` plumbing details directly and
// so swapping the datasource (e.g. for a fake in tests) is one provider
// override away.
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../model/route_model.dart';
import 'route_remote_datasource.dart';

class RouteRepository {
  RouteRepository(this._datasource);
  final RouteRemoteDatasource _datasource;

  Future<ApiResult<TodayRoute>> getTodayRoute() => _datasource.getTodayRoute();

  Future<ApiResult<bool>> updateDriverStatus({required String status}) =>
      _datasource.updateDriverStatus(status: status);

  Future<ApiResult<bool>> pickupOrder({required String orderId}) =>
      _datasource.pickupOrder(orderId: orderId);
}

final routeRepositoryProvider = Provider<RouteRepository>(
      (ref) => RouteRepository(ref.watch(routeRemoteDatasourceProvider)),
);