// ============================================================================
// presentation/providers/delivery_providers.dart
// Riverpod providers + StateNotifier controlling the delivery flow.
// ============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/delivery_state.dart';
import '../repository/delivery_repository.dart';

// -- Repository provider ------------------------------------------------------
final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) {
  return DeliveryRepository();
});

// -- Order provider -----------------------------------------------------------
final deliveryOrderProvider = Provider<DeliveryOrder>((ref) {
  return const DeliveryOrder(
    orderId: 'RX-48291',
    customerName: 'John Smith',
    address: '1400-048-665, 24 Maple Street, Apt 5B',
    pharmacyName: 'WellCare Pharmacy',
    statusLabel: 'Arrived at destination',
  );
});

// -- StateNotifier ------------------------------------------------------------
class DeliveryController extends StateNotifier<DeliveryState> {
  DeliveryController(this._repo, this._order) : super(const DeliveryState()) {
    _watchConnectivity();
  }

  final DeliveryRepository _repo;
  final DeliveryOrder _order;
  StreamSubscription<bool>? _connSub;

  /// The raw, unstamped photo path from the camera. Kept so that retrying
  /// location re-stamps the original rather than stacking stamps.
  String? _rawPhotoPath;

  void _watchConnectivity() {
    _connSub = _repo.onConnectivityChanged.listen((online) {
      if (online && state.status == DeliveryStatus.offlinePendingUpload) {
        retryPendingUpload();
      }
    });
  }

  // -- Open camera & capture (+ location) ------------------------------------
  Future<void> openCamera() async {
    state = state.copyWith(
      status: DeliveryStatus.cameraOpening,
      clearError: true,
      clearLocationWarning: true,
    );
    try {
      final path = await _repo.captureFromCamera();
      if (path == null) {
        // User cancelled — go back to whatever made sense before.
        state = state.copyWith(
          status: state.hasPhoto
              ? DeliveryStatus.photoCaptured
              : DeliveryStatus.initial,
        );
        return;
      }

      // Capture location at the moment of the photo. Best-effort: if it fails,
      // we WARN but still let the driver proceed.
      CaptureLocation? loc;
      String? warning;
      try {
        loc = await _repo.getCurrentLocation();
      } on LocationException catch (e) {
        warning = e.message;
      } catch (_) {
        warning = 'Could not capture location. You can retry or proceed.';
      }

      // Burn the location text onto the image when we have a fix. The stamped
      // file becomes the photo we preview, upload, and persist.
      _rawPhotoPath = path;
      String finalPath = path;
      if (loc != null) {
        state = state.copyWith(status: DeliveryStatus.cameraOpening);
        try {
          finalPath = await _repo.stampLocationOnImage(
            photoPath: path,
            location: loc,
          );
        } catch (_) {
          finalPath = path; // if stamping fails, keep the raw photo
        }
      }

      state = state.copyWith(
        status: DeliveryStatus.photoCaptured,
        photoPath: finalPath,
        location: loc,
        locationWarning: warning,
        clearLocation: loc == null,
        clearLocationWarning: warning == null,
        uploadProgress: 0.0,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: DeliveryStatus.initial,
        errorMessage: 'Could not open the camera. Please try again.',
      );
    }
  }

  Future<void> retakePhoto() => openCamera();

  /// Retry just the location capture without retaking the photo. Re-stamps
  /// the original (unstamped) image with the new fix.
  Future<void> retryLocation() async {
    if (!state.hasPhoto) return;
    try {
      final loc = await _repo.getCurrentLocation();
      var path = state.photoPath!;
      final raw = _rawPhotoPath ?? path;
      try {
        path = await _repo.stampLocationOnImage(
          photoPath: raw,
          location: loc,
        );
      } catch (_) {
        path = raw; // keep raw if stamping fails
      }
      state = state.copyWith(
        photoPath: path,
        location: loc,
        clearLocationWarning: true,
      );
    } on LocationException catch (e) {
      state = state.copyWith(locationWarning: e.message);
    } catch (_) {
      state = state.copyWith(
        locationWarning: 'Could not capture location. You can retry or proceed.',
      );
    }
  }

  // -- Upload ----------------------------------------------------------------
  Future<void> uploadAndComplete() async {
    if (!state.hasPhoto) return;

    state = state.copyWith(
      status: DeliveryStatus.uploading,
      uploadProgress: 0.0,
      clearError: true,
    );

    try {
      await _repo.uploadDeliveryPhoto(
        orderId: _order.orderId,
        photoPath: state.photoPath!,
        location: state.location,
        onProgress: (p) {
          state = state.copyWith(uploadProgress: p);
        },
      );
      state = state.copyWith(
        status: DeliveryStatus.uploadSuccess,
        uploadProgress: 1.0,
      );
    } on NoInternetException {
      state = state.copyWith(
        status: DeliveryStatus.offlinePendingUpload,
        errorMessage:
        'Photo saved locally. It will upload when internet is restored.',
      );
    } on UploadFailedException catch (e) {
      state = state.copyWith(
        status: DeliveryStatus.uploadFailed,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: DeliveryStatus.uploadFailed,
        errorMessage: 'Something went wrong. Please retry.',
      );
    }
  }

  Future<void> retryUpload() => uploadAndComplete();

  /// Retry a photo (+ its location) that was cached while offline.
  Future<void> retryPendingUpload() async {
    final pending = await _repo.getPending();
    if (pending == null) return;
    state = state.copyWith(
      status: DeliveryStatus.photoCaptured,
      photoPath: pending.photoPath,
      location: pending.location,
      clearLocation: pending.location == null,
    );
    await uploadAndComplete();
  }

  void reset() {
    state = const DeliveryState();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }
}

final deliveryControllerProvider =
StateNotifierProvider<DeliveryController, DeliveryState>((ref) {
  final repo = ref.watch(deliveryRepositoryProvider);
  final order = ref.watch(deliveryOrderProvider);
  return DeliveryController(repo, order);
});
