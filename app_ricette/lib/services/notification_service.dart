import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ingredient.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  NotificationService._internal({
    FlutterLocalNotificationsPlugin? plugin,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _notificationsPlugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @visibleForTesting
  NotificationService.test({
    required FlutterLocalNotificationsPlugin plugin,
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _notificationsPlugin = plugin,
        _auth = auth,
        _firestore = firestore;

  bool _initialized = false;

  // Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Rome'));
    } catch (e) {
      tz.setLocalLocation(tz.UTC);
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  Future<bool> requestPermissions() async {
    // Android 13+ permissions (unchanged)
    final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      if (granted != true) {
        debugPrint('NotificationService: Android notification permission NOT granted');
        return false;
      }
    }

    // iOS permissions
    final iosPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final result = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return result ?? false;
    }

    return true;
  }

  // Helper to get user-specific preference key
  String _getUserKey(String baseKey) {
    final uid = _auth.currentUser?.uid ?? 'guest';
    return '${baseKey}_$uid';
  }

  // Check and schedule notifications for expiring products
  Future<void> checkAndScheduleExpiringProducts() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('NotificationService: No user logged in');
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // Check if notifications are enabled
    final notificationsEnabled = prefs.getBool(_getUserKey('notifications_enabled')) ?? true;
    if (!notificationsEnabled) {
      debugPrint('NotificationService: Notifications disabled');
      await cancelAllNotifications();
      return;
    }

    // Get settings
    final reminderIndex = prefs.getInt(_getUserKey('reminder_index')) ?? 2;
    final warningDays = _getDaysFromIndex(reminderIndex);
    final hour = prefs.getInt(_getUserKey('notification_hour')) ?? 9;
    final minute = prefs.getInt(_getUserKey('notification_minute')) ?? 0;

    debugPrint('NotificationService: Checking products. Warning days: $warningDays, Time: $hour:$minute');

    // Load products from Firestore
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('fridge')
        .get();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<Ingredient> expiringProducts = [];
    List<Ingredient> expiredProducts = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final ingredient = Ingredient.fromJson(data);
      ingredient.id = doc.id;

      final scadenza = ingredient.scadenza;
      if (scadenza.isEmpty) continue;

      try {
        final parts = scadenza.split('/');
        if (parts.length == 3) {
          final expiryDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );

          final daysLeft = expiryDate.difference(today).inDays;

          if (daysLeft < 0) {
            expiredProducts.add(ingredient);
          } else if (daysLeft <= warningDays && daysLeft >= 0) {
            expiringProducts.add(ingredient);
          }
        }
      } catch (e) {
        debugPrint('Error parsing date: $e');
      }
    }

    debugPrint('NotificationService: Found ${expiredProducts.length} expired, ${expiringProducts.length} expiring');

    // Cancel all previous notifications
    await cancelAllNotifications();

    // Schedule notifications at the user's preferred time
    if (expiredProducts.isNotEmpty || expiringProducts.isNotEmpty) {
      await _scheduleNotificationAtTime(
        hour: hour,
        minute: minute,
        expiredProducts: expiredProducts,
        expiringProducts: expiringProducts,
      );
    }
  }

  // Schedule notification at specific time
  Future<void> _scheduleNotificationAtTime({
    required int hour,
    required int minute,
    required List<Ingredient> expiredProducts,
    required List<Ingredient> expiringProducts,
  }) async {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    // Build notification content
    String title;
    String body;

    if (expiredProducts.isNotEmpty && expiringProducts.isNotEmpty) {
      title = '🍎 FridgeWizard Alert';
      body = '${expiredProducts.length} expired and ${expiringProducts.length} expiring soon!';
    } else if (expiredProducts.isNotEmpty) {
      final count = expiredProducts.length;
      title = '⚠️ ${count == 1 ? "1 Product Expired" : "$count Products Expired"}';
      body = count == 1
          ? '${expiredProducts[0].displayName} has expired!'
          : '${expiredProducts.take(3).map((p) => p.displayName).join(", ")}${count > 3 ? " and ${count - 3} more" : ""} have expired!';
    } else {
      final count = expiringProducts.length;
      title = '⏰ ${count == 1 ? "1 Product Expiring Soon" : "$count Products Expiring Soon"}';
      body = count == 1
          ? '${expiringProducts[0].displayName} expires ${_getDaysLeftText(expiringProducts[0].scadenza)}'
          : '${expiringProducts.take(3).map((p) => p.displayName).join(", ")}${count > 3 ? " and ${count - 3} more" : ""} expiring soon!';
    }

    debugPrint('NotificationService: Scheduling notification for $scheduledDate');

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'expiry_channel',
      'Product Expiry Notifications',
      channelDescription: 'Notifications for expiring and expired products',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      1, // Main notification ID
      title,
      body,
      tzScheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at this time
      payload: 'expiry_alert',
    );
  }

  // Show immediate notification (for testing or immediate alerts)
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'expiry_channel',
      'Product Expiry Notifications',
      channelDescription: 'Notifications for expiring and expired products',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  int _getDaysFromIndex(int index) {
    switch (index) {
      case 0: return 1;
      case 1: return 2;
      case 2: return 3;
      case 3: return 4;
      case 4: return 7;
      case 5: return 14;
      default: return 3;
    }
  }

  String _getDaysLeftText(String scadenza) {
    try {
      final parts = scadenza.split('/');
      if (parts.length == 3) {
        final expiryDate = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final daysLeft = expiryDate.difference(today).inDays;

        if (daysLeft == 0) return 'today';
        if (daysLeft == 1) return 'tomorrow';
        return 'in $daysLeft days';
      }
    } catch (e) {
      // ignore
    }
    return 'soon';
  }

  // Test notification (for debugging)
  Future<void> showTestNotification() async {
    await _showNotification(
      id: 0,
      title: '🧪 Test Notification',
      body: 'FridgeWizard notifications are working!',
      payload: 'test',
    );
  }
}
