import 'package:flutter/material.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  UserRole _role = UserRole.manager; // Default to manager

  UserRole get role => _role;

  bool get isEmployee => _role == UserRole.employee;

  void setRole(UserRole newRole) {
    _role = newRole;
    notifyListeners();
  }
}
