import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'home_screen.dart';
import 'chat_sceen.dart';
import 'exercise_screen.dart';
import 'theme_manager.dart';

class MentalHealthProfessionalsPage extends StatefulWidget {
  const MentalHealthProfessionalsPage({super.key});

  @override
  State<MentalHealthProfessionalsPage> createState() => _MentalHealthProfessionalsPageState();
}

class _MentalHealthProfessionalsPageState extends State<MentalHealthProfessionalsPage> {
  // Theme variables
  int _currentThemeIndex = 0;
  ColorTheme _currentTheme = ThemeManager.colorThemes[0];
  
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Data variables
  List<Map<String, dynamic>> doctors = [];
  List<Map<String, dynamic>> organizations = [];
  Map<String, dynamic> _userData = {};
  User? _currentUser;
  bool _isLoading = true;
  bool _showDoctors = true; // Toggle between doctors and organizations

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _getUserData();
    _fetchProfessionals();
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
          });
        }
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  // Function to decode Base64 image
  ImageProvider? _getImageProvider(dynamic photoData) {
    if (photoData == null || photoData.toString().isEmpty) {
      return const AssetImage('assets/default_avatar.png');
    }
    
    try {
      final String photoString = photoData.toString();
      
      // Check if it's a Base64 data URL
      if (photoString.startsWith('data:image/')) {
        // Extract Base64 part from data URL
        final base64String = photoString.split(',').last;
        final bytes = base64.decode(base64String);
        return MemoryImage(bytes);
      }
      // Check if it's a regular URL
      else if (photoString.startsWith('http')) {
        return NetworkImage(photoString);
      }
      // Assume it's raw Base64 without data URL prefix
      else {
        final bytes = base64.decode(photoString);
        return MemoryImage(bytes);
      }
    } catch (e) {
      print("Error decoding image: $e");
      return const AssetImage('assets/default_avatar.png');
    }
  }

  // Function to check if photo data is Base64
  bool _isBase64Photo(dynamic photoData) {
    if (photoData == null || photoData.toString().isEmpty) return false;
    
    final String photoString = photoData.toString();
    return photoString.startsWith('data:image/') || 
           (photoString.length > 100 && !photoString.startsWith('http'));
  }

  Future<void> _fetchProfessionals() async {
    try {
      // Fetch doctors from Realtime Database
      final doctorsSnapshot = await _database.ref('doctors').once();
      final organizationsSnapshot = await _database.ref('organizations').once();

      List<Map<String, dynamic>> doctorsList = [];
      List<Map<String, dynamic>> organizationsList = [];

      if (doctorsSnapshot.snapshot.value != null) {
        final doctorsData = doctorsSnapshot.snapshot.value as Map<dynamic, dynamic>;
        doctorsData.forEach((key, value) {
          doctorsList.add({
            'id': key,
            ...Map<String, dynamic>.from(value as Map<dynamic, dynamic>),
            'type': 'doctor'
          });
        });
      }

      if (organizationsSnapshot.snapshot.value != null) {
        final organizationsData = organizationsSnapshot.snapshot.value as Map<dynamic, dynamic>;
        organizationsData.forEach((key, value) {
          organizationsList.add({
            'id': key,
            ...Map<String, dynamic>.from(value as Map<dynamic, dynamic>),
            'type': 'organization'
          });
        });
      }

      setState(() {
        doctors = doctorsList;
        organizations = organizationsList;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching professionals: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showProfessionalDetails(Map<String, dynamic> professional) {
    final isDoctor = professional['type'] == 'doctor';
    final photoProvider = _getImageProvider(professional['photo']);
    final isBase64 = _isBase64Photo(professional['photo']);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: _currentTheme.containerColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: _currentTheme.primary.withOpacity(0.1),
                    backgroundImage: photoProvider,
                    onBackgroundImageError: (exception, stackTrace) {
                      print("Error loading professional image: $exception");
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          professional['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isDoctor 
                              ? (professional['specialization'] ?? 'Mental Health Professional')
                              : (professional['type'] ?? 'Organization'),
                          style: TextStyle(
                            fontSize: 16,
                            color: _currentTheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isBase64) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _currentTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Base64 Image',
                              style: TextStyle(
                                fontSize: 10,
                                color: _currentTheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (isDoctor) ...[
                          Row(
                            children: [
                              Icon(Icons.work, color: _currentTheme.primary, size: 16),
                              const SizedBox(width: 4),
                              Text(professional['experience'] ?? 'Not specified'),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Icon(Icons.business, color: _currentTheme.primary, size: 16),
                              const SizedBox(width: 4),
                              Text(professional['type'] ?? 'Organization'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                "About",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _currentTheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                professional['description'] ?? 'No description available.',
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 20),
              Text(
                "Contact Information",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _currentTheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              if (professional['contact'] != null) ...[
                Row(
                  children: [
                    Icon(Icons.phone, color: _currentTheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      professional['contact'] as String,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (professional['email'] != null && professional['email'].toString().isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.email, color: _currentTheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      professional['email'] as String,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (professional['location'] != null) ...[
                Row(
                  children: [
                    Icon(Icons.location_on, color: _currentTheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        professional['location'] as String,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              // Social Media Links
              if ((professional['website'] != null && professional['website'].toString().isNotEmpty) ||
                  (professional['facebook'] != null && professional['facebook'].toString().isNotEmpty) ||
                  (professional['linkedin'] != null && professional['linkedin'].toString().isNotEmpty)) ...[
                const SizedBox(height: 16),
                Text(
                  "Social Links",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _currentTheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    if (professional['website'] != null && professional['website'].toString().isNotEmpty)
                      Chip(
                        label: const Text('Website'),
                        backgroundColor: _currentTheme.primary.withOpacity(0.1),
                      ),
                    if (professional['facebook'] != null && professional['facebook'].toString().isNotEmpty)
                      Chip(
                        label: const Text('Facebook'),
                        backgroundColor: _currentTheme.primary.withOpacity(0.1),
                      ),
                    if (professional['linkedin'] != null && professional['linkedin'].toString().isNotEmpty)
                      Chip(
                        label: const Text('LinkedIn'),
                        backgroundColor: _currentTheme.primary.withOpacity(0.1),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showContactDialog(professional);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentTheme.primary,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isDoctor ? "Contact Professional" : "Contact Organization",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showContactDialog(Map<String, dynamic> professional) {
    final isDoctor = professional['type'] == 'doctor';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: _currentTheme.containerColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Contact ${professional['name']}",
            style: TextStyle(
              color: _currentTheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (professional['contact'] != null) ...[
                Text(
                  "Phone: ${professional['contact']}",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
              ],
              if (professional['email'] != null && professional['email'].toString().isNotEmpty) ...[
                Text(
                  "Email: ${professional['email']}",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
              ],
              if (professional['location'] != null) ...[
                Text(
                  "Location: ${professional['location']}",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),
              const Text(
                "Please be respectful and professional when contacting mental health professionals.",
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
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

  Widget _buildProfessionalCard(Map<String, dynamic> professional) {
    final isDoctor = professional['type'] == 'doctor';
    final photoProvider = _getImageProvider(professional['photo']);
    final isBase64 = _isBase64Photo(professional['photo']);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _currentTheme.containerColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _showProfessionalDetails(professional),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: _currentTheme.primary.withOpacity(0.1),
                    backgroundImage: photoProvider,
                    onBackgroundImageError: (exception, stackTrace) {
                      print("Error loading professional image: $exception");
                    },
                  ),
                  if (isBase64)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: _currentTheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'B64',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      professional['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDoctor 
                          ? (professional['specialization'] ?? 'Mental Health Professional')
                          : (professional['type'] ?? 'Organization'),
                      style: TextStyle(
                        fontSize: 14,
                        color: _currentTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      professional['description'] ?? 'No description available.',
                      style: const TextStyle(fontSize: 14, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (isDoctor && professional['experience'] != null) ...[
                      Row(
                        children: [
                          Icon(Icons.work, color: _currentTheme.primary, size: 16),
                          const SizedBox(width: 4),
                          Text(professional['experience']),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (professional['location'] != null) ...[
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: _currentTheme.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              professional['location'] as String,
                              style: const TextStyle(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (professional['contact'] != null) ...[
                      Row(
                        children: [
                          Icon(Icons.phone, size: 16, color: _currentTheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            professional['contact'] as String,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Function to show image in full screen
  void _showFullScreenImage(dynamic photoData) {
    final photoProvider = _getImageProvider(photoData);
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: 400,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: photoProvider ?? const AssetImage('assets/images/user_photo.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
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
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    const Text(
                      "Meet Professionals",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 28, color: Colors.black),
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                        });
                        _fetchProfessionals();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Toggle Buttons for Doctors/Organizations
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _showDoctors ? _currentTheme.primary : Colors.white,
                          foregroundColor: _showDoctors ? Colors.white : Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _showDoctors = true;
                          });
                        },
                        child: const Text('Doctors'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: !_showDoctors ? _currentTheme.primary : Colors.white,
                          foregroundColor: !_showDoctors ? Colors.white : Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _showDoctors = false;
                          });
                        },
                        child: const Text('Organizations'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Header Section
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
                        Icons.medical_services,
                        size: 40,
                        color: _currentTheme.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _showDoctors ? "Professional Doctors" : "Health Organizations",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _currentTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _showDoctors 
                                  ? "Connect with qualified mental health doctors for personalized support"
                                  : "Find mental health organizations and support centers near you",
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

              // Professionals List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : (_showDoctors ? doctors : organizations).isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: _currentTheme.primary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _showDoctors 
                                      ? "No doctors available"
                                      : "No organizations available",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: _currentTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _showDoctors ? doctors.length : organizations.length,
                            itemBuilder: (context, index) {
                              final professional = _showDoctors ? doctors[index] : organizations[index];
                              return _buildProfessionalCard(professional);
                            },
                          ),
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
                        height: 30,
                        width: 30,
                        color: Colors.black,
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
                              userId: _currentUser?.uid ?? 'AYPqR0TqB4cjbZeofNIPYAOTtWO2',
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
      ),
    );
  }
}