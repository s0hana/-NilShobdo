import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'home_screen.dart';
import 'exercise_screen.dart';
import 'chat_sceen.dart';
import 'theme_manager.dart';
import 'setup_analisis_time_manager.dart'; // Add this import

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

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _getUserData();
  }

  Future<void> _loadTheme() async {
    final themeIndex = await ThemeManager.getSelectedThemeIndex();
    setState(() {
      _currentThemeIndex = themeIndex;
      _currentTheme = ThemeManager.getCurrentTheme(themeIndex);
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

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> settingsOptions = [
      {"icon": Icons.analytics, "title": "Chat Analysis Settings", "onTap": _showAnalysisTimeSettings},
      {"icon": Icons.notifications, "title": "Notifications", "route": "/notifications"},
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
                        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: _currentTheme.primary),
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
                            builder: (context) => RecommendationsScreen(p_userData: _userData, userId: 'AYPqR0TqB4cjbZeofNIPYAOTtWO2'),
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

// 🔹 Appearance Settings Screen
class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  State<AppearanceSettingsScreen> createState() => _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  int _selectedThemeIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSelectedTheme();
  }

  Future<void> _loadSelectedTheme() async {
    final index = await ThemeManager.getSelectedThemeIndex();
    setState(() {
      _selectedThemeIndex = index;
    });
  }

  Future<void> _selectTheme(int index) async {
    await ThemeManager.saveSelectedTheme(index);
    setState(() {
      _selectedThemeIndex = index;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${ThemeManager.colorThemes[index].name} theme selected'),
        duration: const Duration(seconds: 2),
        backgroundColor: ThemeManager.colorThemes[index].primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ThemeManager.getCurrentTheme(_selectedThemeIndex);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [currentTheme.gradientStart, currentTheme.gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: currentTheme.primary, width: 2),
                  ),
                  color: currentTheme.primary,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Appearance Settings",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Current Theme Preview
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: currentTheme.containerColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Current Theme: ${currentTheme.name}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [currentTheme.gradientStart, currentTheme.gradientEnd],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: currentTheme.primary),
                          ),
                          child: Center(
                            child: Text(
                              'Preview',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Theme Selection List
              Expanded(
                child: ListView.builder(
                  itemCount: ThemeManager.colorThemes.length,
                  itemBuilder: (context, index) {
                    final theme = ThemeManager.colorThemes[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: theme.containerColor,
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [theme.gradientStart, theme.gradientEnd],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          theme.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: _selectedThemeIndex == index
                            ? Icon(Icons.check_circle, color: theme.primary)
                            : Icon(Icons.radio_button_unchecked, color: theme.primary),
                        onTap: () => _selectTheme(index),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 🔹 Analysis Time Settings Screen
class AnalysisTimeSettingsScreen extends StatefulWidget {
  const AnalysisTimeSettingsScreen({super.key});

  @override
  State<AnalysisTimeSettingsScreen> createState() => _AnalysisTimeSettingsScreenState();
}

class _AnalysisTimeSettingsScreenState extends State<AnalysisTimeSettingsScreen> {
  late AnalysisTimeOption _selectedOption;
  late ColorTheme _currentTheme;

  @override
  void initState() {
    super.initState();
    _loadThemeAndSelectedOption();
  }

  Future<void> _loadThemeAndSelectedOption() async {
    final themeIndex = await ThemeManager.getSelectedThemeIndex();
    final selectedOption = await AnalysisTimeManager.getSelectedTimeOption();
    
    setState(() {
      _currentTheme = ThemeManager.getCurrentTheme(themeIndex);
      _selectedOption = selectedOption;
    });
  }

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
              // Top Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _currentTheme.primary, width: 2),
                  ),
                  color: _currentTheme.primary,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Chat Analysis Settings",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Current Selection Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: _currentTheme.containerColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'Current Analysis Time Range',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _selectedOption.label,
                          style: TextStyle(
                            fontSize: 16,
                            color: _currentTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This determines how far back in time your chat analysis will include.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Time Options List
              Expanded(
                child: ListView.builder(
                  itemCount: AnalysisTimeManager.timeOptions.length,
                  itemBuilder: (context, index) {
                    final option = AnalysisTimeManager.timeOptions[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: _currentTheme.containerColor,
                      child: ListTile(
                        leading: Icon(
                          Icons.access_time,
                          color: _currentTheme.primary,
                        ),
                        title: Text(
                          option.label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: _selectedOption == option
                            ? Icon(Icons.check_circle, color: _currentTheme.primary)
                            : Icon(Icons.radio_button_unchecked, color: _currentTheme.primary),
                        onTap: () async {
                          await AnalysisTimeManager.setSelectedTimeInMinutes(option.minutes);
                          setState(() {
                            _selectedOption = option;
                          });
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Analysis time range set to ${option.label}'),
                              backgroundColor: _currentTheme.primary,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 🔹 Dummy Pages for Navigation
class DummyPage extends StatelessWidget {
  final String title;
  const DummyPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          "This is the $title Page",
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: {
        "/": (context) => const SettingsScreen(),
        "/menu": (context) => const DummyPage(title: "Menu"),
        "/notifications": (context) => const DummyPage(title: "Notifications"),
        "/help": (context) => const DummyPage(title: "Help & Support"),
        "/privacy": (context) => const DummyPage(title: "Privacy & Safety"),
        "/about": (context) => const DummyPage(title: "About"),
        "/home": (context) => const DummyPage(title: "Home"),
        "/exercise": (context) => const DummyPage(title: "Exercise"),
        "/chat": (context) => const DummyPage(title: "Chat"),
        "/profile": (context) => const DummyPage(title: "Profile"),
        "/appearance": (context) => const AppearanceSettingsScreen(),
        "/analysisSettings": (context) => const AnalysisTimeSettingsScreen(), // New route
      },
    );
  }
}