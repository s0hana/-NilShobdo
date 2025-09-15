import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';
import 'chat_sceen.dart';

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

  @override
  void initState() {
    super.initState();
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

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      print("Error signing out: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF90CAF9), Color(0xFFBAE0FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 🔹 Top Container
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF2196F3),
                  border: Border(
                    bottom: BorderSide(color: Colors.blue, width: 2),
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
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: _userData['photoURL'] != null
                                ? NetworkImage(_userData['photoURL'])
                                : const AssetImage('assets/images/user_photo.png') as ImageProvider,
                          ),
                          const SizedBox(width: 16),
                          // Greeting Text
                          Text(
                            "Hi, ${_userData['fullName'] ?? 'User'}!",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
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
                          ),
                          const SizedBox(height: 12),
                          // Email
                          ProfileInfoTile(
                            label: "Email",
                            value: _userData['email'] ?? 'Not set',
                            icon: Icons.email,
                          ),
                          const SizedBox(height: 12),
                          // Birthday
                          ProfileInfoTile(
                            label: "Birthday",
                            value: _userData['birthday'] ?? 'Not set',
                            icon: Icons.cake,
                          ),
                          const SizedBox(height: 12),
                          // Gender
                          ProfileInfoTile(
                            label: "Gender",
                            value: _userData['gender'] ?? 'Not set',
                            icon: _userData['gender']?.toString().toLowerCase() == 'female'
                                ? Icons.female
                                : Icons.male,
                          ),
                          const SizedBox(height: 20),

                          // Update Profile Button
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
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
                              backgroundColor: Colors.blueAccent,
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

                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
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
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _signOut,
                            child: const Text(
                              "Logout",
                              style: TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
              ),

              // 🔹 Bottom Navigation Bar
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF2196F3),
                  border: Border(
                    top: BorderSide(color: Colors.blue, width: 2),
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
                        Navigator.pushNamed(context, '/exercise');
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

// 🔹 Custom Widget for Profile Info
class ProfileInfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const ProfileInfoTile(
      {super.key, required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white70,
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
          Icon(icon, color: Colors.black87),
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