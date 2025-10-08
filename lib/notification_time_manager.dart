import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:convert';


class NotificationTimeOption {
  final String label;
  final TimeOfDay time;
  final bool enabled;

  NotificationTimeOption({
    required this.label,
    required this.time,
    required this.enabled,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'hour': time.hour,
    'minute': time.minute,
    'enabled': enabled,
  };

  factory NotificationTimeOption.fromJson(Map<String, dynamic> json) {
    return NotificationTimeOption(
      label: json['label'],
      time: TimeOfDay(hour: json['hour'], minute: json['minute']),
      enabled: json['enabled'],
    );
  }
}

class NotificationTimeManager {
  static const String _notificationTimesKey = 'notification_times';
  static const String _notificationsEnabledKey = 'notifications_enabled';

  // Default notification times
  static List<NotificationTimeOption> get defaultNotificationTimes => [
    NotificationTimeOption(
      label: '🌅',
      time: const TimeOfDay(hour: 9, minute: 0),
      enabled: true,
    ),
    NotificationTimeOption(
      label: '☀️',
      time: const TimeOfDay(hour: 14, minute: 0),
      enabled: true,
    ),
    NotificationTimeOption(
      label: '🌇',
      time: const TimeOfDay(hour: 19, minute: 0),
      enabled: true,
    ),
  ];

  // Save notification times
  static Future<void> saveNotificationTimes(List<NotificationTimeOption> times) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> timesJson = times.map((time) => jsonEncode(time.toJson())).toList();
    await prefs.setStringList(_notificationTimesKey, timesJson);
  }

  // Get notification times
  static Future<List<NotificationTimeOption>> getNotificationTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? timesJson = prefs.getStringList(_notificationTimesKey);
    
    if (timesJson == null) {
      // Return default times if none saved
      return defaultNotificationTimes;
    }

    return timesJson.map((json) {
      final Map<String, dynamic> data = jsonDecode(json);
      return NotificationTimeOption.fromJson(data);
    }).toList();
  }

  // Save notifications enabled state
  static Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
  }

  // Get notifications enabled state
  static Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true; // Default to enabled
  }

  // Add a new notification time
  static Future<void> addNotificationTime(NotificationTimeOption newTime) async {
    final List<NotificationTimeOption> currentTimes = await getNotificationTimes();
    currentTimes.add(newTime);
    await saveNotificationTimes(currentTimes);
  }

  // Update a notification time
  static Future<void> updateNotificationTime(int index, NotificationTimeOption updatedTime) async {
    final List<NotificationTimeOption> currentTimes = await getNotificationTimes();
    if (index >= 0 && index < currentTimes.length) {
      currentTimes[index] = updatedTime;
      await saveNotificationTimes(currentTimes);
    }
  }

  // Remove a notification time
  static Future<void> removeNotificationTime(int index) async {
    final List<NotificationTimeOption> currentTimes = await getNotificationTimes();
    if (index >= 0 && index < currentTimes.length) {
      currentTimes.removeAt(index);
      await saveNotificationTimes(currentTimes);
    }
  }
}