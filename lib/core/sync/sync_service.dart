import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart';
import '../database/app_database.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref.watch(databaseProvider));
  ref.onDispose(service.dispose);
  return service;
});

class SyncService {
  SyncService(this.db) {
    _subscription = Connectivity().onConnectivityChanged.listen(_onConnectivity);
  }
  final AppDatabase db;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  bool syncing = false;

  Future<void> _onConnectivity(List<ConnectivityResult> result) async {
    if (result.any((x) => x != ConnectivityResult.none)) await syncNow();
  }

  Future<void> syncNow() async {
    if (syncing) return;
    syncing = true;
    try {
      await Future<void>.delayed(Duration.zero);
    } finally {
      syncing = false;
    }
  }

  void dispose() => _subscription.cancel();
}
