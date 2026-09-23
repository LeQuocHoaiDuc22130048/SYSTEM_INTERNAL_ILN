import 'dart:async';

import 'package:flutter/foundation.dart';

import 'network_checker.dart';

class NetworkProvider extends ChangeNotifier {
  bool _isOnline = true;
  bool _hasChecked = false;
  bool _isChecking = false;
  Timer? _timer;
  final Future<bool> Function() _checker;

  NetworkProvider({bool autoPoll = true, Future<bool> Function()? checker})
    : _checker = checker ?? hasInternetConnection {
    if (autoPoll) {
      checkNow();
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => checkNow());
    } else {
      _hasChecked = true;
    }
  }

  bool get isOnline => _isOnline;
  bool get isOffline => _hasChecked && !_isOnline;
  bool get hasChecked => _hasChecked;

  Future<bool> checkNow() async {
    if (_isChecking) return _isOnline;
    _isChecking = true;

    try {
      final nextStatus = await _checker();

      if (!_hasChecked || nextStatus != _isOnline) {
        _hasChecked = true;
        _isOnline = nextStatus;
        notifyListeners();
      }

      return _isOnline;
    } finally {
      _isChecking = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
