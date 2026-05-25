import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../models/app_notification.dart';
import 'api_client.dart';
import 'auth_provider.dart';

class NotificationProvider extends ChangeNotifier {
  final ApiClient api;

  NotificationProvider({required this.api});

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  List<AppNotification> notifications = [];
  int unreadCount = 0;
  bool isLoading = false;
  bool firebaseReady = false;
  String? error;

  AuthProvider? _auth;
  Timer? _pollTimer;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  StreamSubscription<String>? _tokenRefreshSub;
  StompClient? _stompClient;
  bool _localNotificationsReady = false;
  String? _lastUploadedToken;
  bool _firebaseInitializing = false;
  bool _deviceTokenSyncing = false;
  String? _lastSyncToken;

  AppNotification? pendingNotificationClick;

  final StreamController<Map<String, dynamic>> _messageStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<AppNotification> _clickStreamController =
      StreamController<AppNotification>.broadcast();

  Stream<Map<String, dynamic>> get messageStream =>
      _messageStreamController.stream;

  Stream<AppNotification> get notificationClickStream =>
      _clickStreamController.stream;

  void clickNotification(AppNotification notification) {
    _log('Notification clicked: id=${notification.id}, type=${notification.type}');
    pendingNotificationClick = notification;
    _clickStreamController.add(notification);
    notifyListeners();
  }

  AppNotification _parseNotificationFromPayload(Map<String, dynamic> data, {String? defaultTitle, String? defaultBody}) {
    return AppNotification(
      id: data['notificationId']?.toString() ?? data['id']?.toString() ?? '',
      recipientId: data['recipientId']?.toString() ?? '',
      type: data['type']?.toString() ?? '',
      title: data['title']?.toString() ?? defaultTitle ?? '',
      body: data['body']?.toString() ?? defaultBody ?? '',
      refType: data['refType']?.toString(),
      refId: data['refId']?.toString(),
      isRead: false,
    );
  }

  Future<void> initializeFirebase() async {
    if (_firebaseInitializing || firebaseReady) return;
    _firebaseInitializing = true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp().timeout(const Duration(seconds: 5));
      }

      firebaseReady = true;
      await _initializeLocalNotifications();
      _foregroundSub ??= FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );
      _onMessageOpenedAppSub ??= FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _log('FCM onMessageOpenedApp triggered');
        final notification = _parseNotificationFromPayload(
          message.data,
          defaultTitle: message.notification?.title,
          defaultBody: message.notification?.body,
        );
        clickNotification(notification);
      });

      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) {
          _log('FCM getInitialMessage triggered');
          final notification = _parseNotificationFromPayload(
            message.data,
            defaultTitle: message.notification?.title,
            defaultBody: message.notification?.body,
          );
          clickNotification(notification);
        }
      });

      _tokenRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => _uploadDeviceToken(token),
      );
    } catch (e) {
      firebaseReady = false;
      _log('Firebase init skipped or timed out: $e');
    } finally {
      _firebaseInitializing = false;
    }
  }

  void bindAuth(AuthProvider auth) {
    _auth = auth;
    Future.microtask(_syncForAuthState);
  }

  Future<void> loadNotifications({bool notify = true}) async {
    if (!apiHasToken) return;
    isLoading = true;
    error = null;
    if (notify) notifyListeners();

    try {
      final data = await api.get(
        '/api/v1/notifications',
        queryParameters: {'size': 50},
      );
      notifications = _content(data).map(AppNotification.fromJson).toList();
      unreadCount = notifications.where((item) => !item.isRead).length;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Khong the tai thong bao.';
    } finally {
      isLoading = false;
      if (notify) notifyListeners();
    }
  }

  Future<void> loadUnreadCount({bool notify = true}) async {
    if (!apiHasToken) return;

    try {
      final data = await api.get('/api/v1/notifications/unread-count');
      if (data is Map<String, dynamic>) {
        unreadCount = int.tryParse(data['unreadCount']?.toString() ?? '') ?? 0;
        if (notify) notifyListeners();
      }
    } catch (_) {
      // Badge refresh failure should not disturb the rest of the app.
    }
  }

  Future<void> markAsRead(AppNotification notification) async {
    if (notification.isRead || !apiHasToken) return;

    await api.put('/api/v1/notifications/${notification.id}/read');
    notifications = notifications
        .map(
          (item) =>
              item.id == notification.id ? item.copyWith(isRead: true) : item,
        )
        .toList();
    unreadCount = notifications.where((item) => !item.isRead).length;
    notifyListeners();
  }

  Future<void> markAllAsRead() async {
    if (!apiHasToken || unreadCount == 0) return;

    await api.put('/api/v1/notifications/read-all');
    notifications = notifications
        .map((item) => item.copyWith(isRead: true))
        .toList();
    unreadCount = 0;
    notifyListeners();
  }

  bool get apiHasToken => api.accessToken != null;

  void _syncForAuthState() {
    final token = api.accessToken;
    if (_auth?.isAuthenticated == true && token != null) {
      if (token == _lastSyncToken) return;
      _lastSyncToken = token;

      initializeFirebase().then((_) => _syncDeviceToken());
      loadUnreadCount();
      loadNotifications(notify: false).then((_) => notifyListeners());
      _connectRealtime();
      _pollTimer ??= Timer.periodic(
        const Duration(seconds: 30),
        (_) => loadUnreadCount(),
      );
    } else {
      _lastSyncToken = null;
      _disconnectRealtime();
      _pollTimer?.cancel();
      _pollTimer = null;
      _lastUploadedToken = null;
      notifications = [];
      unreadCount = 0;
      error = null;
      notifyListeners();
    }
  }

  void _connectRealtime() {
    if (!apiHasToken || _stompClient != null) return;

    final token = api.accessToken;
    if (token == null) return;

    final headers = {'Authorization': 'Bearer $token'};
    final url = '${api.activeBaseUrl}/ws';

    _stompClient = StompClient(
      config: StompConfig.sockJS(
        url: url,
        stompConnectHeaders: headers,
        webSocketConnectHeaders: headers,
        reconnectDelay: const Duration(seconds: 5),
        onConnect: _onRealtimeConnected,
        onWebSocketError: (error) => _log('WebSocket error: $error'),
        onStompError: (frame) => _log('STOMP error: ${frame.body}'),
      ),
    )..activate();
  }

  void _onRealtimeConnected(StompFrame frame) {
    _stompClient?.subscribe(
      destination: '/user/queue/notifications',
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) return;

        try {
          final decoded = jsonDecode(body);
          if (decoded is! Map<String, dynamic>) return;

          final notification = AppNotification.fromJson(decoded);
          notifications = [
            notification,
            ...notifications.where((item) => item.id != notification.id),
          ];
          unreadCount = notifications.where((item) => !item.isRead).length;
          notifyListeners();
        } catch (e) {
          _log('Realtime notification parse failed: $e');
        }
      },
    );

    _stompClient?.subscribe(
      destination: '/user/queue/messages',
      callback: (frame) {
        final body = frame.body;
        if (body == null || body.isEmpty) return;

        try {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            _messageStreamController.add(decoded);
          }
        } catch (e) {
          _log('Realtime message parse failed: $e');
        }
      },
    );
  }

  void _disconnectRealtime() {
    _stompClient?.deactivate();
    _stompClient = null;
  }

  Future<void> _syncDeviceToken() async {
    if (!firebaseReady || !apiHasToken || kIsWeb || _deviceTokenSyncing) return;
    _deviceTokenSyncing = true;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission()
          .timeout(const Duration(seconds: 5));
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await FirebaseMessaging.instance.getToken()
          .timeout(const Duration(seconds: 5));
      if (token != null) await _uploadDeviceToken(token);
    } catch (e) {
      _log('Device token sync failed or timed out: $e');
    } finally {
      _deviceTokenSyncing = false;
    }
  }

  Future<void> _uploadDeviceToken(String token) async {
    if (!apiHasToken || token == _lastUploadedToken) return;

    try {
      await api.put(
        '/api/v1/notifications/device-token',
        body: {'deviceToken': token},
      );
      _lastUploadedToken = token;
    } catch (e) {
      _log('Device token upload failed: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsReady || kIsWeb) return;

    try {
      const android = AndroidInitializationSettings('@mipmap/launcher_icon');
      const darwin = DarwinInitializationSettings();
      const settings = InitializationSettings(android: android, iOS: darwin);
      await _localNotifications.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            try {
              final Map<String, dynamic> data = jsonDecode(payload);
              final notification = _parseNotificationFromPayload(data);
              clickNotification(notification);
            } catch (e) {
              _log('Failed to parse local notification payload: $e');
            }
          }
        },
      ).timeout(const Duration(seconds: 4));

      const channel = AndroidNotificationChannel(
        'system_internal_notifications',
        'System Internal Notifications',
        description: 'In-app and push notifications',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel)
          .timeout(const Duration(seconds: 4));

      _localNotificationsReady = true;
    } catch (e) {
      _log('Local notifications init failed or timed out: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification != null && _localNotificationsReady && !kIsWeb) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'system_internal_notifications',
            'System Internal Notifications',
            channelDescription: 'In-app and push notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }

    await loadNotifications();
  }

  List<Map<String, dynamic>> _content(dynamic data) {
    if (data is Map<String, dynamic>) {
      final content = data['content'];
      if (content is List) {
        return content.whereType<Map<String, dynamic>>().toList();
      }
    }
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    return const [];
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[NOTIFICATION] $message');
  }

  @override
  void dispose() {
    _disconnectRealtime();
    _pollTimer?.cancel();
    _foregroundSub?.cancel();
    _onMessageOpenedAppSub?.cancel();
    _tokenRefreshSub?.cancel();
    _messageStreamController.close();
    _clickStreamController.close();
    super.dispose();
  }
}
