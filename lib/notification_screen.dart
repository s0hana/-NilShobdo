import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme_manager.dart';
import 'notification_service.dart';
import 'home_screen.dart';
import 'exercise_screen.dart';
import 'chat_sceen.dart';
class MotivationScreen extends StatefulWidget {
  const MotivationScreen({super.key});

  @override
  State<MotivationScreen> createState() => _MotivationScreenState();
}

class _MotivationScreenState extends State<MotivationScreen> {
  int _currentThemeIndex = 0;
  ColorTheme _currentTheme = ThemeManager.colorThemes[0];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Stream<QuerySnapshot>? _notificationsStream;
  bool _isLoading = true;
  Map<String, dynamic> _userData = {};
  late User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _setupNotificationsStream();
    _getUserData();
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

  Future<void> _loadTheme() async {
    final themeIndex = await ThemeManager.getSelectedThemeIndex();
    setState(() {
      _currentThemeIndex = themeIndex;
      _currentTheme = ThemeManager.getCurrentTheme(themeIndex);
    });
  }

  void _setupNotificationsStream() {
    setState(() {
      _isLoading = true;
    });
    
    _notificationsStream = NotificationService.getNotificationHistory();
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  // Format timestamp to readable time
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    final dateTime = timestamp.toDate();
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $period';
  }

  // Format timestamp to readable date
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown date';
    final dateTime = timestamp.toDate();
    final day = dateTime.day;
    final month = _getMonthName(dateTime.month);
    final year = dateTime.year;
    return '$day $month $year';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  // Mark notification as read
  Future<void> _markAsRead(String notificationId) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('userNotifications')
            .doc(user.uid)
            .collection('notifications')
            .doc(notificationId)
            .update({'read': true});
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Delete notification
  Future<void> _deleteNotification(String notificationId) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('userNotifications')
            .doc(user.uid)
            .collection('notifications')
            .doc(notificationId)
            .delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Notification deleted"),
              backgroundColor: _currentTheme.primary,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Clear all notifications
  Future<void> _clearAllNotifications() async {
    try {
      await NotificationService.clearAllNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("All notifications cleared"),
            backgroundColor: _currentTheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error clearing notifications: $e');
    }
  }

  // Send motivational notification
  Future<void> _sendMotivationNotification() async {
    try {
      await NotificationService.sendImmediateMotivation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Motivational message sent"),
            backgroundColor: _currentTheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error sending motivation: $e');
    }
  }

  // Refresh notifications
  Future<void> _refreshNotifications() async {
    setState(() {
      _isLoading = true;
    });
    
    await Future.delayed(const Duration(milliseconds: 500));
    _setupNotificationsStream();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _currentTheme.gradientStart,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: _currentTheme.primary, width: 2)),
                color: _currentTheme.primary,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 28, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    "Notifications",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 28, color: Colors.black),
                    onSelected: (value) {
                      if (value == 'clear_all') {
                        _clearAllNotifications();
                      } else if (value == 'send_motivation') {
                        _sendMotivationNotification();
                      } else if (value == 'refresh') {
                        _refreshNotifications();
                      } else if (value == 'settings') {
                        Navigator.pushNamed(context, "/set");
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem<String>(
                        value: 'send_motivation',
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome),
                            SizedBox(width: 8),
                            Text('Send Motivation'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'refresh',
                        child: Row(
                          children: [
                            Icon(Icons.refresh),
                            SizedBox(width: 8),
                            Text('Refresh'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'clear_all',
                        child: Row(
                          children: [
                            Icon(Icons.clear_all),
                            SizedBox(width: 8),
                            Text('Clear All'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'settings',
                        child: Row(
                          children: [
                            Icon(Icons.settings),
                            SizedBox(width: 8),
                            Text('Settings'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _currentTheme.containerColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _currentTheme.primary.withOpacity(0.3), width: 2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications_active, size: 40, color: _currentTheme.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Daily Motivation", style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: _currentTheme.primary,
                          )),
                          const SizedBox(height: 4),
                          Text(
                            "Your motivational messages and notification history",
                            style: TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Notifications List
            Expanded(
              child: _buildNotificationsList(),
            ),

            // Bottom Bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _currentTheme.primary, width: 2)),
                color: _currentTheme.primary,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Icons.home, size: 30, color: Colors.black),
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
                      height: 30, width: 30, color: Colors.black,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.account_circle_outlined, size: 30, color: Colors.black),
                    onPressed: () => Navigator.pushNamed(context, '/profile'),
                  ),
                 IconButton(
                      icon: const Icon(Icons.fitness_center, size: 30, color: Colors.black),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecommendationsScreen(
                              pUserData: _userData, 
                              userId: _currentUser?.uid ?? 'AYPqR0TqB4cjbZeofNIPYAOTtWO2'
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendMotivationNotification,
        backgroundColor: _currentTheme.primary,
        foregroundColor: Colors.black,
        child: const Icon(Icons.auto_awesome),
      ),
    );
  }

  Widget _buildNotificationsList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _currentTheme.primary),
            const SizedBox(height: 16),
            Text(
              "Loading notifications...",
              style: TextStyle(
                color: _currentTheme.primary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _notificationsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState("Error loading notifications");
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        final notifications = snapshot.data?.docs ?? [];

        if (notifications.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          backgroundColor: _currentTheme.primary,
          color: Colors.black,
          onRefresh: _refreshNotifications,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: notifications.length,
            itemBuilder: (context, index) => _buildNotificationItem(notifications[index]),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: _currentTheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: _currentTheme.primary,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshNotifications,
            style: ElevatedButton.styleFrom(
              backgroundColor: _currentTheme.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: _currentTheme.primary),
          const SizedBox(height: 16),
          Text(
            "Loading notifications...",
            style: TextStyle(
              color: _currentTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off,
            size: 64,
            color: _currentTheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              color: _currentTheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your motivational messages will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _sendMotivationNotification,
            style: ElevatedButton.styleFrom(
              backgroundColor: _currentTheme.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Send Motivational Message'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final content = data['content'] ?? 'No content available';
    final timestamp = data['timestamp'] as Timestamp?;
    final title = data['title'] ?? '🌟 Daily Motivation';
    final isRead = data['read'] ?? false;
    final type = data['type'] ?? 'scheduled';

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 30),
      ),
      onDismissed: (direction) => _deleteNotification(doc.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: GestureDetector(
          onTap: () => !isRead ? _markAsRead(doc.id) : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isRead 
                ? _currentTheme.containerColor.withOpacity(0.7)
                : _currentTheme.containerColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isRead
                    ? _currentTheme.primary.withOpacity(0.1)
                    : _currentTheme.primary.withOpacity(0.3),
                width: isRead ? 1 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(2, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_getNotificationIcon(type), color: _currentTheme.primary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _currentTheme.primary,
                        ),
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentTheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                    color: Colors.black87,
                    fontStyle: isRead ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _currentTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getNotificationTypeLabel(type),
                        style: TextStyle(
                          fontSize: 12,
                          color: _currentTheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      "${_formatTime(timestamp)} | ${_formatDate(timestamp)}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'manual': return Icons.touch_app;
      case 'test': return Icons.bug_report;
      default: return Icons.auto_awesome;
    }
  }

  String _getNotificationTypeLabel(String type) {
    switch (type) {
      case 'manual': return 'Quick Motivation';
      case 'test': return 'Test';
      default: return 'Scheduled';
    }
  }
}