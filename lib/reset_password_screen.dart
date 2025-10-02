import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme_manager.dart'; // Theme manager import করুন

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _emailController = TextEditingController();
  
  bool _isLoading = false;
  bool _emailSent = false;
  bool _redirecting = false;

  // Theme variables
  int _currentThemeIndex = 0;
  ColorTheme _currentTheme = ThemeManager.colorThemes[0];

  @override
  void initState() {
    super.initState();
    _loadTheme();
    // Pre-fill with current user's email if available
    User? user = _auth.currentUser;
    if (user != null && user.email != null) {
      _emailController.text = user.email!;
    }
  }

  Future<void> _loadTheme() async {
    final themeIndex = await ThemeManager.getSelectedThemeIndex();
    setState(() {
      _currentThemeIndex = themeIndex;
      _currentTheme = ThemeManager.getCurrentTheme(themeIndex);
    });
  }

  Future<void> _sendPasswordResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      
      setState(() {
        _emailSent = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Password reset email sent! Check your inbox.'),
          backgroundColor: _currentTheme.primary,
          duration: const Duration(seconds: 5),
        )
      );
      
      // Start countdown to redirect
      _startRedirectCountdown();
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email address.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is invalid.';
          break;
        case 'user-disabled':
          errorMessage = 'This user account has been disabled.';
          break;
        default:
          errorMessage = 'An error occurred: ${e.message}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: Colors.red,
        )
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startRedirectCountdown() {
    // Set a timer to redirect after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _redirecting = true;
        });
        _redirectToLogin();
      }
    });
  }

  void _redirectToLogin() {
    // Navigate to login and remove all previous routes
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
        title: const Text('Reset Password'),
        backgroundColor: _currentTheme.primary,
        foregroundColor: Colors.black,
        elevation: 0,
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
                  // Header Icon
                  Icon(
                    _emailSent ? Icons.mark_email_read : Icons.lock_reset,
                    size: 80,
                    color: _emailSent ? Colors.green : _currentTheme.primary,
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    _redirecting ? 'Redirecting...' :
                    _emailSent ? 'Check Your Email' : 'Reset Password',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_redirecting) ...[
                    // Redirecting message
                    Column(
                      children: [
                        CircularProgressIndicator(
                          color: _currentTheme.primary,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Redirecting to login...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: _currentTheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ] else if (_emailSent) ...[
                    // Success Message Container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _currentTheme.containerColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'We\'ve sent a password reset link to:',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _emailController.text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _currentTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Please check your inbox and follow the instructions to reset your password.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Redirect Now Button
                    ElevatedButton(
                      onPressed: _redirectNow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentTheme.primary,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        'Go to Login Now',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Resend Button
                    OutlinedButton(
                      onPressed: _isLoading ? null : _sendPasswordResetEmail,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _currentTheme.primary,
                        side: BorderSide(
                          color: _currentTheme.primary,
                          width: 2,
                        ),
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: _currentTheme.primary,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Resend Email',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ] else ...[
                    // Instructions Container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _currentTheme.containerColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Enter your email address and we\'ll send you a link to reset your password.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: _currentTheme.primary),
                        prefixIcon: Icon(Icons.email, color: _currentTheme.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _currentTheme.primary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _currentTheme.primary, width: 2),
                        ),
                        filled: true,
                        fillColor: _currentTheme.containerColor,
                        hintText: 'Enter your email address',
                        hintStyle: TextStyle(color: Colors.black54),
                      ),
                      style: const TextStyle(color: Colors.black87),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    
                    // Send Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _sendPasswordResetEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentTheme.primary,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        shadowColor: _currentTheme.primary.withOpacity(0.3),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Send Reset Link',
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
                        side: BorderSide(
                          color: _currentTheme.primary,
                          width: 2,
                        ),
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Additional Help Text
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _currentTheme.containerColor.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: _currentTheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Check your spam folder if you don\'t see the email within a few minutes.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
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
    _emailController.dispose();
    super.dispose();
  }
}