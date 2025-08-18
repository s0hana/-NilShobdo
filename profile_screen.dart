import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
                      icon: const Icon(Icons.settings, size: 28, color: Colors.black),
                      onPressed: () {
                        Navigator.pushNamed(context, "/set");
                      },
                    ),
                    Text(
                      "Profile",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Icon(Icons.more_vert, size: 28, color: Colors.black),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 🔹 User Greeting with Profile Photo
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  child: Row(
    children: [
      // Profile Photo
      CircleAvatar(
        radius: 30,
        backgroundImage: AssetImage('assets/images/user_photo.png'), // user photo path
      ),
      const SizedBox(width: 16),
      // Greeting Text
      const Text(
        "Hi, Rahul!",
        style: TextStyle(
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
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // Full Name
                    ProfileInfoTile(
                      label: "Full Name",
                      value: "Rahul S.",
                      icon: Icons.person,
                    ),
                    const SizedBox(height: 12),
                    // Email
                    ProfileInfoTile(
                      label: "Email",
                      value: "rahul@example.com",
                      icon: Icons.email,
                    ),
                    const SizedBox(height: 12),
                    // Birthday
                    ProfileInfoTile(
                      label: "Birthday",
                      value: "Jan 9, 2004",
                      icon: Icons.cake,
                    ),
                    const SizedBox(height: 12),
                    // Gender
                    ProfileInfoTile(
                      label: "Gender",
                      value: "Male",
                      icon: Icons.male,
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
                      onPressed: () {},
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
                      onPressed: () {},
                      child: const Text(
                        "Change Password",
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
                      onPressed: () {},
                      child: const Text(
                        "Logout",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // 🔹 Bottom Container
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
                      icon: const Icon(Icons.home,
                          size: 30, color: Colors.black),
                      onPressed: () {Navigator.pushNamed(context, '/home');},
                    ),
                    GestureDetector(
                      onTap: () {Navigator.pushNamed(context, '/chat');},
                      child: Image.asset(
                        'assets/icons/4616759.png',
                        height: 30,
                        width: 30,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.fitness_center,
                          size: 30, color: Colors.black),
                      onPressed: () {Navigator.pushNamed(context, '/exercise');},
                    ),
                    
                    GestureDetector(
                      onTap: () {Navigator.pushNamed(context, '/pro');},
                      child: Image.asset(
                        'assets/icons/a.png',
                        height: 30,
                        width: 30,
                        color: Colors.black,
                      ),
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
