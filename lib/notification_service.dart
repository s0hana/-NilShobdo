// notification_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  static const String geminiApiKey = 'AIzaSyBSx-y5UfkQ8XlFGjFB5jDJHkmWI0Is-wQ';
  static late GenerativeModel _model;

  bool _isInitialized = false;

  // Initialize the notification service
  static Future<void> initialize() async {
    try {
      tz.initializeTimeZones();
      
      // Initialize Gemini model
      _model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: geminiApiKey,
      );

      // Request notification permissions
      final NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      print('Notification permission: ${settings.authorizationStatus}');

      // Initialize local notifications
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

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          print('Notification tapped: ${response.payload}');
        },
      );

      // Create notification channel
      await _createNotificationChannel();

      // Get FCM token
      final String? token = await _firebaseMessaging.getToken();
      print('FCM Token: $token');

      // Start scheduled notifications
      await _startScheduledNotifications();

      _instance._isInitialized = true;
      print('Notification service initialized successfully');
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }

  static Future<void> updateScheduledNotifications() async {
    try {
      print('🔄 Updating scheduled notifications...');
      
      // Cancel existing notifications
      await _notificationsPlugin.cancelAll();
      
      // Check if notifications are enabled
      final prefs = await SharedPreferences.getInstance();
      final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      
      if (!notificationsEnabled) {
        print('🔕 Notifications are disabled, cancelling all scheduled notifications');
        return;
      }
      
      // Get saved notification times
      final notificationTimes = await getNotificationTimes();
      
      print('📅 Found ${notificationTimes.length} notification times to schedule');
      
      // Schedule notifications
      for (int i = 0; i < notificationTimes.length; i++) {
        await _scheduleDailyNotification(notificationTimes[i], i);
      }
      
      // Verify scheduling by checking pending notifications
      final pending = await getPendingNotifications();
      print('✅ Scheduled ${pending.length} notifications successfully');
      
    } catch (e) {
      print('❌ Error updating scheduled notifications: $e');
    }
  }

  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'motivation_channel',
      'Motivation & Recommendations',
      description: 'Personalized motivational quotes and recommendations',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Public method to show local notifications
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    try {
      final notificationId = id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
      
      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'motivation_channel',
            'Motivation & Recommendations',
            channelDescription: 'Personalized motivational quotes and recommendations',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        payload: payload,
      );
      print('📲 Local notification shown: $title');
    } catch (e) {
      print('❌ Error showing local notification: $e');
    }
  }

  // Generate personalized content using Gemini API
  static Future<String> generatePersonalizedContent() async {
    try {
      final userAnalysis = await _getUserAnalysis();
      
      String prompt;
      
      if (userAnalysis == null) {
        prompt = "Create a short, uplifting motivational message for someone who needs encouragement. Keep it positive and inspiring (max 80 words).";
      } else {
        // Extract key information from user analysis
        final mentalCondition = userAnalysis['mental_condition'] ?? {};
        final interests = userAnalysis['interests'] ?? {};
        final summary = userAnalysis['summary'] ?? '';

        prompt = """
Based on this user analysis, create a personalized motivational message:

User Mental State: ${mentalCondition['overall_assessment'] ?? 'Not specified'}
Current Mood: ${mentalCondition['mood_patterns'] ?? 'Not specified'}
Interests: ${interests['topics'] ?? 'Not specified'}
Summary: $summary

Create a short, uplifting motivational quote or message (max 80 words). Make it empathetic and tailored to their current situation. Be supportive and encouraging.
""";
      }

      print('🤖 Generating AI content...');
      
      final content = Content.text(prompt);
      final response = await _model.generateContent([content]);
      
      final generatedText = response.text ?? "You're doing amazing! Keep up the great work! 🌟";
      print('✅ Generated content: $generatedText');
      
      return generatedText;
      
    } catch (e) {
      print('❌ Error generating content: $e');
      // Fallback messages
      final fallbackMessages = [
        "You're doing great! Take a moment to appreciate how far you've come. 🌟",
        "Small progress is still progress. Keep moving forward! 💪",
        "Your journey is unique and beautiful. Trust the process. ✨",
        "Every day is a new opportunity to grow and learn. 🌱",
        "You have the strength to overcome any challenge. Believe in yourself! 🚀",
      ];
      final selectedMessage = fallbackMessages[DateTime.now().millisecondsSinceEpoch % fallbackMessages.length];
      return selectedMessage;
    }
  }

  // Start scheduled notifications
  static Future<void> _startScheduledNotifications() async {
    try {
      await updateScheduledNotifications();
    } catch (e) {
      print('❌ Error starting scheduled notifications: $e');
    }
  }

  static Future<void> _scheduleDailyNotification(TimeOfDay time, int id) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      // If the time has passed today, schedule for tomorrow
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
        print('⏰ Time passed, scheduling for tomorrow');
      }

      print('🕐 Scheduling notification $id for ${time.hour}:${time.minute.toString().padLeft(2, '0')}');
      print('📅 Scheduled for: $scheduledTime');

      // Generate content for the notification
      final content = await generatePersonalizedContent();

      // Schedule the notification
      await _notificationsPlugin.zonedSchedule(
        id,
        '🌟 Daily Motivation',
        content,
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'motivation_channel',
            'Motivation & Recommendations',
            channelDescription: 'Personalized motivational quotes and recommendations',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            colorized: true,
          ),
        ),
        //uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'scheduled_$id',
      );

      // Save to Firestore
      await _saveScheduledNotificationToFirestore(content, time, scheduledTime);

      print('✅ Notification $id scheduled successfully');

    } catch (e) {
      print('❌ Error scheduling notification $id: $e');
      
      // Fallback: Try without AI content
      try {
        final now = tz.TZDateTime.now(tz.local);
        var scheduledTime = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          time.hour,
          time.minute,
        );

        if (scheduledTime.isBefore(now)) {
          scheduledTime = scheduledTime.add(const Duration(days: 1));
        }

        await _notificationsPlugin.zonedSchedule(
          id,
          '🌟 Daily Motivation',
          "Your daily dose of motivation is here! 💫",
          scheduledTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'motivation_channel',
              'Motivation & Recommendations',
              channelDescription: 'Personalized motivational quotes and recommendations',
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
              enableVibration: true,
            ),
          ),
          //uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'scheduled_fallback_$id',
        );
        
        print('✅ Fallback notification $id scheduled');
      } catch (e2) {
        print('❌ Even fallback scheduling failed: $e2');
      }
    }
  }

  // Save scheduled notification to Firestore for tracking
  static Future<void> _saveScheduledNotificationToFirestore(String content, TimeOfDay time, tz.TZDateTime scheduledTime) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('scheduledNotifications')
            .doc(user.uid)
            .collection('upcoming')
            .add({
          'content': content,
          'scheduledTime': scheduledTime.toUtc().millisecondsSinceEpoch,
          'displayTime': '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
          'scheduledAt': FieldValue.serverTimestamp(),
          'status': 'scheduled',
        });

        print('💾 Scheduled notification saved to Firestore');
      }
    } catch (e) {
      print('❌ Error saving scheduled notification to Firestore: $e');
    }
  }

  // Manual method to send immediate notification
  static Future<void> sendImmediateMotivation() async {
    try {
      print('🚀 Sending immediate motivation...');
      final content = await generatePersonalizedContent();
      
      await showLocalNotification(
        title: '💫 Quick Motivation',
        body: content,
        payload: 'immediate',
      );
      
      // Save to Firestore
      await _saveNotificationToFirestore(content, 'manual');
      
      print('✅ Immediate motivation sent successfully');
    } catch (e) {
      print('❌ Error sending immediate motivation: $e');
      // Show error notification
      await showLocalNotification(
        title: '💫 Quick Motivation',
        body: "You're doing great! Keep moving forward! 💪",
        payload: 'fallback',
      );
    }
  }

  // Save notification to Firestore
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
      } else {
        print('👤 No user logged in, skipping Firestore save');
      }
    } catch (e) {
      print('❌ Error saving notification to Firestore: $e');
    }
  }

  // Test notification
  static Future<void> sendTestNotification() async {
    try {
      await showLocalNotification(
        title: '✅ Test Notification',
        body: 'This is a test notification from Nil Shobdo! If you see this, notifications are working properly. 🎉',
        payload: 'test',
      );
      print('✅ Test notification sent successfully');
    } catch (e) {
      print('❌ Error sending test notification: $e');
    }
  }

  // Test scheduled notification (for immediate testing)
  static Future<void> sendTestScheduledNotification() async {
    try {
      // Schedule a notification for 1 minute from now
      final scheduledTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
      
      final content = "🧪 This is a test scheduled notification! It was scheduled to appear 1 minute after you tapped the button.";
      
      await _notificationsPlugin.zonedSchedule(
        9999, // Special ID for test
        '🧪 Test Scheduled Notification',
        content,
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'motivation_channel',
            'Motivation & Recommendations',
            channelDescription: 'Personalized motivational quotes and recommendations',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        //uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'test_scheduled',
      );
      
      print('✅ Test scheduled notification set for ${scheduledTime.hour}:${scheduledTime.minute}');
      
      // Show immediate confirmation
      await showLocalNotification(
        title: '⏰ Test Scheduled',
        body: 'A test notification is scheduled to appear in 1 minute. Please wait and check!',
        payload: 'test_confirmation',
      );
      
    } catch (e) {
      print('❌ Error sending test scheduled notification: $e');
    }
  }

  // Get notification history
  static Stream<QuerySnapshot> getNotificationHistory() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('👤 No user logged in, returning empty stream');
        return const Stream.empty();
      }
      
      return FirebaseFirestore.instance
          .collection('userNotifications')
          .doc(user.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .snapshots();
    } catch (e) {
      print('❌ Error getting notification history: $e');
      return const Stream.empty();
    }
  }

  // Get user analysis from Firestore
  static Future<Map<String, dynamic>?> _getUserAnalysis() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final doc = await FirebaseFirestore.instance
          .collection('userAnalysis')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        return doc.data();
      } else {
        print('📊 No user analysis found for user: ${user.uid}');
        return null;
      }
    } catch (e) {
      print('❌ Error getting user analysis: $e');
      return null;
    }
  }

  // Clear all notifications from Firestore
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
      print('❌ Error clearing notifications: $e');
    }
  }

  // Cancel all scheduled notifications
  static Future<void> cancelAllScheduledNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      print('🚫 All scheduled notifications cancelled');
    } catch (e) {
      print('❌ Error cancelling scheduled notifications: $e');
    }
  }

  // Get current notification times
  static Future<List<TimeOfDay>> getNotificationTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? timesJson = prefs.getStringList('notification_times');
      
      if (timesJson != null && timesJson.isNotEmpty) {
        final times = timesJson.map((json) {
          final Map<String, dynamic> data = jsonDecode(json);
          return TimeOfDay(hour: data['hour'], minute: data['minute']);
        }).toList();
        
        print('📋 Retrieved ${times.length} notification times from storage');
        return times;
      } else {
        // Return default times
        print('⚙️ Using default notification times');
        return [
          const TimeOfDay(hour: 9, minute: 0),
          const TimeOfDay(hour: 14, minute: 0),
          const TimeOfDay(hour: 19, minute: 0),
        ];
      }
    } catch (e) {
      print('❌ Error getting notification times: $e');
      return [
        const TimeOfDay(hour: 9, minute: 0),
        const TimeOfDay(hour: 14, minute: 0),
        const TimeOfDay(hour: 19, minute: 0),
      ];
    }
  }

  // Check if service is initialized
  bool get isInitialized => _isInitialized;

  // Get pending notifications (for debugging)
  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      print('📋 Found ${pending.length} pending notifications');
      for (var notif in pending) {
        print('   - ID: ${notif.id}, Title: "${notif.title}", Body: "${notif.body}"');
      }
      return pending;
    } catch (e) {
      print('❌ Error getting pending notifications: $e');
      return [];
    }
  }

  // Force reschedule all notifications (for debugging)
  static Future<void> forceRescheduleNotifications() async {
    print('🔄 Force rescheduling all notifications...');
    await updateScheduledNotifications();
  }
}