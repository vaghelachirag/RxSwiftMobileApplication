// ============================================================================
// lib/features/today_route/route_map/provider/location_sync_provider.dart
// ============================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/location_sync_remote_datasource.dart';
import '../repository/location_sync_repository.dart';

const _kSyncInterval = Duration(minutes: 1);

// ── Repository provider ───────────────────────────────────────────────────

final locationSyncRepositoryProvider = Provider<LocationSyncRepository>(
      (ref) => LocationSyncRepository(
    ref.watch(locationSyncRemoteDataSourceProvider),
  ),
);

// ── Notifier ──────────────────────────────────────────────────────────────
//
// Uses StateNotifier<void> — universally supported across all Riverpod 2.x
// versions with no async build complications.

class LocationSyncNotifier extends StateNotifier<void> {
  LocationSyncNotifier(this._repo) : super(null);

  final LocationSyncRepository _repo;
  Timer? _timer;

  /// Start the periodic sync. Safe to call multiple times.
  void start() {
    stop();           // cancel any existing timer first
    _syncNow();       // fire immediately
    _timer = Timer.periodic(_kSyncInterval, (_) => _syncNow());
  }

  /// Stop the periodic sync and cancel the timer.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _syncNow() {
    // Fire-and-forget. syncOnce() swallows all exceptions internally.
    _repo.syncOnce();
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