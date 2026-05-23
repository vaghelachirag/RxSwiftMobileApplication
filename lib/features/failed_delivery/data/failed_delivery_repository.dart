// ============================================================================
// data/failed_delivery_repository.dart
// Camera capture (camera-only), multipart submit via Dio, connectivity
// checks, and local persistence of a pending report for offline retry.
// ============================================================================

import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/failed_delivery_state.dart';

class NoInternetException implements Exception {
  const NoInternetException();
}

class SubmitFailedException implements Exception {
  const SubmitFailedException(this.message);
  final String message;
}

/// Plain payload used both for live submit and offline persistence.
class FailedDeliveryReport {
  const FailedDeliveryReport({
    required this.orderId,
    required this.reasonCode,
    required this.notes,
    required this.photoPaths,
  });

  final String orderId;
  final String reasonCode;
  final String notes;
  final List<String> photoPaths;

  Map<String, dynamic> toJson() => {
        'order_id': orderId,
        'reason_code': reasonCode,
        'notes': notes,
        'photo_paths': photoPaths,
      };

  factory FailedDeliveryReport.fromJson(Map<String, dynamic> json) {
    return FailedDeliveryReport(
      orderId: json['order_id'] as String,
      reasonCode: json['reason_code'] as String,
      notes: json['notes'] as String? ?? '',
      photoPaths: (json['photo_paths'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
    );
  }
}

class FailedDeliveryRepository {
  FailedDeliveryRepository({
    Dio? dio,
    ImagePicker? picker,
    Connectivity? connectivity,
  })  : _dio = dio ?? Dio(),
        _picker = picker ?? ImagePicker(),
        _connectivity = connectivity ?? Connectivity();

  final Dio _dio;
  final ImagePicker _picker;
  final Connectivity _connectivity;

  static const String _submitUrl =
      'https://api.example.com/v1/deliveries/failed';

  static const String _pendingKey = 'pending_failed_delivery_report';

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
    return !result.contains(ConnectivityResult.none);
  }

  Stream<bool> get onConnectivityChanged => _connectivity.onConnectivityChanged
      .map((results) => !results.contains(ConnectivityResult.none));

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------
  Future<void> submitReport(
    FailedDeliveryReport report, {
    void Function(double progress)? onProgress,
  }) async {
    if (!await hasInternet()) {
      await savePending(report);
      throw const NoInternetException();
    }

    try {
      final formData = FormData.fromMap({
        'order_id': report.orderId,
        'reason_code': report.reasonCode,
        'notes': report.notes,
        if (report.photoPaths.isNotEmpty)
          'photos': [
            for (var i = 0; i < report.photoPaths.length; i++)
              await MultipartFile.fromFile(
                report.photoPaths[i],
                filename: 'failed_${report.orderId}_$i.jpg',
              ),
          ],
      });

      final response = await _dio.post(
        _submitUrl,
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) onProgress(sent / total);
        },
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw SubmitFailedException(
          'Server responded with ${response.statusCode}.',
        );
      }

      await clearPending();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        await savePending(report);
        throw const NoInternetException();
      }
      throw SubmitFailedException(e.message ?? 'Submit failed. Please retry.');
    }
  }

  // ---------------------------------------------------------------------------
  // Local persistence for offline retry
  // ---------------------------------------------------------------------------
  Future<void> savePending(FailedDeliveryReport report) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, jsonEncode(report.toJson()));
  }

  Future<FailedDeliveryReport?> getPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null) return null;
    return FailedDeliveryReport.fromJson(
        jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
  }
}
