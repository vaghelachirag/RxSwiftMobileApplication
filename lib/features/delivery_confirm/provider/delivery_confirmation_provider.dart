
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/delivery_state.dart';
import '../repository/delivery_repository.dart';



// -- Repository provider ------------------------------------------------------
final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) {
  final repo = DeliveryRepository();
  return repo;
});

// -- Order provider -----------------------------------------------------------
// In a real app this would be fed by the order you navigated in with.
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
  DeliveryController(this._repo, this._order)
      : super(const DeliveryState()) {
    _watchConnectivity();
  }

  final DeliveryRepository _repo;
  final DeliveryOrder _order;
  StreamSubscription<bool>? _connSub;

  /// Auto-retry a pending upload as soon as connectivity returns.
  void _watchConnectivity() {
    _connSub = _repo.onConnectivityChanged.listen((online) {
      if (online && state.status == DeliveryStatus.offlinePendingUpload) {
        retryPendingUpload();
      }
    });
  }

  // -- Open camera & capture -------------------------------------------------
  Future<void> openCamera() async {
    state = state.copyWith(
      status: DeliveryStatus.cameraOpening,
      clearError: true,
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
      state = state.copyWith(
        status: DeliveryStatus.photoCaptured,
        photoPath: path,
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

  /// Alias for clarity in the UI ("Retake Photo").
  Future<void> retakePhoto() => openCamera();

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

  /// Retry after a server-side failure.
  Future<void> retryUpload() => uploadAndComplete();

  /// Retry a photo that was cached while offline.
  Future<void> retryPendingUpload() async {
    final pending = await _repo.getPendingPhoto();
    if (pending == null) return;
    state = state.copyWith(
      status: DeliveryStatus.photoCaptured,
      photoPath: pending.photoPath,
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