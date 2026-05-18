import 'dart:async';

import 'package:flutter/foundation.dart';

import 'network_provider.dart';

enum PendingSyncType {
  faceAttendance,
  qrScan,
  boardCheckout,
  boardReturn,
}

class PendingSyncAction {
  final String id;
  final PendingSyncType type;
  final String title;
  final String description;
  final DateTime createdAt;

  const PendingSyncAction({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.createdAt,
  });
}

class PendingSyncProvider extends ChangeNotifier {
  final List<PendingSyncAction> _pendingActions = [];
  NetworkProvider? _network;
  bool _isSyncing = false;

  List<PendingSyncAction> get pendingActions => List.unmodifiable(_pendingActions);
  int get pendingCount => _pendingActions.length;
  bool get hasPending => _pendingActions.isNotEmpty;
  bool get isSyncing => _isSyncing;

  void bindNetwork(NetworkProvider network) {
    if (_network == network) return;
    _network?.removeListener(_syncWhenOnline);
    _network = network;
    _network?.addListener(_syncWhenOnline);
    _syncWhenOnline();
  }

  void addAction({
    required PendingSyncType type,
    required String title,
    required String description,
  }) {
    _pendingActions.add(
      PendingSyncAction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: type,
        title: title,
        description: description,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  Future<void> _syncWhenOnline() async {
    final network = _network;
    if (network == null || !network.isOnline || _pendingActions.isEmpty || _isSyncing) {
      return;
    }

    _isSyncing = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 900));

    _pendingActions.clear();
    _isSyncing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _network?.removeListener(_syncWhenOnline);
    super.dispose();
  }
}
