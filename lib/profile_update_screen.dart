import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'theme_manager.dart'; 

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _realtimeDb = FirebaseDatabase.instance.ref();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _fullNameController;
  late TextEditingController _birthdayController;
  late TextEditingController _genderController;
  
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String? _base64Image;
  String? _existingPhotoUrl;

  // Theme variables
  int _currentThemeIndex = 0;
  ColorTheme _currentTheme = ThemeManager.colorThemes[0];

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _fullNameController = TextEditingController();
    _birthdayController = TextEditingController();
    _genderController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadTheme() async {
    final themeIndex = await ThemeManager.getSelectedThemeIndex();
    setState(() {
      _currentThemeIndex = themeIndex;
      _currentTheme = ThemeManager.getCurrentTheme(themeIndex);
    });
  }

  Future<void> _loadUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Load from Firestore
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        
        if (userDoc.exists) {
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _fullNameController.text = data['fullName'] ?? '';
            _birthdayController.text = data['birthday'] ?? '';
            _genderController.text = data['gender'] ?? '';
            _existingPhotoUrl = data['photoURL'];
            _base64Image = data['profilePictureBase64'];
          });
        }
      }
    } catch (e) {
      print("Error loading user data: $e");
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60, // Quality reduce to make file smaller
        maxWidth: 512,
        maxHeight: 512,
      );
      
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        
        // Convert image to base64
        await _convertImageToBase64();
      }
    } catch (e) {
      print("Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  Future<void> _convertImageToBase64() async {
    if (_imageFile == null) return;
    
    try {
      // Read file as bytes
      final bytes = await _imageFile!.readAsBytes();
      
      // Encode to base64
      final base64String = base64Encode(bytes);
      
      setState(() {
        _base64Image = base64String;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Image converted successfully!'),
          backgroundColor: _currentTheme.primary,
        )
      );
    } catch (e) {
      print("Error converting image to base64: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing image: $e'),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  ImageProvider _getImageProvider() {
    if (_imageFile != null) {
      return FileImage(_imageFile!);
    } else if (_base64Image != null) {
      return MemoryImage(base64Decode(_base64Image!));
    } else if (_existingPhotoUrl != null) {
      return NetworkImage(_existingPhotoUrl!);
    } else {
      return const AssetImage('assets/images/user_photo.png');
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Prepare update data for Firestore
        Map<String, dynamic> firestoreData = {
          'fullName': _fullNameController.text,
          'birthday': _birthdayController.text,
          'gender': _genderController.text,
          'updatedAt': FieldValue.serverTimestamp(),
          'email': user.email,
          'uid': user.uid,
        };
        
        // Add base64 image to Firestore if available
        if (_base64Image != null) {
          firestoreData['profilePictureBase64'] = _base64Image;
          firestoreData['hasProfilePicture'] = true;
          firestoreData['profilePictureUpdatedAt'] = FieldValue.serverTimestamp();
        }
        
        // Update Firestore
        await _firestore.collection('users').doc(user.uid).set(
          firestoreData, 
          SetOptions(merge: true)
        );
        
        // Prepare update data for Realtime Database
        Map<String, dynamic> realtimeData = {
          'fullName': _fullNameController.text,
          'birthday': _birthdayController.text,
          'gender': _genderController.text,
          'updatedAt': ServerValue.timestamp,
          'email': user.email,
          'uid': user.uid,
        };
        
        // Add base64 image to Realtime Database if available
        if (_base64Image != null) {
          realtimeData['profilePictureBase64'] = _base64Image;
          realtimeData['hasProfilePicture'] = true;
          realtimeData['profilePictureUpdatedAt'] = ServerValue.timestamp;
        }
        
        // Update Realtime Database
        await _realtimeDb.child('users/${user.uid}').update(realtimeData);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully in both databases!'),
            backgroundColor: _currentTheme.primary,
            duration: const Duration(seconds: 3),
          )
        );
        
        Navigator.pop(context);
      }
    } catch (e) {
      print("Error updating profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        )
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removeProfilePicture() {
    setState(() {
      _imageFile = null;
      _base64Image = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profile picture removed'),
        backgroundColor: _currentTheme.primary,
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Profile'),
        backgroundColor: _currentTheme.primary,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_base64Image != null || _imageFile != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _removeProfilePicture,
              tooltip: 'Remove Profile Picture',
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_currentTheme.gradientStart, _currentTheme.gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // Profile Photo Section
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _currentTheme.primary,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _currentTheme.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 58,
                                backgroundColor: _currentTheme.containerColor,
                                backgroundImage: _getImageProvider(),
                                child: (_base64Image == null && 
                                        _imageFile == null && 
                                        _existingPhotoUrl == null)
                                    ? Icon(
                                        Icons.person,
                                        size: 50,
                                        color: _currentTheme.primary.withOpacity(0.5),
                                      )
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _currentTheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _currentTheme.containerColor,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                  onPressed: _pickImage,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Update Profile Picture',
                          style: TextStyle(
                            color: _currentTheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        if (_base64Image != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Image ready to upload',
                              style: TextStyle(
                                color: _currentTheme.primary,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Full Name Field
                  TextFormField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      labelStyle: TextStyle(
                        color: _currentTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _currentTheme.primary),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _currentTheme.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: _currentTheme.containerColor.withOpacity(0.8),
                      prefixIcon: Icon(Icons.person, color: _currentTheme.primary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      if (value.length < 2) {
                        return 'Name must be at least 2 characters long';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // Birthday Field
                  TextFormField(
                    controller: _birthdayController,
                    decoration: InputDecoration(
                      labelText: 'Birthday (MM/DD/YYYY)',
                      labelStyle: TextStyle(
                        color: _currentTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _currentTheme.primary),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _currentTheme.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: _currentTheme.containerColor.withOpacity(0.8),
                      prefixIcon: Icon(Icons.cake, color: _currentTheme.primary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                    readOnly: true,
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: _currentTheme.primary,
                                onPrimary: Colors.black,
                                surface: _currentTheme.containerColor,
                                onSurface: Colors.black87,
                              ),
                              dialogBackgroundColor: _currentTheme.containerColor,
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _birthdayController.text = 
                            "${pickedDate.month.toString().padLeft(2, '0')}/"
                            "${pickedDate.day.toString().padLeft(2, '0')}/"
                            "${pickedDate.year}";
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // Gender Field
                  TextFormField(
                    controller: _genderController,
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      labelStyle: TextStyle(
                        color: _currentTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _currentTheme.primary),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _currentTheme.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: _currentTheme.containerColor.withOpacity(0.8),
                      prefixIcon: Icon(Icons.people, color: _currentTheme.primary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                    readOnly: true,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              dialogBackgroundColor: _currentTheme.containerColor,
                            ),
                            child: AlertDialog(
                              backgroundColor: _currentTheme.containerColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Text(
                                'Select Gender',
                                style: TextStyle(
                                  color: _currentTheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildGenderOption('Male', Icons.male),
                                  _buildGenderOption('Female', Icons.female),
                                  _buildGenderOption('Other', Icons.transgender),
                                  _buildGenderOption('Prefer not to say', Icons.visibility_off),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  
                  // Update Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentTheme.primary,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      shadowColor: _currentTheme.primary.withOpacity(0.4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 3,
                            ),
                          )
                        : const Text(
                            'Update Profile',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Cancel Button
                  OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _currentTheme.primary,
                      side: BorderSide(color: _currentTheme.primary, width: 2),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderOption(String gender, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: _genderController.text == gender 
          ? _currentTheme.primary.withOpacity(0.15)
          : _currentTheme.containerColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _genderController.text == gender 
              ? _currentTheme.primary 
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: _currentTheme.primary, size: 24),
        title: Text(
          gender,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        onTap: () {
          setState(() {
            _genderController.text = gender;
          });
          Navigator.pop(context);
        },
      ),
    );
  }
  
  @override
  void dispose() {
    _fullNameController.dispose();
    _birthdayController.dispose();
    _genderController.dispose();
    super.dispose();
  }
}