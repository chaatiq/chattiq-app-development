import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../theme/app_colors.dart';
import 'push_payload.dart';

enum PushPermission { granted, denied, notDetermined, unavailable }

/// What the app needs from push notifications. Tests replace it with a fake.
abstract class PushPlatform {
  Future<void> init();
  Future<PushPermission> permission();
  Future<PushPermission> requestPermission();
  Future<String?> token();
  Stream<String> get tokenRefreshes;

  /// The user tapped a message notification (app open, in the background, or closed).
  Stream<NewMessagePayload> get taps;

  /// A message notification arrived while the app was open.
  Stream<NewMessagePayload> get foregroundMessages;
}

/// Firebase Cloud Messaging for delivery, plus local notifications so a
/// message is also shown while the app is open (Firebase does not show it then).
class FirebasePushPlatform implements PushPlatform {
  FirebasePushPlatform({FlutterLocalNotificationsPlugin? local}) : _local = local ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _local;
  final _taps = StreamController<NewMessagePayload>.broadcast();
  final _foreground = StreamController<NewMessagePayload>.broadcast();
  Future<void>? _initialized;

  /// Firebase could not start (e.g. google-services.json missing): notifications are off.
  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  @override
  Future<void> init() => _initialized ??= _init();

  Future<void> _init() async {
    if (!_firebaseReady) return;

    await _local.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_notification')),
      onDidReceiveNotificationResponse: (response) => _emitTap(response.payload),
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            chatChannelId,
            chatChannelName,
            description: chatChannelDescription,
            importance: Importance.max,
          ),
        );

    FirebaseMessaging.onMessage.listen(_showWhileOpen);
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _emitTapData(message.data));

    // Opened from a notification while the app was closed. Emitted after a
    // short delay so the app's listeners are attached.
    final launch = await FirebaseMessaging.instance.getInitialMessage();
    final localLaunch = await _local.getNotificationAppLaunchDetails();
    Timer(const Duration(milliseconds: 300), () {
      if (launch != null) _emitTapData(launch.data);
      if (localLaunch?.didNotificationLaunchApp ?? false) _emitTap(localLaunch!.notificationResponse?.payload);
    });
  }

  void _emitTap(String? payload) {
    if (payload == null) return;
    try {
      _emitTapData(Map<String, dynamic>.from(jsonDecode(payload) as Map));
    } catch (_) {
      // Not one of ours.
    }
  }

  void _emitTapData(Map<String, dynamic> data) {
    final message = NewMessagePayload.fromData(data);
    if (message != null) _taps.add(message);
  }

  Future<void> _showWhileOpen(RemoteMessage message) async {
    final payload = NewMessagePayload.fromData(message.data);
    if (payload == null) return;
    _foreground.add(payload);
    final notification = message.notification;
    if (notification == null) return;
    await _local.show(
      id: payload.sessionId.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          chatChannelId,
          chatChannelName,
          channelDescription: chatChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          icon: 'ic_notification',
          // Same tint as the notifications Firebase shows when the app is closed.
          color: AppColors.brandGreen,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static PushPermission _map(AuthorizationStatus status) => switch (status) {
    AuthorizationStatus.authorized || AuthorizationStatus.provisional => PushPermission.granted,
    AuthorizationStatus.denied || AuthorizationStatus.deniedPermanently => PushPermission.denied,
    AuthorizationStatus.notDetermined => PushPermission.notDetermined,
  };

  @override
  Future<PushPermission> permission() async {
    if (!_firebaseReady) return PushPermission.unavailable;
    return _map((await FirebaseMessaging.instance.getNotificationSettings()).authorizationStatus);
  }

  @override
  Future<PushPermission> requestPermission() async {
    if (!_firebaseReady) return PushPermission.unavailable;
    return _map((await FirebaseMessaging.instance.requestPermission()).authorizationStatus);
  }

  @override
  Future<String?> token() async => _firebaseReady ? FirebaseMessaging.instance.getToken() : null;

  @override
  Stream<String> get tokenRefreshes =>
      _firebaseReady ? FirebaseMessaging.instance.onTokenRefresh : const Stream<String>.empty();

  @override
  Stream<NewMessagePayload> get taps => _taps.stream;

  @override
  Stream<NewMessagePayload> get foregroundMessages => _foreground.stream;
}
