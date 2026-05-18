import 'dart:async';

import 'package:flutter/foundation.dart';

import 'network_checker.dart';

class NetworkProvider extends ChangeNotifier {
  bool _isOnline = true;
  bool _hasChecked = false;
  bool _isChecking = false;
  Timer? _timer;

  NetworkProvider() {
    checkNow();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => checkNow());
  }

  bool get isOnline => _isOnline;
  bool get isOffline => _hasChecked && !_isOnline;
  bool get hasChecked => _hasChecked;

  Future<bool> checkNow() async {
    if (_isChecking) return _isOnline;
    _isChecking = true;

    final nextStatus = await hasInternetConnection();
    _isChecking = false;

    if (!_hasChecked || nextStatus != _isOnline) {
      _hasChecked = true;
      _isOnline = nextStatus;
      notifyListeners();
    }

    return _isOnline;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
