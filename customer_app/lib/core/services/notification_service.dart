import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../main.dart';

/// Top-level FCM background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.notification?.title}');
}

/// Service managing customer FCM push tokens and emails via Resend.
class NotificationService {
  NotificationService._();

  /// Active chat recipient ID if customer is currently viewing ConversationScreen.
  /// When set, foreground notifications from this user are suppressed to avoid double alerts.
  static String? activeChatUserId;

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static StreamSubscription<QuerySnapshot>? _notificationsSubscription;
  static bool _isFirstLoad = true;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Android notification channel for high-priority MartFood notifications.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'martfood_customer_high',
    'MartFood Customer Notifications',
    description: 'High priority notifications for MartFood Customer app.',
    importance: Importance.max,
    playSound: true,
  );

  /// Fallback notification channel for messages targeted at rider channel.
  static const AndroidNotificationChannel _fallbackChannel = AndroidNotificationChannel(
    'martfood_rider_high',
    'MartFood Notifications',
    description: 'High priority notifications for MartFood.',
    importance: Importance.max,
    playSound: true,
  );

  /// Resend API Key for sending emails.
  static const String _resendApiKey = 're_E2Shjtsn_3sc3dyrtXePVLU8p8NZ7MgCr';

  /// Verified custom domain sender on Resend.
  static const String _defaultSender = 'MartFood <no-reply@martfooddelivery.com>';

  /// Cached FCM server key (fetched once from Firestore settings/fcm_config).
  static String? _cachedFcmServerKey;

  /// Initialize Firebase Messaging permissions, local notifications, and listeners.
  static Future<void> initialize() async {
    try {
      // 1. Request notification permissions
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (kDebugMode) {
        print('User notification permission status: ${settings.authorizationStatus}');
      }

      // 2. Create Android notification channels
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_channel);
      await androidPlugin?.createNotificationChannel(_fallbackChannel);

      // 3. Set FCM foreground presentation options (iOS)
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 4. Initialize flutter_local_notifications
      const initSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: initSettingsAndroid,
        iOS: initSettingsIOS,
      );
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _handleNotificationTap(response.payload);
        },
      );

      // 5. Register background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 6. Listen for foreground messages and show them using flutter_local_notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Received foreground message: ${message.notification?.title}');
        }
        _showLocalNotification(message);
      });

      // 7. Handle notification tap when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('App opened from notification: ${message.data}');
        }
        _handleNotificationTap(jsonEncode(message.data));
      });

      // 8. Handle notification that launched the app from terminated state
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        if (kDebugMode) {
          print('[FCM] App launched from notification: ${initialMessage.data}');
        }
        _handleNotificationTap(jsonEncode(initialMessage.data));
      }
    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
    }
  }

  /// Navigates to appropriate screen based on notification payload.
  static void _handleNotificationTap(String? payload) {
    if (payload == null || payload.isEmpty || payload == '{}') return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type']?.toString();
      final riderId = data['riderId']?.toString() ??
          data['senderId']?.toString() ??
          data['userId']?.toString();

      if ((type == 'chat_message' || riderId != null) && riderId != null && riderId.isNotEmpty) {
        appRouter.push('/conversation/$riderId', extra: {
          'riderName': data['riderName'] ?? data['senderName'] ?? data['title'] ?? 'Rider',
          'riderPhotoUrl': data['riderPhotoUrl'] ?? data['senderPhoto'],
        });
      } else if (data['orderId'] != null) {
        appRouter.push('/track_driver', extra: {'orderId': data['orderId']});
      } else {
        appRouter.push('/notifications');
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
    }
  }

  /// Shows a local notification for an incoming foreground FCM message.
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final senderId = message.data['senderId']?.toString() ?? message.data['riderId']?.toString();
    if (activeChatUserId != null && senderId == activeChatUserId) {
      // Customer is actively viewing ConversationScreen with this rider
      return;
    }

    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'New Message';
    final body = message.notification?.body ??
        message.data['body']?.toString() ??
        '';

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      title.hashCode ^ body.hashCode,
      title,
      body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  /// Shows a local notification using direct title, body, and payload.
  static Future<void> _showLocalNotificationDirect(String title, String body, String payload) async {
    try {
      if (payload.isNotEmpty && payload != '{}') {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final senderId = data['senderId']?.toString() ?? data['riderId']?.toString();
        if (activeChatUserId != null && senderId == activeChatUserId) {
          return;
        }
      }
    } catch (_) {}

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      title.hashCode ^ body.hashCode,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Listens to real-time Firestore notification subcollection for fallback delivery.
  static void listenToFirestoreNotifications(String customerId) {
    _notificationsSubscription?.cancel();
    _isFirstLoad = true;

    _notificationsSubscription = _firestore
        .collection('customers')
        .doc(customerId)
        .collection('notifications')
        .snapshots()
        .listen((snapshot) {
          if (_isFirstLoad) {
            _isFirstLoad = false;
            return;
          }

          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data != null) {
                // Ignore notifications older than 2 minutes
                final createdAtObj = data['createdAt'];
                if (createdAtObj != null) {
                  Timestamp timestamp = createdAtObj as Timestamp;
                  final difference = DateTime.now().difference(timestamp.toDate());
                  if (difference.inMinutes > 2) {
                    continue;
                  }
                }

                final title = data['title']?.toString() ?? 'Notification';
                final body = data['body']?.toString() ?? '';
                final payload = data['data'] != null ? jsonEncode(data['data']) : '{}';
                
                _showLocalNotificationDirect(title, body, payload);
              }
            }
          }
        }, onError: (err) {
          debugPrint('Error listening to Firestore notifications: $err');
        });
  }

  /// Registers or refreshes the FCM token for a customer.
  static Future<void> registerCustomerToken(String customerId) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenToFirestore(customerId, token);
      }

      // Listen for token updates
      _messaging.onTokenRefresh.listen((newToken) async {
        await _saveTokenToFirestore(customerId, newToken);
      });
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  static Future<void> _saveTokenToFirestore(String customerId, String token) async {
    try {
      final docRef = _firestore.collection('customers').doc(customerId);
      final doc = await docRef.get();

      if (doc.exists) {
        final currentToken = doc.data()?['fcmToken'];
        if (currentToken == token) return; // Already up-to-date
        await docRef.update({
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.set({
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (kDebugMode) {
        print('FCM token saved for customer $customerId');
      }
    } catch (e) {
      try {
        await _firestore.collection('customers').doc(customerId).set({
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (ex) {
        debugPrint('Error saving FCM token: $ex');
      }
    }
  }

  /// Fetches (and caches) the FCM server key from Firestore settings/fcm_config.
  static Future<String?> _getFcmServerKey() async {
    if (_cachedFcmServerKey != null && _cachedFcmServerKey!.isNotEmpty) {
      return _cachedFcmServerKey;
    }
    try {
      final doc = await _firestore.collection('settings').doc('fcm_config').get();
      _cachedFcmServerKey = doc.data()?['serverKey']?.toString();
      return _cachedFcmServerKey;
    } catch (e) {
      debugPrint('Error fetching FCM server key: $e');
      return null;
    }
  }

  /// Calls the FCM Legacy HTTP API directly to push a notification to a device.
  static Future<void> _dispatchFcm({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String channelId = 'martfood_customer_high',
  }) async {
    final serverKey = await _getFcmServerKey();
    if (serverKey == null || serverKey.isEmpty) {
      debugPrint('[FCM] Server key not found in settings/fcm_config. Skipping push.');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode({
          'to': fcmToken,
          'notification': {
            'title': title,
            'body': body,
            'sound': 'default',
          },
          'data': data ?? {},
          'priority': 'high',
          'content_available': true,
          'android': {
            'notification': {
              'channel_id': channelId,
              'priority': 'high',
            },
          },
        }),
      );

      if (kDebugMode) {
        print('[FCM] Response ${response.statusCode}: ${response.body}');
      }

      if (response.statusCode != 200) {
        debugPrint('[FCM] Failed: ${response.statusCode} — ${response.body}');
      }
    } catch (e) {
      debugPrint('[FCM] Exception dispatching notification: $e');
    }
  }

  /// Sends a transactional email using the Resend REST API.
  static Future<bool> sendEmail({
    required String to,
    required String subject,
    required String htmlContent,
  }) async {
    try {
      final url = Uri.parse('https://api.resend.com/emails');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_resendApiKey',
        },
        body: jsonEncode({
          'from': _defaultSender,
          'to': [to],
          'subject': subject,
          'html': htmlContent,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (kDebugMode) {
          print('Email sent successfully to $to: $subject');
        }
        return true;
      } else {
        debugPrint('Resend failed. Status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Exception in sendEmail: $e');
      return false;
    }
  }

  /// Sends a push notification to a customer.
  /// Logs it to Firestore notifications subcollection AND calls FCM directly.
  static Future<void> sendPushNotification({
    required String customerId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 1. Log in notification history (for in-app bell screen)
      await _firestore
          .collection('customers')
          .doc(customerId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'data': data ?? {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Dispatch FCM push directly via HTTP API
      final docSnap = await _firestore.collection('customers').doc(customerId).get();
      final fcmToken = docSnap.data()?['fcmToken']?.toString();

      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _dispatchFcm(
          fcmToken: fcmToken,
          title: title,
          body: body,
          data: data,
        );
      } else {
        debugPrint('[FCM] No token found for customer $customerId');
      }
    } catch (e) {
      debugPrint('Error sending push notification: $e');
    }
  }

  /// Sends a push notification to a rider.
  /// Logs it to their notifications subcollection AND dispatches via FCM directly.
  static Future<void> sendPushToRider({
    required String riderId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 1. Log in notification history
      await _firestore
          .collection('riders')
          .doc(riderId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'data': data ?? {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Dispatch FCM push directly
      final docSnap = await _firestore.collection('riders').doc(riderId).get();
      final fcmToken = docSnap.data()?['fcmToken']?.toString();

      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _dispatchFcm(
          fcmToken: fcmToken,
          title: title,
          body: body,
          data: data,
          channelId: 'martfood_rider_high',
        );
      } else {
        debugPrint('[FCM] No token found for rider $riderId');
      }
    } catch (e) {
      debugPrint('Error sending rider push: $e');
    }
  }

  /// Sends a push notification to a vendor.
  /// Logs it to their notifications subcollection AND dispatches via FCM directly if available.
  static Future<void> sendPushToVendor({
    required String vendorId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 1. Log in vendor's notification subcollection
      await _firestore
          .collection('vendors')
          .doc(vendorId)
          .collection('notifications')
          .add({
        'title': title,
        'body': body,
        'data': data ?? {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Dispatch FCM push directly if vendor has registered an FCM token
      final docSnap = await _firestore.collection('vendors').doc(vendorId).get();
      final fcmToken = docSnap.data()?['fcmToken']?.toString();

      if (fcmToken != null && fcmToken.isNotEmpty) {
        await _dispatchFcm(
          fcmToken: fcmToken,
          title: title,
          body: body,
          data: data,
          channelId: 'martfood_rider_high',
        );
      }
    } catch (e) {
      debugPrint('Error sending vendor push: $e');
    }
  }
}

