// ============================================================================
// lib/features/today_route/route_map/provider/location_sync_provider.dart
//
// Sends driver location to API every 1 minute.
// Latest position is fed in from route_map_screen.dart via updateLatestPosition().
// ============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/location_sync_remote_datasource.dart';
import '../repository/location_sync_repository.dart';
import 'driver_location_provider.dart';

const _kSyncInterval = Duration(seconds: 5);

// ── Repository provider ───────────────────────────────────────────────────

final locationSyncRepositoryProvider = Provider<LocationSyncRepository>(
      (ref) => LocationSyncRepository(
    ref.watch(locationSyncRemoteDataSourceProvider),
  ),
);

// ── Notifier ──────────────────────────────────────────────────────────────

class LocationSyncNotifier extends StateNotifier<void> {
  LocationSyncNotifier(this._repo) : super(null);

  final LocationSyncRepository _repo;
  Timer? _timer;
  DriverPosition? _latestPosition;

  /// Called by route_map_screen on every GPS fix (via listenManual).
  /// Keeps the latest position ready for the next timer tick.
  void updateLatestPosition(DriverPosition pos) {
    _latestPosition = pos;
  }

  /// Start 1-min periodic sync. Safe to call multiple times.
  void start() {
    stop();
    _timer = Timer.periodic(_kSyncInterval, (_) => _syncNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _syncNow() {
    final pos = _latestPosition;
    if (pos != null) {
      _repo.syncWithPosition(pos); // fire-and-forget, errors swallowed
    } else {
      _repo.syncOnce(); // fallback if no GPS fix received yet
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────

final locationSyncProvider =
StateNotifierProvider.autoDispose<LocationSyncNotifier, void>(
      (ref) => LocationSyncNotifier(ref.watch(locationSyncRepositoryProvider)),
);