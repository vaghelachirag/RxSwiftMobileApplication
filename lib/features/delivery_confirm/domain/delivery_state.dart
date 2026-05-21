// ============================================================================
// domain/delivery_state.dart
// Immutable state model + status enum for the delivery confirmation flow.
// ============================================================================

import 'package:flutter/foundation.dart';

/// All possible stages of the delivery-confirmation flow.
enum DeliveryStatus {
  initial,
  cameraOpening,
  photoCaptured,
  uploading,
  uploadSuccess,
  uploadFailed,
  offlinePendingUpload,
}

/// Geolocation captured at the moment the delivery photo is taken.
@immutable
class CaptureLocation {
  const CaptureLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final double latitude;
  final double longitude;

  /// Best-effort reverse-geocoded address. May be null.
  final String? address;

  /// "23.022500, 72.571400" — useful for compact display.
  String get coordinatesLabel =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      };

  factory CaptureLocation.fromJson(Map<String, dynamic> json) {
    return CaptureLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaptureLocation &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          address == other.address;

  @override
  int get hashCode => Object.hash(latitude, longitude, address);
}

@immutable
class DeliveryState {
  const DeliveryState({
    this.status = DeliveryStatus.initial,
    this.photoPath,
    this.location,
    this.errorMessage,
    this.locationWarning,
    this.uploadProgress = 0.0,
  });

  final DeliveryStatus status;
  final String? photoPath;

  /// Lat/long/address captured alongside the photo. May be null if location
  /// could not be obtained.
  final CaptureLocation? location;

  final String? errorMessage;

  /// Non-blocking warning shown when location could not be captured.
  final String? locationWarning;

  final double uploadProgress;

  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;
  bool get hasLocation => location != null;
  bool get isUploading => status == DeliveryStatus.uploading;
  bool get isSuccess => status == DeliveryStatus.uploadSuccess;
  bool get isOfflinePending => status == DeliveryStatus.offlinePendingUpload;

  bool get canComplete =>
      hasPhoto &&
      status != DeliveryStatus.uploading &&
      status != DeliveryStatus.uploadSuccess;

  DeliveryState copyWith({
    DeliveryStatus? status,
    String? photoPath,
    CaptureLocation? location,
    String? errorMessage,
    String? locationWarning,
    double? uploadProgress,
    bool clearError = false,
    bool clearPhoto = false,
    bool clearLocation = false,
    bool clearLocationWarning = false,
  }) {
    return DeliveryState(
      status: status ?? this.status,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      location: clearLocation ? null : (location ?? this.location),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      locationWarning: clearLocationWarning
          ? null
          : (locationWarning ?? this.locationWarning),
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
          location == other.location &&
          errorMessage == other.errorMessage &&
          locationWarning == other.locationWarning &&
          uploadProgress == other.uploadProgress;

  @override
  int get hashCode => Object.hash(
        status,
        photoPath,
        location,
        errorMessage,
        locationWarning,
        uploadProgress,
      );
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
