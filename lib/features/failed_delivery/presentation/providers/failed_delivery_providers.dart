// ============================================================================
// lib/features/failed_delivery/presentation/providers/failed_delivery_providers.dart
//
// Riverpod providers + StateNotifier controlling the failed-delivery report.
//
// KEY CHANGES vs original:
//   • Repository now receives FailedDeliveryRemoteDataSource (DioClient-based)
//   • failedDeliveryOrderProvider is a .family keyed on orderId so the real
//     RouteStop UUID is forwarded to the API — nothing hardcoded
//   • Controller.submit() builds FailedDeliveryReport with a single photoPath
//     (API accepts one Photo field); first photo in the list is used
//   • onProgress removed — DioClient.post() does not expose onSendProgress
// ============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/failed_delivery_remote_datasource.dart';
import '../../data/failed_delivery_repository.dart';
import '../../domain/failed_delivery_state.dart';

// ── Infrastructure providers ──────────────────────────────────────────────

final failedDeliveryRepositoryProvider =
Provider<FailedDeliveryRepository>((ref) {
  return FailedDeliveryRepository(
    remoteDataSource: ref.watch(failedDeliveryRemoteDataSourceProvider),
  );
});

// ── Order provider (family keyed on orderId) ──────────────────────────────
// Accepts the real RouteStop UUID from the navigation args so every API
// call uses the correct path parameter.

final failedDeliveryOrderProvider =
Provider.family<DeliveryOrder, String>((ref, orderId) {
  // Customer details are passed via the navigation args in the screen;
  // orderId is the only field strictly required for the API call.
  return DeliveryOrder(
    orderId:      orderId,
    customerName: '',
    address:      '',
    pharmacyName: '',
    statusLabel:  'Attempt failed',
  );
});

// ── StateNotifier ─────────────────────────────────────────────────────────

class FailedDeliveryController extends StateNotifier<FailedDeliveryState> {
  FailedDeliveryController(this._repo, this._order)
      : super(const FailedDeliveryState()) {
    _watchConnectivity();
  }

  final FailedDeliveryRepository _repo;
  final DeliveryOrder             _order;
  StreamSubscription<bool>?       _connSub;

  void _watchConnectivity() {
    _connSub = _repo.onConnectivityChanged.listen((online) {
      if (online && state.status == SubmitStatus.offlinePending) {
        retryPendingSubmit();
      }
    });
  }

  // ── Form edits ────────────────────────────────────────────────────────

  void selectReason(FailureReason reason) {
    state = state.copyWith(reason: reason, clearError: true);
  }

  void updateNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  // ── Photos (camera only) ──────────────────────────────────────────────

  Future<void> addPhoto() async {
    final prevStatus = state.status;
    state = state.copyWith(status: SubmitStatus.capturingPhoto);
    try {
      final path = await _repo.captureFromCamera();
      if (path == null) {
        state = state.copyWith(status: prevStatus);
        return;
      }
      state = state.copyWith(
        status:     SubmitStatus.initial,
        photoPaths: [...state.photoPaths, path],
      );
    } catch (_) {
      state = state.copyWith(
        status:       prevStatus,
        errorMessage: 'Could not open the camera. Please try again.',
      );
    }
  }

  void removePhoto(int index) {
    if (index < 0 || index >= state.photoPaths.length) return;
    final updated = [...state.photoPaths]..removeAt(index);
    state = state.copyWith(photoPaths: updated);
  }

  // ── Submit ────────────────────────────────────────────────────────────

  Future<void> submit() async {
    if (!state.canSubmit) return;

    state = state.copyWith(
      status:         SubmitStatus.submitting,
      uploadProgress: 0.0,
      clearError:     true,
    );

    // API accepts a single Photo field — use the first captured photo.
    final report = FailedDeliveryReport(
      orderId:    _order.orderId,
      reasonCode: state.reason!.label,   // server expects human-readable label
      notes:      state.notes,
      photoPath:  state.photoPaths.isNotEmpty ? state.photoPaths.first : null,
    );

    try {
      await _repo.submitReport(report);
      state = state.copyWith(
        status:         SubmitStatus.submitSuccess,
        uploadProgress: 1.0,
      );
    } on NoInternetException {
      state = state.copyWith(
        status:       SubmitStatus.offlinePending,
        errorMessage: 'Report saved locally. It will submit when internet is restored.',
      );
    } on SubmitFailedException catch (e) {
      state = state.copyWith(
        status:       SubmitStatus.submitFailed,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        status:       SubmitStatus.submitFailed,
        errorMessage: 'Something went wrong. Please retry.',
      );
    }
  }

  Future<void> retrySubmit() => submit();

  Future<void> retryPendingSubmit() async {
    final pending = await _repo.getPending();
    if (pending == null) return;

    state = state.copyWith(status: SubmitStatus.submitting);
    try {
      await _repo.submitReport(pending);
      state = state.copyWith(
        status:         SubmitStatus.submitSuccess,
        uploadProgress: 1.0,
      );
    } on NoInternetException {
      state = state.copyWith(status: SubmitStatus.offlinePending);
    } on SubmitFailedException catch (e) {
      state = state.copyWith(
        status:       SubmitStatus.submitFailed,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        status:       SubmitStatus.submitFailed,
        errorMessage: 'Something went wrong. Please retry.',
      );
    }
  }

  void reset() => state = const FailedDeliveryState();

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }
}

// ── Controller provider (family keyed on orderId) ─────────────────────────

final failedDeliveryControllerProvider = StateNotifierProvider.family<
    FailedDeliveryController, FailedDeliveryState, String>(
      (ref, orderId) {
    final repo  = ref.watch(failedDeliveryRepositoryProvider);
    final order = ref.watch(failedDeliveryOrderProvider(orderId));
    return FailedDeliveryController(repo, order);
  },
);