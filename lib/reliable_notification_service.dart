import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class ReliableNotificationService {
  static final ReliableNotificationService _instance = ReliableNotificationService._internal();
  factory ReliableNotificationService() => _instance;
  ReliableNotificationService._internal();

  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static Timer? _notificationTimer;

  static Future<void> initialize() async {
    try {
      print('🚀 Initializing Reliable Notification Service...');
      
      tz.initializeTimeZones();
      
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings();
      
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(initializationSettings);
      
      await _createNotificationChannel();
      
      print('✅ Reliable Notification Service initialized');
      
    } catch (e) {
      print('❌ Error initializing reliable notification service: $e');
    }
  }

  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'reliable_motivation_channel',
      'Motivation Notifications',
      description: 'Reliable motivational notifications',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // SIMPLE TEST - This should definitely work
  static Future<void> sendTestNotificationNow() async {
    try {
      print('🔔 SENDING TEST NOTIFICATION NOW...');
      
      await _notificationsPlugin.show(
        99999,
        '🧪 TEST NOTIFICATION',
        'This is an immediate test notification! If you see this, basic notifications work! ✅',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reliable_motivation_channel',
            'Motivation Notifications',
            channelDescription: 'Reliable motivational notifications',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
      );
      
      print('✅ TEST NOTIFICATION SENT SUCCESSFULLY');
      
    } catch (e) {
      print('❌ TEST NOTIFICATION FAILED: $e');
    }
  }

  // SIMPLE SCHEDULED TEST - 1 minute from now
  static Future<void> scheduleSimpleTest() async {
    try {
      final scheduledTime = tz.TZDateTime.now(tz.local).add(Duration(minutes: 1));
      
      print('⏰ Scheduling simple test for: $scheduledTime');
      
      await _notificationsPlugin.zonedSchedule(
        88888,
        '🧪 SCHEDULED TEST',
        'This is a scheduled test notification! Should appear in 1 minute.',
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reliable_motivation_channel',
            'Motivation Notifications',
            channelDescription: 'Reliable motivational notifications',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        //uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      
      print('✅ SIMPLE TEST SCHEDULED SUCCESSFULLY');
      
    } catch (e) {
      print('❌ SIMPLE SCHEDULING FAILED: $e');
    }
  }

  // Check if any notifications are pending
  static Future<void> checkPendingNotifications() async {
    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      print('📋 PENDING NOTIFICATIONS: ${pending.length}');
      
      for (var notif in pending) {
        print('   - ID: ${notif.id}, Title: "${notif.title}"');
      }
      
    } catch (e) {
      print('❌ Error checking pending notifications: $e');
    }
  }

  // Cancel all notifications
  static Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
      _notificationTimer?.cancel();
      print('🗑️ All notifications cancelled');
    } catch (e) {
      print('❌ Error cancelling notifications: $e');
    }
  }
}