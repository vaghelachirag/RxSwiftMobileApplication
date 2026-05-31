// ============================================================================
// lib/features/delivery_confirm/data/delivery_remote_datasource.dart
//
// Mirrors route_remote_datasource.dart exactly — uses _dioClient.post<T>()
// with fromJson. onSendProgress removed: DioClient.post() does not expose it.
// ============================================================================

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_result.dart';
import '../../../core/network/dio_client.dart';
import '../../../uttils/RouteApiConstants.dart';

// ── Response model ─────────────────────────────────────────────────────────

class DeliveryPhotoResponse {
  const DeliveryPhotoResponse({
    required this.orderId,
    required this.orderNumber,
    required this.photoUrl,
  });

  final String orderId;
  final String orderNumber;
  final String photoUrl;

  /// DioClient already unwrapped the outer envelope, so [json] is the inner
  /// `data` object: { "orderId": "…", "orderNumber": "…", "photoUrl": "…" }
  factory DeliveryPhotoResponse.fromJson(Map<String, dynamic> json) {
    return DeliveryPhotoResponse(
      orderId:     json['orderId']     as String? ?? '',
      orderNumber: json['orderNumber'] as String? ?? '',
      photoUrl:    json['photoUrl']    as String? ?? '',
    );
  }
}

// ── Data source ────────────────────────────────────────────────────────────

class DeliveryRemoteDataSource {
  DeliveryRemoteDataSource(this._dioClient);
  final DioClient _dioClient;

  /// Upload delivery proof photo for [orderId].
  /// Field name is case-sensitive: must be exactly "Photo".
  Future<ApiResult<DeliveryPhotoResponse>> uploadDeliveryPhoto({
    required String orderId,
    required String photoPath,
  }) async {
    final file     = File(photoPath);
    final fileName = file.uri.pathSegments.last;
    final ext      = fileName.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

    final formData = FormData.fromMap({
      'Photo': await MultipartFile.fromFile(
        photoPath,
        filename: fileName,
        contentType: DioMediaType.parse(mimeType),
      ),
    });

    return _dioClient.post<DeliveryPhotoResponse>(
      RouteApiConstants.deliveryPhoto(orderId),
      data: formData,
      fromJson: (json) =>
          DeliveryPhotoResponse.fromJson(json as Map<String, dynamic>),
    );
  }
}

// ── Provider ───────────────────────────────────────────────────────────────

final deliveryRemoteDataSourceProvider = Provider<DeliveryRemoteDataSource>(
      (ref) => DeliveryRemoteDataSource(ref.watch(dioClientProvider)),
);