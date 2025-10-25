import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'chat_sceen.dart';
import 'theme_manager.dart';
import 'exercise_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HomeScreen({super.key, required this.userData});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> motivationalMessages = [
    "Believe in yourself, stay focused, and embrace challenges as opportunities💪. Success is built daily through discipline, patience, and consistent effort. Trust your journey, keep learning, and never give up hope.💖",
    "Every sunrise offers a new chance to grow stronger, wiser, and braver🌄. Failure isn't the end but a lesson for tomorrow⏰. Keep moving forward, because persistence always creates amazing victories.👑",
    "Your dreams matter, so protect them with determination and courage. Stay positive, surround yourself with supportive energy, and work consistently🧋. Remember, little daily progress leads to extraordinary transformations over time.🚀",
    "Life becomes meaningful when you believe, act, and persist with confidence.🌟 Challenges may slow you, but strength grows from struggles. Shine brightly, inspire others, and let passion guide your purpose.💝",
    "Great things never come from comfort zones🔥. Dare to step out, explore the unknown, and push your limits. Every risk you take brings you closer to remarkable achievements.🏆",
    "Your future is created by what you do today, not tomorrow⏳. Stay disciplined, stay hopeful, and keep going forward. Hard work today builds the life you've always dreamed of.🌈",
    "Storms make trees take deeper roots🌳. Similarly, challenges make you stronger, wiser, and unshakable. Embrace every obstacle as a teacher, for it prepares you for greater victories ahead.⚡",
    "Don't wait for the perfect moment, create it instead✨. Your determination, passion, and courage can turn ordinary days into extraordinary achievements. Start now, because your best self awaits.🌹",
    "Doubt kills more dreams than failure ever will💭. Replace fear with faith, and watch how doors of opportunity open when you trust yourself and your vision.🌠",
    "Discipline is the bridge between goals and accomplishments🌉. Keep showing up, even on tough days. Small consistent efforts build extraordinary results over time.💎",
    "Happiness is not by chance, but by choice😊. Choose gratitude, kindness, and positivity every day, and your life will bloom beautifully like a garden.🌸",
    "The harder you work for something, the greater you'll feel when you achieve it⚡. Keep grinding, your success story is being written every single day.📖",
    "Opportunities don't happen, you create them🌍. Stay active, curious, and fearless, because your actions shape the future you dream of.✨",
    "Don't compare your journey to others🌱. Focus on your growth, your path, your progress. Flowers bloom at different times, but each shines beautifully in its season.🌻",
    "A river cuts through rock not because of its power, but its persistence💦. Stay steady, never give up, and you'll achieve things once thought impossible.🏔️",
    "Your potential is endless♾️. Don't let doubts or fears limit what you can achieve. Believe, act, and transform your dreams into a beautiful reality.🌠",
    "Success is not final, failure is not fatal; it's the courage to continue that counts🔥. Keep moving, keep learning, and you'll rise stronger every time.🦅",
    "Big journeys begin with small steps👣. Don't underestimate little actions you take daily—they build the foundation for greatness. Stay patient, trust the process, and keep walking forward.🌈",
  ];

  int _currentThemeIndex = 0;
  ColorTheme _currentTheme = ThemeManager.colorThemes[0];
  int _unreadCount = 0;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _setupNotificationListener();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTheme() async {
    final themeIndex = await ThemeManager.getSelectedThemeIndex();
    setState(() {
      _currentThemeIndex = themeIndex;
      _currentTheme = ThemeManager.getCurrentTheme(themeIndex);
    });
  }

  void _setupNotificationListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _notificationSubscription = FirebaseFirestore.instance
          .collection('userNotifications')
          .doc(user.uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .snapshots()
          .listen((snapshot) {
        setState(() {
          _unreadCount = snapshot.docs.length;
        });
      });
    }
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
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_none, size: 28, color: Colors.black),
                          onPressed: () {
                            Navigator.pushNamed(context, '/note');
                          },
                        ),
                        if (_unreadCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
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
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email,
                      style: const TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 90),

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
                              fontSize: 15,
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
                              pUserData: widget.userData, 
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