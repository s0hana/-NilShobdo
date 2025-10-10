import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_time_manager.dart';
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static Timer? _notificationTimer;
  
  // Gemini AI
  static const String _geminiApiKey = 'AIzaSyAHVUp0i4eX-9xmBuaRP25rNBQ7Ghda1pU';
  static late GenerativeModel _model;

  bool _isInitialized = false;
  static final List<TimeOfDay> _activeTimes = [];

  // ========== LOCAL NOTIFICATION METHODS ==========

/// Show local notification immediately
static Future<void> showLocalNotification({
  required String title,
  required String body,
  String? payload,
  int? id,
}) async {
  try {
    final notificationId = id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
    
    await _notifications.show(
      notificationId,
      title,
      body,
      _getNotificationDetails(),
      payload: payload,
    );
    
    print('📲 Local notification shown: $title');
    
    // Also save to Firestore for history
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('userNotifications')
          .doc(user.uid)
          .collection('notifications')
          .add({
        'content': body,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'local',
        'title': title,
        'read': false,
      });
    }
    
  } catch (e) {
    print('❌ Error showing local notification: $e');
  }
}
/// Show local notification with custom details
static Future<void> showCustomLocalNotification({
  required String title,
  required String body,
  String? channelId,
  String? channelName,
  String? payload,
  int? id,
}) async {
  try {
    final notificationId = id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
    
    final NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId ?? 'motivation_channel',
        channelName ?? 'Motivation Notifications',
        channelDescription: 'Daily motivational quotes and reminders',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        colorized: true,
        autoCancel: true,
      ),
      iOS: const DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    
    await _notifications.show(
      notificationId,
      title,
      body,
      details,
      payload: payload,
    );
    
    print('📲 Custom local notification shown: $title');
    
  } catch (e) {
    print('❌ Error showing custom local notification: $e');
  }
}
  // ========== BACKGROUND NOTIFICATION HANDLER ==========

/// Handle background notifications from Firebase
 static Future<void> handleBackgroundNotification(RemoteMessage message) async {
  try {
    print('🔔 Handling background notification for Android: ${message.messageId}');
    
    // ✅ Android-specific notification setup
    final FlutterLocalNotificationsPlugin notificationsPlugin = 
        FlutterLocalNotificationsPlugin();
    
    // ✅ Android initialization only
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      // iOS: null - skip for Android only
    );
    
    await notificationsPlugin.initialize(initSettings);
    
    // ✅ Show notification only if it's from FCM
    if (message.notification != null) {
      final RemoteNotification notification = message.notification!;
      
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'nil_shobdo_channel', // Channel ID
        'Nil Shobdo Notifications', // Channel Name
        channelDescription: 'General notifications for Nil Shobdo app',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        autoCancel: true,
        enableVibration: true,
        playSound: true,
      );
      
      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        // iOS: null - skip for Android only
      );
      
      // Generate unique ID
      final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      
      await notificationsPlugin.show(
        notificationId,
        notification.title ?? 'Nil Shobdo',
        notification.body ?? 'New message',
        platformDetails,
        payload: message.data.toString(),
      );
      
      print('✅ Android background notification shown. ID: $notificationId');
    }
    
  } catch (e) {
    print('❌ Error handling Android background notification: $e');
    
    // Fallback - System will handle basic notification
  }
}

  // ========== INITIALIZATION ==========

  static Future<void> initialize() async {
    try {
      print('🚀 INITIALIZING NOTIFICATION SERVICE...');
      
      // Initialize timezone
      tz.initializeTimeZones();
      
      // Initialize Gemini AI
      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: _geminiApiKey,
      );

      // Setup local notifications
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(initializationSettings);
      
      await _createNotificationChannel();
      
      // Request permissions & setup FCM
      await _setupFirebaseMessaging();
      
      _instance._isInitialized = true;
      print('✅ NOTIFICATION SERVICE READY!');
      
    } catch (e) {
      print('❌ INIT ERROR: $e');
    }
  }

  static Future<void> _setupFirebaseMessaging() async {
    try {
      final NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print('📱 Notification permission: ${settings.authorizationStatus}');

      // Get FCM token
      final String? token = await _firebaseMessaging.getToken();
      print('🔑 FCM Token: $token');
      await saveFCMToken(token);

      // Setup message handlers
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📲 Foreground message: ${message.notification?.title}');
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('📱 App opened from notification: ${message.data}');
      });
    } catch (e) {
      print('❌ FCM SETUP ERROR: $e');
    }
  }

  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'motivation_channel',
      'Motivation Notifications',
      description: 'Daily motivational quotes and reminders',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ========== CORE NOTIFICATION METHODS ==========

  /// 🔥 IMMEDIATE NOTIFICATION
  static Future<void> sendNow() async {
    try {
      print('🔔 SENDING NOTIFICATION NOW...');
      
      final content = await generatePersonalizedContent();
      
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '🌟 Daily Motivation',
        content,
        _getNotificationDetails(),
      );
      
      await _saveNotificationToFirestore(content, 'immediate');
      print('✅ NOTIFICATION SENT SUCCESSFULLY!');
      
    } catch (e) {
      print('❌ SEND FAILED: $e');
      await _sendFallbackNotification();
    }
  }

  /// Send immediate motivation notification
  static Future<void> sendImmediateMotivation() async {
    try {
      final content = await generatePersonalizedContent();
      
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '💫 Quick Motivation',
        content,
        _getNotificationDetails(),
      );
      
      await _saveNotificationToFirestore(content, 'manual');
      print('🎯 Immediate motivation sent successfully');
      
    } catch (e) {
      print('❌ IMMEDIATE MOTIVATION FAILED: $e');
    }
  }

  /// 🔥 SIMPLE TEST SCHEDULE - 1 MINUTE FROM NOW
  static Future<void> scheduleInOneMinute() async {
    try {
      print('⏰ SCHEDULING NOTIFICATION IN 1 MINUTE...');
      
      _notificationTimer?.cancel();
      
      _notificationTimer = Timer(const Duration(minutes: 1), () async {
        print('🎯 1 MINUTE PASSED - SENDING NOTIFICATION...');
        await sendNow();
      });
      
      print('✅ SCHEDULED! Timer will trigger in 1 minute');
      
    } catch (e) {
      print('❌ SCHEDULING FAILED: $e');
    }
  }

  // ========== DAILY NOTIFICATION SERVICE ==========

  /// 🔥 MAIN SOLUTION: Timer-based daily notifications
  static Future<void> startDailyNotifications(List<TimeOfDay> times) async {
    try {
      print('🔄 STARTING DAILY NOTIFICATION SERVICE...');
      print('⏰ Monitoring ${times.length} time(s): ${_formatTimes(times)}');
      
      _notificationTimer?.cancel();
      _activeTimes.clear();
      _activeTimes.addAll(times);
      
      // Check immediately and then every minute
      await _checkAndSendNotifications();
      
      _notificationTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
        await _checkAndSendNotifications();
      });
      
      print('✅ DAILY NOTIFICATION SERVICE STARTED!');
      
    } catch (e) {
      print('❌ DAILY SERVICE FAILED: $e');
    }
  }

  /// Check current time against scheduled times
  static Future<void> _checkAndSendNotifications() async {
    try {
      final now = DateTime.now();
      final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);
      
      // Check if notifications are enabled globally
      final notificationsEnabled = await NotificationTimeManager.getNotificationsEnabled();
      if (!notificationsEnabled) {
        return;
      }
      
      for (final scheduledTime in _activeTimes) {
        if (currentTime.hour == scheduledTime.hour && 
            currentTime.minute == scheduledTime.minute) {
          
          print('🎯 TIME MATCH! ${_formatTime(scheduledTime)} - Sending notification...');
          await _sendScheduledNotification(scheduledTime);
          break; // Only send one per minute
        }
      }
      
    } catch (e) {
      print('❌ CHECK FAILED: $e');
    }
  }

  static Future<void> _sendScheduledNotification(TimeOfDay scheduledTime) async {
    try {
      final content = await generatePersonalizedContent();
      
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '🌟 Daily Motivation',
        content,
        _getNotificationDetails(),
      );
      
      await _saveNotificationToFirestore(content, 'daily');
      print('✅ SCHEDULED NOTIFICATION SENT for ${_formatTime(scheduledTime)}');
      
    } catch (e) {
      print('❌ SCHEDULED NOTIFICATION FAILED: $e');
    }
  }

  // ========== SYSTEM SCHEDULED NOTIFICATIONS ==========

  /// Update scheduled notifications using system scheduler
  static Future<void> updateScheduledNotifications() async {
    try {
      print('🔄 UPDATING SYSTEM SCHEDULED NOTIFICATIONS...');
      
      await _notifications.cancelAll();
      
      final notificationsEnabled = await NotificationTimeManager.getNotificationsEnabled();
      if (!notificationsEnabled) {
        print('🔕 Notifications are disabled globally');
        return;
      }
      
      final notificationTimes = await NotificationTimeManager.getNotificationTimes();
      print('📅 Found ${notificationTimes.length} notification times');
      
      int scheduledCount = 0;
      
      for (int i = 0; i < notificationTimes.length; i++) {
        final timeOption = notificationTimes[i];
        
        if (timeOption.enabled) {
          await _scheduleSystemNotification(timeOption, i);
          scheduledCount++;
        }
      }
      
      print('✅ Successfully scheduled $scheduledCount system notifications');
      await _saveNotificationScheduleToFirestore(notificationTimes);
      
    } catch (e) {
      print('❌ SYSTEM SCHEDULING ERROR: $e');
    }
  }

  /// Schedule using system notification scheduler
  static Future<void> _scheduleSystemNotification(NotificationTimeOption timeOption, int id) async {
    try {
      final now = DateTime.now();
      
      var scheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
        timeOption.time.hour,
        timeOption.time.minute,
      );

      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

      print('🕐 System scheduling notification $id for ${_formatTime(timeOption.time)}');

      final content = await generatePersonalizedContent();
      
      await _notifications.zonedSchedule(
        id,
        '🌟 Daily Motivation',
        content,
        tzScheduledTime,
        _getNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      print('✅ System notification $id scheduled successfully');

    } catch (e) {
      print('❌ SYSTEM SCHEDULING FAILED for $id: $e');
    }
  }

  // ========== CONTENT GENERATION ==========

  /// Generate personalized content using Gemini API
  static Future<String> generatePersonalizedContent() async {
    try {
      final userAnalysis = await _getUserAnalysis();
      
      String prompt;
      
      if (userAnalysis == null) {
        prompt = "Create a short, uplifting motivational message. Keep it positive and inspiring (max 60 words).";
      } else {
        final mentalCondition = userAnalysis['mental_condition'] ?? {};
        final interests = userAnalysis['interests'] ?? {};
        final summary = userAnalysis['summary'] ?? '';

        prompt = """
Based on this user analysis, create a personalized motivational message:

User Mental State: ${mentalCondition['overall_assessment'] ?? 'Not specified'}
Current Mood: ${mentalCondition['mood_patterns'] ?? 'Not specified'}
Interests: ${interests['topics'] ?? 'Not specified'}
Summary: $summary

Create a short, uplifting motivational quote or message (max 60 words).
""";
      }

      final content = Content.text(prompt);
      final response = await _model.generateContent([content]);
      
      return response.text?.trim() ?? _getFallbackMessage();
      
    } catch (e) {
      print('❌ CONTENT GENERATION ERROR: $e');
      return _getFallbackMessage();
    }
  }

  /// Get user analysis from Firestore
  static Future<Map<String, dynamic>?> _getUserAnalysis() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final doc = await FirebaseFirestore.instance
          .collection('userAnalysis')
          .doc(user.uid)
          .get();

      return doc.data();
    } catch (e) {
      print('❌ USER ANALYSIS ERROR: $e');
      return null;
    }
  }

  /// Fallback messages
  static String _getFallbackMessage() {
    final messages = [
      "You're doing great! Keep moving forward and believe in yourself. 🌟",
      "Every small step counts. You're making progress every single day! 💪",
      "Your journey is unique and amazing. Trust the process! ✨",
      "You have so much potential. Keep going and never give up! 🚀",
      "Today is a new opportunity to shine. Make it count! 🌈",
    ];
    return messages[DateTime.now().millisecond % messages.length];
  }

  /// Send fallback notification if main method fails
  static Future<void> _sendFallbackNotification() async {
    try {
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '💫 Motivation',
        _getFallbackMessage(),
        _getNotificationDetails(),
      );
    } catch (e) {
      print('❌ FALLBACK ALSO FAILED: $e');
    }
  }

  // ========== FIREBASE INTEGRATION ==========

  /// Save FCM token to user document
  static Future<void> saveFCMToken(String? token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': token,
          'fcmTokenUpdated': FieldValue.serverTimestamp(),
        });
        print('💾 FCM token saved to user document');
      }
    } catch (e) {
      print('❌ FCM TOKEN SAVE ERROR: $e');
    }
  }

  /// Save notification to Firestore
  static Future<void> _saveNotificationToFirestore(String content, String type) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('userNotifications')
            .doc(user.uid)
            .collection('notifications')
            .add({
          'content': content,
          'timestamp': FieldValue.serverTimestamp(),
          'type': type,
          'title': type == 'manual' ? '💫 Quick Motivation' : '🌟 Daily Motivation',
          'read': false,
        });
        print('💾 Notification saved to Firestore');
      }
    } catch (e) {
      print('❌ FIRESTORE SAVE ERROR: $e');
    }
  }

  /// Save notification schedule to Firestore
  static Future<void> _saveNotificationScheduleToFirestore(List<NotificationTimeOption> times) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final enabledTimes = times.where((time) => time.enabled).map((time) => 
          '${time.time.hour}:${time.time.minute.toString().padLeft(2, '0')}'
        ).toList();
        
        await FirebaseFirestore.instance
            .collection('notificationSchedules')
            .doc(user.uid)
            .set({
          'scheduledTimes': enabledTimes,
          'lastUpdated': FieldValue.serverTimestamp(),
          'notificationsEnabled': true,
        });

        print('💾 Notification schedule saved to Firestore');
      }
    } catch (e) {
      print('❌ SCHEDULE SAVE ERROR: $e');
    }
  }

  // ========== NOTIFICATION MANAGEMENT ==========

  /// Get notification details
  static NotificationDetails _getNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'motivation_channel',
        'Motivation Notifications',
        channelDescription: 'Daily motivational quotes and reminders',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        colorized: true,
        autoCancel: true,
      ),
      iOS: DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Get notification history
  static Stream<QuerySnapshot> getNotificationHistory() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return const Stream.empty();
      
      return FirebaseFirestore.instance
          .collection('userNotifications')
          .doc(user.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .snapshots();
    } catch (e) {
      print('❌ HISTORY ERROR: $e');
      return const Stream.empty();
    }
  }

  /// Clear all notifications from Firestore
  static Future<void> clearAllNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final batch = FirebaseFirestore.instance.batch();
        final notifications = await FirebaseFirestore.instance
            .collection('userNotifications')
            .doc(user.uid)
            .collection('notifications')
            .get();

        for (final doc in notifications.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();
        print('🗑️ All notifications cleared from Firestore');
      }
    } catch (e) {
      print('❌ CLEAR ERROR: $e');
    }
  }

  /// Cancel all scheduled notifications
  static Future<void> cancelAllScheduledNotifications() async {
    try {
      await _notifications.cancelAll();
      print('🚫 All scheduled notifications cancelled');
    } catch (e) {
      print('❌ CANCEL ERROR: $e');
    }
  }

  // ========== STATUS & DEBUGGING ==========

  /// Check notification status
  static Future<void> checkNotificationStatus() async {
    try {
      final settings = await _firebaseMessaging.getNotificationSettings();
      print('📱 Notification settings: ${settings.authorizationStatus}');
      
      final pending = await _notifications.pendingNotificationRequests();
      print('📋 Pending notifications: ${pending.length}');
      
      final notificationTimes = await NotificationTimeManager.getNotificationTimes();
      final enabledTimes = notificationTimes.where((time) => time.enabled).length;
      print('⏰ Configured notification times: ${notificationTimes.length} (${enabledTimes} enabled)');
      
      print('🕐 Active timer times: ${_activeTimes.length}');
      print('⏰ Timer running: ${_notificationTimer != null}');
      
    } catch (e) {
      print('❌ STATUS CHECK ERROR: $e');
    }
  }

  /// Force reschedule all notifications
  static Future<void> forceRescheduleNotifications() async {
    print('🔄 Force rescheduling all notifications...');
    await updateScheduledNotifications();
  }

  /// Send test scheduled notification
  static Future<void> sendTestScheduledNotification() async {
    try {
      final scheduledTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
      
      await _notifications.zonedSchedule(
        9999,
        '🧪 Test Scheduled Notification',
        'This is a test scheduled notification! It should appear in 1 minute.',
        scheduledTime,
        _getNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      
      print('✅ Test scheduled notification set for 1 minute');
      
    } catch (e) {
      print('❌ TEST SCHEDULED ERROR: $e');
    }
  }

  // ========== MANAGEMENT METHODS ==========

  /// Stop all notifications
  static void stopAll() {
    _notificationTimer?.cancel();
    _notifications.cancelAll();
    _activeTimes.clear();
    print('🛑 ALL NOTIFICATIONS STOPPED');
  }

  /// Restart with new times
  static Future<void> restartWithNewTimes(List<TimeOfDay> times) async {
    stopAll();
    await startDailyNotifications(times);
  }

  // ========== HELPER METHODS ==========

  static String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  static String _formatTimes(List<TimeOfDay> times) {
    return times.map(_formatTime).join(', ');
  }

  // ========== PUBLIC GETTERS ==========

  bool get isInitialized => _isInitialized;
  bool get isRunning => _notificationTimer != null;
  List<TimeOfDay> get activeTimes => List.unmodifiable(_activeTimes);
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('📱 Handling background message: ${message.messageId}');
}