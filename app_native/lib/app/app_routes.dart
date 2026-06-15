import 'package:flutter/material.dart';

import '../screens/login_page.dart';
import '../screens/main_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const login = '/login';
  static const dashboard = '/dashboard';

  static Widget get initialPage => const LoginPage();

  static Map<String, WidgetBuilder> get routes => {
    login: (context) => const LoginPage(),
    dashboard: (context) => const MainScreen(),
  };
}
