// ============================================================================
// lib/features/notifications/data/fcm_token_remote_datasource.dart
//
// Network layer for registering the driver's FCM device token.
// Mirrors location_sync_remote_datasource.dart:
//   • Uses shared DioClient — Bearer token via auth interceptor, envelope
//     unwrapping, ApiResult<T> return type.
//
// Endpoint:
//   POST /api/driver/fcm-token
//   Content-Type: application/json
//   Body: { fcmToken }
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../uttils/RouteApiConstants.dart';

class FcmTokenRemoteDataSource {
  FcmTokenRemoteDataSource(this._dioClient);
  final DioClient _dioClient;

  Future<ApiResult<bool>> registerToken(String fcmToken) {
    return _dioClient.post<bool>(
      RouteApiConstants.fcmToken,
      data: {'fcmToken': fcmToken},
      fromJson: (_) => true,
    );
  }
}

final fcmTokenRemoteDataSourceProvider = Provider<FcmTokenRemoteDataSource>(
  (ref) => FcmTokenRemoteDataSource(ref.watch(dioClientProvider)),
);
