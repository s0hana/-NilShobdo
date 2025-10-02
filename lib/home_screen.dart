import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'chat_sceen.dart';
import 'theme_manager.dart';
import 'exercise_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HomeScreen({super.key, required this.userData});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> motivationalMessages = [
    "Believe in yourself! 💪",
    "Every day is a fresh start 🌅",
    "Stay positive, work hard, make it happen ✨",
    "Little progress each day adds up to big results 📈",
  ];

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

  ImageProvider _getProfileImage() {
    // First check if base64 image exists
    if (widget.userData['profilePictureBase64'] != null) {
      try {
        final base64String = widget.userData['profilePictureBase64'];
        final bytes = base64Decode(base64String);
        return MemoryImage(bytes);
      } catch (e) {
        print('Error decoding base64 image: $e');
        // If base64 decoding fails, fall back to other options
      }
    }
    
    // Then check if network URL exists
    if (widget.userData['photoURL'] != null) {
      return NetworkImage(widget.userData['photoURL']);
    }
    
    // Finally use default asset image
    return const AssetImage('assets/images/user_photo.png');
  }

  @override
  Widget build(BuildContext context) {
    final randomMessage = motivationalMessages[Random().nextInt(motivationalMessages.length)];

    final userName = widget.userData['fullName'] ?? 'User'; 
    final email = widget.userData['email'] ?? ' ';   

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
              // Top Bar with theme colors
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                      icon: const Icon(Icons.settings, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, "/set");
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_none, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, '/note');
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 60),

              // Welcome Message
              Center(
                child: Column(
                  children: [
                    // Profile Photo with proper base64 handling
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _currentTheme.primary,
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 38,
                        backgroundColor: _currentTheme.containerColor,
                        backgroundImage: _getProfileImage(),
                        child: widget.userData['profilePictureBase64'] == null && 
                               widget.userData['photoURL'] == null
                            ? Icon(
                                Icons.person,
                                size: 40,
                                color: _currentTheme.primary.withOpacity(0.5),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Hi, $userName!\nWelcome Back!",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email,
                      style: const TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 200),

                    // Motivational Message Box with theme container color
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          color: _currentTheme.containerColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                          child: Text(
                            randomMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Bottom Navigation Bar with theme colors
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
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(userData: widget.userData),
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
                      icon: const Icon(Icons.fitness_center, size: 30, color: Colors.black),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecommendationsScreen(
                              p_userData: widget.userData, 
                              userId: 'AYPqR0TqB4cjbZeofNIPYAOTtWO2'
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.account_circle_outlined, size: 30, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, '/profile');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.people, size: 30, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, '/pro');
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
}