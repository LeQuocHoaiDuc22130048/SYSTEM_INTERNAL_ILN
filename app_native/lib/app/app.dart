import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../widgets/offline_banner.dart';
import 'app_routes.dart';
import 'theme_provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Inverter like new',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: AppRoutes.initialPage,
          builder: (context, child) {
            return OfflineBanner(child: child ?? const SizedBox.shrink());
          },
          routes: AppRoutes.routes,
        );
      },
    );
  }
}
