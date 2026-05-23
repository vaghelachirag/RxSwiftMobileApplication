// ============================================================================
// presentation/providers/failed_delivery_providers.dart
// Riverpod providers + StateNotifier controlling the failed-delivery report.
// ============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/failed_delivery_repository.dart';
import '../../domain/failed_delivery_state.dart';

// -- Repository provider ------------------------------------------------------
final failedDeliveryRepositoryProvider =
    Provider<FailedDeliveryRepository>((ref) {
  return FailedDeliveryRepository();
});

// -- Order provider -----------------------------------------------------------
final failedDeliveryOrderProvider = Provider<DeliveryOrder>((ref) {
  return const DeliveryOrder(
    orderId: 'RX-48291',
    customerName: 'John Smith',
    address: '1400-048-665, 24 Maple Street, Apt 5B',
    pharmacyName: 'WellCare Pharmacy',
    statusLabel: 'Attempt failed',
  );
});

// -- StateNotifier ------------------------------------------------------------
class FailedDeliveryController extends StateNotifier<FailedDeliveryState> {
  FailedDeliveryController(this._repo, this._order)
      : super(const FailedDeliveryState()) {
    _watchConnectivity();
  }

  final FailedDeliveryRepository _repo;
  final DeliveryOrder _order;
  StreamSubscription<bool>? _connSub;

  void _watchConnectivity() {
    _connSub = _repo.onConnectivityChanged.listen((online) {
      if (online && state.status == SubmitStatus.offlinePending) {
        retryPendingSubmit();
      }
    });
  }

  // -- Form edits ------------------------------------------------------------
  void selectReason(FailureReason reason) {
    state = state.copyWith(reason: reason, clearError: true);
  }

  void updateNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  // -- Photos (camera only) --------------------------------------------------
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
        status: prevStatus == SubmitStatus.capturingPhoto
            ? SubmitStatus.initial
            : prevStatus,
        photoPaths: [...state.photoPaths, path],
      );
    } catch (_) {
      state = state.copyWith(
        status: prevStatus,
        errorMessage: 'Could not open the camera. Please try again.',
      );
    }
  }

  void removePhoto(int index) {
    if (index < 0 || index >= state.photoPaths.length) return;
    final updated = [...state.photoPaths]..removeAt(index);
    state = state.copyWith(photoPaths: updated);
  }

  // -- Submit ----------------------------------------------------------------
  Future<void> submit() async {
    if (!state.canSubmit) return;

    state = state.copyWith(
      status: SubmitStatus.submitting,
      uploadProgress: 0.0,
      clearError: true,
    );

    final report = FailedDeliveryReport(
      orderId: _order.orderId,
      reasonCode: state.reason!.code,
      notes: state.notes,
      photoPaths: state.photoPaths,
    );

    try {
      await _repo.submitReport(
        report,
        onProgress: (p) => state = state.copyWith(uploadProgress: p),
      );
      state = state.copyWith(
        status: SubmitStatus.submitSuccess,
        uploadProgress: 1.0,
      );
    } on NoInternetException {
      state = state.copyWith(
        status: SubmitStatus.offlinePending,
        errorMessage:
            'Report saved locally. It will submit when internet is restored.',
      );
    } on SubmitFailedException catch (e) {
      state = state.copyWith(
        status: SubmitStatus.submitFailed,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: SubmitStatus.submitFailed,
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
        status: SubmitStatus.submitSuccess,
        uploadProgress: 1.0,
      );
    } on NoInternetException {
      state = state.copyWith(status: SubmitStatus.offlinePending);
    } on SubmitFailedException catch (e) {
      state = state.copyWith(
        status: SubmitStatus.submitFailed,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        status: SubmitStatus.submitFailed,
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

final failedDeliveryControllerProvider =
    StateNotifierProvider<FailedDeliveryController, FailedDeliveryState>((ref) {
  final repo = ref.watch(failedDeliveryRepositoryProvider);
  final order = ref.watch(failedDeliveryOrderProvider);
  return FailedDeliveryController(repo, order);
});
