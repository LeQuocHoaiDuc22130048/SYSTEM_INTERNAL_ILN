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
<<<<<<< HEAD
          title: 'System Inverter Likenew',
=======
          title: 'System Inverter LikeNew',
>>>>>>> 1eaf0b7 (Refactor project name from "system_internal_likenew" to "system_inverter_likenew" across all configurations, files, and tests. Update dependencies and versioning in pubspec.yaml and pubspec.lock. Modify web index.html and manifest.json for new app title. Adjust Windows and iOS project files to reflect the new application name. Ensure all references in test files are updated accordingly.)
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
