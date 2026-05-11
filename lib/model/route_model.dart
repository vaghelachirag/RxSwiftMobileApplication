// ─────────────────────────────────────────────────────────────
//  Domain Models — Today's Route
// ─────────────────────────────────────────────────────────────

enum StopStatus { pending, inProgress, completed, skipped }

class RouteStop {
  const RouteStop({
    required this.id,
    required this.stopNumber,
    required this.patientName,
    required this.address,
    required this.scheduledTime,
    this.status = StopStatus.pending,
    this.notes,
  });

  final String id;
  final int stopNumber;
  final String patientName;
  final String address;
  final String scheduledTime;
  final StopStatus status;
  final String? notes;

  RouteStop copyWith({
    String? id,
    int? stopNumber,
    String? patientName,
    String? address,
    String? scheduledTime,
    StopStatus? status,
    String? notes,
  }) {
    return RouteStop(
      id: id ?? this.id,
      stopNumber: stopNumber ?? this.stopNumber,
      patientName: patientName ?? this.patientName,
      address: address ?? this.address,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}

class TodayRoute {
  const TodayRoute({
    required this.totalStops,
    required this.pickupTime,
    required this.stops,
  });

  final int totalStops;
  final String pickupTime;
  final List<RouteStop> stops;

  TodayRoute copyWith({
    int? totalStops,
    String? pickupTime,
    List<RouteStop>? stops,
  }) {
    return TodayRoute(
      totalStops: totalStops ?? this.totalStops,
      pickupTime: pickupTime ?? this.pickupTime,
      stops: stops ?? this.stops,
    );
  }
}