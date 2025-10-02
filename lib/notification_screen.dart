import 'package:flutter/material.dart';
import 'theme_manager.dart'; 

class MotivationScreen extends StatefulWidget {
  const MotivationScreen({super.key});

  @override
  State<MotivationScreen> createState() => _MotivationScreenState();
}

class _MotivationScreenState extends State<MotivationScreen> {
  // Theme variables
  int _currentThemeIndex = 0;
  ColorTheme _currentTheme = ThemeManager.colorThemes[0];

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final themeIndex = await ThemeManager.getSelectedThemeIndex();
    setState(() {
      _currentThemeIndex = themeIndex;
      _currentTheme = ThemeManager.getCurrentTheme(themeIndex);
    });
  }

  // Dummy Motivational Quotes
  final List<Map<String, String>> quotes = [
    {
      "text": "Believe in yourself and all that you are.",
      "time": "10:30 AM",
      "date": "18 Aug 2025"
    },
    {
      "text": "Every day is a second chance.",
      "time": "08:15 AM",
      "date": "18 Aug 2025"
    },
    {
      "text": "Push yourself, because no one else will do it for you.",
      "time": "09:00 PM",
      "date": "17 Aug 2025"
    },
    {
      "text": "Small steps every day lead to big results.",
      "time": "05:45 PM",
      "date": "17 Aug 2025"
    },
    {
      "text": "Your only limit is your mind.",
      "time": "04:20 PM",
      "date": "16 Aug 2025"
    },
    {
      "text": "Your only limit is your mind.",
      "time": "04:20 PM",
      "date": "15 Aug 2025"
    },
    {
      "text": "Small steps every day lead to big results.",
      "time": "04:00 AM",
      "date": "15 Aug 2025"
    },
    {
      "text": "Your password was changed.",
      "time": "12:20 AM",
      "date": "14 Aug 2025"
    },
    {
      "text": "Welcome to Nilshobdo! We are here to support you.",
      "time": "1:30 AM",
      "date": "13 Aug 2025"
    },
  ];

  @override
  Widget build(BuildContext context) {
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
                    Text(
                      "Notifications",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, "/set");
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 🔹 Header Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _currentTheme.containerColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _currentTheme.primary.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        size: 40,
                        color: _currentTheme.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Daily Motivation",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _currentTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Your daily dose of inspiration and positive vibes",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 🔹 Quotes List (Scrollable)
              Expanded(
                child: ListView.builder(
                  itemCount: quotes.length,
                  itemBuilder: (context, index) {
                    final quote = quotes[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _currentTheme.containerColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _currentTheme.primary.withOpacity(0.2),
                            width: 1,
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
                                Icon(
                                  Icons.favorite,
                                  color: _currentTheme.primary,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "“${quote["text"]}”",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _currentTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "Motivation",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _currentTheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  "${quote["time"]} | ${quote["date"]}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
                      icon: const Icon(Icons.home, size: 30, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, '/home');
                      },
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/chat');
                      },
                      child: Image.asset(
                        'assets/icons/4616759.png',
                        height: 30,
                        width: 30,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.account_circle_outlined,
                          size: 30, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, '/profile');
                      },
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/exercise');
                      },
                      child: Icon(
                        Icons.fitness_center,
                        size: 30,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // 🔹 Floating Action Button for New Notifications
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add new notification functionality
          _showAddNotificationDialog();
        },
        backgroundColor: _currentTheme.primary,
        foregroundColor: Colors.black,
        elevation: 4,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddNotificationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _currentTheme.containerColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Add Custom Notification",
            style: TextStyle(
              color: _currentTheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Create your own motivational message",
                style: TextStyle(
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _currentTheme.containerColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _currentTheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: _currentTheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Custom notifications coming soon!",
                        style: TextStyle(
                          color: Colors.black87,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "Close",
                style: TextStyle(
                  color: _currentTheme.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}