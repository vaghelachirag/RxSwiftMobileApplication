// ============================================================================
// data/delivery_repository.dart
// Handles camera capture, network upload (Dio), connectivity checks, and
// local persistence of a pending photo path for offline retry.
// ============================================================================

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown when there is no internet connection during an upload attempt.
class NoInternetException implements Exception {
  const NoInternetException();
}

/// Thrown when the server rejects the upload or any non-network error occurs.
class UploadFailedException implements Exception {
  const UploadFailedException(this.message);
  final String message;
}

class DeliveryRepository {
  DeliveryRepository({
    Dio? dio,
    ImagePicker? picker,
    Connectivity? connectivity,
  })  : _dio = dio ?? Dio(),
        _picker = picker ?? ImagePicker(),
        _connectivity = connectivity ?? Connectivity();

  final Dio _dio;
  final ImagePicker _picker;
  final Connectivity _connectivity;

  // Replace with your real endpoint.
  static const String _uploadUrl =
      'https://api.example.com/v1/deliveries/confirm';

  static const String _pendingPhotoKey = 'pending_delivery_photo_path';
  static const String _pendingOrderKey = 'pending_delivery_order_id';

  // ---------------------------------------------------------------------------
  // Camera — CAMERA SOURCE ONLY. No gallery option is ever exposed.
  // ---------------------------------------------------------------------------
  Future<String?> captureFromCamera() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.camera, // <-- gallery is intentionally never used
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85,
      maxWidth: 1920,
    );
    return file?.path;
  }

  // ---------------------------------------------------------------------------
  // Connectivity
  // ---------------------------------------------------------------------------
  Future<bool> hasInternet() async {
    final result = await _connectivity.checkConnectivity();
    // connectivity_plus >=6 returns List<ConnectivityResult>.
    return !result.contains(ConnectivityResult.none);
  }

  // ---------------------------------------------------------------------------
  // Upload
  // ---------------------------------------------------------------------------
  /// Uploads [photoPath] for [orderId]. Reports progress through [onProgress].
  ///
  /// Throws [NoInternetException] if offline, or [UploadFailedException] on a
  /// server / unexpected error.
  Future<void> uploadDeliveryPhoto({
    required String orderId,
    required String photoPath,
    void Function(double progress)? onProgress,
  }) async {
    if (!await hasInternet()) {
      // Persist for later retry, then signal offline to the caller.
      await savePendingPhoto(orderId: orderId, photoPath: photoPath);
      throw const NoInternetException();
    }

    try {
      final formData = FormData.fromMap({
        'order_id': orderId,
        'proof': await MultipartFile.fromFile(
          photoPath,
          filename: 'delivery_$orderId.jpg',
        ),
      });

      final response = await _dio.post(
        _uploadUrl,
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            onProgress(sent / total);
          }
        },
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw UploadFailedException(
          'Server responded with ${response.statusCode}.',
        );
      }

      // Success — clear any locally cached pending photo.
      await clearPendingPhoto();
    } on DioException catch (e) {
      // Network-layer failures map to a retryable "offline" outcome.
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        await savePendingPhoto(orderId: orderId, photoPath: photoPath);
        throw const NoInternetException();
      }
      throw UploadFailedException(e.message ?? 'Upload failed. Please retry.');
    }
  }

  // ---------------------------------------------------------------------------
  // Local persistence for offline retry
  // ---------------------------------------------------------------------------
  Future<void> savePendingPhoto({
    required String orderId,
    required String photoPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingPhotoKey, photoPath);
    await prefs.setString(_pendingOrderKey, orderId);
  }

  Future<({String orderId, String photoPath})?> getPendingPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_pendingPhotoKey);
    final order = prefs.getString(_pendingOrderKey);
    if (path == null || order == null) return null;
    return (orderId: order, photoPath: path);
  }

  Future<void> clearPendingPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingPhotoKey);
    await prefs.remove(_pendingOrderKey);
  }

  /// Emits connectivity changes so the app can auto-retry pending uploads.
  Stream<bool> get onConnectivityChanged => _connectivity.onConnectivityChanged
      .map((results) => !results.contains(ConnectivityResult.none));
}