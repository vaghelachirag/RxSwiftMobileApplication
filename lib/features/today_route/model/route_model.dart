// ============================================================================
// model/route_model.dart
// Mirrors the /api/driver/today-route response. Field names kept compatible
// with the existing TodayRouteScreen where practical, via getters.
// ============================================================================

/// Pickup vs drop leg of an order.
enum StopType { pickup, drop }

extension StopTypeX on StopType {
  /// Server code → enum.
  static StopType fromCode(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'PICKUP':
        return StopType.pickup;
      case 'DROP':
        return StopType.drop;
      default:
        return StopType.drop;
    }
  }

  /// UI label per the spec: PICKUP -> "Pickup", DROP -> "Drop".
  String get label => this == StopType.pickup ? 'Pickup' : 'Drop';

  String get code => this == StopType.pickup ? 'PICKUP' : 'DROP';
}

/// Lifecycle status of a stop.
enum StopStatus { pending, inProgress, completed, skipped }

extension StopStatusX on StopStatus {
  static StopStatus fromCode(String? code) {
    switch ((code ?? '').toUpperCase()) {
      case 'COMPLETED':
      case 'DELIVERED':
        return StopStatus.completed;
      case 'INPROGRESS':
      case 'IN_PROGRESS':
        return StopStatus.inProgress;
      case 'SKIPPED':
        return StopStatus.skipped;
      case 'PENDING':
      default:
        return StopStatus.pending;
    }
  }
}

class RouteStop {
  const RouteStop({
    required this.sequence,
    required this.stopType,
    required this.orderId,
    required this.orderNumber,
    required this.patientName,
    required this.patientPhone,
    required this.pharmacyName,
    required this.address,
    required this.status,
    required this.statusLabel,
    required this.priority,
    required this.distanceKmFromPreviousStop,
    this.latitude,
    this.longitude,
    this.notes,
  });

  final int sequence;
  final StopType stopType;
  final String orderId;
  final String orderNumber;
  final String patientName;
  final String patientPhone;
  final String pharmacyName;
  final String address;
  final StopStatus status;
  final String statusLabel;
  final bool priority;
  final double distanceKmFromPreviousStop;
  final double? latitude;
  final double? longitude;
  final String? notes;

  // -- Compatibility getters for the existing screen ----------------------

  /// The screen used `stop.id`; map it to the sequence-scoped order id so it
  /// stays unique per row (an order has both a pickup and a drop).
  String get id => '$orderId-${stopType.code}-$sequence';

  /// The screen used `stop.stopNumber`.
  int get stopNumber => sequence;

  /// The screen showed `stop.scheduledTime` on the right; the API has no time,
  /// so surface the pickup/drop label there instead.
  String get scheduledTime => stopType.label;

  bool get hasCoordinates => latitude != null && longitude != null;

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      stopType: StopTypeX.fromCode(json['stopType'] as String?),
      orderId: json['orderId'] as String? ?? '',
      orderNumber: json['orderNumber'] as String? ?? '',
      patientName: json['patientName'] as String? ?? '',
      patientPhone: json['patientPhone'] as String? ?? '',
      pharmacyName: json['pharmacyName'] as String? ?? '',
      address: json['address'] as String? ?? '',
      status: StopStatusX.fromCode(json['status'] as String?),
      statusLabel: json['statusLabel'] as String? ?? '',
      priority: json['priority'] as bool? ?? false,
      distanceKmFromPreviousStop:
          (json['distanceKmFromPreviousStop'] as num?)?.toDouble() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );
  }

  RouteStop copyWith({
    int? sequence,
    StopType? stopType,
    String? orderId,
    String? orderNumber,
    String? patientName,
    String? patientPhone,
    String? pharmacyName,
    String? address,
    StopStatus? status,
    String? statusLabel,
    bool? priority,
    double? distanceKmFromPreviousStop,
    double? latitude,
    double? longitude,
    String? notes,
  }) {
    return RouteStop(
      sequence: sequence ?? this.sequence,
      stopType: stopType ?? this.stopType,
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      patientName: patientName ?? this.patientName,
      patientPhone: patientPhone ?? this.patientPhone,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      address: address ?? this.address,
      status: status ?? this.status,
      statusLabel: statusLabel ?? this.statusLabel,
      priority: priority ?? this.priority,
      distanceKmFromPreviousStop:
          distanceKmFromPreviousStop ?? this.distanceKmFromPreviousStop,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
    );
  }
}

class TodayRoute {
  const TodayRoute({
    required this.driverId,
    required this.driverName,
    required this.totalStops,
    required this.totalOrders,
    required this.estimatedDistanceKm,
    required this.stops,
    this.startLatitude,
    this.startLongitude,
    this.routeDate,
  });

  final String driverId;
  final String driverName;
  final int totalStops;
  final int totalOrders;
  final double estimatedDistanceKm;
  final List<RouteStop> stops;
  final double? startLatitude;
  final double? startLongitude;
  final DateTime? routeDate;

  /// The screen showed `route.pickupTime` in the subheader. The API has no
  /// pickup time, so expose the order count there instead.
  String get pickupTime => '$totalOrders Orders';

  factory TodayRoute.fromJson(Map<String, dynamic> json) {
    return TodayRoute(
      driverId: json['driverId'] as String? ?? '',
      driverName: json['driverName'] as String? ?? '',
      totalStops: (json['totalStops'] as num?)?.toInt() ?? 0,
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      estimatedDistanceKm:
          (json['estimatedDistanceKm'] as num?)?.toDouble() ?? 0,
      startLatitude: (json['startLatitude'] as num?)?.toDouble(),
      startLongitude: (json['startLongitude'] as num?)?.toDouble(),
      routeDate: json['routeDate'] == null
          ? null
          : DateTime.tryParse(json['routeDate'] as String),
      stops: (json['stops'] as List<dynamic>? ?? [])
          .map((e) => RouteStop.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  TodayRoute copyWith({
    String? driverId,
    String? driverName,
    int? totalStops,
    int? totalOrders,
    double? estimatedDistanceKm,
    List<RouteStop>? stops,
    double? startLatitude,
    double? startLongitude,
    DateTime? routeDate,
  }) {
    return TodayRoute(
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      totalStops: totalStops ?? this.totalStops,
      totalOrders: totalOrders ?? this.totalOrders,
      estimatedDistanceKm: estimatedDistanceKm ?? this.estimatedDistanceKm,
      stops: stops ?? this.stops,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      routeDate: routeDate ?? this.routeDate,
    );
  }
}
