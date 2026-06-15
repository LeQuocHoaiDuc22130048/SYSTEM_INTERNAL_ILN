import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../utils/auth_provider.dart';
import '../utils/backend_data_provider.dart';
import '../utils/chat_provider.dart';
import '../utils/network_provider.dart';
import '../utils/notification_provider.dart';
import '../utils/pending_sync_provider.dart';
import 'theme_provider.dart';

class AppProviders extends StatelessWidget {
  const AppProviders({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, BackendDataProvider>(
          create: (context) =>
              BackendDataProvider(api: context.read<AuthProvider>().api),
          update: (_, auth, previous) =>
              previous ?? BackendDataProvider(api: auth.api),
        ),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (context) =>
              NotificationProvider(api: context.read<AuthProvider>().api),
          update: (_, auth, previous) {
            final provider = previous ?? NotificationProvider(api: auth.api);
            provider.bindAuth(auth);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider2<
          AuthProvider,
          NotificationProvider,
          ChatProvider
        >(
          create: (context) => ChatProvider(
            api: context.read<AuthProvider>().api,
            notificationProvider: context.read<NotificationProvider>(),
          ),
          update: (_, auth, notifications, previous) {
            final provider =
                previous ??
                ChatProvider(
                  api: auth.api,
                  notificationProvider: notifications,
                );
            provider.updateAuthAndNotification(auth, notifications);
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => NetworkProvider()),
        ChangeNotifierProxyProvider<NetworkProvider, PendingSyncProvider>(
          create: (_) => PendingSyncProvider(),
          update: (_, network, pendingSync) {
            final provider = pendingSync ?? PendingSyncProvider();
            provider.bindNetwork(network);
            return provider;
          },
        ),
      ],
      child: child,
    );
  }
}
