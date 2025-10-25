import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'verify_email_screen.dart';
import 'home_screen.dart';
import 'theme_manager.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // Form controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _realtimeDb = FirebaseDatabase.instance.ref();

  // Image handling
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  String? _base64Image;
  
  // Form state
  String? _selectedGender;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isImageProcessing = false;

  // Theme
  late ColorTheme _currentTheme;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final themeIndex = await ThemeManager.getSelectedThemeIndex();
    setState(() {
      _currentTheme = ThemeManager.getCurrentTheme(themeIndex);
    });
  }

  // Image picking and processing
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
        maxWidth: 512,
        maxHeight: 512,
      );

      if (pickedFile != null) {
        setState(() {
          _isImageProcessing = true;
        });

        // Check file size
        final file = File(pickedFile.path);
        final stat = await file.stat();
        
        if (stat.size > 2 * 1024 * 1024) { // 2MB limit
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Image size should be less than 2MB'),
              backgroundColor: Colors.red,
            )
          );
          return;
        }

        setState(() {
          _imageFile = file;
        });

        await _convertImageToBase64();
      }
    } catch (e) {
      print("Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: ${e.toString()}'),
          backgroundColor: Colors.red,
        )
      );
    } finally {
      setState(() {
        _isImageProcessing = false;
      });
    }
  }

  Future<void> _convertImageToBase64() async {
    if (_imageFile == null) return;

    try {
      final bytes = await _imageFile!.readAsBytes();
      final base64String = base64Encode(bytes);

      setState(() {
        _base64Image = base64String;
      });

      print("Image converted to base64. Size: ${base64String.length} characters");
    } catch (e) {
      print("Error converting image to base64: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing image: ${e.toString()}'),
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
    } else {
      return const AssetImage('assets/images/user_photo.png');
    }
  }

  void _removeProfilePicture() {
    setState(() {
      _imageFile = null;
      _base64Image = null;
    });
  }

  // Date picker
  Future<void> _pickBirthday() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)), // Default to 18 years ago
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
  }

  // Form validation
  String? _validateFullName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your full name';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters long';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String? _validateBirthday(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please select your birthday';
    }
    return null;
  }

  String? _validateGender(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please select your gender';
    }
    return null;
  }

  // Firebase operations
  Future<void> _saveUserData(User user) async {
    final userData = {
      'uid': user.uid,
      'fullName': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'birthday': _birthdayController.text,
      'gender': _selectedGender,
      'createdAt': FieldValue.serverTimestamp(),
      'emailVerified': user.emailVerified,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Add base64 image data if available
    if (_base64Image != null && _base64Image!.isNotEmpty) {
      userData['profilePictureBase64'] = _base64Image;
      userData['hasProfilePicture'] = true;
      userData['profilePictureUpdatedAt'] = FieldValue.serverTimestamp();
    }

    try {
      // Save to Firestore
      await _firestore.collection('users').doc(user.uid).set(userData);
      print("User data saved to Firestore");

      // Prepare Realtime Database data (convert timestamps)
      Map<String, dynamic> realtimeData = Map.from(userData);
      realtimeData['createdAt'] = ServerValue.timestamp;
      realtimeData['updatedAt'] = ServerValue.timestamp;
      if (_base64Image != null) {
        realtimeData['profilePictureUpdatedAt'] = ServerValue.timestamp;
      }

      // Save to Realtime Database
      await _realtimeDb.child('users/${user.uid}').set(realtimeData);
      print("User data saved to Realtime Database");

    } catch (e) {
      print("Error saving user data: $e");
      rethrow;
    }
  }

  Future<void> _createAccount() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print("Starting account creation...");

      // Create user with email and password
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      print("User created successfully");
      final User user = userCredential.user!;

      // Convert image to base64 if not already done
      if (_imageFile != null && _base64Image == null) {
        await _convertImageToBase64();
      }

      print("Saving user data to databases...");
      await _saveUserData(user);

      print("Sending email verification...");
      await user.sendEmailVerification();

      // Navigate to appropriate screen
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        final snapshot = await _realtimeDb.child("users/${user.uid}").get();
        Map<String, dynamic> userData = {};
        if (snapshot.exists) {
          userData = Map<String, dynamic>.from(snapshot.value as Map);
        }

        if (!user.emailVerified) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VerifyEmailScreen(userData: userData),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(userData: userData),
            ),
          );
        }
      }

    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      print("Error during signup: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('An unexpected error occurred. Please try again.'),
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

  bool _validateForm() {
    return _validateFullName(_fullNameController.text) == null &&
        _validateEmail(_emailController.text) == null &&
        _validatePassword(_passwordController.text) == null &&
        _validateConfirmPassword(_confirmPasswordController.text) == null &&
        _validateBirthday(_birthdayController.text) == null &&
        _validateGender(_selectedGender) == null;
  }

  void _handleAuthError(FirebaseAuthException e) {
    String errorMessage = 'An error occurred. Please try again.';

    switch (e.code) {
      case 'weak-password':
        errorMessage = 'The password provided is too weak.';
        break;
      case 'email-already-in-use':
        errorMessage = 'An account already exists for that email.';
        break;
      case 'invalid-email':
        errorMessage = 'The email address is not valid.';
        break;
      case 'operation-not-allowed':
        errorMessage = 'Email/password accounts are not enabled.';
        break;
      case 'network-request-failed':
        errorMessage = 'Network error. Please check your connection.';
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      )
    );
  }

  void _navigateToLogin() {
    Navigator.pushReplacementNamed(context, '/login');
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
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header Tabs
                  _buildHeaderTabs(),
                  const SizedBox(height: 40),

                  // Profile Photo Section
                  _buildProfilePhotoSection(),
                  const SizedBox(height: 30),

                  // Form Fields
                  _buildFormFields(),
                  const SizedBox(height: 30),

                  // Action Buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _navigateToLogin,
          child: Text(
            "Log in",
            style: TextStyle(
              fontSize: 20,
              color: _currentTheme.primary.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 30),
        Text(
          "Sign up",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _currentTheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePhotoSection() {
    return Column(
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
                child: _isImageProcessing
                    ? CircularProgressIndicator(color: _currentTheme.primary)
                    : (_base64Image == null && _imageFile == null)
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
                  onPressed: _isImageProcessing ? null : _pickImage,
                ),
              ),
            ),
            if (_base64Image != null || _imageFile != null)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _removeProfilePicture,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Profile Picture',
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
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        // Full Name
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
          ),
          style: const TextStyle(color: Colors.black87, fontSize: 16),
          validator: _validateFullName,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        const SizedBox(height: 20),

        // Email
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email',
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
            prefixIcon: Icon(Icons.email, color: _currentTheme.primary),
          ),
          style: const TextStyle(color: Colors.black87, fontSize: 16),
          validator: _validateEmail,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        const SizedBox(height: 20),

        // Birthday
        TextFormField(
          controller: _birthdayController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Birthday',
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
            suffixIcon: Icon(Icons.calendar_today, color: _currentTheme.primary),
          ),
          style: const TextStyle(color: Colors.black87, fontSize: 16),
          onTap: _pickBirthday,
          validator: _validateBirthday,
        ),
        const SizedBox(height: 20),

        // Gender
        DropdownButtonFormField<String>(
          value: _selectedGender,
          items: ['Male', 'Female', 'Other', 'Prefer not to say']
              .map((gender) => DropdownMenuItem(
                    value: gender,
                    child: Text(
                      gender,
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedGender = value;
            });
          },
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
          ),
          validator: _validateGender,
        ),
        const SizedBox(height: 20),

        // Password
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
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
            prefixIcon: Icon(Icons.lock, color: _currentTheme.primary),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: _currentTheme.primary,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
          style: const TextStyle(color: Colors.black87, fontSize: 16),
          validator: _validatePassword,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        const SizedBox(height: 20),

        // Confirm Password
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
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
            prefixIcon: Icon(Icons.lock_outline, color: _currentTheme.primary),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                color: _currentTheme.primary,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
          ),
          style: const TextStyle(color: Colors.black87, fontSize: 16),
          validator: _validateConfirmPassword,
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Sign Up Button
        ElevatedButton(
          onPressed: _isLoading ? null : _createAccount,
          style: ElevatedButton.styleFrom(
            backgroundColor: _currentTheme.primary,
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            shadowColor: _currentTheme.primary.withOpacity(0.4),
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
                  'Create Account',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(height: 16),

        // Login Redirect
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: TextStyle(
                color: _currentTheme.primary.withOpacity(0.8),
              ),
            ),
            GestureDetector(
              onTap: _navigateToLogin,
              child: Text(
                'Log in',
                style: TextStyle(
                  color: _currentTheme.primary,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }
}