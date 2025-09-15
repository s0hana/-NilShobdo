import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UpdateEmailScreen extends StatefulWidget {
  const UpdateEmailScreen({super.key});

  @override
  State<UpdateEmailScreen> createState() => _UpdateEmailScreenState();
}

class _UpdateEmailScreenState extends State<UpdateEmailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _realtimeDb = FirebaseDatabase.instance.ref();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _currentEmailController = TextEditingController();
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _verificationSent = false;
  bool _emailUpdated = false;
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentEmail();
  }

  void _loadCurrentEmail() {
    User? user = _auth.currentUser;
    if (user != null && user.email != null) {
      _currentEmailController.text = user.email!;
    }
  }

  Future<void> _updateEmailInDatabases(String oldEmail, String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userId = user.uid;
      
      // Update email in Realtime Database
      final userRealtimeRef = _realtimeDb.child('users').child(userId);
      
      // Check if the user exists in Realtime Database before updating
      final userSnapshot = await userRealtimeRef.get();
      if (userSnapshot.exists) {
        await userRealtimeRef.update({
          'email': newEmail,
          'updatedAt': ServerValue.timestamp,
        });
      }

      // Update email in Firestore
      final userFirestoreRef = _firestore.collection('users').doc(userId);
      
      // Check if the user exists in Firestore before updating
      final userDoc = await userFirestoreRef.get();
      if (userDoc.exists) {
        await userFirestoreRef.update({
          'email': newEmail,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating email in databases: $e');
      // Re-throw the error to handle it in the calling function
      throw e;
    }
  }

  Future<void> _sendEmailVerification() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      User? user = _auth.currentUser;
      
      if (user != null) {
        // Re-authenticate user
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _passwordController.text,
        );
        
        await user.reauthenticateWithCredential(credential);
        
        // Send verification to new email
        await user.verifyBeforeUpdateEmail(_newEmailController.text.trim());
        
        setState(() {
          _verificationSent = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent to your new email address.'),
            duration: Duration(seconds: 5),
          )
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is invalid.';
          break;
        case 'email-already-in-use':
          errorMessage = 'This email is already registered.';
          break;
        case 'requires-recent-login':
          errorMessage = 'This operation requires recent authentication. Please log out and log in again.';
          break;
        default:
          errorMessage = 'An error occurred: ${e.message}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e'))
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkEmailVerified() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Reload user to get latest email verification status
      await _auth.currentUser?.reload();
      User? user = _auth.currentUser;
      
      if (user != null && user.email == _newEmailController.text.trim()) {
        // Update email in both databases
        await _updateEmailInDatabases(_currentEmailController.text, user.email!);
        
        setState(() {
          _emailUpdated = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email successfully verified and updated in all systems!'))
        );
        
        // Start countdown to redirect
        _startRedirectCountdown();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email not yet verified. Please check your inbox.'))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating email: $e'))
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startRedirectCountdown() {
    // Set a timer to redirect after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _redirecting = true;
        });
        _redirectToLogin();
      }
    });
  }

  void _redirectToLogin() {
    // Sign out and navigate to login
    _auth.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _redirectNow() {
    setState(() {
      _redirecting = true;
    });
    _redirectToLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Email'),
        backgroundColor: const Color(0xFF2196F3),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF90CAF9), Color(0xFFBAE0FF)],
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
                  // Header Icon
                  Icon(
                    _emailUpdated ? Icons.check_circle : 
                    _verificationSent ? Icons.mark_email_read : Icons.email,
                    size: 80,
                    color: _emailUpdated ? Colors.green : Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    _redirecting ? 'Logging out...' :
                    _emailUpdated ? 'Email Updated!' :
                    _verificationSent ? 'Verify Your Email' : 'Update Email',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_redirecting) ...[
                    // Redirecting message
                    const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text(
                          'Email updated successfully. Redirecting to login...',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ] else if (_emailUpdated) ...[
                    // Success Message
                    Text(
                      'Your email has been successfully updated to ${_newEmailController.text}. '
                      'You need to login again with your new email address.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    
                    // Redirect Now Button
                    ElevatedButton(
                      onPressed: _redirectNow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Login Now',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ] else if (_verificationSent) ...[
                    // Verification Sent Message
                    Text(
                      'We\'ve sent a verification email to ${_newEmailController.text}. '
                      'Please check your inbox and click the verification link to confirm your new email address.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    
                    // Check Verification Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _checkEmailVerified,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'I\'ve Verified My Email',
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Resend Button
                    OutlinedButton(
                      onPressed: _isLoading ? null : _sendEmailVerification,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Resend Verification',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ] else ...[
                    // Instructions
                    const Text(
                      'To update your email address, we need to verify your identity and send a confirmation to your new email.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    
                    // Current Email Field
                    TextFormField(
                      controller: _currentEmailController,
                      decoration: InputDecoration(
                        labelText: 'Current Email',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white70,
                      ),
                      enabled: false,
                    ),
                    const SizedBox(height: 16),
                    
                    // New Email Field
                    TextFormField(
                      controller: _newEmailController,
                      decoration: InputDecoration(
                        labelText: 'New Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white70,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your new email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        if (value == _currentEmailController.text) {
                          return 'New email must be different from current email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white70,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Send Verification Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _sendEmailVerification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Send Verification Email',
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _currentEmailController.dispose();
    _newEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}