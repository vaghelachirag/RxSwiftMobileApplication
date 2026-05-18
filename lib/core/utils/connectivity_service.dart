import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lightweight wrapper around [Connectivity].
/// Inject this wherever you need to guard an API call behind a connectivity check.
class ConnectivityService {
  const ConnectivityService(this._connectivity);
  final Connectivity _connectivity;

  /// Returns `true` if the device has an active network connection.
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Stream of connectivity changes — useful for reactive UI.
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;
}

// ── Provider ─────────────────────────────────────────────────

final connectivityProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService(Connectivity());
});