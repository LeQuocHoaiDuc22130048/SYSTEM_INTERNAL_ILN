import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppProviders(child: MyApp()));
}
