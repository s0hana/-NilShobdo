import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'home_screen.dart';
import 'exercise_screen.dart';
import 'chat_sceen.dart';
import 'theme_manager.dart';
import 'setup_analisis_time_manager.dart';

// Add these imports for notifications
import 'notification_time_manager.dart';
import 'notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late User? _currentUser;
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;

  // Theme variables
  int _currentThemeIndex = 0;
  ColorTheme _currentTheme = ThemeManager.colorThemes[0];

  // Notification variables
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _getUserData();
    _loadNotificationSettings();
  }

  Future<void> _loadTheme() async {
    final themeIndex = await ThemeManager.getSelectedThemeIndex();
    setState(() {
      _currentThemeIndex = themeIndex;
      _currentTheme = ThemeManager.getCurrentTheme(themeIndex);
    });
  }

  Future<void> _loadNotificationSettings() async {
    final enabled = await NotificationTimeManager.getNotificationsEnabled();
    setState(() {
      _notificationsEnabled = enabled;
    });
  }

  Future<void> _getUserData() async {
    try {
      _currentUser = _auth.currentUser;
      if (_currentUser != null) {
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(_currentUser!.uid)
            .get();
            
        if (userDoc.exists) {
          setState(() {
            _userData = userDoc.data() as Map<String, dynamic>;
            _isLoading = false;
          });
        } else {
          // If user document doesn't exist, create one with basic data
          await _firestore.collection('users').doc(_currentUser!.uid).set({
            'fullName': _currentUser!.displayName ?? 'User',
            'email': _currentUser!.email ?? '',
            'photoURL': _currentUser!.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
          });
          
          // Fetch the newly created document
          DocumentSnapshot newUserDoc = await _firestore
              .collection('users')
              .doc(_currentUser!.uid)
              .get();
              
          setState(() {
            _userData = newUserDoc.data() as Map<String, dynamic>;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error fetching user data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  ImageProvider _getProfileImage() {
    // First check if base64 image exists
    if (_userData['profilePictureBase64'] != null) {
      try {
        final base64String = _userData['profilePictureBase64'];
        final bytes = base64Decode(base64String);
        return MemoryImage(bytes);
      } catch (e) {
        print('Error decoding base64 image: $e');
        // If base64 decoding fails, fall back to other options
      }
    }
    
    // Then check if network URL exists
    if (_userData['photoURL'] != null) {
      return NetworkImage(_userData['photoURL']);
    }
    
    // Finally use default asset image
    return const AssetImage('assets/images/user_photo.png');
  }

  // Show Analysis Time Settings Dialog
  Future<void> _showAnalysisTimeSettings() async {
    final result = await showDialog(
      context: context,
      builder: (context) => AnalysisTimeSettingsDialog(primaryColor: _currentTheme.primary),
    );
    
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Analysis time range updated"),
          backgroundColor: _currentTheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Show Notification Time Settings
  Future<void> _showNotificationTimeSettings() async {
    final result = await showDialog(
      context: context,
      builder: (context) => NotificationTimeSettingsDialog(primaryColor: _currentTheme.primary),
    );
    
    if (result == true) {
      // Update scheduled notifications when settings are saved
      await NotificationService.updateScheduledNotifications();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Notification settings updated"),
          backgroundColor: _currentTheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Toggle notifications on/off
  Future<void> _toggleNotifications(bool enabled) async {
    await NotificationTimeManager.setNotificationsEnabled(enabled);
    setState(() {
      _notificationsEnabled = enabled;
    });
    
    // Update scheduled notifications
    if (enabled) {
      await NotificationService.updateScheduledNotifications();
    } else {
      await NotificationService.cancelAllScheduledNotifications();
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(enabled ? "Notifications enabled" : "Notifications disabled"),
        backgroundColor: _currentTheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> settingsOptions = [
      {"icon": Icons.analytics, "title": "Chat Analysis Settings", "onTap": _showAnalysisTimeSettings},
      {
        "icon": Icons.notifications, 
        "title": "Notifications", 
        "onTap": _showNotificationTimeSettings,
        "trailing": Switch(
          value: _notificationsEnabled,
          onChanged: _toggleNotifications,
          activeColor: _currentTheme.primary,
        ),
      },
      {"icon": Icons.color_lens, "title": "Appearance", "route": "/appearance"},
      {"icon": Icons.help_outline, "title": "Help & Support", "route": "/help"},
      {"icon": Icons.lock_outline, "title": "Privacy & Safety", "route": "/privacy"},
      {"icon": Icons.info_outline, "title": "About", "route": "/about"},
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_currentTheme.gradientStart, _currentTheme.gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 🔹 Top Bar with theme colors
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _currentTheme.primary, width: 2),
                  ),
                  color: _currentTheme.primary,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                   
                    const Text(
                      "Settings",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    
                    // 🔹 User Profile Photo in Top Bar
                    _isLoading
                        ? const CircularProgressIndicator()
                        : Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: _currentTheme.containerColor,
                              backgroundImage: _getProfileImage(),
                              child: _userData['profilePictureBase64'] == null && 
                                     _userData['photoURL'] == null
                                  ? Icon(
                                      Icons.person,
                                      size: 20,
                                      color: Colors.black.withOpacity(0.5),
                                    )
                                  : null,
                            ),
                          ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 🔹 User Info Card with theme colors
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: _currentTheme.containerColor,
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _currentTheme.primary,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 23,
                                backgroundColor: _currentTheme.containerColor,
                                backgroundImage: _getProfileImage(),
                                child: _userData['profilePictureBase64'] == null && 
                                       _userData['photoURL'] == null
                                    ? Icon(
                                        Icons.person,
                                        size: 25,
                                        color: _currentTheme.primary.withOpacity(0.5),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _userData['fullName'] ?? 'User',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _userData['email'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  FutureBuilder<AnalysisTimeOption>(
                                    future: AnalysisTimeManager.getSelectedTimeOption(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        return Text(
                                          "Analysis: ${snapshot.data!.label}",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _currentTheme.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        );
                                      }
                                      return const SizedBox();
                                    },
                                  ),
                                  Text(
                                    "Notifications: ${_notificationsEnabled ? 'Enabled' : 'Disabled'}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _currentTheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit, color: _currentTheme.primary),
                              onPressed: () {
                                Navigator.pushNamed(context, '/updateinfo');
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

              const SizedBox(height: 20),

              // 🔹 Settings List with theme colors
              Expanded(
                child: ListView.builder(
                  itemCount: settingsOptions.length,
                  itemBuilder: (context, index) {
                    final option = settingsOptions[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: _currentTheme.containerColor,
                      elevation: 2,
                      child: ListTile(
                        leading: Icon(option["icon"], color: _currentTheme.primary),
                        title: Text(
                          option["title"],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: option["trailing"] ?? Icon(Icons.arrow_forward_ios, size: 16, color: _currentTheme.primary),
                        onTap: () {
                          if (option["onTap"] != null) {
                            option["onTap"]();
                          } else if (option["route"] != null) {
                            Navigator.pushNamed(context, option["route"]);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),

              // 🔹 Sign Out Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 4,
                    ),
                    onPressed: () {
                      _showSignOutDialog();
                    },
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              // 🔹 Bottom Bar with theme colors
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: _currentTheme.primary, width: 2),
                  ),
                  color: _currentTheme.primary,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.home, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HomeScreen(userData: _userData),
                          ),
                        );
                      },
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(userData: _userData),
                          ),
                        );
                      },
                      child: Image.asset(
                        'assets/icons/4616759.png',
                        height: 30,
                        width: 30,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.fitness_center, size: 28, color: Colors.black),
                      onPressed: () {
                       Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecommendationsScreen(pUserData: _userData, userId: _currentUser?.uid ?? 'default_user_id'),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.account_circle_outlined, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, "/profile");
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _currentTheme.containerColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Sign Out',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Are you sure you want to sign out?',
            style: TextStyle(
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: _currentTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _auth.signOut();
                  Navigator.of(context).pop();
                  // Navigate to login screen or home screen
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                } catch (e) {
                  print("Error signing out: $e");
                }
              },
              child: const Text(
                'Sign Out',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Add this new dialog for notification time settings
class NotificationTimeSettingsDialog extends StatefulWidget {
  final Color primaryColor;
  
  const NotificationTimeSettingsDialog({
    super.key,
    required this.primaryColor,
  });

  @override
  State<NotificationTimeSettingsDialog> createState() => _NotificationTimeSettingsDialogState();
}

class _NotificationTimeSettingsDialogState extends State<NotificationTimeSettingsDialog> {
  List<NotificationTimeOption> _notificationTimes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationTimes();
  }

  Future<void> _loadNotificationTimes() async {
    final times = await NotificationTimeManager.getNotificationTimes();
    setState(() {
      _notificationTimes = times;
      _isLoading = false;
    });
  }

  Future<void> _addNewNotificationTime() async {
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      final newTime = NotificationTimeOption(
        label: _getTimeLabel(selectedTime),
        time: selectedTime,
        enabled: true,
      );
      
      await NotificationTimeManager.addNotificationTime(newTime);
      await _loadNotificationTimes();
      
      // Update scheduled notifications
      await NotificationService.updateScheduledNotifications();
    }
  }

  String _getTimeLabel(TimeOfDay time) {
    if (time.hour < 12) {
      return '🌅';
    } else if (time.hour < 17) {
      return '☀️';
    } else {
      return '🌇';
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _toggleNotification(int index, bool enabled) async {
    final updatedTime = NotificationTimeOption(
      label: _notificationTimes[index].label,
      time: _notificationTimes[index].time,
      enabled: enabled,
    );
    
    await NotificationTimeManager.updateNotificationTime(index, updatedTime);
    await _loadNotificationTimes();
    
    // Update scheduled notifications
    await NotificationService.updateScheduledNotifications();
  }

  Future<void> _editNotificationTime(int index) async {
    final currentTime = _notificationTimes[index].time;
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime != null) {
      final updatedTime = NotificationTimeOption(
        label: _getTimeLabel(selectedTime),
        time: selectedTime,
        enabled: _notificationTimes[index].enabled,
      );
      
      await NotificationTimeManager.updateNotificationTime(index, updatedTime);
      await _loadNotificationTimes();
      
      // Update scheduled notifications
      await NotificationService.updateScheduledNotifications();
    }
  }

  Future<void> _deleteNotificationTime(int index) async {
    await NotificationTimeManager.removeNotificationTime(index);
    await _loadNotificationTimes();
    
    // Update scheduled notifications
    await NotificationService.updateScheduledNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        'Notification Settings',
        style: TextStyle(
          color: widget.primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Schedule your daily motivational notifications',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Fixed: Added scrollable content with limited height
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: _notificationTimes.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'No notification times added yet',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _notificationTimes.length,
                            itemBuilder: (context, index) {
                              final timeOption = _notificationTimes[index];
                              
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: Icon(
                                    Icons.access_time,
                                    color: widget.primaryColor,
                                  ),
                                  title: Text(timeOption.label),
                                  subtitle: Text(_formatTime(timeOption.time),
                                   style: const TextStyle(
                                    fontSize: 10,   
                                  ),),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Switch(
                                        value: timeOption.enabled,
                                        onChanged: (value) => _toggleNotification(index, value),
                                        activeColor: widget.primaryColor,
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.edit, color: widget.primaryColor),
                                        onPressed: () => _editNotificationTime(index),
                                      ),
                                      if (_notificationTimes.length > 1)
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _deleteNotificationTime(index),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Time'),
                    onPressed: _addNewNotificationTime,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}