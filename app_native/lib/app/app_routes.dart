import 'package:flutter/material.dart';

import '../screens/home_page.dart';
import '../screens/login_page.dart';
import '../screens/main_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const login = '/login';
  static const dashboard = '/dashboard';
  static const home = '/home';
  static const profile = '/profile';

  static Widget get initialPage => const LoginPage();

  static Map<String, WidgetBuilder> get routes => {
    login: (context) => const LoginPage(),
    dashboard: (context) => const MainScreen(),
    home: (context) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final initialTab = args is int ? args : 0;
      return HomePage(showBottomNav: true, initialNavTab: initialTab);
    },
    profile: (context) => const HomePage(showBottomNav: true, initialNavTab: 2),
  };
}
