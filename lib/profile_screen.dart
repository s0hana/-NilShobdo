import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'home_screen.dart';
import 'chat_sceen.dart';
import 'exercise_screen.dart';
import 'theme_manager.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      print("Error signing out: $e");
    }
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
              onPressed: _signOut,
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
              // 🔹 Top Container with theme colors
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _currentTheme.primary,
                  border: Border(
                    bottom: BorderSide(color: _currentTheme.primary, width: 2),
                  ),
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
                      "Profile",
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

              const SizedBox(height: 20),

              // 🔹 User Greeting with Profile Photo
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          // Profile Photo
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _currentTheme.primary,
                                width: 3,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 32,
                              backgroundColor: _currentTheme.containerColor,
                              backgroundImage: _getProfileImage(),
                              child: _userData['profilePictureBase64'] == null && 
                                     _userData['photoURL'] == null
                                  ? Icon(
                                      Icons.person,
                                      size: 35,
                                      color: _currentTheme.primary.withOpacity(0.5),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Greeting Text
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Hi, ${_userData['fullName'] ?? 'User'}!",
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _userData['email'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (_userData['profilePictureBase64'] != null)
                                  Text(
                                    '✓ Profile Picture Saved',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _currentTheme.primary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

              const SizedBox(height: 20),

              // 🔹 User Info Box
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Full Name
                          ProfileInfoTile(
                            label: "Full Name",
                            value: _userData['fullName'] ?? 'Not set',
                            icon: Icons.person,
                            theme: _currentTheme,
                          ),
                          const SizedBox(height: 12),
                          // Email
                          ProfileInfoTile(
                            label: "Email",
                            value: _userData['email'] ?? 'Not set',
                            icon: Icons.email,
                            theme: _currentTheme,
                          ),
                          const SizedBox(height: 12),
                          // Birthday
                          ProfileInfoTile(
                            label: "Birthday",
                            value: _userData['birthday'] ?? 'Not set',
                            icon: Icons.cake,
                            theme: _currentTheme,
                          ),
                          const SizedBox(height: 12),
                          // Gender
                          ProfileInfoTile(
                            label: "Gender",
                            value: _userData['gender'] ?? 'Not set',
                            icon: _userData['gender']?.toString().toLowerCase() == 'female'
                                ? Icons.female
                                : Icons.male,
                            theme: _currentTheme,
                          ),
                          const SizedBox(height: 20),

                          // Update Profile Button
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _currentTheme.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pushNamed(context, '/updateinfo');
                            },
                            child: const Text(
                              "Update Profile",
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Change Password Button
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _currentTheme.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pushNamed(context, '/resetpass');
                            },
                            child: const Text(
                              "Change Password",
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Change Email Button
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _currentTheme.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pushNamed(context, '/resetemail');
                            },
                            child: const Text(
                              "Change E-mail",
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Logout Button
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _showSignOutDialog,
                            child: const Text(
                              "Logout",
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
              ),

              // 🔹 Bottom Navigation Bar with theme colors
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _currentTheme.primary,
                  border: Border(
                    top: BorderSide(color: _currentTheme.primary, width: 2),
                  ),
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
                              pUserData: _userData, 
                              userId: _currentUser?.uid ?? 'AYPqR0TqB4cjbZeofNIPYAOTtWO2'
                            ),
                          ),
                        );
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

// 🔹 Custom Widget for Profile Info with theme support
class ProfileInfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final ColorTheme theme;

  const ProfileInfoTile({
    super.key, 
    required this.label, 
    required this.value, 
    required this.icon,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.containerColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}