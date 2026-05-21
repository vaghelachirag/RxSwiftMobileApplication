// ============================================================================
// domain/delivery_state.dart
// Immutable state model + status enum for the delivery confirmation flow.
// ============================================================================

import 'package:flutter/foundation.dart';

/// All possible stages of the delivery-confirmation flow.
enum DeliveryStatus {
  /// Nothing captured yet — show the "Open Camera" prompt.
  initial,

  /// The native camera UI is being launched.
  cameraOpening,

  /// A photo has been captured and is ready to upload.
  photoCaptured,

  /// The captured photo is being uploaded to the server.
  uploading,

  /// Upload completed successfully — delivery confirmed.
  uploadSuccess,

  /// Upload failed (server error). Allow retry.
  uploadFailed,

  /// No internet. Photo saved locally; will upload when restored.
  offlinePendingUpload,
}

@immutable
class DeliveryState {
  const DeliveryState({
    this.status = DeliveryStatus.initial,
    this.photoPath,
    this.errorMessage,
    this.uploadProgress = 0.0,
  });

  final DeliveryStatus status;

  /// Local file path of the captured image (null until a photo is taken).
  final String? photoPath;

  /// Human-readable error for the [uploadFailed] state.
  final String? errorMessage;

  /// 0.0 → 1.0 upload progress, used to drive the progress indicator.
  final double uploadProgress;

  // -- Convenience getters -------------------------------------------------

  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;

  bool get isUploading => status == DeliveryStatus.uploading;

  bool get isSuccess => status == DeliveryStatus.uploadSuccess;

  bool get isOfflinePending => status == DeliveryStatus.offlinePendingUpload;

  /// "Upload & Complete" is only enabled once a photo exists and we're
  /// not mid-upload / already done.
  bool get canComplete =>
      hasPhoto &&
      status != DeliveryStatus.uploading &&
      status != DeliveryStatus.uploadSuccess;

  // -- copyWith ------------------------------------------------------------

  DeliveryState copyWith({
    DeliveryStatus? status,
    String? photoPath,
    String? errorMessage,
    double? uploadProgress,
    bool clearError = false,
    bool clearPhoto = false,
  }) {
    return DeliveryState(
      status: status ?? this.status,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          photoPath == other.photoPath &&
          errorMessage == other.errorMessage &&
          uploadProgress == other.uploadProgress;

  @override
  int get hashCode =>
      status.hashCode ^
      photoPath.hashCode ^
      errorMessage.hashCode ^
      uploadProgress.hashCode;
}

/// Plain order model shown in the summary card.
@immutable
class DeliveryOrder {
  const DeliveryOrder({
    required this.orderId,
    required this.customerName,
    required this.address,
    required this.pharmacyName,
    this.statusLabel = 'Arrived at destination',
  });

  final String orderId;
  final String customerName;
  final String address;
  final String pharmacyName;
  final String statusLabel;
}
