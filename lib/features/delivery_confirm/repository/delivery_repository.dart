// ============================================================================
// data/delivery_repository.dart
// Handles camera capture, geolocation, network upload (Dio), connectivity
// checks, and local persistence of a pending photo + location for offline
// retry.
// ============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/delivery_state.dart';

/// Thrown when there is no internet connection during an upload attempt.
class NoInternetException implements Exception {
  const NoInternetException();
}

/// Thrown when the server rejects the upload or any non-network error occurs.
class UploadFailedException implements Exception {
  const UploadFailedException(this.message);
  final String message;
}

/// Thrown when the device location cannot be obtained.
class LocationException implements Exception {
  const LocationException(this.message);
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

  static const String _pendingKey = 'pending_delivery_payload';

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
  // Location
  // ---------------------------------------------------------------------------
  Future<CaptureLocation> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('Location services are turned off.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        'Location permission is permanently denied. Enable it in Settings.',
      );
    }

    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
    } catch (_) {
      // Fall back to last known fix if a fresh one times out.
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) {
        throw const LocationException('Could not determine your location.');
      }
      pos = last;
    }

    String? address;
    try {
      final placemarks =
      await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        address = [p.street, p.subLocality, p.locality, p.postalCode]
            .where((e) => e != null && e.isNotEmpty)
            .join(', ');
      }
    } catch (_) {
      // Reverse geocoding is best-effort; ignore failures.
    }

    return CaptureLocation(
      latitude: pos.latitude,
      longitude: pos.longitude,
      address: (address != null && address.isEmpty) ? null : address,
    );
  }

  Future<String> stampLocationOnImage({required String photoPath, required CaptureLocation location,}) async {
    final bytes = await File(photoPath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return photoPath; // fall back to original

    var image = img.bakeOrientation(decoded);
    const targetWidth = 1080;
    if (image.width > targetWidth) {
      image = img.copyResize(image, width: targetWidth);
    }

    final lines = <String>[
      'Lat: ${location.latitude.toStringAsFixed(6)}   '
          'Lng: ${location.longitude.toStringAsFixed(6)}',
      if (location.address != null && location.address!.isNotEmpty)
        location.address!,
    ];

    final font = img.arial24;
    final lineHeight = font.lineHeight + 6;
    const marginX = 20;
    const marginBottom = 16;

    // Draw bottom-up so the last line sits at the very bottom.
    var y = image.height - marginBottom - lineHeight * lines.length;
    final white = img.ColorRgb8(255, 255, 255);
    final shadow = img.ColorRgba8(0, 0, 0, 200);

    for (final line in lines) {
      // Shadow: draw the text offset in 4 directions for a readable outline.
      for (final off in const [
        [1, 1],
        [-1, 1],
        [1, -1],
        [-1, -1],
        [2, 2],
      ]) {
        img.drawString(
          image,
          line,
          font: font,
          x: marginX + off[0],
          y: y + off[1],
          color: shadow,
        );
      }
      // Foreground text.
      img.drawString(
        image,
        line,
        font: font,
        x: marginX,
        y: y,
        color: white,
      );
      y += lineHeight;
    }

    final dir = await getTemporaryDirectory();
    final out =
        '${dir.path}/stamped_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(out).writeAsBytes(img.encodeJpg(image, quality: 88));
    return out;
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
  // Upload
  // ---------------------------------------------------------------------------
  Future<void> uploadDeliveryPhoto({
    required String orderId,
    required String photoPath,
    CaptureLocation? location,
    void Function(double progress)? onProgress,
  }) async {
    if (!await hasInternet()) {
      await savePending(
        orderId: orderId,
        photoPath: photoPath,
        location: location,
      );
      throw const NoInternetException();
    }

    try {
      // Location is burned into the image pixels, so we only send the photo.
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

      await clearPending();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        await savePending(
          orderId: orderId,
          photoPath: photoPath,
          location: location,
        );
        throw const NoInternetException();
      }
      throw UploadFailedException(e.message ?? 'Upload failed. Please retry.');
    }
  }

  // ---------------------------------------------------------------------------
  // Local persistence for offline retry (photo + location together)
  // ---------------------------------------------------------------------------
  Future<void> savePending({
    required String orderId,
    required String photoPath,
    CaptureLocation? location,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'order_id': orderId,
      'photo_path': photoPath,
      'location': location?.toJson(),
    });
    await prefs.setString(_pendingKey, payload);
  }

  Future<({String orderId, String photoPath, CaptureLocation? location})?>
  getPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingKey);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final locJson = map['location'] as Map<String, dynamic>?;
    return (
    orderId: map['order_id'] as String,
    photoPath: map['photo_path'] as String,
    location: locJson == null ? null : CaptureLocation.fromJson(locJson),
    );
  }

  Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
  }
}
