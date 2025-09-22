import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'home_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  VerifyEmailScreen({super.key, required this.userData});
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool isEmailVerified = false;
  Timer? timer;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;

  @override
  void initState() {
    super.initState();

    isEmailVerified = _auth.currentUser!.emailVerified;

    if (!isEmailVerified) {
      timer = Timer.periodic(const Duration(seconds: 3), (_) => checkEmailVerified());
    }
  }
 
  Future<void> checkEmailVerified() async {
    await _auth.currentUser!.reload();
    setState(() {
      isEmailVerified = _auth.currentUser!.emailVerified;
    });

    if (isEmailVerified) {
      timer?.cancel();
      
      // Update email verification status in databases
      await _updateEmailVerificationStatus();
      
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(userData: widget.userData),
          ),
);
    }
  }

  Future<void> _updateEmailVerificationStatus() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        // Update Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'emailVerified': true,
          'emailVerifiedAt': DateTime.now().toString(),
        });

        // Update Realtime Database
        DatabaseReference userRef = _realtimeDb.ref().child('users/${user.uid}');
        await userRef.update({
          'emailVerified': true,
          'emailVerifiedAt': DateTime.now().toString(),
        });
      } catch (e) {
        print("Error updating verification status: $e");
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.email, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                "Verify Your Email",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "We have sent a verification link to your email.\nPlease check your inbox.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await _auth.currentUser!.sendEmailVerification();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Verification email resent!")),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error sending email: $e")),
                    );
                  }
                },
                child: const Text("Resend Email"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}